import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

int _pulses(HapticPattern p) => p.timings.length ~/ 2;

void main() {
  test('every pattern is wait/vibrate pairs starting with a wait', () {
    for (final pattern in HapticPattern.values) {
      expect(pattern.timings.length.isEven, isTrue, reason: pattern.name);
      expect(pattern.timings.first, 0, reason: pattern.name);
      expect(
        pattern.timings.every((ms) => ms >= 0),
        isTrue,
        reason: pattern.name,
      );
    }
  });

  test('distance bands are distinguishable by pulse count', () {
    expect(_pulses(HapticPattern.far), 1);
    expect(_pulses(HapticPattern.near), 2);
    expect(_pulses(HapticPattern.close), greaterThan(2));
  });

  test('alerts are short enough not to overlap the next frame of alerts', () {
    for (final pattern in HapticPattern.values) {
      expect(
        pattern.totalDuration,
        lessThan(const Duration(seconds: 1)),
        reason: pattern.name,
      );
    }
  });
}
