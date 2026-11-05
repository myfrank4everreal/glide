import 'package:equatable/equatable.dart';
import 'package:glide/core/constants/app_constants.dart';

class UserSettings extends Equatable {
  const UserSettings({
    this.voiceEnabled = true,
    this.speechRate = 0.5,
    this.hapticsEnabled = true,
    this.hapticIntensity = 1,
    this.confidenceThreshold = AppConstants.defaultConfidenceThreshold,
    this.highContrast = false,
    this.languageCode = 'en',
    this.onboardingDone = false,
  });

  final bool voiceEnabled;

  /// 0.0–1.0, 0.5 = normal.
  final double speechRate;

  final bool hapticsEnabled;

  /// 0.0–1.0
  final double hapticIntensity;

  /// Detections below this confidence are ignored. Lower = more alerts.
  final double confidenceThreshold;

  final bool highContrast;

  /// Language code matching an ARB file, e.g. `en`, `es`, `zh`.
  final String languageCode;

  /// The first-launch tutorial (including the safety notice) was completed.
  final bool onboardingDone;

  UserSettings copyWith({
    bool? voiceEnabled,
    double? speechRate,
    bool? hapticsEnabled,
    double? hapticIntensity,
    double? confidenceThreshold,
    bool? highContrast,
    String? languageCode,
    bool? onboardingDone,
  }) {
    return UserSettings(
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      speechRate: speechRate ?? this.speechRate,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      highContrast: highContrast ?? this.highContrast,
      languageCode: languageCode ?? this.languageCode,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  @override
  List<Object> get props => [
    voiceEnabled,
    speechRate,
    hapticsEnabled,
    hapticIntensity,
    confidenceThreshold,
    highContrast,
    languageCode,
    onboardingDone,
  ];
}
