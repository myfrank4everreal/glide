import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract interface class TextRecognitionService {
  /// Returns all text in the image at [imagePath] in reading order, one line
  /// per entry. Empty when nothing was found.
  Future<List<String>> recognizeLines(String imagePath);

  Future<void> close();
}

class MlKitTextRecognitionService implements TextRecognitionService {
  MlKitTextRecognitionService({TextRecognizer? recognizer})
    : _recognizer = recognizer ?? TextRecognizer();

  final TextRecognizer _recognizer;

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final lines = [for (final block in result.blocks) ...block.lines]
      ..sort(_readingOrder);
    return [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line.text.trim(),
    ];
  }

  @override
  Future<void> close() => _recognizer.close();

  /// Top-to-bottom, then left-to-right for lines on roughly the same row.
  static int _readingOrder(TextLine a, TextLine b) {
    final rowTolerance = a.boundingBox.height / 2;
    final dy = a.boundingBox.top - b.boundingBox.top;
    if (dy.abs() > rowTolerance) return dy.sign.toInt();
    return a.boundingBox.left.compareTo(b.boundingBox.left);
  }
}
