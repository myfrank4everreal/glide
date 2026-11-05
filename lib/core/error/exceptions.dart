/// Errors raised by services and repositories. Cubits catch these and turn
/// them into user-facing (spoken) states.
sealed class GlideException implements Exception {
  const GlideException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class PermissionDeniedException extends GlideException {
  const PermissionDeniedException(super.message, {this.permanently = false});

  /// True when the OS will no longer show the prompt and the user must
  /// change the permission in system settings.
  final bool permanently;
}

final class CameraUnavailableException extends GlideException {
  const CameraUnavailableException(super.message);
}

final class ModelLoadException extends GlideException {
  const ModelLoadException(super.message);
}

final class LocationUnavailableException extends GlideException {
  const LocationUnavailableException(super.message);
}
