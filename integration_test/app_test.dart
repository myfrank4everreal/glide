import 'package:flutter_test/flutter_test.dart';
import 'package:glide/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// Runs on a real device or emulator with the real plugins:
///   flutter test integration_test
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts and shows the home actions', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // A fresh install opens on the tutorial first.
    if (find.text('Welcome to Glide').evaluate().isNotEmpty) {
      for (final button in ['Next', 'I understand', 'Next', 'Next']) {
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Start using Glide'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Detect obstacles'), findsOneWidget);
    expect(find.text('Read text'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
  });
}
