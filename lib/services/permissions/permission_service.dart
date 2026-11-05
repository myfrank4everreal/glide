import 'package:permission_handler/permission_handler.dart';

enum AppPermission { camera, location }

enum AppPermissionStatus { granted, denied, permanentlyDenied }

abstract interface class PermissionService {
  Future<AppPermissionStatus> status(AppPermission permission);
  Future<AppPermissionStatus> request(AppPermission permission);

  /// Opens the OS settings page for this app. Returns false if it couldn't.
  Future<bool> openSettings();
}

class PermissionHandlerService implements PermissionService {
  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      _map(await _toPlugin(permission).status);

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async =>
      _map(await _toPlugin(permission).request());

  @override
  Future<bool> openSettings() => openAppSettings();

  Permission _toPlugin(AppPermission permission) => switch (permission) {
    AppPermission.camera => Permission.camera,
    AppPermission.location => Permission.locationWhenInUse,
  };

  AppPermissionStatus _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited => AppPermissionStatus.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => AppPermissionStatus.permanentlyDenied,
    _ => AppPermissionStatus.denied,
  };
}
