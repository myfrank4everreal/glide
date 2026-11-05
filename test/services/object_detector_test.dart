import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/services/ai/object_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a missing model fails with ModelLoadException, not a crash', () async {
    final detector = TfliteObjectDetector(
      modelAsset: 'assets/models/missing.tflite',
    );

    await expectLater(detector.load(), throwsA(isA<ModelLoadException>()));
    expect(detector.isLoaded, isFalse);
    expect(detector.labels, isEmpty);
  });

  test('ModelLoadException names the model file', () async {
    final detector = TfliteObjectDetector(
      modelAsset: 'assets/models/missing.tflite',
    );

    await expectLater(
      detector.load(),
      throwsA(
        isA<ModelLoadException>().having(
          (e) => e.toString(),
          'message',
          contains('missing.tflite'),
        ),
      ),
    );
  });

  test('close on an unloaded detector is safe', () async {
    await TfliteObjectDetector().close();
  });
}
