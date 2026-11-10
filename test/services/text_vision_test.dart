import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/ai/frame_preprocessor.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecognizer extends Mock implements TextRecognizer {}

/// 4×2 sensor frame (portrait after a 90° turn: 2×4).
CameraFrame _nv21({
  int luma = 128,
  int rotation = 90,
  int v = 128,
  int u = 128,
}) {
  // 8 Y bytes, then 4 interleaved V,U bytes for the 2×1 chroma grid.
  final bytes = Uint8List(12)
    ..fillRange(0, 8, luma)
    ..setAll(8, [v, u, v, u]);
  return CameraFrame(
    format: FrameFormat.nv21,
    width: 4,
    height: 2,
    rotation: rotation,
    planes: [FramePlane(bytes: bytes, bytesPerRow: 4, bytesPerPixel: 1)],
  );
}

TextLine _line(String text, Rect box) => TextLine(
  text: text,
  elements: const [],
  boundingBox: box,
  recognizedLanguages: const [],
  cornerPoints: const <Point<int>>[],
  confidence: 0.9,
  angle: 0,
);

void main() {
  group('CameraFrame', () {
    test('meanLuma reads the Y plane of NV21', () {
      expect(_nv21(luma: 40).meanLuma(), 40);
    });

    test('meanLuma approximates BGRA brightness', () {
      final frame = CameraFrame(
        format: FrameFormat.bgra8888,
        width: 1,
        height: 1,
        rotation: 0,
        planes: [
          FramePlane(
            bytes: Uint8List.fromList([100, 100, 100, 255]),
            bytesPerRow: 4,
            bytesPerPixel: 4,
          ),
        ],
      );
      expect(frame.meanLuma(), 100);
    });
  });

  test('NV21 frames convert to RGB too', () {
    final rgb = frameToRgb(_nv21(luma: 90), outWidth: 2, outHeight: 2);
    // Neutral chroma: grey at the luma value.
    expect(rgb.toSet(), {90});
  });

  group('uprightLine', () {
    final frame = _nv21(); // 4×2 sensor, 2×4 upright.

    test('boxes already upright are scaled to 0–1', () {
      final line = uprightLine(
        'a',
        const Rect.fromLTRB(0, 1, 1, 2),
        frame: frame,
        alreadyUpright: true,
      );
      expect(
        [line.left, line.top, line.right, line.bottom],
        [0, 0.25, 0.5, 0.5],
      );
    });

    test('sensor boxes are rotated clockwise into the upright picture', () {
      // Top-left sensor corner ends up top-right after a 90° clockwise turn.
      final line = uprightLine(
        'a',
        const Rect.fromLTRB(0, 0, 1, 1),
        frame: frame,
        alreadyUpright: false,
      );
      expect([line.left, line.top, line.right, line.bottom], [0.5, 0, 1, 0.25]);
    });
  });

  group('recognizeFrame', () {
    late _MockRecognizer recognizer;

    setUpAll(() => registerFallbackValue(InputImage.fromFilePath('x')));

    setUp(() {
      recognizer = _MockRecognizer();
      when(() => recognizer.processImage(any())).thenAnswer(
        (_) async => RecognizedText(
          text: '',
          blocks: [
            TextBlock(
              text: '',
              lines: [
                _line('Exit', const Rect.fromLTRB(0, 2, 1, 3)),
                _line(' ', const Rect.fromLTRB(0, 0, 1, 1)),
                _line('Platform', const Rect.fromLTRB(0, 0, 2, 1)),
              ],
              boundingBox: Rect.zero,
              recognizedLanguages: const [],
              cornerPoints: const <Point<int>>[],
            ),
          ],
        ),
      );
    });

    test('returns placed lines in reading order, blanks dropped', () async {
      final service = MlKitTextRecognitionService(
        recognizer: recognizer,
        isIOS: false,
      );
      final lines = await service.recognizeFrame(_nv21());
      expect(lines.map((l) => l.text), ['Platform', 'Exit']);
      final image =
          verify(() => recognizer.processImage(captureAny())).captured.single
              as InputImage;
      expect(image.metadata?.format, InputImageFormat.nv21);
      expect(image.metadata?.rotation, InputImageRotation.rotation90deg);
    });

    test('three-plane YUV frames are not sent to the recogniser', () async {
      final service = MlKitTextRecognitionService(
        recognizer: recognizer,
        isIOS: false,
      );
      final frame = CameraFrame(
        format: FrameFormat.yuv420,
        width: 2,
        height: 2,
        rotation: 90,
        planes: [
          FramePlane(bytes: Uint8List(4), bytesPerRow: 2, bytesPerPixel: 1),
        ],
      );
      expect(await service.recognizeFrame(frame), isEmpty);
      verifyNever(() => recognizer.processImage(any()));
    });
  });
}
