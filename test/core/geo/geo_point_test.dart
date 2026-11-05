import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/geo/geo_point.dart';

void main() {
  // One degree of latitude on a 6371 km sphere.
  const metersPerDegree = 111194.9;

  test('distance along a meridian matches the arc length', () {
    expect(
      distanceMeters(const GeoPoint(51, 0), const GeoPoint(52, 0)),
      closeTo(metersPerDegree, 1),
    );
  });

  test('walking-scale distances are accurate', () {
    const a = GeoPoint(51.5, -0.12);
    final b = GeoPoint(51.5 + 50 / metersPerDegree, -0.12);
    expect(distanceMeters(a, b), closeTo(50, 0.05));
    expect(distanceMeters(a, a), 0);
  });

  test('bearings point the right way', () {
    const origin = GeoPoint(0, 0);
    expect(bearingDegrees(origin, const GeoPoint(1, 0)), closeTo(0, 1e-9));
    expect(bearingDegrees(origin, const GeoPoint(0, 1)), closeTo(90, 1e-9));
    expect(bearingDegrees(origin, const GeoPoint(-1, 0)), closeTo(180, 1e-9));
    expect(bearingDegrees(origin, const GeoPoint(0, -1)), closeTo(270, 1e-9));
  });

  test('normalizeDegrees wraps into 0–360', () {
    expect(normalizeDegrees(-90), 270);
    expect(normalizeDegrees(360), 0);
    expect(normalizeDegrees(725), 5);
  });
}
