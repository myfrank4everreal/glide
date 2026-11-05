import 'package:glide/features/detection/domain/entities/detection.dart';

/// Tells the user a street crossing may be ahead, from things the detector
/// can see near one (traffic lights, stop signs).
///
/// It never says it is safe to cross: the model can't read pedestrian
/// signals or see crossing markings, and a missed car could kill. That needs
/// a purpose-trained model and testing with blind users (see docs/tasks.md).
class CrossingCuePolicy {
  CrossingCuePolicy({this.cooldown = const Duration(seconds: 20)});

  /// Quiet time after a cue, so waiting at a crossing isn't one long alarm.
  final Duration cooldown;

  static const cueLabels = {'traffic light', 'stop sign'};

  DateTime? _lastAt;

  bool next(List<Detection> detections, DateTime now) {
    final last = _lastAt;
    if (last != null && now.difference(last) < cooldown) return false;
    if (!detections.any((d) => cueLabels.contains(d.label))) return false;
    _lastAt = now;
    return true;
  }

  void reset() => _lastAt = null;
}
