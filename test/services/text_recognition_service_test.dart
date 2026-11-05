import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecognizer extends Mock implements TextRecognizer {}

TextLine _line(String text, {required double left, required double top}) =>
    TextLine(
      text: text,
      elements: const [],
      boundingBox: Rect.fromLTWH(left, top, 100, 20),
      recognizedLanguages: const [],
      cornerPoints: const <Point<int>>[],
      confidence: 0.9,
      angle: 0,
    );

TextBlock _block(List<TextLine> lines) => TextBlock(
  text: lines.map((l) => l.text).join('\n'),
  lines: lines,
  boundingBox: Rect.zero,
  recognizedLanguages: const [],
  cornerPoints: const <Point<int>>[],
);

void main() {
  late _MockRecognizer recognizer;
  late MlKitTextRecognitionService service;

  setUpAll(() => registerFallbackValue(InputImage.fromFilePath('fallback')));

  setUp(() {
    recognizer = _MockRecognizer();
    service = MlKitTextRecognitionService(recognizer: recognizer);
  });

  void stubBlocks(List<TextBlock> blocks) {
    when(
      () => recognizer.processImage(any()),
    ).thenAnswer((_) async => RecognizedText(text: '', blocks: blocks));
  }

  test('reads lines top to bottom across blocks', () async {
    stubBlocks([
      _block([_line('Exit', left: 0, top: 200)]),
      _block([_line('Platform 2', left: 0, top: 10)]),
    ]);

    expect(await service.recognizeLines('photo.jpg'), ['Platform 2', 'Exit']);
  });

  test('reads lines on the same row left to right', () async {
    stubBlocks([
      _block([
        _line('right', left: 300, top: 52),
        _line('left', left: 10, top: 50),
      ]),
    ]);

    expect(await service.recognizeLines('photo.jpg'), ['left', 'right']);
  });

  test('drops blank lines and trims whitespace', () async {
    stubBlocks([
      _block([
        _line('  Open  ', left: 0, top: 0),
        _line('   ', left: 0, top: 40),
      ]),
    ]);

    expect(await service.recognizeLines('photo.jpg'), ['Open']);
  });

  test('returns an empty list when there is no text', () async {
    stubBlocks([]);

    expect(await service.recognizeLines('photo.jpg'), isEmpty);
  });

  test('close releases the recognizer', () async {
    when(() => recognizer.close()).thenAnswer((_) async {});

    await service.close();

    verify(() => recognizer.close()).called(1);
  });
}
