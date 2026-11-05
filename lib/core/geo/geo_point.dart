import 'dart:math';

import 'package:equatable/equatable.dart';

/// A position on Earth in decimal degrees (WGS 84).
class GeoPoint extends Equatable {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  List<Object> get props => [latitude, longitude];
}

/// A position from the location provider with its uncertainty.
class LocationFix extends Equatable {
  const LocationFix(this.point, {required this.accuracyMeters});

  final GeoPoint point;

  /// Radius in metres within which the true position probably lies.
  final double accuracyMeters;

  @override
  List<Object> get props => [point, accuracyMeters];
}

const double _earthRadiusMeters = 6371000;

double _rad(double degrees) => degrees * pi / 180;

/// Great-circle distance (haversine). Accurate to well under a metre at the
/// walking distances Glide deals with.
double distanceMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * pow(sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * asin(min(1, sqrt(h)));
}

/// Compass bearing from [from] to [to], 0–360 degrees, 0 = north.
double bearingDegrees(GeoPoint from, GeoPoint to) {
  final lat1 = _rad(from.latitude);
  final lat2 = _rad(to.latitude);
  final dLon = _rad(to.longitude - from.longitude);
  final y = sin(dLon) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  return normalizeDegrees(atan2(y, x) * 180 / pi);
}

/// Wraps any angle into 0 (inclusive) to 360 (exclusive).
double normalizeDegrees(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}
