import 'package:glide/core/constants/app_constants.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';

/// Picks which detections are worth telling the user about: drops low
/// confidence ones, then orders by danger (closest first, objects straight
/// ahead before ones to the side) and keeps the top few.
class PrioritizeDetections {
  const PrioritizeDetections({
    this.maxResults = AppConstants.maxAlertsPerFrame,
  });

  final int maxResults;

  List<Detection> call(
    List<Detection> detections, {
    required double confidenceThreshold,
  }) {
    final relevant =
        detections.where((d) => d.confidence >= confidenceThreshold).toList()
          ..sort(_byDanger);
    return relevant.take(maxResults).toList(growable: false);
  }

  static int _byDanger(Detection a, Detection b) {
    final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
    if (byDistance != 0) return byDistance;
    final aAhead = a.direction == Direction.ahead ? 0 : 1;
    final bAhead = b.direction == Direction.ahead ? 0 : 1;
    if (aAhead != bAhead) return aAhead - bAhead;
    return b.confidence.compareTo(a.confidence);
  }
}
