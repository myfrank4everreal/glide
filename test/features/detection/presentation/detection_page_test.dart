import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/detection_result.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/features/detection/presentation/pages/detection_page.dart';
import 'package:glide/features/detection/presentation/widgets/detection_overlay.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/permissions/permission_service.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakePermissionService permissions;
  late FakeCameraService camera;
  late FakeHapticService haptics;
  late FakeTtsService tts;
  late FakeSettingsRepository settings;
  late FakeDetectionRepository detections;

  setUp(() {
    permissions = FakePermissionService();
    camera = FakeCameraService();
    haptics = FakeHapticService();
    tts = FakeTtsService();
    settings = FakeSettingsRepository();
    detections = FakeDetectionRepository();
    addTearDown(detections.dispose);
  });

  late SettingsCubit pumpedSettings;

  Future<CameraCubit> pumpPage(WidgetTester tester) async {
    final settingsCubit = pumpedSettings = buildSettingsCubit(settings);
    await settingsCubit.load();
    final cubit = CameraCubit(
      permissions: permissions,
      camera: camera,
      haptics: haptics,
      tts: tts,
      hapticTestGap: Duration.zero,
    );
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider(
              create: (_) => DetectionCubit(
                repository: detections,
                tts: tts,
                haptics: haptics,
                // These tests send few frames; the watchdog has its own tests.
                stallTimeout: const Duration(hours: 1),
              ),
            ),
          ],
          child: const DetectionPage(),
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await cubit.start();
    await tester.pumpAndSettle();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);
    return cubit;
  }

  Future<SettingsCubit> pumpPageWithSettings(WidgetTester tester) async {
    await pumpPage(tester);
    return pumpedSettings;
  }

  testWidgets('explains and speaks why the camera is needed before asking', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(
      find.textContaining('Images never leave your phone'),
      findsOneWidget,
    );
    expect(find.text('Allow camera'), findsOneWidget);
    expect(tts.spoken.single, contains('Images never leave your phone'));
    expect(permissions.requests, 0);
  });

  testWidgets('allowing the camera shows the live preview', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Allow camera'));
    await tester.pumpAndSettle();

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.text('Test vibration'), findsOneWidget);
    expect(tts.spoken.last, startsWith('Camera on'));
  });

  testWidgets('permanently denied offers system settings', (tester) async {
    permissions.current = AppPermissionStatus.permanentlyDenied;
    await pumpPage(tester);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(permissions.settingsOpened, 1);
    expect(tts.spoken.single, contains('Open settings'));
  });

  testWidgets('denied once offers to try again', (tester) async {
    permissions.onRequest = AppPermissionStatus.denied;
    await pumpPage(tester);

    await tester.tap(find.text('Allow camera'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    permissions.onRequest = AppPermissionStatus.granted;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsOneWidget);
  });

  testWidgets('a camera failure can be retried', (tester) async {
    permissions.current = AppPermissionStatus.granted;
    camera.initializeError = const CameraUnavailableException('busy');
    await pumpPage(tester);
    expect(find.textContaining('could not start'), findsOneWidget);

    camera.initializeError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsOneWidget);
  });

  testWidgets('test vibration plays all three distance patterns', (
    tester,
  ) async {
    permissions.current = AppPermissionStatus.granted;
    await pumpPage(tester);
    haptics.played.clear();

    await tester.tap(find.text('Test vibration'));
    // Advances the fake clock past all three patterns and their gaps.
    await tester.pump(const Duration(seconds: 3));

    expect(haptics.played, [
      HapticPattern.far,
      HapticPattern.near,
      HapticPattern.close,
    ]);
  });

  testWidgets('stays silent when voice alerts are off', (tester) async {
    settings.stored = const UserSettings(voiceEnabled: false);
    await pumpPage(tester);

    expect(tts.spoken, isEmpty);
  });

  testWidgets('going to the background releases the camera', (tester) async {
    permissions.current = AppPermissionStatus.granted;
    await pumpPage(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    // Not pumpAndSettle: the paused screen shows an endless spinner.
    await tester.pump();
    await tester.pump();
    expect(camera.disposeCalls, 1);
    expect(find.byType(CameraPreview), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsOneWidget);
  });

  testWidgets('meets accessibility guidelines on the permission screen', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('the preview is labelled for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    permissions.current = AppPermissionStatus.granted;
    await pumpPage(tester);

    expect(find.bySemanticsLabel(RegExp('^Camera view')), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  group('detection', () {
    const person = Detection(
      label: 'person',
      confidence: 0.9,
      left: 0.4,
      top: 0.2,
      right: 0.6,
      bottom: 0.8,
      distanceMeters: 2.5,
    );

    testWidgets('starts when the preview is live and draws results', (
      tester,
    ) async {
      permissions.current = AppPermissionStatus.granted;
      await pumpPage(tester);
      expect(detections.starts, 1);

      detections.results.add(
        const DetectionResult(
          detections: [person],
          processingTime: Duration(milliseconds: 18),
        ),
      );
      await tester.pumpAndSettle();

      final overlay = tester.widget<DetectionOverlay>(
        find.byType(DetectionOverlay),
      );
      expect(overlay.detections, [person]);
      expect(find.text('18 ms per frame'), findsOneWidget);
    });

    testWidgets('screen readers hear what is in view', (tester) async {
      final semantics = tester.ensureSemantics();
      permissions.current = AppPermissionStatus.granted;
      await pumpPage(tester);

      detections.results.add(
        const DetectionResult(
          detections: [person],
          processingTime: Duration.zero,
        ),
      );
      // Results pass through two async stream hops before the rebuild.
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Camera view. Detected: person ahead.'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('says so when nothing is in view', (tester) async {
      final semantics = tester.ensureSemantics();
      permissions.current = AppPermissionStatus.granted;
      await pumpPage(tester);

      detections.results.add(
        const DetectionResult(detections: [], processingTime: Duration.zero),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Camera view. Nothing detected.'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a missing model is shown but the camera keeps working', (
      tester,
    ) async {
      detections.startError = const ModelLoadException('missing');
      permissions.current = AppPermissionStatus.granted;
      await pumpPage(tester);

      expect(find.textContaining('model is not installed'), findsOneWidget);
      expect(find.byType(CameraPreview), findsOneWidget);
    });

    testWidgets('detection stops when the app goes to the background', (
      tester,
    ) async {
      permissions.current = AppPermissionStatus.granted;
      await pumpPage(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(detections.stops, greaterThanOrEqualTo(1));
    });
  });

  group('spoken alerts', () {
    testWidgets('a near obstacle is announced in plain words', (tester) async {
      permissions.current = AppPermissionStatus.granted;
      await pumpPage(tester);

      detections.results.add(
        const DetectionResult(
          detections: [
            Detection(
              label: 'bench',
              confidence: 0.9,
              left: 0.05,
              top: 0.3,
              right: 0.25,
              bottom: 0.7,
              distanceMeters: 2,
            ),
          ],
          processingTime: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();

      expect(tts.spoken.last, 'bench on your left, near');
      expect(haptics.played, contains(HapticPattern.near));
    });

    testWidgets('turning voice off in settings silences alerts at once', (
      tester,
    ) async {
      permissions.current = AppPermissionStatus.granted;
      final settingsCubit = await pumpPageWithSettings(tester);
      await settingsCubit.update((s) => s.copyWith(voiceEnabled: false));
      await tester.pumpAndSettle();
      final spokenBefore = tts.spoken.length;

      detections.results.add(
        const DetectionResult(
          detections: [
            Detection(
              label: 'bench',
              confidence: 0.9,
              left: 0.4,
              top: 0.3,
              right: 0.6,
              bottom: 0.7,
              distanceMeters: 2,
            ),
          ],
          processingTime: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();

      expect(tts.spoken.length, spokenBefore);
    });
  });
}
