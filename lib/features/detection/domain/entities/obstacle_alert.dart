import 'package:equatable/equatable.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';

/// Something the user should be told about right now.
class ObstacleAlert extends Equatable {
  const ObstacleAlert({
    required this.label,
    required this.direction,
    required this.band,
  });

  final String label;
  final Direction direction;
  final DistanceBand band;

  /// Close-range alerts interrupt any speech in progress.
  bool get urgent => band == DistanceBand.close;

  @override
  List<Object> get props => [label, direction, band];
}
