import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/app.dart';
import 'package:glide/core/di/injection.dart';
import 'package:glide/core/themes/app_theme.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/tts/tts_service.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeSettingsRepository repository;
  late FakeTtsService tts;
  late FakeHapticService haptics;
  late FakePermissionService permissions;
  late FakeCameraService camera;

  setUp(() async {
    await getIt.reset();
    repository = FakeSettingsRepository()
      ..stored = const UserSettings(onboardingDone: true);
    tts = FakeTtsService();
    haptics = FakeHapticService();
    permissions = FakePermissionService();
    camera = FakeCameraService();
    getIt
      ..registerSingleton<TtsService>(tts)
      ..registerSingleton<HapticService>(haptics)
      ..registerFactory(() => buildSettingsCubit(repository))
      ..registerFactory(
        () => DetectionCubit(
          repository: FakeDetectionRepository(),
          tts: tts,
          haptics: haptics,
        ),
      )
      ..registerFactory(
        () => TextReaderCubit(
          camera: camera,
          ocr: _NoTextOcr(),
          tts: tts,
          haptics: haptics,
        ),
      )
      ..registerFactory(
        () => NavigationCubit(
          places: FakeSavedPlacesRepository(),
          location: FakeLocationService(),
          heading: FakeHeadingService(),
          permissions: permissions,
          tts: tts,
          haptics: haptics,
        ),
      )
      ..registerFactory(() => OnboardingCubit(tts: tts, haptics: haptics))
      ..registerFactory(
        () => CameraCubit(
          permissions: permissions,
          camera: camera,
          haptics: haptics,
          tts: tts,
        ),
      );
  });

  testWidgets('starts on the home page', (tester) async {
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    expect(find.text('Detect obstacles'), findsOneWidget);
  });

  testWidgets('applies stored high contrast and speech settings on start', (
    tester,
  ) async {
    repository.stored = const UserSettings(
      highContrast: true,
      speechRate: 0.8,
      onboardingDone: true,
    );

    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme, AppTheme.highContrast.colorScheme);
    expect(tts.speechRate, 0.8);
  });

  testWidgets('turning haptics off mutes the haptic service', (tester) async {
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Detect obstacles'));
    await tester.runAsync(
      () => context.read<SettingsCubit>().update(
        (s) => s.copyWith(hapticsEnabled: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(haptics.intensity, 0);
  });

  testWidgets('each home action opens its screen', (tester) async {
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    // Both camera screens start with the permission explanation, and
    // leaving releases the camera.
    for (final (button, disposals) in [
      ('Detect obstacles', 1),
      ('Read text', 2),
    ]) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.text('Allow camera'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(camera.disposeCalls, greaterThanOrEqualTo(disposals));
    }

    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();
    expect(find.text('Allow location'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Voice alerts'), findsOneWidget);
  });

  testWidgets('first launch shows the tutorial, then home', (tester) async {
    repository.stored = const UserSettings();
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Glide'), findsOneWidget);
    for (final button in ['Next', 'I understand', 'Next', 'Next']) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start using Glide'));
    await tester.pumpAndSettle();

    expect(find.text('Detect obstacles'), findsOneWidget);
    expect(repository.stored.onboardingDone, isTrue);
  });

  testWidgets('the tutorial can be replayed from settings', (tester) async {
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Replay the tutorial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replay the tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Glide'), findsOneWidget);

    final context = tester.element(find.text('Welcome to Glide'));
    context.read<OnboardingCubit>().goTo(OnboardingCubit.pageCount - 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start using Glide'));
    await tester.pumpAndSettle();
    // Back on settings, where it was opened from.
    expect(find.text('Replay the tutorial'), findsOneWidget);
  });

  testWidgets('Spanish switches the screens and the voice', (tester) async {
    repository.stored = const UserSettings(
      languageCode: 'es',
      onboardingDone: true,
    );
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    expect(find.text('Detectar obstáculos'), findsOneWidget);
    expect(tts.language, 'es-ES');
  });

  testWidgets('an unknown saved language falls back to English', (
    tester,
  ) async {
    repository.stored = const UserSettings(
      languageCode: 'xx',
      onboardingDone: true,
    );
    await tester.pumpWidget(const GlideApp());
    await tester.pumpAndSettle();

    expect(find.text('Detect obstacles'), findsOneWidget);
    expect(tts.language, 'en-US');
  });
}

class _NoTextOcr implements TextRecognitionService {
  @override
  Future<List<String>> recognizeLines(String imagePath) async => const [];

  @override
  Future<void> close() async {}
}
