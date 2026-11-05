import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/tts/tts_service.dart';

/// The first-launch tutorial. State is the index of the page being shown.
class OnboardingCubit extends Cubit<int> {
  OnboardingCubit({
    required this._tts,
    required this._haptics,
    this._patternGap = const Duration(milliseconds: 700),
  }) : super(0);

  final TtsService _tts;
  final HapticService _haptics;
  final Duration _patternGap;

  static const pageCount = 5;

  bool get isLastPage => state == pageCount - 1;

  /// Shows [page]. [speak] is read aloud for users without a screen reader
  /// (a screen reader already reads the page, and two voices clash).
  void goTo(int page, {String? speak}) {
    final target = page.clamp(0, pageCount - 1);
    if (target != state) emit(target);
    if (speak != null) unawaited(_tts.speak(speak, interrupt: true));
  }

  void next({String? speak}) => goTo(state + 1, speak: speak);

  void back({String? speak}) => goTo(state - 1, speak: speak);

  /// Plays each alert pattern after saying its name, so the user learns to
  /// tell them apart before relying on them.
  Future<void> playPatterns({
    required Map<HapticPattern, String> labels,
    required bool speak,
  }) async {
    for (final MapEntry(key: pattern, value: label) in labels.entries) {
      if (isClosed) return;
      if (speak) await _tts.speak(label, interrupt: true);
      await _haptics.play(pattern);
      await Future<void>.delayed(pattern.totalDuration + _patternGap);
    }
  }

  Future<void> stopSpeaking() => _tts.stop();
}
