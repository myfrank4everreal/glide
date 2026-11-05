part of 'navigation_cubit.dart';

sealed class NavigationState extends Equatable {
  const NavigationState();

  @override
  List<Object?> get props => [];
}

final class NavigationLoading extends NavigationState {
  const NavigationLoading();
}

/// Location permission not asked yet: explain why before the OS prompt.
final class NavigationNeedsPermission extends NavigationState {
  const NavigationNeedsPermission();
}

final class NavigationPermissionDenied extends NavigationState {
  const NavigationPermissionDenied({required this.permanently});

  /// The OS won't ask again; the user must use system settings.
  final bool permanently;

  @override
  List<Object?> get props => [permanently];
}

/// Location services are off, or no position could be found.
final class NavigationLocationOff extends NavigationState {
  const NavigationLocationOff();
}

final class NavigationPlaces extends NavigationState {
  const NavigationPlaces(this.places, {this.saving = false});

  final List<SavedPlace> places;

  /// Waiting for a GPS fix to save the current spot.
  final bool saving;

  @override
  List<Object?> get props => [places, saving];
}

final class NavigationGuiding extends NavigationState {
  const NavigationGuiding(this.place, {this.guidance});

  final SavedPlace place;

  /// Null until the first GPS fix.
  final Guidance? guidance;

  @override
  List<Object?> get props => [place, guidance];
}
