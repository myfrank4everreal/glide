import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/domain/usecases/compute_guidance.dart';

const _metersPerDegree = 111194.9;
const _here = GeoPoint(51.5, -0.12);

GeoPoint _north(double meters) =>
    GeoPoint(_here.latitude + meters / _metersPerDegree, _here.longitude);

LocationFix _fix({double accuracy = 5}) =>
    LocationFix(_here, accuracyMeters: accuracy);

void main() {
  const compute = ComputeGuidance();

  test('distance and clock direction to the target', () {
    final g = compute(target: _north(100), fix: _fix(), headingDegrees: 0);

    expect(g.distanceMeters, closeTo(100, 0.1));
    expect(g.clockHour, 12);
    expect(g.arrived, isFalse);
    expect(g.weakSignal, isFalse);
  });

  test('direction is relative to where the phone points', () {
    final target = _north(100);
    expect(
      compute(target: target, fix: _fix(), headingDegrees: 90).clockHour,
      9,
    );
    expect(
      compute(target: target, fix: _fix(), headingDegrees: 180).clockHour,
      6,
    );
    expect(
      compute(target: target, fix: _fix(), headingDegrees: 300).clockHour,
      2,
    );
  });

  test('no direction before the compass has a reading', () {
    expect(compute(target: _north(100), fix: _fix()).clockHour, isNull);
  });

  test('arrival radius grows with GPS uncertainty, within a limit', () {
    expect(compute(target: _north(8), fix: _fix()).arrived, isTrue);
    expect(compute(target: _north(14), fix: _fix()).arrived, isFalse);
    expect(
      compute(target: _north(14), fix: _fix(accuracy: 15)).arrived,
      isTrue,
    );
    expect(
      compute(target: _north(30), fix: _fix(accuracy: 60)).arrived,
      isFalse,
    );
  });

  test('poor accuracy is flagged', () {
    expect(
      compute(target: _north(100), fix: _fix(accuracy: 40)).weakSignal,
      isTrue,
    );
  });

  test('clockHourFor rounds to the nearest hour', () {
    expect(clockHourFor(0), 12);
    expect(clockHourFor(14), 12);
    expect(clockHourFor(16), 1);
    expect(clockHourFor(90), 3);
    expect(clockHourFor(-90), 9);
    expect(clockHourFor(346), 12);
  });
}
