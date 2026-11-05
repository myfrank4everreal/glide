import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/home/presentation/pages/home_page.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('shows the three main actions and the safety disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const HomePage()));

    expect(find.text('Detect obstacles'), findsOneWidget);
    expect(find.text('Read text'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.textContaining('does not replace your cane'), findsOneWidget);
  });

  testWidgets('main actions announce a label and hint to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(testApp(const HomePage()));

    expect(
      tester.getSemantics(find.text('Detect obstacles')),
      matchesSemantics(
        label: 'Detect obstacles',
        hint: 'Starts the camera and warns you about obstacles ahead',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('meets Flutter accessibility guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(testApp(const HomePage()));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('settings button has a tooltip for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const HomePage()));

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
