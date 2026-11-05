import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/ai/object_detector.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the real model on a real device:
///   flutter test integration_test/detector_test.dart
///
/// Unit tests can't cover this: the TFLite native library only exists on
/// the phone. Accuracy on real street images is a separate benchmark
/// (see docs/tasks.md, Milestone 2).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A 640×480 mid-grey YUV frame, the size and format Android delivers.
  CameraFrame greyFrame() => CameraFrame(
    format: FrameFormat.yuv420,
    width: 640,
    height: 480,
    rotation: 90,
    planes: [
      FramePlane(
        bytes: Uint8List(640 * 480)..fillRange(0, 640 * 480, 128),
        bytesPerRow: 640,
        bytesPerPixel: 1,
      ),
      for (var i = 0; i < 2; i++)
        FramePlane(
          bytes: Uint8List(640 * 240)..fillRange(0, 640 * 240, 128),
          bytesPerRow: 640,
          bytesPerPixel: 2,
        ),
    ],
  );

  testWidgets('the bundled model loads and runs within budget', (_) async {
    final detector = TfliteObjectDetector();
    await detector.load();
    expect(detector.isLoaded, isTrue);
    expect(detector.labels, contains('person'));

    // Warm up: the first inference includes one-off allocation.
    await detector.detect(greyFrame());

    final timer = Stopwatch()..start();
    const runs = 20;
    for (var i = 0; i < runs; i++) {
      final result = await detector.detect(greyFrame());
      // A flat grey image contains no objects.
      expect(result.where((d) => d.score > 0.6), isEmpty);
    }
    final perFrame = timer.elapsedMilliseconds / runs;
    debugPrint('Detector: ${perFrame.toStringAsFixed(1)} ms per frame');

    // Spec target is 30 ms on reference devices; fail only on a clear miss
    // so slower test phones still report a number.
    expect(perFrame, lessThan(100));
    await detector.close();
  });
}
