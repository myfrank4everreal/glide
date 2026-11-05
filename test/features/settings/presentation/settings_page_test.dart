import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/features/settings/presentation/pages/settings_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeSettingsRepository repository;
  late SettingsCubit cubit;

  setUp(() {
    repository = FakeSettingsRepository();
    cubit = buildSettingsCubit(repository);
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) =>
      tester.pumpWidget(testApp(const SettingsPage(), settingsCubit: cubit));

  testWidgets('toggling voice alerts saves the setting', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Voice alerts'));
    await tester.pumpAndSettle();

    expect(cubit.state.voiceEnabled, isFalse);
    expect(repository.stored.voiceEnabled, isFalse);
  });

  testWidgets('speech rate slider is disabled when voice is off', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Voice alerts'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(slider.onChanged, isNull);
  });

  testWidgets('high contrast switch updates state', (tester) async {
    await pumpPage(tester);

    await tester.scrollUntilVisible(find.text('High contrast'), 100);
    await tester.tap(find.text('High contrast'));
    await tester.pumpAndSettle();

    expect(cubit.state.highContrast, isTrue);
  });

  testWidgets('delete my data asks for confirmation before deleting', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(find.text('Delete my data'), 100);

    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isFalse);

    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isTrue);
    expect(find.text('Your data has been deleted'), findsOneWidget);
  });

  testWidgets('language can be changed, each named in itself', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsWidgets);
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(cubit.state.languageCode, 'es');
    expect(repository.stored.languageCode, 'es');
  });

  testWidgets('offers to replay the tutorial', (tester) async {
    await pumpPage(tester);
    expect(find.text('Replay the tutorial'), findsOneWidget);
  });

  testWidgets('meets tap target and labelling guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
