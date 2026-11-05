import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/presentation/widgets/detection_overlay.dart';

Detection _at(double distance) => Detection(
  label: 'person',
  confidence: 0.9,
  left: 0.1,
  top: 0.2,
  right: 0.5,
  bottom: 0.9,
  distanceMeters: distance,
);

void main() {
  const colors = (close: Colors.red, near: Colors.amber, far: Colors.blue);
  DetectionPainter painter(List<Detection> detections) => DetectionPainter(
    detections: detections,
    colors: colors,
    textStyle: const TextStyle(fontSize: 12),
  );

  test('colours boxes by distance band', () {
    final p = painter(const []);
    expect(p.colorFor(_at(0.5)), Colors.red);
    expect(p.colorFor(_at(2)), Colors.amber);
    expect(p.colorFor(_at(6)), Colors.blue);
  });

  test('repaints only when detections change', () {
    final detections = [_at(2)];
    expect(painter(detections).shouldRepaint(painter(detections)), isFalse);
    expect(painter(detections).shouldRepaint(painter([_at(5)])), isTrue);
  });

  testWidgets('draws a box and label for each detection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // Center keeps the SizedBox from being stretched to the screen.
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: DetectionOverlay(detections: [_at(2), _at(0.6)]),
          ),
        ),
      ),
    );

    // Each detection: outline + label background.
    expect(
      find.byType(DetectionOverlay),
      paints
        ..rect(rect: const Rect.fromLTRB(30, 80, 150, 360))
        ..rect()
        ..rect(rect: const Rect.fromLTRB(30, 80, 150, 360))
        ..rect(),
    );
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: DetectionOverlay(detections: [_at(2)])),
    );

    expect(find.bySemanticsLabel(RegExp('person')), findsNothing);
    semantics.dispose();
  });
}
