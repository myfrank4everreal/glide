import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/core/geo/geo_point.dart';

/// Location is used only while the navigation screen is open. Positions are
/// never stored, except a place the user explicitly saves.
abstract interface class LocationService {
  /// Throws [LocationUnavailableException] if location services are off or
  /// no fix could be obtained.
  Future<LocationFix> currentFix();

  /// Emits a new fix every [distanceFilterMeters] of movement. Errors are
  /// reported as [LocationUnavailableException].
  Stream<LocationFix> fixStream({int distanceFilterMeters = 2});
}

class GeolocatorLocationService implements LocationService {
  static const _settings = LocationSettings(accuracy: LocationAccuracy.best);

  static LocationFix _toFix(Position p) => LocationFix(
    GeoPoint(p.latitude, p.longitude),
    accuracyMeters: p.accuracy,
  );

  @override
  Future<LocationFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException('Location services are off');
    }
    try {
      return _toFix(
        await Geolocator.getCurrentPosition(locationSettings: _settings),
      );
    } on Exception catch (e) {
      throw LocationUnavailableException('$e');
    }
  }

  @override
  Stream<LocationFix> fixStream({int distanceFilterMeters = 2}) =>
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilterMeters,
        ),
      ).transform(
        StreamTransformer<Position, LocationFix>.fromHandlers(
          handleData: (p, sink) => sink.add(_toFix(p)),
          handleError: (e, _, sink) =>
              sink.addError(LocationUnavailableException('$e')),
        ),
      );
}
