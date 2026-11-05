import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/data/repositories/detection_repository_impl.dart';
import 'package:glide/features/detection/domain/entities/detection_result.dart';
import 'package:glide/services/ai/object_detector.dart';
import 'package:glide/services/camera/camera_frame.dart';

import '../../../helpers/fakes.dart';

final _frame = CameraFrame(
  format: FrameFormat.bgra8888,
  width: 1,
  height: 1,
  rotation: 0,
  planes: [FramePlane(bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 4)],
);

class _FakeDetector implements ObjectDetector {
  bool loaded = false;
  int calls = 0;
  Completer<List<RawDetection>>? pending;
  List<RawDetection> next = const [];
  Object? loadError;
  Object? detectError;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> load() async {
    if (loadError case final e?) throw e;
    loaded = true;
  }

  @override
  Future<List<RawDetection>> detect(CameraFrame frame) {
    calls++;
    if (detectError case final e?) return Future.error(e);
    final completer = pending;
    return completer != null ? completer.future : Future.value(next);
  }

  @override
  Future<void> close() async => loaded = false;
}

const _person = RawDetection(
  label: 'person',
  score: 0.9,
  left: 0.4,
  top: 0.25,
  right: 0.6,
  bottom: 0.75,
);

void main() {
  late FakeCameraService camera;
  late _FakeDetector detector;
  late DetectionRepositoryImpl repository;

  setUp(() async {
    camera = FakeCameraService();
    await camera.initialize();
    detector = _FakeDetector();
    repository = DetectionRepositoryImpl(
      camera: camera,
      detector: detector,
      minFrameInterval: Duration.zero,
    );
  });

  test('start loads the model and listens to the camera', () async {
    await repository.start();

    expect(detector.loaded, isTrue);
    expect(camera.frameListener, isNotNull);
  });

  test('turns raw obstacles into detections with a distance', () async {
    detector.next = const [_person];
    await repository.start();
    final result = repository.watchDetections().first;

    camera.emitFrame(_frame);

    final DetectionResult r = await result;
    final d = r.detections.single;
    expect(d.label, 'person');
    expect(d.confidence, closeTo(0.9, 1e-6));
    expect(d.distanceMeters, greaterThan(0));
    expect(r.processingTime.isNegative, isFalse);
  });

  test('drops classes that are not obstacles', () async {
    detector.next = const [
      RawDetection(
        label: 'toothbrush',
        score: 0.9,
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
      ),
    ];
    await repository.start();
    final result = repository.watchDetections().first;

    camera.emitFrame(_frame);

    expect((await result).detections, isEmpty);
  });

  test('drops frames while the detector is busy', () async {
    detector.pending = Completer();
    await repository.start();

    camera
      ..emitFrame(_frame)
      ..emitFrame(_frame)
      ..emitFrame(_frame);

    expect(detector.calls, 1);
    detector.pending!.complete(const []);
    await Future<void>.delayed(Duration.zero);

    detector.pending = null;
    camera.emitFrame(_frame);
    expect(detector.calls, 2);
  });

  test('limits the frame rate to save battery', () async {
    final throttled = DetectionRepositoryImpl(
      camera: camera,
      detector: detector,
      minFrameInterval: const Duration(hours: 1),
    );
    await throttled.start();

    camera.emitFrame(_frame);
    await Future<void>.delayed(Duration.zero);
    camera.emitFrame(_frame);

    expect(detector.calls, 1);
  });

  test('a failed inference is skipped and the next frame still runs', () async {
    detector.detectError = StateError('boom');
    await repository.start();

    camera.emitFrame(_frame);
    await Future<void>.delayed(Duration.zero);
    detector.detectError = null;
    camera.emitFrame(_frame);

    expect(detector.calls, 2);
  });

  test('start surfaces a missing model', () async {
    detector.loadError = StateError('no model');

    expect(repository.start(), throwsStateError);
  });

  test('stop detaches from the camera', () async {
    await repository.start();

    await repository.stop();

    expect(camera.frameListener, isNull);
  });
}
