import 'package:glide/features/navigation/domain/entities/guidance.dart';

/// Decides when to speak while guiding. Position and compass update many
/// times a second; the user needs a few clear sentences, not a stream:
///
/// * The first reading is announced at once.
/// * A change of direction (clock hour) is announced, at most once per
///   [minGap], so turning on the spot doesn't make it babble.
/// * Otherwise the guidance is repeated every [repeatEvery] as reassurance.
/// * Weak GPS is announced once each time it becomes weak.
/// * Arrival is announced once.
class GuidancePolicy {
  GuidancePolicy({
    this.minGap = const Duration(seconds: 4),
    this.repeatEvery = const Duration(seconds: 30),
  });

  final Duration minGap;
  final Duration repeatEvery;

  DateTime? _lastAt;
  int? _lastHour;
  bool _weakTold = false;
  bool _arrivedTold = false;

  GuidanceCue? next(Guidance guidance, DateTime now) {
    if (guidance.arrived) {
      if (_arrivedTold) return null;
      _arrivedTold = true;
      return _told(GuidanceCue.arrived, guidance, now);
    }
    if (!guidance.weakSignal) _weakTold = false;
    if (guidance.weakSignal && !_weakTold) {
      _weakTold = true;
      return _told(GuidanceCue.weakSignal, guidance, now);
    }

    final last = _lastAt;
    if (last == null) return _told(GuidanceCue.update, guidance, now);
    final since = now.difference(last);
    final turned = guidance.clockHour != _lastHour;
    if ((turned && since >= minGap) || since >= repeatEvery) {
      return _told(GuidanceCue.update, guidance, now);
    }
    return null;
  }

  GuidanceCue _told(GuidanceCue cue, Guidance guidance, DateTime now) {
    _lastAt = now;
    _lastHour = guidance.clockHour;
    return cue;
  }

  void reset() {
    _lastAt = null;
    _lastHour = null;
    _weakTold = false;
    _arrivedTold = false;
  }
}
