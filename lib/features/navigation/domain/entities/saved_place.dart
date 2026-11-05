import 'package:equatable/equatable.dart';
import 'package:glide/core/geo/geo_point.dart';

/// A place the user chose to remember, e.g. "Front door" or "Bus stop".
class SavedPlace extends Equatable {
  const SavedPlace({required this.id, required this.name, required this.point});

  final String id;
  final String name;
  final GeoPoint point;

  @override
  List<Object> get props => [id, name, point];
}
