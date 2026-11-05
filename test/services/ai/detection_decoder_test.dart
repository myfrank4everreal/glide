import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/ai/detection_decoder.dart';

void main() {
  group('resolveOutputLayout', () {
    test('uses tensor names when the model provides them', () {
      // MediaPipe EfficientDet order.
      final layout = resolveOutputLayout([
        (name: 'StatefulPartitionedCall:3', shape: [1, 25, 4]),
        (name: 'StatefulPartitionedCall:0', shape: [1]),
        (name: 'score', shape: [1, 25]),
        (name: 'category', shape: [1, 25]),
      ]);

      expect(layout.boxes, 0);
      expect(layout.count, 1);
      expect(layout.scores, 2);
      expect(layout.classes, 3);
    });

    test(
      'falls back to the standard SSD order: boxes, classes, scores, count',
      () {
        final layout = resolveOutputLayout([
          (name: 'TFLite_Detection_PostProcess', shape: [1, 10, 4]),
          (name: 'TFLite_Detection_PostProcess:1', shape: [1, 10]),
          (name: 'TFLite_Detection_PostProcess:2', shape: [1, 10]),
          (name: 'TFLite_Detection_PostProcess:3', shape: [1]),
        ]);

        expect(
          (layout.boxes, layout.classes, layout.scores, layout.count),
          (0, 1, 2, 3),
        );
      },
    );

    test('rejects models without detection post-processing', () {
      expect(
        () => resolveOutputLayout([
          (name: 'logits', shape: [1, 1001]),
        ]),
        throwsFormatException,
      );
    });
  });

  group('decodeDetections', () {
    final labels = ['person', 'bicycle', '???', 'car'];

    List<RawDetectionLike> decode({
      required List<double> boxes,
      required List<double> classes,
      required List<double> scores,
      required int count,
      double minScore = 0.3,
    }) => decodeDetections(
      boxes: Float32List.fromList(boxes),
      classes: Float32List.fromList(classes),
      scores: Float32List.fromList(scores),
      count: count,
      labels: labels,
      minScore: minScore,
    ).map((d) => (d.label, d.score, d.left, d.top, d.right, d.bottom)).toList();

    test('maps ymin, xmin, ymax, xmax boxes to left, top, right, bottom', () {
      final result = decode(
        boxes: [0.1, 0.2, 0.5, 0.6],
        classes: [0],
        scores: [0.9],
        count: 1,
      );

      expect(result.single.$1, 'person');
      expect(result.single.$2, closeTo(0.9, 1e-6));
      expect(result.single.$3, closeTo(0.2, 1e-6)); // left = xmin
      expect(result.single.$4, closeTo(0.1, 1e-6)); // top = ymin
      expect(result.single.$5, closeTo(0.6, 1e-6)); // right = xmax
      expect(result.single.$6, closeTo(0.5, 1e-6)); // bottom = ymax
    });

    test('drops low scores, placeholder labels and unknown class ids', () {
      final result = decode(
        boxes: List.filled(16, 0.5),
        classes: [1, 2, 3, 99],
        scores: [0.2, 0.9, 0.9, 0.9],
        count: 4,
      );

      // bicycle: score too low; '???': placeholder; 99: out of range.
      expect(result.map((d) => d.$1), ['car']);
    });

    test('only reads up to count even if buffers are longer', () {
      final result = decode(
        boxes: List.filled(8, 0.5),
        classes: [0, 3],
        scores: [0.9, 0.9],
        count: 1,
      );

      expect(result, hasLength(1));
    });

    test('recovers when a model reports classes and scores swapped', () {
      // Scores can never exceed 1, so values like 3.0 must be class ids.
      final result = decode(
        boxes: List.filled(8, 0.5),
        classes: [0.9, 0.8],
        scores: [3, 0],
        count: 2,
      );

      expect(result.map((d) => d.$1), ['car', 'person']);
      // Float32 storage: 0.9 comes back as 0.89999997.
      expect(result[0].$2, closeTo(0.9, 1e-6));
      expect(result[1].$2, closeTo(0.8, 1e-6));
    });

    test('clamps boxes that spill outside the frame', () {
      final result = decode(
        boxes: [-0.2, -0.1, 1.3, 1.1],
        classes: [0],
        scores: [0.9],
        count: 1,
      );

      expect(result.single.$3, 0);
      expect(result.single.$4, 0);
      expect(result.single.$5, 1);
      expect(result.single.$6, 1);
    });
  });
}

typedef RawDetectionLike = (String, double, double, double, double, double);
