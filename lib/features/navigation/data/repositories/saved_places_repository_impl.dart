import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';
import 'package:glide/features/navigation/domain/repositories/saved_places_repository.dart';

/// Keeps places in the platform's encrypted store (Android Keystore, iOS
/// Keychain). A location someone saved, like their front door, is sensitive.
/// `SettingsRepository.deleteAllUserData` erases it with the rest of the
/// secure store.
class SavedPlacesRepositoryImpl implements SavedPlacesRepository {
  SavedPlacesRepositoryImpl(this._storage);

  final FlutterSecureStorage _storage;

  static const storageKey = 'navigation.savedPlaces';

  @override
  Future<List<SavedPlace>> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final item in list.cast<Map<String, Object?>>())
          SavedPlace(
            id: item['id']! as String,
            name: item['name']! as String,
            point: GeoPoint(
              (item['lat']! as num).toDouble(),
              (item['lon']! as num).toDouble(),
            ),
          ),
      ];
    } on Object {
      // Unreadable data is dropped rather than crashing the screen.
      return const [];
    }
  }

  @override
  Future<void> add(SavedPlace place) async => _write([...await load(), place]);

  @override
  Future<void> remove(String id) async =>
      _write([...(await load()).where((p) => p.id != id)]);

  Future<void> _write(List<SavedPlace> places) => _storage.write(
    key: storageKey,
    value: jsonEncode([
      for (final p in places)
        {
          'id': p.id,
          'name': p.name,
          'lat': p.point.latitude,
          'lon': p.point.longitude,
        },
    ]),
  );
}
