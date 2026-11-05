import 'package:equatable/equatable.dart';

/// Where the target is relative to the user right now.
class Guidance extends Equatable {
  const Guidance({
    required this.distanceMeters,
    required this.accuracyMeters,
    this.clockHour,
    this.arrived = false,
    this.weakSignal = false,
  });

  /// Straight-line distance to the target.
  final double distanceMeters;

  /// GPS uncertainty of the user's position.
  final double accuracyMeters;

  /// Direction as a clock face, the way orientation and mobility instructors
  /// teach it: 12 is straight ahead, 3 is to the right. Null until the
  /// compass has given a reading.
  final int? clockHour;

  final bool arrived;

  /// GPS too inaccurate for the directions to be trusted.
  final bool weakSignal;

  @override
  List<Object?> get props => [
    distanceMeters,
    accuracyMeters,
    clockHour,
    arrived,
    weakSignal,
  ];
}

/// Why something is being announced.
enum GuidanceCue { update, weakSignal, arrived }
