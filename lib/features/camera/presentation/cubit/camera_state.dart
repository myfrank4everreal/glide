import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';

sealed class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

final class CameraInitial extends CameraState {
  const CameraInitial();
}

/// Camera access not granted yet. The page explains why it's needed before
/// the OS prompt appears.
final class CameraNeedsPermission extends CameraState {
  const CameraNeedsPermission();
}

final class CameraPermissionDenied extends CameraState {
  const CameraPermissionDenied({required this.permanently});

  /// When true the OS won't ask again; the user has to use system settings.
  final bool permanently;

  @override
  List<Object?> get props => [permanently];
}

final class CameraStarting extends CameraState {
  const CameraStarting();
}

final class CameraReady extends CameraState {
  const CameraReady(this.controller);

  final CameraController controller;

  @override
  List<Object?> get props => [controller];
}

/// App went to the background; the camera was released.
final class CameraPaused extends CameraState {
  const CameraPaused();
}

final class CameraFailed extends CameraState {
  const CameraFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
