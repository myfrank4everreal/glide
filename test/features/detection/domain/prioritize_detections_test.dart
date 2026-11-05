import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/usecases/prioritize_detections.dart';

Detection _d(
  String label, {
  double confidence = 0.9,
  double distance = 2,
  double centerX = 0.5,
}) => Detection(
  label: label,
  confidence: confidence,
  left: centerX - 0.05,
  top: 0,
  right: centerX + 0.05,
  bottom: 1,
  distanceMeters: distance,
);

void main() {
  const prioritize = PrioritizeDetections(maxResults: 2);

  test('drops detections below the confidence threshold', () {
    final result = prioritize([
      _d('pole', confidence: 0.5),
      _d('bench', confidence: 0.8),
    ], confidenceThreshold: 0.6);
    expect(result.map((d) => d.label), ['bench']);
  });

  test('keeps detections exactly at the threshold', () {
    final result = prioritize([
      _d('pole', confidence: 0.6),
    ], confidenceThreshold: 0.6);
    expect(result, hasLength(1));
  });

  test('closest first', () {
    final result = prioritize([
      _d('far', distance: 5),
      _d('close', distance: 0.8),
    ], confidenceThreshold: 0.6);
    expect(result.map((d) => d.label), ['close', 'far']);
  });

  test('at equal distance, objects ahead beat objects to the side', () {
    final result = prioritize([
      _d('side', centerX: 0.1),
      _d('ahead', centerX: 0.5),
    ], confidenceThreshold: 0.6);
    expect(result.first.label, 'ahead');
  });

  test('at equal distance and direction, higher confidence first', () {
    final result = prioritize([
      _d('unsure', confidence: 0.7),
      _d('sure', confidence: 0.95),
    ], confidenceThreshold: 0.6);
    expect(result.first.label, 'sure');
  });

  test('limits the number of results', () {
    final result = prioritize([
      _d('a', distance: 1),
      _d('b', distance: 2),
      _d('c', distance: 3),
    ], confidenceThreshold: 0.6);
    expect(result.map((d) => d.label), ['a', 'b']);
  });

  test('does not modify the input list', () {
    final input = [_d('far', distance: 5), _d('close', distance: 0.5)];
    prioritize(input, confidenceThreshold: 0.6);
    expect(input.first.label, 'far');
  });

  test('empty input gives empty output', () {
    expect(prioritize(const [], confidenceThreshold: 0.6), isEmpty);
  });
}
