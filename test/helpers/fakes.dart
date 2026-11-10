import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/core/vision/recognized_line.dart';
import 'package:glide/features/detection/domain/entities/detection_result.dart';
import 'package:glide/features/detection/domain/repositories/detection_repository.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';
import 'package:glide/features/navigation/domain/repositories/saved_places_repository.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/domain/repositories/settings_repository.dart';
import 'package:glide/features/settings/domain/usecases/settings_usecases.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/location/location_service.dart';
import 'package:glide/services/permissions/permission_service.dart';
import 'package:glide/services/screen/screen_awake_service.dart';
import 'package:glide/services/sensors/heading_service.dart';
import 'package:glide/services/tts/tts_service.dart';
import 'package:mocktail/mocktail.dart';

class FakeSettingsRepository implements SettingsRepository {
  UserSettings stored = const UserSettings();
  bool deleted = false;

  @override
  Future<UserSettings> load() async => stored;

  @override
  Future<void> save(UserSettings settings) async => stored = settings;

  @override
  Future<void> deleteAllUserData() async {
    deleted = true;
    stored = const UserSettings();
  }
}

class FakeTtsService implements TtsService {
  final List<String> spoken = [];

  /// Whether each spoken text cut off speech in progress.
  final List<bool> interrupted = [];
  double speechRate = 0.5;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    spoken.add(text);
    interrupted.add(interrupt);
  }

  int stops = 0;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> setSpeechRate(double rate) async => speechRate = rate;

  @override
  Future<void> setLanguage(String languageTag) async => language = languageTag;

  String? language;
}

class FakeHapticService implements HapticService {
  final List<HapticPattern> played = [];
  double intensity = 1;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<void> play(HapticPattern pattern) async => played.add(pattern);

  @override
  void setIntensity(double intensity) => this.intensity = intensity;

  @override
  Future<void> cancel() async {}
}

class FakePermissionService implements PermissionService {
  AppPermissionStatus current = AppPermissionStatus.denied;

  /// What the user "chooses" when the OS prompt appears.
  AppPermissionStatus onRequest = AppPermissionStatus.granted;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async => current;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requests++;
    return current = onRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class _MockCameraController extends Mock implements CameraController {}

/// Camera fake backed by a mock controller that [CameraPreview] can render.
class FakeCameraService implements CameraService {
  FakeCameraService() {
    final mock = _MockCameraController();
    final value = const CameraValue.uninitialized(
      CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ).copyWith(isInitialized: true, previewSize: const Size(480, 640));
    when(() => mock.value).thenReturn(value);
    when(
      () => mock.buildPreview(),
    ).thenReturn(const ColoredBox(color: Colors.black));
    when(() => mock.addListener(any())).thenReturn(null);
    when(() => mock.removeListener(any())).thenReturn(null);
    _mock = mock;
  }

  late final CameraController _mock;
  Object? initializeError;
  int initializeCalls = 0;
  int disposeCalls = 0;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  CameraController? get controller => _initialized ? _mock : null;

  CameraUse? lastUse;
  int focusCalls = 0;
  bool hasTorch = true;
  bool torchOn = false;

  @override
  Future<void> initialize({CameraUse use = CameraUse.detection}) async {
    initializeCalls++;
    lastUse = use;
    if (initializeError case final error?) throw error;
    _initialized = true;
  }

  @override
  Future<void> focusOnCenter() async => focusCalls++;

  @override
  Future<bool> setTorch({required bool on}) async {
    if (hasTorch) torchOn = on;
    return hasTorch;
  }

  void Function(CameraFrame frame)? frameListener;

  /// Delivers [frame] as if the camera produced it.
  void emitFrame(CameraFrame frame) => frameListener?.call(frame);

  @override
  Future<void> startFrameStream(
    void Function(CameraFrame frame) onFrame,
  ) async => frameListener = onFrame;

  @override
  Future<void> stopFrameStream() async => frameListener = null;

  Object? pictureError;

  @override
  Future<XFile> takePicture() async {
    if (pictureError case final e?) throw e;
    return XFile('photo.jpg');
  }

