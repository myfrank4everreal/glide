import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen from sleeping while Glide is watching or guiding. If the
/// phone locked mid-walk the camera and compass would stop, silently.
abstract interface class ScreenAwakeService {
  Future<void> keepOn();
  Future<void> allowOff();
}

class WakelockScreenAwakeService implements ScreenAwakeService {
  @override
  Future<void> keepOn() => WakelockPlus.enable();

  @override
  Future<void> allowOff() => WakelockPlus.disable();
}

/// For places where keeping the screen on doesn't matter (and tests).
class NoScreenAwakeService implements ScreenAwakeService {
  const NoScreenAwakeService();

  @override
  Future<void> keepOn() async {}

  @override
  Future<void> allowOff() async {}
}
