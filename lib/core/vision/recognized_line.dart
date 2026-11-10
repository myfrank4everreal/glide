import 'package:equatable/equatable.dart';

/// One line of text found in a camera frame. The box is a fraction (0–1) of
/// the upright picture, so it doesn't depend on the camera resolution.
class RecognizedLine extends Equatable {
  const RecognizedLine(
    this.text, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get height => bottom - top;

  @override
  List<Object> get props => [text, left, top, right, bottom];
}

/// Top to bottom, then left to right for lines on roughly the same row.
int readingOrder(RecognizedLine a, RecognizedLine b) {
  final dy = a.top - b.top;
  if (dy.abs() > a.height / 2) return dy.sign.toInt();
  return a.left.compareTo(b.left);
}
