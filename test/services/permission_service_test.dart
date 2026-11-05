import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/permissions/permission_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPermissions extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {}

void main() {
  late _MockPermissions platform;
  final service = PermissionHandlerService();

  setUpAll(() => registerFallbackValue(Permission.camera));

  setUp(() {
    platform = _MockPermissions();
    PermissionHandlerPlatform.instance = platform;
  });

  void stubStatus(PermissionStatus status) {
    when(
      () => platform.checkPermissionStatus(any()),
    ).thenAnswer((_) async => status);
  }

  test('maps granted and limited to granted', () async {
    stubStatus(PermissionStatus.granted);
    expect(
      await service.status(AppPermission.camera),
      AppPermissionStatus.granted,
    );

    stubStatus(PermissionStatus.limited);
    expect(
      await service.status(AppPermission.camera),
      AppPermissionStatus.granted,
    );
  });

  test('maps denied to denied', () async {
    stubStatus(PermissionStatus.denied);
    expect(
      await service.status(AppPermission.camera),
      AppPermissionStatus.denied,
    );
  });

  test('maps permanently denied and restricted to permanentlyDenied', () async {
    stubStatus(PermissionStatus.permanentlyDenied);
    expect(
      await service.status(AppPermission.camera),
      AppPermissionStatus.permanentlyDenied,
    );

    stubStatus(PermissionStatus.restricted);
    expect(
      await service.status(AppPermission.camera),
      AppPermissionStatus.permanentlyDenied,
    );
  });

  test('location asks for when-in-use permission only', () async {
    when(() => platform.requestPermissions(any())).thenAnswer(
      (_) async => {Permission.locationWhenInUse: PermissionStatus.granted},
    );

    final result = await service.request(AppPermission.location);

    expect(result, AppPermissionStatus.granted);
    verify(
      () => platform.requestPermissions([Permission.locationWhenInUse]),
    ).called(1);
  });

  test('openSettings delegates to the platform', () async {
    when(() => platform.openAppSettings()).thenAnswer((_) async => true);

    expect(await service.openSettings(), isTrue);
  });
}
