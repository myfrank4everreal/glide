import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:glide/core/error/error_reporter.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/detection/data/repositories/detection_repository_impl.dart';
import 'package:glide/features/detection/domain/repositories/detection_repository.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/features/navigation/data/repositories/saved_places_repository_impl.dart';
import 'package:glide/features/navigation/domain/repositories/saved_places_repository.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:glide/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:glide/features/settings/domain/repositories/settings_repository.dart';
import 'package:glide/features/settings/domain/usecases/settings_usecases.dart';
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
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

/// The only place that decides which implementation backs each interface.
/// Tests call [getIt.reset] and register fakes instead.
Future<void> configureDependencies() async {
  await Hive.initFlutter();
  final prefs = await SharedPreferences.getInstance();

  getIt
    // External
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new)
    ..registerSingleton(ErrorReporter())
    // Services
    ..registerLazySingleton<ScreenAwakeService>(WakelockScreenAwakeService.new)
    ..registerLazySingleton<PermissionService>(PermissionHandlerService.new)
    ..registerLazySingleton<CameraService>(
      PluginCameraService.new,
      dispose: (s) => s.dispose(),
    )
    ..registerLazySingleton<TtsService>(FlutterTtsService.new)
    ..registerLazySingleton<HapticService>(VibrationHapticService.new)
    ..registerLazySingleton<ObjectDetector>(
      TfliteObjectDetector.new,
      dispose: (d) => d.close(),
    )
    ..registerLazySingleton<TextRecognitionService>(
      MlKitTextRecognitionService.new,
      dispose: (s) => s.close(),
    )
    ..registerLazySingleton<LocationService>(GeolocatorLocationService.new)
    ..registerLazySingleton<HeadingService>(SensorsHeadingService.new)
    // Detection feature
    ..registerFactory<DetectionRepository>(
      () => DetectionRepositoryImpl(camera: getIt(), detector: getIt()),
    )
    ..registerFactory(
      () => DetectionCubit(
        repository: getIt(),
        tts: getIt(),
        haptics: getIt(),
        screen: getIt(),
      ),
    )
    ..registerFactory(
      () => CameraCubit(
        permissions: getIt(),
        camera: getIt(),
        haptics: getIt(),
        tts: getIt(),
      ),
    )
    // Text reader feature
    ..registerFactory(
      () => TextReaderCubit(
        camera: getIt(),
        ocr: getIt(),
        tts: getIt(),
        haptics: getIt(),
      ),
    )
    // Navigation feature
    ..registerLazySingleton<SavedPlacesRepository>(
      () => SavedPlacesRepositoryImpl(getIt()),
    )
    ..registerFactory(
      () => NavigationCubit(
        places: getIt(),
        location: getIt(),
        heading: getIt(),
        permissions: getIt(),
        tts: getIt(),
        haptics: getIt(),
        screen: getIt(),
      ),
    )
    ..registerFactory(() => OnboardingCubit(tts: getIt(), haptics: getIt()))
    // Settings feature
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory(() => GetSettings(getIt()))
    ..registerFactory(() => SaveSettings(getIt()))
    ..registerFactory(() => DeleteUserData(getIt()))
    ..registerFactory(
      () => SettingsCubit(
        getSettings: getIt(),
        saveSettings: getIt(),
        deleteUserData: getIt(),
      ),
    );

  // Without speech Glide still vibrates, so a failing engine must not stop
  // the app from starting.
  try {
    await getIt<TtsService>().initialize();
  } on Object catch (e, stack) {
    getIt<ErrorReporter>().report(e, stack, context: 'TTS initialise');
  }
}
