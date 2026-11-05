import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/obstacle_alert.dart';
import 'package:glide/features/detection/domain/usecases/alert_policy.dart';

Detection _d(String label, double meters, {double centerX = 0.5}) => Detection(
  label: label,
  confidence: 0.9,
  left: centerX - 0.05,
  top: 0.2,
  right: centerX + 0.05,
  bottom: 0.8,
  distanceMeters: meters,
);

void main() {
  late AlertPolicy policy;
  final t0 = DateTime(2026, 11, 4, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  setUp(
    () => policy = AlertPolicy(
      cooldown: const Duration(seconds: 3),
      minGap: const Duration(milliseconds: 1500),
    ),
  );

  test('alerts on a near obstacle with label, direction and band', () {
    expect(
      policy.next([_d('person', 2, centerX: 0.1)], at(0)),
      const ObstacleAlert(
        label: 'person',
        direction: Direction.left,
        band: DistanceBand.near,
      ),
    );
  });

  test('far obstacles are shown but not announced', () {
    expect(policy.next([_d('bench', 6)], at(0)), isNull);
  });

  test('only the most dangerous detection is announced per frame', () {
    final alert = policy.next([_d('pole', 0.6), _d('bench', 2)], at(0));
    expect(alert?.label, 'pole');
  });

  test('close obstacles are urgent', () {
    expect(policy.next([_d('car', 0.6)], at(0))!.urgent, isTrue);
    policy.reset();
    expect(policy.next([_d('car', 2)], at(0))!.urgent, isFalse);
  });

  group('repetition', () {
    test('the same object is not repeated within the cooldown', () {
      policy.next([_d('bench', 2)], at(0));
      expect(policy.next([_d('bench', 2)], at(2000)), isNull);
    });

    test('after the cooldown it is announced again', () {
      policy.next([_d('bench', 2)], at(0));
      expect(policy.next([_d('bench', 2)], at(3000)), isNotNull);
    });

    test('moving into a closer band is announced immediately', () {
      policy.next([_d('person', 2)], at(0));
      final alert = policy.next([_d('person', 0.7)], at(300));
      expect(alert?.band, DistanceBand.close);
    });

    test('moving further away is not announced', () {
      policy.next([_d('person', 0.7)], at(0));
      expect(policy.next([_d('person', 2)], at(300)), isNull);
    });

    test('the same type on the other side counts as a different object', () {
      policy.next([_d('person', 2, centerX: 0.1)], at(0));
      expect(
        policy.next([_d('person', 2, centerX: 0.9)], at(2000))?.direction,
        Direction.right,
      );
    });

    test('a repeated object does not block a new one behind it', () {
      policy.next([_d('bench', 2)], at(0));
      final alert = policy.next([_d('bench', 2), _d('bicycle', 2.5)], at(2000));
      expect(alert?.label, 'bicycle');
    });
  });

  group('pacing', () {
    test('non-urgent alerts keep a gap so speech stays understandable', () {
      policy.next([_d('bench', 2)], at(0));
      expect(policy.next([_d('bicycle', 2)], at(800)), isNull);
      expect(policy.next([_d('bicycle', 2)], at(1600)), isNotNull);
    });

    test('urgent alerts ignore the gap', () {
      policy.next([_d('bench', 2)], at(0));
      expect(policy.next([_d('car', 0.6)], at(200))?.urgent, isTrue);
    });
  });

  test('reset forgets history, e.g. when the camera restarts', () {
    policy.next([_d('bench', 2)], at(0));
    policy.reset();
    expect(policy.next([_d('bench', 2)], at(100)), isNotNull);
  });

  test('empty frames produce no alert', () {
    expect(policy.next(const [], at(0)), isNull);
  });
}
