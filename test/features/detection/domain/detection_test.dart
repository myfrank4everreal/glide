import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';

Detection _at({required double centerX, double distance = 2}) => Detection(
  label: 'pole',
  confidence: 0.9,
  left: centerX - 0.05,
  top: 0.2,
  right: centerX + 0.05,
  bottom: 0.8,
  distanceMeters: distance,
);

void main() {
  group('Detection.direction', () {
    test('left third is left', () {
      expect(_at(centerX: 0.1).direction, Direction.left);
    });

    test('middle third is ahead', () {
      expect(_at(centerX: 0.5).direction, Direction.ahead);
    });

    test('right third is right', () {
      expect(_at(centerX: 0.9).direction, Direction.right);
    });
  });

  group('Detection.bandFor', () {
    DistanceBand band(double meters) => _at(
      centerX: 0.5,
      distance: meters,
    ).bandFor(closeMeters: 1, nearMeters: 3);

    test('under 1 m is close', () => expect(band(0.5), DistanceBand.close));
    test('1 m exactly is near', () => expect(band(1), DistanceBand.near));
    test('under 3 m is near', () => expect(band(2.9), DistanceBand.near));
    test('3 m and beyond is far', () => expect(band(3), DistanceBand.far));
  });

  test('value equality', () {
    expect(_at(centerX: 0.5), _at(centerX: 0.5));
    expect(_at(centerX: 0.5), isNot(_at(centerX: 0.6)));
  });
}
