import 'package:equatable/equatable.dart';

enum DistanceBand { close, near, far }

enum Direction { left, ahead, right }

/// An object the detector found in the current frame.
class Detection extends Equatable {
  const Detection({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.distanceMeters,
  });

  final String label;

  /// 0.0–1.0
  final double confidence;

  /// Bounding box, normalised 0–1, origin top-left.
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Rough estimate; treat as a band, not a measurement.
  final double distanceMeters;

  double get centerX => (left + right) / 2;

  Direction get direction {
    if (centerX < 1 / 3) return Direction.left;
    if (centerX > 2 / 3) return Direction.right;
    return Direction.ahead;
  }

  DistanceBand bandFor({
    required double closeMeters,
    required double nearMeters,
  }) {
    if (distanceMeters < closeMeters) return DistanceBand.close;
    if (distanceMeters < nearMeters) return DistanceBand.near;
    return DistanceBand.far;
  }

  @override
  List<Object> get props => [
    label,
    confidence,
    left,
    top,
    right,
    bottom,
    distanceMeters,
  ];
}
