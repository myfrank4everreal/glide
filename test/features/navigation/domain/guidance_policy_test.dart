import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/navigation/domain/entities/guidance.dart';
import 'package:glide/features/navigation/domain/usecases/guidance_policy.dart';

Guidance _g({int? hour = 12, bool arrived = false, bool weak = false}) =>
    Guidance(
      distanceMeters: 100,
      accuracyMeters: 5,
      clockHour: hour,
      arrived: arrived,
      weakSignal: weak,
    );

void main() {
  late GuidancePolicy policy;
  final t0 = DateTime(2026, 11, 4, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  setUp(() => policy = GuidancePolicy());

  test('the first reading is announced, then not every update', () {
    expect(policy.next(_g(), at(0)), GuidanceCue.update);
    expect(policy.next(_g(), at(1)), isNull);
    expect(policy.next(_g(), at(10)), isNull);
  });

  test('a turn is announced, but not more than once per gap', () {
    policy.next(_g(), at(0));
    expect(policy.next(_g(hour: 1), at(2)), isNull);
    expect(policy.next(_g(hour: 1), at(4)), GuidanceCue.update);
    expect(policy.next(_g(hour: 1), at(6)), isNull);
  });

  test('guidance is repeated as reassurance', () {
    policy.next(_g(), at(0));
    expect(policy.next(_g(), at(30)), GuidanceCue.update);
  });

  test('weak GPS is announced once each time it becomes weak', () {
    policy.next(_g(), at(0));
    expect(policy.next(_g(weak: true), at(1)), GuidanceCue.weakSignal);
    expect(policy.next(_g(weak: true), at(2)), isNull);
    policy.next(_g(), at(40));
    expect(policy.next(_g(weak: true), at(41)), GuidanceCue.weakSignal);
  });

  test('arrival is announced once, straight away', () {
    policy.next(_g(), at(0));
    expect(policy.next(_g(arrived: true), at(1)), GuidanceCue.arrived);
    expect(policy.next(_g(arrived: true), at(40)), isNull);
  });

  test('reset starts over', () {
    policy
      ..next(_g(), at(0))
      ..reset();
    expect(policy.next(_g(), at(1)), GuidanceCue.update);
  });
}
