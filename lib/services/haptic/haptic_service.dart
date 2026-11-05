import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:vibration/vibration.dart';

abstract interface class HapticService {
  Future<bool> get isAvailable;

  Future<void> play(HapticPattern pattern);

  /// 0.0 to 1.0. Ignored on devices without amplitude control (most iPhones
  /// via this plugin, older Android phones).
  void setIntensity(double intensity);

  Future<void> cancel();
}

class VibrationHapticService implements HapticService {
  double _intensity = 1;
  bool? _hasVibrator;
  bool? _hasAmplitudeControl;

  @override
  Future<bool> get isAvailable async =>
      _hasVibrator ??= await Vibration.hasVibrator();

  @override
  void setIntensity(double intensity) => _intensity = intensity.clamp(0.0, 1.0);

  @override
  Future<void> play(HapticPattern pattern) async {
    if (!await isAvailable || _intensity == 0) return;
    _hasAmplitudeControl ??= await Vibration.hasAmplitudeControl();
    final amplitude = (_intensity * 255).round().clamp(1, 255);
    await Vibration.vibrate(
      pattern: pattern.timings,
      // One amplitude per timing entry: 0 for waits, amplitude for pulses.
      intensities: _hasAmplitudeControl!
          ? [
              for (var i = 0; i < pattern.timings.length; i++)
                i.isOdd ? amplitude : 0,
            ]
          : const [],
    );
  }

  @override
  Future<void> cancel() => Vibration.cancel();
}
