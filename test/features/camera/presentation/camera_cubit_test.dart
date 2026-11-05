import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/permissions/permission_service.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakePermissionService permissions;
  late FakeCameraService camera;
  late FakeHapticService haptics;
  late FakeTtsService tts;

  setUp(() {
    permissions = FakePermissionService();
    camera = FakeCameraService();
    haptics = FakeHapticService();
    tts = FakeTtsService();
  });

  CameraCubit build() => CameraCubit(
    permissions: permissions,
    camera: camera,
    haptics: haptics,
    tts: tts,
    hapticTestGap: Duration.zero,
  );

  group('start', () {
    blocTest<CameraCubit, CameraState>(
      'with permission already granted, goes straight to the camera',
      setUp: () => permissions.current = AppPermissionStatus.granted,
      build: build,
      act: (cubit) => cubit.start(),
      expect: () => [const CameraStarting(), isA<CameraReady>()],
      verify: (_) {
        expect(permissions.requests, 0);
        expect(haptics.played, [HapticPattern.success]);
      },
    );

    blocTest<CameraCubit, CameraState>(
      'without permission, explains why before asking (no OS prompt yet)',
      build: build,
      act: (cubit) => cubit.start(),
      expect: () => [const CameraNeedsPermission()],
      verify: (_) => expect(permissions.requests, 0),
    );

    blocTest<CameraCubit, CameraState>(
      'when permanently denied, offers system settings',
      setUp: () => permissions.current = AppPermissionStatus.permanentlyDenied,
      build: build,
      act: (cubit) => cubit.start(),
      expect: () => [const CameraPermissionDenied(permanently: true)],
    );
  });

  group('requestPermission', () {
    blocTest<CameraCubit, CameraState>(
      'granted starts the camera',
      build: build,
      act: (cubit) => cubit.requestPermission(),
      expect: () => [const CameraStarting(), isA<CameraReady>()],
    );

    blocTest<CameraCubit, CameraState>(
      'denied shows the denied state, which can ask again',
      setUp: () => permissions.onRequest = AppPermissionStatus.denied,
      build: build,
      act: (cubit) => cubit.requestPermission(),
      expect: () => [const CameraPermissionDenied(permanently: false)],
      verify: (_) => expect(haptics.played, [HapticPattern.error]),
    );

    blocTest<CameraCubit, CameraState>(
      'permanently denied shows the settings route',
      setUp: () =>
          permissions.onRequest = AppPermissionStatus.permanentlyDenied,
      build: build,
      act: (cubit) => cubit.requestPermission(),
      expect: () => [const CameraPermissionDenied(permanently: true)],
    );
  });

  test('openSettings opens the system settings page', () async {
    final cubit = build();
    await cubit.openSettings();
    expect(permissions.settingsOpened, 1);
    await cubit.close();
  });

  blocTest<CameraCubit, CameraState>(
    'camera failure becomes an error state, not a crash',
    setUp: () {
      permissions.current = AppPermissionStatus.granted;
      camera.initializeError = const CameraUnavailableException('busy');
    },
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => [const CameraStarting(), const CameraFailed('busy')],
    verify: (_) => expect(haptics.played, [HapticPattern.error]),
  );

  group('app lifecycle', () {
    test(
      'the preview leaves the screen before the camera is released',
      () async {
        permissions.current = AppPermissionStatus.granted;
        final cubit = build();
        await cubit.start();
        final statesAtDispose = <CameraState>[];
        camera.onDispose = () => statesAtDispose.add(cubit.state);

        await cubit.pause();

        expect(statesAtDispose, [const CameraPaused()]);
        await cubit.close();
      },
    );

    blocTest<CameraCubit, CameraState>(
      'pausing releases the camera; resuming reopens it',
      setUp: () => permissions.current = AppPermissionStatus.granted,
      build: build,
      act: (cubit) async {
        await cubit.start();
        await cubit.pause();
        expect(camera.disposeCalls, 1);
        await cubit.resume();
        expect(camera.initializeCalls, 2);
      },
      expect: () => [
        const CameraStarting(),
        isA<CameraReady>(),
        const CameraPaused(),
        const CameraStarting(),
        isA<CameraReady>(),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'the OS permission prompt pausing the app does not disturb the flow',
      build: build,
      act: (cubit) async {
        await cubit.start();
        await cubit.pause();
        await cubit.resume();
        expect(camera.disposeCalls, 0);
        expect(camera.initializeCalls, 0);
      },
      expect: () => [const CameraNeedsPermission()],
    );

    blocTest<CameraCubit, CameraState>(
      'returning from system settings with permission granted starts the camera',
      setUp: () => permissions.current = AppPermissionStatus.permanentlyDenied,
      build: build,
      act: (cubit) async {
        await cubit.start();
        permissions.current = AppPermissionStatus.granted;
        await cubit.resume();
      },
      expect: () => [
        const CameraPermissionDenied(permanently: true),
        const CameraStarting(),
        isA<CameraReady>(),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'returning from system settings still denied stays denied',
      setUp: () => permissions.current = AppPermissionStatus.permanentlyDenied,
      build: build,
      act: (cubit) async {
        await cubit.start();
        await cubit.resume();
      },
      expect: () => [const CameraPermissionDenied(permanently: true)],
    );
  });

  test('close releases the camera', () async {
    permissions.current = AppPermissionStatus.granted;
    final cubit = build();
    await cubit.start();

    await cubit.close();

    expect(camera.disposeCalls, 1);
  });

  group('testHaptics', () {
    test('plays far, near, close and names each one', () async {
      final cubit = build();

      await cubit.testHaptics(
        labels: {
          HapticPattern.far: 'far',
          HapticPattern.near: 'near',
          HapticPattern.close: 'very close',
        },
        speak: true,
      );

      expect(haptics.played, [
        HapticPattern.far,
        HapticPattern.near,
        HapticPattern.close,
      ]);
      expect(tts.spoken, ['far', 'near', 'very close']);
      await cubit.close();
    });

    test('stays silent when voice is off', () async {
      final cubit = build();

      await cubit.testHaptics(
        labels: {HapticPattern.far: 'far', HapticPattern.near: 'near'},
        speak: false,
      );

      expect(haptics.played, [HapticPattern.far, HapticPattern.near]);
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });
  });

  test('announce speaks through TTS', () async {
    final cubit = build();
    await cubit.announce('Camera on');
    expect(tts.spoken, ['Camera on']);
    await cubit.close();
  });
}
