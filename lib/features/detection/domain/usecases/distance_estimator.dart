import 'dart:math';

/// Rough distance from how tall an object looks, using a typical real height
/// per object type and the camera's vertical field of view (pinhole model).
///
/// Accuracy is about ±30–50%: good enough to choose a distance band, not a
/// measurement. Milestone 3 calibrates it; Phase 2 adds LiDAR depth.
class DistanceEstimator {
  const DistanceEstimator({this.verticalFovDegrees = 65});

  /// Vertical field of view in portrait. Typical phone main cameras are
  /// 60–70° along the long side.
  final double verticalFovDegrees;

  static const double minMeters = 0.5;
  static const double maxMeters = 20;

  /// Typical heights in metres for the COCO classes that matter to a person
  /// walking. Anything not listed is ignored as an obstacle.
  static const Map<String, double> typicalHeights = {
    'person': 1.7,
    'bicycle': 1.0,
    'car': 1.5,
    'motorcycle': 1.1,
    'bus': 3.0,
    'truck': 3.0,
    'traffic light': 0.8,
    'fire hydrant': 0.7,
    'stop sign': 0.75,
    'parking meter': 1.3,
    'bench': 0.85,
    'dog': 0.6,
    'horse': 1.6,
    'cow': 1.5,
    'chair': 0.9,
    'couch': 0.85,
    'potted plant': 0.8,
    'dining table': 0.75,
    'suitcase': 0.65,
  };

  bool isObstacle(String label) => typicalHeights.containsKey(label);

  /// [boxHeight] is the box height as a fraction of the upright frame.
  double estimateMeters({required String label, required double boxHeight}) {
    // Taller than the frame: the object is right in front of the camera.
    if (boxHeight >= 0.95) return minMeters;
    final realHeight = typicalHeights[label] ?? 1.0;
    final halfFov = verticalFovDegrees / 2 * pi / 180;
    final meters = realHeight / (2 * max(boxHeight, 1e-6) * tan(halfFov));
    return meters.clamp(minMeters, maxMeters);
  }
}
