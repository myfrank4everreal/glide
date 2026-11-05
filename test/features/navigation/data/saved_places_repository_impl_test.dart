import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/data/repositories/saved_places_repository_impl.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';

void main() {
  const storage = FlutterSecureStorage();
  late SavedPlacesRepositoryImpl repository;

  const door = SavedPlace(
    id: '1',
    name: 'Front door',
    point: GeoPoint(51.5, -0.12),
  );
  const bus = SavedPlace(
    id: '2',
    name: 'Bus stop',
    point: GeoPoint(51.501, -0.121),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = SavedPlacesRepositoryImpl(storage);
  });

  test('starts empty', () async {
    expect(await repository.load(), isEmpty);
  });

  test('places survive a round trip, in the order saved', () async {
    await repository.add(door);
    await repository.add(bus);

    expect(await SavedPlacesRepositoryImpl(storage).load(), [door, bus]);
  });

  test('remove deletes only that place', () async {
    await repository.add(door);
    await repository.add(bus);

    await repository.remove('1');

    expect(await repository.load(), [bus]);
  });

  test('unreadable data is dropped, not thrown', () async {
    FlutterSecureStorage.setMockInitialValues({
      SavedPlacesRepositoryImpl.storageKey: 'not json',
    });

    expect(await repository.load(), isEmpty);
  });

  test('erased with the rest of the secure store', () async {
    await repository.add(door);

    await storage.deleteAll();

    expect(await repository.load(), isEmpty);
  });
}
