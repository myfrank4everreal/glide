import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/error_reporter.dart';
import 'package:glide/core/widgets/error_views.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorReporter', () {
    test('keeps the most recent errors, up to its capacity', () {
      final logged = <String>[];
      final reporter = ErrorReporter(capacity: 2, log: logged.add);

      reporter
        ..report(StateError('one'), null)
        ..report(StateError('two'), null, context: 'camera')
        ..report(StateError('three'), StackTrace.current);

      expect(reporter.recent, hasLength(2));
      expect(reporter.recent.first, contains('camera'));
      expect(reporter.recent.last, contains('three'));
      expect(logged, hasLength(3));
    });

    test('install routes framework and async errors to it', () {
      final originalFlutter = FlutterError.onError;
      final originalPlatform =
          WidgetsBinding.instance.platformDispatcher.onError;
      addTearDown(() {
        FlutterError.onError = originalFlutter;
        WidgetsBinding.instance.platformDispatcher.onError = originalPlatform;
      });
      final reporter = ErrorReporter(log: (_) {})..install();

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('build failed')),
      );
      final handled = WidgetsBinding.instance.platformDispatcher.onError!(
        StateError('async failed'),
        StackTrace.empty,
      );

      expect(handled, isTrue);
      expect(reporter.recent, [
        contains('build failed'),
        contains('async failed'),
      ]);
    });
  });

  testWidgets('error screen offers a way home', (tester) async {
    var home = 0;
    await tester.pumpWidget(testApp(ErrorScreen(onGoHome: () => home++)));

    expect(find.text('Something went wrong on this screen.'), findsOneWidget);
    await tester.tap(find.text('Go to the home screen'));
    expect(home, 1);
  });

  testWidgets('a broken widget is described, even without localisations', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(testApp(const BrokenWidgetView()));
    expect(
      find.bySemanticsLabel('This part of the screen could not be shown.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: BrokenWidgetView(),
      ),
    );
    expect(
      find.bySemanticsLabel('This part of the screen could not be shown.'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
