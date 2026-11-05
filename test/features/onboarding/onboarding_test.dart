import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:glide/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:glide/features/onboarding/presentation/widgets/onboarding_gate.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeTtsService tts;
  late FakeHapticService haptics;

  setUp(() {
    tts = FakeTtsService();
    haptics = FakeHapticService();
  });

  OnboardingCubit buildCubit() =>
      OnboardingCubit(tts: tts, haptics: haptics, patternGap: Duration.zero);

  group('OnboardingCubit', () {
    test('moves between pages within bounds', () async {
      final cubit = buildCubit();
      cubit.back();
      expect(cubit.state, 0);

      for (var i = 0; i < 10; i++) {
        cubit.next();
      }
      expect(cubit.state, OnboardingCubit.pageCount - 1);
      expect(cubit.isLastPage, isTrue);
      await cubit.close();
    });

    test('speaks the page when asked to', () async {
      final cubit = buildCubit()..next(speak: 'Page two');
      expect(tts.spoken, ['Page two']);
      expect(tts.interrupted, [true]);
      await cubit.close();
    });

    test('plays each pattern after naming it', () async {
      final cubit = buildCubit();
      await cubit.playPatterns(
        labels: {HapticPattern.far: 'far', HapticPattern.near: 'near'},
        speak: true,
      );
      expect(tts.spoken, ['far', 'near']);
      expect(haptics.played, [HapticPattern.far, HapticPattern.near]);

      await cubit.stopSpeaking();
      expect(tts.stops, 1);
      await cubit.close();
    });
  });

  group('OnboardingPage', () {
    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onFinished,
      bool screenReader = false,
      UserSettings settings = const UserSettings(),
    }) async {
      final repo = FakeSettingsRepository()..stored = settings;
      final settingsCubit = buildSettingsCubit(repo);
      await settingsCubit.load();
      final cubit = buildCubit();
      addTearDown(cubit.close);
      addTearDown(settingsCubit.close);
      if (screenReader) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await tester.pumpWidget(
        testApp(
          BlocProvider.value(
            value: cubit,
            child: OnboardingPage(onFinished: onFinished ?? () {}),
          ),
          settingsCubit: settingsCubit,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('walks through every page, safety notice included', (
      tester,
    ) async {
      var finished = false;
      await pump(tester, onFinished: () => finished = true);

      expect(find.text('Welcome to Glide'), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Glide is an extra aid'), findsOneWidget);
      expect(find.textContaining('safe to cross'), findsOneWidget);
      // The safety page must be acknowledged, not just skipped past.
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Learn the vibrations'), findsOneWidget);
      await tester.tap(find.text('Test vibration'));
      // Let all four patterns play out.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(haptics.played, hasLength(4));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Your privacy'), findsOneWidget);
      await tester.tap(find.text('Start using Glide'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });

    testWidgets('back returns to the previous page', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Glide'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('Glide reads the pages aloud without a screen reader', (
      tester,
    ) async {
      await pump(tester);
      expect(tts.spoken.single, startsWith('Welcome to Glide.'));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tts.spoken.last, startsWith('Glide is an extra aid.'));
    });

    testWidgets('stays quiet when a screen reader is reading', (tester) async {
      await pump(tester, screenReader: true);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tts.spoken, isEmpty);
    });

    testWidgets('stays quiet with voice turned off', (tester) async {
      await pump(tester, settings: const UserSettings(voiceEnabled: false));
      expect(tts.spoken, isEmpty);
    });

    testWidgets('meets tap target and labelling guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('OnboardingGate', () {
    testWidgets('shows the tutorial until it is done, then the app', (
      tester,
    ) async {
      final repo = FakeSettingsRepository();
      final settingsCubit = buildSettingsCubit(repo);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      addTearDown(settingsCubit.close);
      await tester.pumpWidget(
        testApp(
          BlocProvider.value(
            value: cubit,
            child: const OnboardingGate(child: Text('Home')),
          ),
          settingsCubit: settingsCubit,
        ),
      );
      expect(find.text('Welcome to Glide'), findsOneWidget);

      cubit.goTo(OnboardingCubit.pageCount - 1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start using Glide'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(repo.stored.onboardingDone, isTrue);
    });
  });
}
