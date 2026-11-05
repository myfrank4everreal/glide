import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/features/camera/presentation/cubit/camera_state.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/permissions/permission_service.dart';
import 'package:glide/services/tts/tts_service.dart';

export 'package:glide/features/camera/presentation/cubit/camera_state.dart';

/// Camera permission and lifecycle for the detection screen.
class CameraCubit extends Cubit<CameraState> {
  CameraCubit({
    required this._permissions,
    required this._camera,
    required this._haptics,
    required this._tts,
    this._hapticTestGap = const Duration(milliseconds: 600),
  }) : super(const CameraInitial());

  final PermissionService _permissions;
  final CameraService _camera;
  final HapticService _haptics;
  final TtsService _tts;
  final Duration _hapticTestGap;

  Future<void> start() async {
    switch (await _permissions.status(AppPermission.camera)) {
      case AppPermissionStatus.granted:
        await _startCamera();
      case AppPermissionStatus.denied:
        emit(const CameraNeedsPermission());
      case AppPermissionStatus.permanentlyDenied:
        emit(const CameraPermissionDenied(permanently: true));
    }
  }

  /// Shows the OS prompt. Call only after the user has heard why.
  Future<void> requestPermission() async {
    switch (await _permissions.request(AppPermission.camera)) {
      case AppPermissionStatus.granted:
        await _startCamera();
      case AppPermissionStatus.denied:
        await _haptics.play(HapticPattern.error);
        emit(const CameraPermissionDenied(permanently: false));
      case AppPermissionStatus.permanentlyDenied:
        await _haptics.play(HapticPattern.error);
        emit(const CameraPermissionDenied(permanently: true));
    }
  }

  Future<void> openSettings() => _permissions.openSettings();

  /// App moved to the background. The OS permission prompt also triggers
  /// this, so only an active camera is released.
  Future<void> pause() async {
    if (state is! CameraReady) return;
    // Take the preview off screen before releasing the controller it renders.
    emit(const CameraPaused());
    await _camera.dispose();
  }

  /// App came back. Reopens a paused camera, and re-checks permission in case
  /// the user just granted it in system settings.
  Future<void> resume() async {
    switch (state) {
      case CameraPaused():
        await _startCamera();
      case CameraPermissionDenied():
        if (await _permissions.status(AppPermission.camera) ==
            AppPermissionStatus.granted) {
          await _startCamera();
        }
      default:
        break;
    }
  }

  Future<void> announce(String text) => _tts.speak(text);

  /// Plays each pattern with a pause in between, saying its name first so
  /// the user learns which feeling means what.
  Future<void> testHaptics({
    required Map<HapticPattern, String> labels,
    required bool speak,
  }) async {
    for (final MapEntry(key: pattern, value: label) in labels.entries) {
      if (speak) await _tts.speak(label, interrupt: true);
      await _haptics.play(pattern);
      await Future<void>.delayed(pattern.totalDuration + _hapticTestGap);
    }
  }

  Future<void> _startCamera() async {
    emit(const CameraStarting());
    try {
      await _camera.initialize();
    } on CameraUnavailableException catch (e) {
      await _haptics.play(HapticPattern.error);
      emit(CameraFailed(e.message));
      return;
    }
    await _haptics.play(HapticPattern.success);
    emit(CameraReady(_camera.controller!));
  }

  @override
  Future<void> close() async {
    await _camera.dispose();
    return super.close();
  }
}
