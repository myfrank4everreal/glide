/// App-wide constants. Values that users can change live in `UserSettings`;
/// these are fixed defaults and limits.
abstract final class AppConstants {
  static const String appName = 'Glide';

  // Detection
  static const double defaultConfidenceThreshold = 0.6;
  static const double closeDistanceMeters = 1;
  static const double nearDistanceMeters = 3;
  static const int maxAlertsPerFrame = 3;
  static const Duration alertCooldown = Duration(seconds: 3);

  // Model assets (added in Milestone 2)
  static const String detectorModelAsset = 'assets/models/detector.tflite';
  static const String detectorLabelsAsset = 'assets/models/labels.txt';

  // Accessibility
  static const double minTouchTarget = 48;
  static const double primaryButtonHeight = 72;
}
