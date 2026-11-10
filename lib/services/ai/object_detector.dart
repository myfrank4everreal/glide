import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:glide/core/constants/app_constants.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/services/ai/detection_decoder.dart';
import 'package:glide/services/ai/frame_preprocessor.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Raw model output for one object. Coordinates are normalised to 0–1,
/// origin top-left, in the orientation the user sees.
class RawDetection {
  const RawDetection({
    required this.label,
    required this.score,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String label;
  final double score;
  final double left;
  final double top;
  final double right;
  final double bottom;
}

abstract interface class ObjectDetector {
  bool get isLoaded;

  /// Loads the model and labels from assets. Throws [ModelLoadException].
  Future<void> load();

  Future<List<RawDetection>> detect(CameraFrame frame);

  Future<void> close();
}

/// TensorFlow Lite detector for models with standard detection
/// post-processing (e.g. EfficientDet-Lite, SSD MobileNet). Preprocessing and
/// inference run on a long-lived background isolate so the UI never waits.
class TfliteObjectDetector implements ObjectDetector {
  TfliteObjectDetector({
    this.modelAsset = AppConstants.detectorModelAsset,
    this.labelsAsset = AppConstants.detectorLabelsAsset,
    this.minScore = 0.3,
  });

  final String modelAsset;
  final String labelsAsset;

  /// Detections below this are discarded in the worker. User-facing
  /// sensitivity is applied later, on top of this floor.
  final double minScore;

  Interpreter? _interpreter;
  _DetectorWorker? _worker;
  List<String> _labels = const [];

  @override
  bool get isLoaded => _worker != null;

  List<String> get labels => _labels;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    try {
      await _checkNotLfsPointer(modelAsset);
      final interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
      _interpreter = interpreter;
      interpreter.allocateTensors();

      final input = interpreter.getInputTensor(0);
      final shape = input.shape;
      if (shape.length != 4 || shape[0] != 1 || shape[3] != 3) {
        throw FormatException('Expected input [1, h, w, 3], got $shape');
      }
      final floatInput = switch (input.type) {
        TensorType.uint8 => false,
        TensorType.float32 => true,
        final other => throw FormatException('Unsupported input type $other'),
      };
      final layout = resolveOutputLayout([
        for (final t in interpreter.getOutputTensors())
          (name: t.name, shape: t.shape),
      ]);

      final rawLabels = await rootBundle.loadString(labelsAsset);
      _labels = rawLabels
          .split('\n')
          .map((l) => l.trim())
          .toList(growable: false);

      _worker = await _DetectorWorker.spawn(
        _WorkerConfig(
          interpreterAddress: interpreter.address,
          inputHeight: shape[1],
          inputWidth: shape[2],
          floatInput: floatInput,
          layout: layout,
          labels: _labels,
          minScore: minScore,
        ),
      );
    } on Object catch (e) {
      await close();
      throw ModelLoadException('Could not load $modelAsset: $e');
    }
  }

  /// A build made without Git LFS bundles a ~130-byte text pointer instead
  /// of the model. Say so plainly rather than as an interpreter error.
  static Future<void> _checkNotLfsPointer(String asset) async {
    final data = await rootBundle.load(asset);
    if (data.lengthInBytes < 1024) {
      throw FormatException(
        '$asset is only ${data.lengthInBytes} bytes: probably a Git LFS '
        'pointer. Build from a checkout with `git lfs pull`.',
      );
    }
  }

  @override
  Future<List<RawDetection>> detect(CameraFrame frame) {
    final worker = _worker;
    if (worker == null) {
      throw const ModelLoadException('Detector used before load()');
    }
    return worker.run(frame);
  }

  @override
  Future<void> close() async {
    _worker?.dispose();
    _worker = null;
    _interpreter?.close();
    _interpreter = null;
    _labels = const [];
  }
}

class _WorkerConfig {
  const _WorkerConfig({
    required this.interpreterAddress,
    required this.inputWidth,
    required this.inputHeight,
    required this.floatInput,
    required this.layout,
    required this.labels,
    required this.minScore,
  });

  final int interpreterAddress;
  final int inputWidth;
  final int inputHeight;
  final bool floatInput;
  final OutputLayout layout;
  final List<String> labels;
  final double minScore;
}

/// Owns the background isolate. Requests are matched to replies by id.
class _DetectorWorker {
  _DetectorWorker._(this._isolate, this._replies, this._requests);

  final Isolate _isolate;
  final ReceivePort _replies;
  final SendPort _requests;
  final _pending = <int, Completer<List<RawDetection>>>{};
  var _nextId = 0;

  static Future<_DetectorWorker> spawn(_WorkerConfig config) async {
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(_main, (config, replies.sendPort));
    final events = replies.asBroadcastStream();
    final requests = await events.first as SendPort;
    final worker = _DetectorWorker._(isolate, replies, requests);
    events.listen(worker._onReply);
    return worker;
  }

  Future<List<RawDetection>> run(CameraFrame frame) {
    final id = _nextId++;
    final completer = Completer<List<RawDetection>>();
    _pending[id] = completer;
    _requests.send((id, frame));
    return completer.future;
  }

  void _onReply(Object? message) {
    switch (message) {
      case (final int id, final List<RawDetection> detections):
        _pending.remove(id)?.complete(detections);
      case (final int id, final String error):
        _pending.remove(id)?.completeError(StateError(error));
    }
  }

  void dispose() {
    _requests.send(null);
    _replies.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
    for (final c in _pending.values) {
      c.completeError(StateError('Detector closed'));
    }
    _pending.clear();
  }

  static void _main((_WorkerConfig, SendPort) args) {
    final (config, replies) = args;
    final interpreter = Interpreter.fromAddress(config.interpreterAddress);
    final input = interpreter.getInputTensor(0);
    final requests = ReceivePort();
    replies.send(requests.sendPort);

    requests.listen((message) {
      if (message case (final int id, final CameraFrame frame)) {
        try {
          final rgb = frameToRgb(
            frame,
            outWidth: config.inputWidth,
            outHeight: config.inputHeight,
          );
          input.data = config.floatInput
              ? rgbToFloat32(rgb).buffer.asUint8List()
              : rgb;
          interpreter.invoke();
          final outputs = interpreter.getOutputTensors();
          Float32List f(int i) => outputs[i].data.buffer.asFloat32List(
            outputs[i].data.offsetInBytes,
            outputs[i].data.lengthInBytes ~/ 4,
          );
          final layout = config.layout;
          replies.send((
            id,
            decodeDetections(
              boxes: f(layout.boxes),
              classes: f(layout.classes),
              scores: f(layout.scores),
              count: f(layout.count)[0].round(),
              labels: config.labels,
              minScore: config.minScore,
            ),
          ));
        } on Object catch (e) {
          replies.send((id, e.toString()));
        }
      } else {
        requests.close();
      }
    });
  }
}