  void Function()? onDispose;

  @override
  Future<void> dispose() async {
    onDispose?.call();
    disposeCalls++;
    _initialized = false;
  }
}

class FakeDetectionRepository implements DetectionRepository {
  final results = StreamController<DetectionResult>.broadcast();
  Object? startError;
  int starts = 0;
  int stops = 0;

  @override
  Stream<DetectionResult> watchDetections() => results.stream;

  Future<void> dispose() => results.close();

  @override
  Future<void> start() async {
    starts++;
    if (startError case final e?) throw e;
  }

  @override
  Future<void> stop() async => stops++;
}

// Each listen gets its own single-subscription stream whose cancel completes
// in the caller's zone, so widget tests (fake async) don't stall on it.
class _FakeSensorStream<T> {
  StreamController<T>? _current;

  Stream<T> open() {
    // Closed by dispose() via _current.
    // ignore: close_sinks
    final c = StreamController<T>(onCancel: () async {});
    _current = c;
    return c.stream;
  }

  void add(T value) => _current?.add(value);
  void addError(Object error) => _current?.addError(error);
  bool get hasListener => _current?.hasListener ?? false;
  Future<void> dispose() async => _current?.close();
}

class FakeLocationService implements LocationService {
  LocationFix fix = const LocationFix(GeoPoint(51.5, -0.12), accuracyMeters: 5);
  bool unavailable = false;
  final _fixes = _FakeSensorStream<LocationFix>();

  void emit(LocationFix fix) => _fixes.add(fix);
  void emitError(Object error) => _fixes.addError(error);
  bool get hasListener => _fixes.hasListener;

  @override
  Future<LocationFix> currentFix() async {
    if (unavailable) throw const LocationUnavailableException('off');
    return fix;
  }

  @override
  Stream<LocationFix> fixStream({int distanceFilterMeters = 2}) =>
      _fixes.open();

  Future<void> dispose() => _fixes.dispose();
}

class FakeHeadingService implements HeadingService {
  final _headings = _FakeSensorStream<double>();

  void emit(double degrees) => _headings.add(degrees);
  bool get hasListener => _headings.hasListener;

  @override
  Stream<double> headings() => _headings.open();

  Future<void> dispose() => _headings.dispose();
}

class FakeSavedPlacesRepository implements SavedPlacesRepository {
  final List<SavedPlace> places = [];

  @override
  Future<List<SavedPlace>> load() async => List.of(places);

  @override
  Future<void> add(SavedPlace place) async => places.add(place);

  @override
  Future<void> remove(String id) async => places.removeWhere((p) => p.id == id);
}

class FakeScreenAwakeService implements ScreenAwakeService {
  bool on = false;

  @override
  Future<void> keepOn() async => on = true;

  @override
  Future<void> allowOff() async => on = false;
}

class FakeOcr implements TextRecognitionService {
  /// Result for photos.
  List<String> lines = const [];

  /// Result for each live frame, in turn; the last one repeats.
  List<List<RecognizedLine>> frameResults = const [[]];
  Object? error;
  Completer<List<String>>? pending;
  final List<String> paths = [];
  int framesSeen = 0;

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    paths.add(imagePath);
    if (error case final e?) throw e;
    return pending?.future ?? lines;
  }

  @override
  Future<List<RecognizedLine>> recognizeFrame(CameraFrame frame) async {
    final i = framesSeen.clamp(0, frameResults.length - 1);
    framesSeen++;
    if (error case final e?) throw e;
    return frameResults[i];
  }

  @override
  Future<void> close() async {}
}

SettingsCubit buildSettingsCubit(SettingsRepository repository) =>
    SettingsCubit(
      getSettings: GetSettings(repository),
      saveSettings: SaveSettings(repository),
      deleteUserData: DeleteUserData(repository),
    );

/// Wraps [child] with localisations and, optionally, a settings cubit, the
/// way the real app does.
Widget testApp(Widget child, {SettingsCubit? settingsCubit}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
  if (settingsCubit == null) return app;
  return BlocProvider.value(value: settingsCubit, child: app);
}
