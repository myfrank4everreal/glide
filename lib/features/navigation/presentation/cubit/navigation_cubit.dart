import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/domain/entities/guidance.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';
import 'package:glide/features/navigation/domain/repositories/saved_places_repository.dart';
import 'package:glide/features/navigation/domain/usecases/compute_guidance.dart';
import 'package:glide/features/navigation/domain/usecases/guidance_policy.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/location/location_service.dart';
import 'package:glide/services/permissions/permission_service.dart';
import 'package:glide/services/screen/screen_awake_service.dart';
import 'package:glide/services/sensors/heading_service.dart';
import 'package:glide/services/tts/tts_service.dart';

part 'navigation_state.dart';

/// Turns guidance into words in the user's language.
typedef GuidancePhrase =
    String Function(SavedPlace place, Guidance guidance, GuidanceCue cue);

/// Saved places and spoken compass guidance back to them.
class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit({
    required this._places,
    required this._location,
    required this._heading,
    required this._permissions,
    required this._tts,
    required this._haptics,
    this._compute = const ComputeGuidance(),
    GuidancePolicy? policy,
    this._screen = const NoScreenAwakeService(),
    this._now = DateTime.now,
  }) : _policy = policy ?? GuidancePolicy(),
       super(const NavigationLoading());

  final SavedPlacesRepository _places;
  final LocationService _location;
  final HeadingService _heading;
  final PermissionService _permissions;
  final TtsService _tts;
  final HapticService _haptics;
  final ComputeGuidance _compute;
  final GuidancePolicy _policy;
  final ScreenAwakeService _screen;
  final DateTime Function() _now;

  StreamSubscription<LocationFix>? _fixes;
  StreamSubscription<double>? _headings;
  LocationFix? _fix;
  double? _headingDegrees;
  GuidancePhrase? _describe;
  bool _voiceEnabled = true;

  Future<void> start() async {
    switch (await _permissions.status(AppPermission.location)) {
      case AppPermissionStatus.granted:
        await _showPlaces();
      case AppPermissionStatus.denied:
        emit(const NavigationNeedsPermission());
      case AppPermissionStatus.permanentlyDenied:
        emit(const NavigationPermissionDenied(permanently: true));
    }
  }

  Future<void> requestPermission() async {
    final status = await _permissions.request(AppPermission.location);
    if (status == AppPermissionStatus.granted) {
      await _showPlaces();
    } else {
      emit(
        NavigationPermissionDenied(
          permanently: status == AppPermissionStatus.permanentlyDenied,
        ),
      );
    }
  }

  Future<void> openSettings() => _permissions.openSettings();

  /// Back from system settings: the user may have changed something.
  Future<void> onResume() async {
    if (state
        case NavigationNeedsPermission() ||
            NavigationPermissionDenied() ||
            NavigationLocationOff()) {
      await start();
    }
  }

  /// Saves where the user is standing under [name].
  Future<void> saveCurrentLocation(
    String name, {
    required String Function(String name) savedPhrase,
    required String failedPhrase,
    bool speak = true,
  }) async {
    final places = switch (state) {
      NavigationPlaces(:final places) => places,
      _ => const <SavedPlace>[],
    };
    emit(NavigationPlaces(places, saving: true));
    try {
      final fix = await _location.currentFix();
      await _places.add(
        SavedPlace(
          id: _now().microsecondsSinceEpoch.toString(),
          name: name.trim(),
          point: fix.point,
        ),
      );
      unawaited(_haptics.play(HapticPattern.success));
      if (speak) unawaited(_tts.speak(savedPhrase(name.trim())));
      await _showPlaces();
    } on LocationUnavailableException {
      unawaited(_haptics.play(HapticPattern.error));
      if (speak) unawaited(_tts.speak(failedPhrase));
      emit(NavigationPlaces(places));
    }
  }

  Future<void> deletePlace(String id) async {
    await _places.remove(id);
    await _showPlaces();
  }

  Future<void> guideTo(
    SavedPlace place, {
    required GuidancePhrase describe,
    bool voiceEnabled = true,
  }) async {
    await _stopSensors();
    _policy.reset();
    _fix = null;
    _headingDegrees = null;
    _describe = describe;
    _voiceEnabled = voiceEnabled;
    emit(NavigationGuiding(place));
    unawaited(_screen.keepOn());
    _fixes = _location.fixStream().listen((fix) {
      _fix = fix;
      _update();
    }, onError: (Object _) => unawaited(_lostLocation()));
    _headings = _heading.headings().listen((degrees) {
      _headingDegrees = degrees;
      _update();
    });
  }

  /// Says the latest guidance again, on request.
  void repeat() {
    if (state case NavigationGuiding(:final place, :final guidance?)) {
      _speak(place, guidance, GuidanceCue.update);
    }
  }

  Future<void> stopGuiding() async {
    await _stopSensors();
    unawaited(_tts.stop());
    await _showPlaces();
  }

  void updateVoice({required bool voiceEnabled}) =>
      _voiceEnabled = voiceEnabled;

  void _update() {
    final fix = _fix;
    if (fix == null || isClosed) return;
    if (state case NavigationGuiding(:final place)) {
      final guidance = _compute(
        target: place.point,
        fix: fix,
        headingDegrees: _headingDegrees,
      );
      emit(NavigationGuiding(place, guidance: guidance));
      final cue = _policy.next(guidance, _now());
      if (cue != null) _deliver(place, guidance, cue);
      if (guidance.arrived) unawaited(_stopSensors());
    }
  }

  void _deliver(SavedPlace place, Guidance guidance, GuidanceCue cue) {
    final pattern = switch (cue) {
      GuidanceCue.arrived => HapticPattern.success,
      GuidanceCue.weakSignal => HapticPattern.error,
      // A tick when facing the target, so the user can turn until they feel it.
      GuidanceCue.update when guidance.clockHour == 12 => HapticPattern.tap,
      GuidanceCue.update => null,
    };
    if (pattern != null) unawaited(_haptics.play(pattern));
    _speak(place, guidance, cue);
  }

  void _speak(SavedPlace place, Guidance guidance, GuidanceCue cue) {
    final describe = _describe;
    if (!_voiceEnabled || describe == null) return;
    // Old directions are useless, so new ones cut them off.
    unawaited(_tts.speak(describe(place, guidance, cue), interrupt: true));
  }

  Future<void> _lostLocation() async {
    await _stopSensors();
    unawaited(_haptics.play(HapticPattern.error));
    if (!isClosed) emit(const NavigationLocationOff());
  }

  Future<void> _showPlaces() async {
    final places = await _places.load();
    if (!isClosed) emit(NavigationPlaces(places));
  }

  Future<void> _stopSensors() async {
    if (_fixes != null) unawaited(_screen.allowOff());
    await _fixes?.cancel();
    await _headings?.cancel();
    _fixes = null;
    _headings = null;
  }

  @override
  Future<void> close() async {
    await _stopSensors();
    return super.close();
  }
}
