import 'dart:math';

import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/domain/entities/guidance.dart';

/// Straight-line ("as the crow flies") guidance to a point. It does not
/// follow streets: that needs a routing service (see docs/tasks.md).
class ComputeGuidance {
  const ComputeGuidance({
    this.arrivalMeters = 10,
    this.maxArrivalMeters = 20,
    this.weakSignalMeters = 25,
  });

  /// Closer than this counts as arrived when GPS is good.
  final double arrivalMeters;

  /// With poor GPS the arrival radius grows with the uncertainty, up to this;
  /// otherwise the user could circle the place without ever "arriving".
  final double maxArrivalMeters;

  final double weakSignalMeters;

  Guidance call({
    required GeoPoint target,
    required LocationFix fix,
    double? headingDegrees,
  }) {
    final distance = distanceMeters(fix.point, target);
    final radius = max(
      arrivalMeters,
      min(fix.accuracyMeters, maxArrivalMeters),
    );
    return Guidance(
      distanceMeters: distance,
      accuracyMeters: fix.accuracyMeters,
      clockHour: headingDegrees == null
          ? null
          : clockHourFor(bearingDegrees(fix.point, target) - headingDegrees),
      arrived: distance <= radius,
      weakSignal: fix.accuracyMeters > weakSignalMeters,
    );
  }
}

/// 12 = straight ahead, 3 = right, 6 = behind, 9 = left. Each hour covers 30°.
int clockHourFor(double relativeDegrees) {
  final hour = (normalizeDegrees(relativeDegrees) / 30).round() % 12;
  return hour == 0 ? 12 : hour;
}
