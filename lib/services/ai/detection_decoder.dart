import 'dart:typed_data';

import 'package:glide/services/ai/object_detector.dart';

/// Which output tensor holds what, for models ending in TensorFlow Lite's
/// standard detection post-processing (SSD MobileNet, EfficientDet-Lite).
class OutputLayout {
  const OutputLayout({
    required this.boxes,
    required this.classes,
    required this.scores,
    required this.count,
  });

  final int boxes;
  final int classes;
  final int scores;
  final int count;
}

typedef TensorInfo = ({String name, List<int> shape});

/// Works out the output order from tensor shapes and, when present, names.
/// Throws [FormatException] for models without detection post-processing.
OutputLayout resolveOutputLayout(List<TensorInfo> outputs) {
  if (outputs.length != 4) {
    throw FormatException(
      'Expected 4 detection outputs (boxes, classes, scores, count), '
      'found ${outputs.length}',
    );
  }
  final boxes = outputs.indexWhere(
    (t) => t.shape.length == 3 && t.shape.last == 4,
  );
  final count = outputs.indexWhere((t) => t.shape.length == 1);
  final perBox = [
    for (var i = 0; i < 4; i++)
      if (outputs[i].shape.length == 2) i,
  ];
  if (boxes < 0 || count < 0 || perBox.length != 2) {
    throw FormatException(
      'Unrecognised detection outputs: ${outputs.map((t) => t.shape).toList()}',
    );
  }
  bool named(int i, String word) =>
      outputs[i].name.toLowerCase().contains(word);
  final (
    classes,
    scores,
  ) = named(perBox[0], 'score') || named(perBox[1], 'categor')
      ? (perBox[1], perBox[0])
      : (perBox[0], perBox[1]);
  return OutputLayout(
    boxes: boxes,
    classes: classes,
    scores: scores,
    count: count,
  );
}

/// Turns raw post-processed outputs into detections. Boxes arrive as
/// normalised `[ymin, xmin, ymax, xmax]`.
List<RawDetection> decodeDetections({
  required Float32List boxes,
  required Float32List classes,
  required Float32List scores,
  required int count,
  required List<String> labels,
  required double minScore,
}) {
  final n = [
    count,
    scores.length,
    classes.length,
    boxes.length ~/ 4,
  ].reduce((a, b) => a < b ? a : b);
  // Guard against a model whose output order we resolved wrongly: a score
  // above 1 can only be a class id. Swapping would otherwise produce
  // confident nonsense alerts.
  if (scores.take(n).any((s) => s > 1.0001)) {
    (scores, classes) = (classes, scores);
  }
  final result = <RawDetection>[];
  for (var i = 0; i < n; i++) {
    final score = scores[i];
    if (score < minScore) continue;
    final classId = classes[i].round();
    if (classId < 0 || classId >= labels.length) continue;
    final label = labels[classId];
    if (label == '???' || label.isEmpty) continue;
    double c(int k) => boxes[i * 4 + k].clamp(0.0, 1.0);
    result.add(
      RawDetection(
        label: label,
        score: score,
        left: c(1),
        top: c(0),
        right: c(3),
        bottom: c(2),
      ),
    );
  }
  return result;
}
