import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/sensors/heading_service.dart';

const _flat = (x: 0.0, y: 0.0, z: 9.8);
const _upright = (x: 0.0, y: 9.8, z: 0.0);

/// Earth's field (north and down) for a flat phone whose top edge points
/// [heading] degrees from north.
Vector3 _flatMagnet(double heading) {
  final r = heading * pi / 180;
  return (x: -20 * sin(r), y: 20 * cos(r), z: -40);
}

void main() {
  group('headingFrom', () {
    test('flat phone uses the top edge', () {
      expect(
        headingFrom(gravity: _flat, magnet: _flatMagnet(0)),
        closeTo(0, 1e-6),
      );
      expect(
        headingFrom(gravity: _flat, magnet: _flatMagnet(90)),
        closeTo(90, 1e-6),
      );
      expect(
        headingFrom(gravity: _flat, magnet: _flatMagnet(225)),
        closeTo(225, 1e-6),
      );
    });

    test('upright phone uses the direction the camera faces', () {
      // Facing north: field points away from the user (-z) and down (-y).
      expect(
        headingFrom(gravity: _upright, magnet: (x: 0, y: -40, z: -20)),
        closeTo(0, 1e-6),
      );
      // Facing east: north is to the user's left (-x).
      expect(
        headingFrom(gravity: _upright, magnet: (x: -20, y: -40, z: 0)),
        closeTo(90, 1e-6),
      );
    });

    test('no reading in free fall', () {
      expect(
        headingFrom(gravity: (x: 0, y: 0, z: 0), magnet: _flatMagnet(0)),
        isNull,
      );
    });
  });

  group('SensorsHeadingService', () {
    late StreamController<Vector3> accelerometer;
    late StreamController<Vector3> magnetometer;

    setUp(() {
      accelerometer = StreamController<Vector3>.broadcast();
      magnetometer = StreamController<Vector3>.broadcast();
    });

    tearDown(() async {
      await accelerometer.close();
      await magnetometer.close();
    });

    SensorsHeadingService build({double smoothing = 0.5}) =>
        SensorsHeadingService(
          accelerometer: () => accelerometer.stream,
          magnetometer: () => magnetometer.stream,
          smoothing: smoothing,
        );

    test('waits for gravity, then smooths across north', () async {
      final headings = <double>[];
      final sub = build().headings().listen(headings.add);

      magnetometer.add(_flatMagnet(0));
      await Future<void>.delayed(Duration.zero);
      expect(headings, isEmpty);

      accelerometer.add(_flat);
      magnetometer.add(_flatMagnet(350));
      magnetometer.add(_flatMagnet(10));
      await Future<void>.delayed(Duration.zero);

      expect(headings.first, closeTo(350, 1e-6));
      // Halfway between 350° and 10° is 0°, not 180°.
      final last = headings.last;
      expect(min(last, 360 - last), closeTo(0, 1e-6));

      await sub.cancel();
      expect(accelerometer.hasListener, isFalse);
      expect(magnetometer.hasListener, isFalse);
    });
  });
}
