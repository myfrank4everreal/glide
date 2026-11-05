import 'package:equatable/equatable.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';

/// Everything found in one processed frame.
class DetectionResult extends Equatable {
  const DetectionResult({
    required this.detections,
    required this.processingTime,
  });

  final List<Detection> detections;

  /// Frame conversion plus inference. The target is ≤ 30 ms.
  final Duration processingTime;

  @override
  List<Object> get props => [detections, processingTime];
}
