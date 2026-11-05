import 'package:glide/core/constants/app_constants.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/obstacle_alert.dart';

/// Decides when to speak. Detection runs ~10 times a second; announcing every
/// frame would be unbearable, and announcing too little is dangerous. Rules:
///
/// * Only near and close obstacles are announced; far ones are shown only.
/// * At most one alert per frame: the most dangerous one not recently told.
/// * The same object (type + side) is repeated only after [cooldown], unless
///   it moved into a closer band, which is announced at once.
/// * Non-urgent alerts keep [minGap] between them so speech stays
///   understandable; close-range alerts ignore the gap.
///
/// Stateful: keep one instance per detection session and [reset] it when the
/// camera restarts.
class AlertPolicy {
  AlertPolicy({
    this.cooldown = AppConstants.alertCooldown,
    this.minGap = const Duration(milliseconds: 1500),
    this.closeMeters = AppConstants.closeDistanceMeters,
    this.nearMeters = AppConstants.nearDistanceMeters,
  });

  final Duration cooldown;
  final Duration minGap;
  final double closeMeters;
  final double nearMeters;

  final _lastByObject = <String, ({DateTime at, DistanceBand band})>{};
  DateTime? _lastAlertAt;

  /// [detections] must be ordered most dangerous first (see
  /// `PrioritizeDetections`). Returns the alert to deliver now, if any.
  ObstacleAlert? next(List<Detection> detections, DateTime now) {
    _lastByObject.removeWhere((_, v) => now.difference(v.at) >= cooldown);
    for (final d in detections) {
      final band = d.bandFor(closeMeters: closeMeters, nearMeters: nearMeters);
      if (band == DistanceBand.far) continue;

      final key = '${d.label}|${d.direction.name}';
      final last = _lastByObject[key];
      final movedCloser = last != null && band.index < last.band.index;
      if (last != null && !movedCloser) continue;

      final alert = ObstacleAlert(
        label: d.label,
        direction: d.direction,
        band: band,
      );
      final lastAt = _lastAlertAt;
      if (!alert.urgent && lastAt != null && now.difference(lastAt) < minGap) {
        return null;
      }
      _lastByObject[key] = (at: now, band: band);
      _lastAlertAt = now;
      return alert;
    }
    return null;
  }

  void reset() {
    _lastByObject.clear();
    _lastAlertAt = null;
  }
}
