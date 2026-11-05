import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockController extends Mock implements CameraController {}

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);
const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

void main() {
  late _MockController controller;
  late CameraValue value;
  CameraDescription? createdFor;
  void Function(CameraImage)? imageCallback;

  PluginCameraService serviceWith(List<CameraDescription> cameras) =>
      PluginCameraService(
        loadCameras: () async => cameras,
        createController: (camera) {
          createdFor = camera;
          return controller;
        },
      );

  setUp(() {
    createdFor = null;
    controller = _MockController();
    value = const CameraValue.uninitialized(_back);
    when(() => controller.value).thenAnswer((_) => value);
    when(() => controller.initialize()).thenAnswer((_) async {
      value = value.copyWith(isInitialized: true);
    });
    when(() => controller.dispose()).thenAnswer((_) async {});
    when(() => controller.description).thenReturn(_back);
    when(() => controller.startImageStream(any())).thenAnswer((
      invocation,
    ) async {
      imageCallback =
          invocation.positionalArguments.first as void Function(CameraImage);
      value = value.copyWith(isStreamingImages: true);
    });
    when(() => controller.stopImageStream()).thenAnswer((_) async {
      value = value.copyWith(isStreamingImages: false);
    });
  });

  test('initialize picks the back camera', () async {
    final service = serviceWith([_front, _back]);

    await service.initialize();

    expect(createdFor, _back);
    expect(service.isInitialized, isTrue);
    expect(service.controller, controller);
  });

  test('falls back to the first camera when there is no back camera', () async {
    await serviceWith([_front]).initialize();

    expect(createdFor, _front);
  });

  test('initialize twice only creates one controller', () async {
    final service = serviceWith([_back]);

    await service.initialize();
    await service.initialize();

    verify(() => controller.initialize()).called(1);
  });

  test('throws when the device has no camera', () {
    expect(
      serviceWith([]).initialize(),
      throwsA(isA<CameraUnavailableException>()),
    );
  });

  test('wraps plugin errors and releases the controller', () async {
    when(
      () => controller.initialize(),
    ).thenThrow(CameraException('CameraAccessDenied', 'Denied'));

    await expectLater(
      serviceWith([_back]).initialize(),
      throwsA(isA<CameraUnavailableException>()),
    );
    verify(() => controller.dispose()).called(1);
  });

  test('frame stream starts once and stops', () async {
    final service = serviceWith([_back]);
    await service.initialize();

    await service.startFrameStream((_) {});
    await service.startFrameStream((_) {});
    await service.stopFrameStream();

    verify(() => controller.startImageStream(any())).called(1);
    verify(() => controller.stopImageStream()).called(1);
  });

  test('streamed images arrive as upright-tagged frames', () async {
    final service = serviceWith([_back]);
    await service.initialize();
    final frames = <CameraFrame>[];
    await service.startFrameStream(frames.add);

    imageCallback!(
      CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 0),
          width: 4,
          height: 2,
          planes: [CameraImagePlane(bytes: Uint8List(32), bytesPerRow: 16)],
        ),
      ),
    );
    imageCallback!(
      CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.jpeg, raw: 0),
          width: 4,
          height: 2,
          planes: [CameraImagePlane(bytes: Uint8List(8), bytesPerRow: 8)],
        ),
      ),
    );

    // The back camera's sensor orientation (90) is attached; JPEG is skipped.
    expect(frames.single.rotation, 90);
  });

  test('using the camera before initialize throws', () {
    final service = serviceWith([_back]);

    expect(
      () => service.startFrameStream((_) {}),
      throwsA(isA<CameraUnavailableException>()),
    );
    expect(service.takePicture, throwsA(isA<CameraUnavailableException>()));
  });

  test('takePicture delegates to the controller', () async {
    final file = XFile('photo.jpg');
    when(() => controller.takePicture()).thenAnswer((_) async => file);
    final service = serviceWith([_back]);
    await service.initialize();

    expect(await service.takePicture(), file);
  });

  test('dispose stops streaming and releases the controller', () async {
    final service = serviceWith([_back]);
    await service.initialize();
    await service.startFrameStream((_) {});

    await service.dispose();

    verify(() => controller.stopImageStream()).called(1);
    verify(() => controller.dispose()).called(1);
    expect(service.controller, isNull);
    expect(service.isInitialized, isFalse);
  });
}
