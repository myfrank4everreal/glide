import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/di/injection.dart';
import 'package:glide/core/error/error_reporter.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/services/ai/object_detector.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/location/location_service.dart';
import 'package:glide/services/permissions/permission_service.dart';
import 'package:glide/services/screen/screen_awake_service.dart';
import 'package:glide/services/sensors/heading_service.dart';
import 'package:glide/services/tts/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tempDir;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('glide_di_test');
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => tempDir.path,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (_) async => 1,
      )
      // getIt.reset() runs dispose callbacks, which close the recogniser.
      ..setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'),
        (_) async => null,
      );
  });

  tearDown(() async {
    await getIt.reset();
    await tempDir.delete(recursive: true);
  });

  test('every interface the app depends on resolves', () async {
    await configureDependencies();

    expect(getIt<PermissionService>(), isA<PermissionHandlerService>());
    expect(getIt<CameraService>(), isA<PluginCameraService>());
    expect(getIt<TtsService>(), isA<FlutterTtsService>());
    expect(getIt<HapticService>(), isA<VibrationHapticService>());
    expect(getIt<ObjectDetector>(), isA<TfliteObjectDetector>());
    expect(getIt<TextRecognitionService>(), isA<MlKitTextRecognitionService>());
    expect(getIt<LocationService>(), isA<GeolocatorLocationService>());
    expect(getIt<HeadingService>(), isA<SensorsHeadingService>());
    expect(getIt<NavigationCubit>(), isA<NavigationCubit>());
    expect(getIt<OnboardingCubit>(), isA<OnboardingCubit>());
    expect(getIt<ScreenAwakeService>(), isA<WakelockScreenAwakeService>());
    expect(getIt<ErrorReporter>(), isA<ErrorReporter>());
    expect(getIt<SettingsCubit>(), isA<SettingsCubit>());
    expect(getIt<CameraCubit>(), isA<CameraCubit>());
    expect(getIt<DetectionCubit>(), isA<DetectionCubit>());
    expect(getIt<TextReaderCubit>(), isA<TextReaderCubit>());
  });

  test('services are singletons, cubits are fresh per request', () async {
    await configureDependencies();

    expect(identical(getIt<TtsService>(), getIt<TtsService>()), isTrue);
    expect(identical(getIt<SettingsCubit>(), getIt<SettingsCubit>()), isFalse);
  });
}
