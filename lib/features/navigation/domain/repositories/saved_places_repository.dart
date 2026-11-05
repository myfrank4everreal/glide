import 'package:glide/features/navigation/domain/entities/saved_place.dart';

/// Places are stored encrypted on the phone only, and erased by
/// "Delete my data".
abstract interface class SavedPlacesRepository {
  /// In the order they were saved.
  Future<List<SavedPlace>> load();

  Future<void> add(SavedPlace place);

  Future<void> remove(String id);
}
