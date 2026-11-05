import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/services/location/location_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

Position _position(double lat, double lng, {double accuracy = 5}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _MockGeolocator platform;
  final service = GeolocatorLocationService();

  setUp(() {
    platform = _MockGeolocator();
    GeolocatorPlatform.instance = platform;
  });

  test('currentFix returns the position and its accuracy', () async {
    when(
      () => platform.isLocationServiceEnabled(),
    ).thenAnswer((_) async => true);
    when(
      () => platform.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) async => _position(51.5, -0.12, accuracy: 8));

    expect(
      await service.currentFix(),
      const LocationFix(GeoPoint(51.5, -0.12), accuracyMeters: 8),
    );
  });

  test('currentFix throws when location services are off', () async {
    when(
      () => platform.isLocationServiceEnabled(),
    ).thenAnswer((_) async => false);

    expect(service.currentFix(), throwsA(isA<LocationUnavailableException>()));
  });

  test('currentFix wraps plugin errors', () async {
    when(
      () => platform.isLocationServiceEnabled(),
    ).thenAnswer((_) async => true);
    when(
      () => platform.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenThrow(const PositionUpdateException('no'));

    expect(service.currentFix(), throwsA(isA<LocationUnavailableException>()));
  });

  test('fixStream maps positions and wraps errors', () async {
    when(
      () => platform.getPositionStream(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        _position(1, 2),
      ]).followedBy(Stream.error(const LocationServiceDisabledException())),
    );

    final events = <Object>[];
    final done = Completer<void>();
    service.fixStream().listen(
      events.add,
      onError: events.add,
      onDone: done.complete,
    );
    await done.future;

    expect(events.first, const LocationFix(GeoPoint(1, 2), accuracyMeters: 5));
    expect(events.last, isA<LocationUnavailableException>());
  });
}

extension<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> next) async* {
    yield* this;
    yield* next;
  }
}
