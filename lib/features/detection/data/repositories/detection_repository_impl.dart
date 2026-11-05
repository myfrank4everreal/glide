import 'dart:async';

import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/detection_result.dart';
import 'package:glide/features/detection/domain/repositories/detection_repository.dart';
import 'package:glide/features/detection/domain/usecases/distance_estimator.dart';
import 'package:glide/services/ai/object_detector.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:glide/services/camera/camera_service.dart';

class DetectionRepositoryImpl implements DetectionRepository {
  DetectionRepositoryImpl({
    required this._camera,
    required this._detector,
    this._estimator = const DistanceEstimator(),
    this._minFrameInterval = const Duration(milliseconds: 100),
  });

  final CameraService _camera;
  final ObjectDetector _detector;
  final DistanceEstimator _estimator;

  /// Caps processing at ~10 fps. Walking speed doesn't need more, and every
  /// skipped frame saves battery.
  final Duration _minFrameInterval;

  final _results = StreamController<DetectionResult>.broadcast();
  final _sinceLastFrame = Stopwatch();
  var _busy = false;

  @override
  Stream<DetectionResult> watchDetections() => _results.stream;

  @override
  Future<void> start() async {
    await _detector.load();
    _sinceLastFrame.reset();
    await _camera.startFrameStream(_onFrame);
  }

  @override
  Future<void> stop() => _camera.stopFrameStream();

  void _onFrame(CameraFrame frame) {
    if (_busy) return;
    if (_sinceLastFrame.isRunning &&
        _sinceLastFrame.elapsed < _minFrameInterval) {
      return;
    }
    _busy = true;
    _sinceLastFrame
      ..reset()
      ..start();
    unawaited(_process(frame));
  }

  Future<void> _process(CameraFrame frame) async {
    final timer = Stopwatch()..start();
    try {
      final raw = await _detector.detect(frame);
      if (_results.isClosed) return;
      _results.add(
        DetectionResult(
          detections: [
            for (final r in raw)
              if (_estimator.isObstacle(r.label)) _toDetection(r),
          ],
          processingTime: timer.elapsed,
        ),
      );
    } on Object {
      // One bad frame shouldn't stop detection; the next frame retries.
    } finally {
      _busy = false;
    }
  }

  Detection _toDetection(RawDetection r) => Detection(
    label: r.label,
    confidence: r.score,
    left: r.left,
    top: r.top,
    right: r.right,
    bottom: r.bottom,
    distanceMeters: _estimator.estimateMeters(
      label: r.label,
      boxHeight: r.bottom - r.top,
    ),
  );
}
