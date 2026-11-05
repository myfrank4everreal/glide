import 'dart:async';
import 'dart:math';

import 'package:glide/core/geo/geo_point.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef Vector3 = ({double x, double y, double z});

/// Which way the phone is pointing, in degrees clockwise from magnetic north.
///
/// Held upright (as on the camera screens) this is the direction the back
/// camera faces; held flat it is the direction the top edge points.
abstract interface class HeadingService {
  Stream<double> headings();
}

/// Tilt-compensated compass from the accelerometer and magnetometer.
///
/// Known limits, to check on real phones: magnetic north differs from true
/// north by the local declination (a few degrees in most places), steel and
/// parked cars bend the readings, and on iOS the plugin reports the raw,
/// uncalibrated magnetometer.
class SensorsHeadingService implements HeadingService {
  SensorsHeadingService({
    Stream<Vector3> Function()? accelerometer,
    Stream<Vector3> Function()? magnetometer,
    this.smoothing = 0.25,
  }) : _accelerometer = accelerometer ?? _pluginAccelerometer,
       _magnetometer = magnetometer ?? _pluginMagnetometer;

  final Stream<Vector3> Function() _accelerometer;
  final Stream<Vector3> Function() _magnetometer;

  /// Weight of each new reading, 0–1. Lower is steadier but slower to follow.
  final double smoothing;

  static Stream<Vector3> _pluginAccelerometer() => accelerometerEventStream(
    samplingPeriod: SensorInterval.uiInterval,
  ).map((e) => (x: e.x, y: e.y, z: e.z));

  static Stream<Vector3> _pluginMagnetometer() => magnetometerEventStream(
    samplingPeriod: SensorInterval.uiInterval,
  ).map((e) => (x: e.x, y: e.y, z: e.z));

  @override
  Stream<double> headings() => Stream<double>.multi((controller) {
    Vector3? gravity;
    double? sinAvg;
    double? cosAvg;

    void onMagnet(Vector3 magnet) {
      final g = gravity;
      if (g == null) return;
      final raw = headingFrom(gravity: g, magnet: magnet);
      if (raw == null) return;
      final r = raw * pi / 180;
      // Average on the circle so 359° and 1° average to 0°, not 180°.
      final s = switch (sinAvg) {
        null => sin(r),
        final avg => avg + smoothing * (sin(r) - avg),
      };
      final c = switch (cosAvg) {
        null => cos(r),
        final avg => avg + smoothing * (cos(r) - avg),
      };
      sinAvg = s;
      cosAvg = c;
      controller.add(normalizeDegrees(atan2(s, c) * 180 / pi));
    }

    final subscriptions = [
      _accelerometer().listen((a) => gravity = a),
      _magnetometer().listen(onMagnet, onError: controller.addError),
    ];
    controller.onCancel = () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    };
  });
}

/// Heading in degrees from one accelerometer and one magnetometer reading in
/// device coordinates (x right, y up the screen, z out of the screen), or
/// null when they can't give one (free fall, or field parallel to gravity).
double? headingFrom({required Vector3 gravity, required Vector3 magnet}) {
  final (:x, :y, :z) = gravity;
  // east = magnet × gravity, north = gravity × east (as Android does it).
  var ex = magnet.y * z - magnet.z * y;
  var ey = magnet.z * x - magnet.x * z;
  var ez = magnet.x * y - magnet.y * x;
  final eNorm = sqrt(ex * ex + ey * ey + ez * ez);
  final gNorm = sqrt(x * x + y * y + z * z);
  if (eNorm < 1e-3 || gNorm < 1) return null;
  ex /= eNorm;
  ey /= eNorm;
  ez /= eNorm;
  final gx = x / gNorm;
  final gy = y / gNorm;
  final gz = z / gNorm;
  final ny = gz * ex - gx * ez;
  final nz = gx * ey - gy * ex;

  // Mostly flat: use the top edge (+y). Mostly upright: the camera (-z).
  final flat = gz.abs() > 0.7;
  final east = flat ? ey : -ez;
  final north = flat ? ny : -nz;
  return normalizeDegrees(atan2(east, north) * 180 / pi);
}
