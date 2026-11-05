import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vibration_platform_interface/vibration_platform_interface.dart';

class _MockVibration extends Mock
    with MockPlatformInterfaceMixin
    implements VibrationPlatform {}

void main() {
  late _MockVibration platform;
  late VibrationHapticService service;

  void stubDevice({required bool vibrator, required bool amplitude}) {
    when(() => platform.hasVibrator()).thenAnswer((_) async => vibrator);
    when(
      () => platform.hasAmplitudeControl(),
    ).thenAnswer((_) async => amplitude);
  }

  setUp(() {
    platform = _MockVibration();
    VibrationPlatform.instance = platform;
    when(
      () => platform.vibrate(
        pattern: any(named: 'pattern'),
        intensities: any(named: 'intensities'),
      ),
    ).thenAnswer((_) async {});
    when(() => platform.cancel()).thenAnswer((_) async {});
    service = VibrationHapticService();
  });

  test('plays the pattern with per-pulse amplitudes when supported', () async {
    stubDevice(vibrator: true, amplitude: true);
    service.setIntensity(0.5);

    await service.play(HapticPattern.near);

    verify(
      () => platform.vibrate(
        pattern: HapticPattern.near.timings,
        intensities: [0, 128, 0, 128],
      ),
    ).called(1);
  });

  test('sends no intensities when amplitude control is missing', () async {
    stubDevice(vibrator: true, amplitude: false);

    await service.play(HapticPattern.far);

    verify(
      () =>
          platform.vibrate(pattern: HapticPattern.far.timings, intensities: []),
    ).called(1);
  });

  test('does nothing on devices without a vibrator', () async {
    stubDevice(vibrator: false, amplitude: false);

    await service.play(HapticPattern.close);

    expect(await service.isAvailable, isFalse);
    verifyNever(
      () => platform.vibrate(
        pattern: any(named: 'pattern'),
        intensities: any(named: 'intensities'),
      ),
    );
  });

  test('intensity 0 mutes haptics', () async {
    stubDevice(vibrator: true, amplitude: true);
    service.setIntensity(0);

    await service.play(HapticPattern.close);

    verifyNever(
      () => platform.vibrate(
        pattern: any(named: 'pattern'),
        intensities: any(named: 'intensities'),
      ),
    );
  });

  test('cancel stops vibration', () async {
    await service.cancel();

    verify(() => platform.cancel()).called(1);
  });
}
