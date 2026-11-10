import 'dart:io';
import 'dart:ui';

import 'package:glide/core/vision/recognized_line.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract interface class TextRecognitionService {
  /// Returns all text in the image at [imagePath] in reading order, one line
  /// per entry. Empty when nothing was found.
  Future<List<String>> recognizeLines(String imagePath);

  /// Finds text in a live camera frame, with where each line is, in reading
  /// order. Frames in a format the recogniser can't read give no lines.
  Future<List<RecognizedLine>> recognizeFrame(CameraFrame frame);

  Future<void> close();
}

class MlKitTextRecognitionService implements TextRecognitionService {
  MlKitTextRecognitionService({TextRecognizer? recognizer, bool? isIOS})
    : _recognizer = recognizer ?? TextRecognizer(),
      _isIOS = isIOS ?? Platform.isIOS;

  final TextRecognizer _recognizer;
  final bool _isIOS;

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final lines = [for (final block in result.blocks) ...block.lines]
      ..sort(_lineOrder);
    return [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line.text.trim(),
    ];
  }

  @override
  Future<List<RecognizedLine>> recognizeFrame(CameraFrame frame) async {
    final format = switch (frame.format) {
      FrameFormat.nv21 => InputImageFormat.nv21,
      FrameFormat.bgra8888 => InputImageFormat.bgra8888,
      // Three-plane YUV would need copying into NV21 first; text mode asks
      // the camera for NV21 so this doesn't happen.
      FrameFormat.yuv420 => null,
    };
    final rotation = InputImageRotationValue.fromRawValue(frame.rotation);
    if (format == null || rotation == null) return const [];
    final plane = frame.planes.first;
    final result = await _recognizer.processImage(
      InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
    );
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          if (line.text.trim().isNotEmpty)
            uprightLine(
              line.text.trim(),
              line.boundingBox,
              frame: frame,
              // Android applies the rotation before recognising; iOS ignores
              // it and reports boxes in sensor coordinates.
              alreadyUpright: !_isIOS,
            ),
    ]..sort(readingOrder);
  }

  @override
  Future<void> close() => _recognizer.close();

  /// Top-to-bottom, then left-to-right for lines on roughly the same row.
  static int _lineOrder(TextLine a, TextLine b) {
    final rowTolerance = a.boundingBox.height / 2;
    final dy = a.boundingBox.top - b.boundingBox.top;
    if (dy.abs() > rowTolerance) return dy.sign.toInt();
    return a.boundingBox.left.compareTo(b.boundingBox.left);
  }
}

/// Converts a pixel box from the recogniser into a 0–1 box of the upright
/// picture. If the box is still in sensor coordinates, it is rotated by the
/// frame's (clockwise) rotation first.
RecognizedLine uprightLine(
  String text,
  Rect box, {
  required CameraFrame frame,
  required bool alreadyUpright,
}) {
  final upright = frame.displaySize;
  if (alreadyUpright) {
    return RecognizedLine(
      text,
      left: (box.left / upright.width).clamp(0, 1),
      top: (box.top / upright.height).clamp(0, 1),
      right: (box.right / upright.width).clamp(0, 1),
      bottom: (box.bottom / upright.height).clamp(0, 1),
    );
  }
  final w = frame.width.toDouble();
  final h = frame.height.toDouble();
  final (l, t, r, b) = (
    box.left / w,
    box.top / h,
    box.right / w,
    box.bottom / h,
  );
  final (nl, nt, nr, nb) = switch (frame.rotation % 360) {
    90 => (1 - b, l, 1 - t, r),
    180 => (1 - r, 1 - b, 1 - l, 1 - t),
    270 => (t, 1 - r, b, 1 - l),
    _ => (l, t, r, b),
  };
  return RecognizedLine(
    text,
    left: nl.clamp(0, 1),
    top: nt.clamp(0, 1),
    right: nr.clamp(0, 1),
    bottom: nb.clamp(0, 1),
  );
}
