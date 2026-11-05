/// Vibration patterns. Each distance band must feel clearly different so a
/// user can tell them apart without hearing the voice alert.
enum HapticPattern {
  /// Short tick to confirm a button press.
  tap([0, 40]),

  /// Obstacle further than 3 m: one soft pulse.
  far([0, 120]),

  /// Obstacle 1–3 m away: two pulses.
  near([0, 150, 100, 150]),

  /// Obstacle closer than 1 m: rapid burst.
  close([0, 80, 60, 80, 60, 80, 60, 80]),

  /// Possible street crossing ahead: three long pulses, unlike any
  /// obstacle pattern.
  crossing([0, 200, 120, 200, 120, 200]),

  /// Something worked (e.g. text found, arrived).
  success([0, 60, 80, 200]),

  /// Something failed (e.g. no text found, GPS lost).
  error([0, 400]);

  const HapticPattern(this.timings);

  /// Alternating wait/vibrate durations in milliseconds, starting with a wait.
  final List<int> timings;

  Duration get totalDuration =>
      Duration(milliseconds: timings.fold(0, (sum, ms) => sum + ms));
}
