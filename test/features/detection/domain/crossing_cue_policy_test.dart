import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/usecases/crossing_cue_policy.dart';

Detection _d(String label) => Detection(
  label: label,
  confidence: 0.9,
  left: 0.4,
  top: 0.1,
  right: 0.5,
  bottom: 0.3,
  distanceMeters: 8,
);

void main() {
  late CrossingCuePolicy policy;
  final t0 = DateTime(2026, 11, 4, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  setUp(() => policy = CrossingCuePolicy());

  test('traffic lights and stop signs give a cue', () {
    expect(policy.next([_d('traffic light')], at(0)), isTrue);
    expect(CrossingCuePolicy().next([_d('stop sign')], at(0)), isTrue);
  });

  test('other objects do not', () {
    expect(policy.next([_d('person'), _d('car')], at(0)), isFalse);
  });

  test('stays quiet while waiting at the crossing', () {
    policy.next([_d('traffic light')], at(0));
    expect(policy.next([_d('traffic light')], at(19)), isFalse);
    expect(policy.next([_d('traffic light')], at(20)), isTrue);
  });

  test('reset allows a new cue at once', () {
    policy
      ..next([_d('traffic light')], at(0))
      ..reset();
    expect(policy.next([_d('traffic light')], at(1)), isTrue);
  });
}
