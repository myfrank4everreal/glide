import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/usecases/distance_estimator.dart';

void main() {
  const estimator = DistanceEstimator();

  test('knows the obstacle classes Glide cares about', () {
    expect(estimator.isObstacle('person'), isTrue);
    expect(estimator.isObstacle('bench'), isTrue);
    expect(estimator.isObstacle('fire hydrant'), isTrue);
    // Not an obstacle a walker needs to hear about.
    expect(estimator.isObstacle('toothbrush'), isFalse);
  });

  test('a person filling half the frame is a few metres away', () {
    final d = estimator.estimateMeters(label: 'person', boxHeight: 0.5);
    expect(d, inInclusiveRange(2, 4));
  });

  test('smaller in frame means further away', () {
    final near = estimator.estimateMeters(label: 'person', boxHeight: 0.6);
    final far = estimator.estimateMeters(label: 'person', boxHeight: 0.15);
    expect(far, greaterThan(near * 3));
  });

  test('taller objects at the same box height are further away', () {
    final bus = estimator.estimateMeters(label: 'bus', boxHeight: 0.3);
    final bench = estimator.estimateMeters(label: 'bench', boxHeight: 0.3);
    expect(bus, greaterThan(bench));
  });

  test('an object filling the frame is treated as very close', () {
    expect(
      estimator.estimateMeters(label: 'car', boxHeight: 0.98),
      DistanceEstimator.minMeters,
    );
  });

  test('results are clamped to a sensible range', () {
    expect(
      estimator.estimateMeters(label: 'person', boxHeight: 0.001),
      DistanceEstimator.maxMeters,
    );
  });
}
