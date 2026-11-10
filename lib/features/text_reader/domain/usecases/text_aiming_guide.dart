import 'dart:math';

import 'package:glide/core/vision/recognized_line.dart';

/// What the user should do with the phone to get the text fully in view.
enum AimHint {
  /// No text in view.
  none,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,

  /// Text is too small to read reliably.
  moveCloser,

  /// Text runs off both sides: it's bigger than the picture.
  moveBack,

  /// Text is in view; waiting for it to stay steady.
  holdStill,

  /// Text has been steady and complete: read it now.
  ready,
}

/// Turns live text recognition into aiming hints, the way a sighted helper
/// would: "a bit to the left", "closer", "hold still". Stateful: it counts
/// how many frames in a row the same text was seen.
class TextAimingGuide {
  TextAimingGuide({
    this.edgeMargin = 0.03,
    this.minLineHeight = 0.025,
    this.stableFrames = 2,
    this.minOverlap = 0.7,
  });

  /// A line this close to an edge (fraction of the picture) counts as cut off.
  final double edgeMargin;

  /// Typical line height below which text is too small to read well.
  final double minLineHeight;

  /// Consecutive matching frames needed before reading.
  final int stableFrames;

  /// Share of words two frames must have in common to count as the same text.
  /// Recognition jitters a little between frames, so exact matches are rare.
  final double minOverlap;

  Set<String> _lastWords = const {};
  int _steady = 0;

  AimHint next(List<RecognizedLine> lines) {
    if (lines.isEmpty) {
      reset();
      return AimHint.none;
    }
    final left = lines.map((l) => l.left).reduce(min);
    final right = lines.map((l) => l.right).reduce(max);
    final top = lines.map((l) => l.top).reduce(min);
    final bottom = lines.map((l) => l.bottom).reduce(max);
    final cutLeft = left < edgeMargin;
    final cutRight = right > 1 - edgeMargin;
    final cutTop = top < edgeMargin;
    final cutBottom = bottom > 1 - edgeMargin;

    final hint = switch (()) {
      _ when (cutLeft && cutRight) || (cutTop && cutBottom) => AimHint.moveBack,
      _ when cutLeft => AimHint.moveLeft,
      _ when cutRight => AimHint.moveRight,
      _ when cutTop => AimHint.moveUp,
      _ when cutBottom => AimHint.moveDown,
      _ when _medianHeight(lines) < minLineHeight => AimHint.moveCloser,
      _ => null,
    };
    if (hint != null) {
      reset();
      return hint;
    }

    final words = _words(lines);
    _steady = _overlap(words, _lastWords) >= minOverlap ? _steady + 1 : 1;
    _lastWords = words;
    return _steady >= stableFrames ? AimHint.ready : AimHint.holdStill;
  }

  void reset() {
    _lastWords = const {};
    _steady = 0;
  }

  static double _medianHeight(List<RecognizedLine> lines) {
    final heights = [for (final l in lines) l.height]..sort();
    return heights[heights.length ~/ 2];
  }

  static Set<String> _words(List<RecognizedLine> lines) => {
    for (final line in lines)
      for (final w in line.text.toLowerCase().split(RegExp(r'\s+')))
        if (w.isNotEmpty) w,
  };

  /// Jaccard similarity: shared words over all words.
  static double _overlap(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    return a.intersection(b).length / a.union(b).length;
  }
}
