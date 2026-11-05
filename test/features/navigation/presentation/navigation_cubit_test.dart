import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/domain/entities/guidance.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/permissions/permission_service.dart';

import '../../../helpers/fakes.dart';

const _metersPerDegree = 111194.9;
const _here = GeoPoint(51.5, -0.12);
final _door = SavedPlace(
  id: 'door',
  name: 'Front door',
  point: GeoPoint(_here.latitude + 100 / _metersPerDegree, _here.longitude),
);

String _describe(SavedPlace p, Guidance g, GuidanceCue cue) =>
    '${cue.name} ${p.name} ${g.distanceMeters.round()} ${g.clockHour}';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeSavedPlacesRepository places;
  late FakeLocationService location;
  late FakeHeadingService heading;
  late FakePermissionService permissions;
  late FakeTtsService tts;
  late FakeHapticService haptics;
  var now = DateTime(2026, 11, 4, 12);
  late FakeScreenAwakeService screen;

  setUp(() {
    places = FakeSavedPlacesRepository();
    location = FakeLocationService();
    heading = FakeHeadingService();
    permissions = FakePermissionService()
      ..current = AppPermissionStatus.granted;
    tts = FakeTtsService();
    haptics = FakeHapticService();
    now = DateTime(2026, 11, 4, 12);
    screen = FakeScreenAwakeService();
  });

  NavigationCubit build() => NavigationCubit(
    places: places,
    location: location,
    heading: heading,
    permissions: permissions,
    tts: tts,
    haptics: haptics,
    screen: screen,
    now: () => now,
  );

  group('permission', () {
    test('granted shows the saved places', () async {
      places.places.add(_door);
      final cubit = build();
      await cubit.start();
      expect(cubit.state, NavigationPlaces([_door]));
      await cubit.close();
    });

    test('not asked yet explains before asking', () async {
      permissions.current = AppPermissionStatus.denied;
      final cubit = build();
      await cubit.start();
      expect(cubit.state, const NavigationNeedsPermission());

      await cubit.requestPermission();
      expect(cubit.state, const NavigationPlaces([]));
      await cubit.close();
    });

    test('refusal offers a retry, permanent refusal offers settings', () async {
      permissions
        ..current = AppPermissionStatus.denied
        ..onRequest = AppPermissionStatus.denied;
      final cubit = build();
      await cubit.requestPermission();
      expect(cubit.state, const NavigationPermissionDenied(permanently: false));

      permissions.onRequest = AppPermissionStatus.permanentlyDenied;
      await cubit.requestPermission();
      expect(cubit.state, const NavigationPermissionDenied(permanently: true));

      await cubit.openSettings();
      expect(permissions.settingsOpened, 1);

      // The user turned it on in settings and came back.
      permissions.current = AppPermissionStatus.granted;
      await cubit.onResume();
      expect(cubit.state, const NavigationPlaces([]));
      await cubit.close();
    });

    test('resume does nothing while places are showing', () async {
      final cubit = build();
      await cubit.start();
      permissions.current = AppPermissionStatus.denied;
      await cubit.onResume();
      expect(cubit.state, isA<NavigationPlaces>());
      await cubit.close();
    });
  });

  group('saving places', () {
    test('saves the current spot and says so', () async {
      final cubit = build();
      await cubit.start();

      await cubit.saveCurrentLocation(
        '  Front door ',
        savedPhrase: (name) => 'Saved $name',
        failedPhrase: 'failed',
      );

      expect(places.places.single.name, 'Front door');
      expect(places.places.single.point, _here);
      expect(cubit.state, NavigationPlaces(places.places));
      expect(tts.spoken, ['Saved Front door']);
      expect(haptics.played, [HapticPattern.success]);
      await cubit.close();
    });

    test('no GPS fix saves nothing and says why', () async {
      location.unavailable = true;
      final cubit = build();
      await cubit.start();

      await cubit.saveCurrentLocation(
        'Door',
        savedPhrase: (name) => 'Saved $name',
        failedPhrase: 'failed',
      );

      expect(places.places, isEmpty);
      expect(cubit.state, const NavigationPlaces([]));
      expect(tts.spoken, ['failed']);
      expect(haptics.played, [HapticPattern.error]);
      await cubit.close();
    });

    test('voice off stays silent', () async {
      final cubit = build();
      await cubit.start();
      await cubit.saveCurrentLocation(
        'Door',
        savedPhrase: (name) => 'Saved $name',
        failedPhrase: 'failed',
        speak: false,
      );
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });

    test('delete removes the place', () async {
      places.places.add(_door);
      final cubit = build();
      await cubit.start();

      await cubit.deletePlace('door');

      expect(cubit.state, const NavigationPlaces([]));
      await cubit.close();
    });
  });

  group('guiding', () {
    Future<NavigationCubit> guide({bool voice = true}) async {
      final cubit = build();
      await cubit.start();
      await cubit.guideTo(_door, describe: _describe, voiceEnabled: voice);
      return cubit;
    }

    void fix(GeoPoint point, {double accuracy = 5}) =>
        location.emit(LocationFix(point, accuracyMeters: accuracy));

    test('waits for a fix, then speaks distance and direction', () async {
      final cubit = await guide();
      expect(cubit.state, NavigationGuiding(_door));
      expect(screen.on, isTrue, reason: 'screen stays on while guiding');

      heading.emit(90);
      await _settle();
      expect(tts.spoken, isEmpty);

      fix(_here);
      await _settle();

      final guidance = (cubit.state as NavigationGuiding).guidance!;
      expect(guidance.clockHour, 9);
      expect(tts.spoken, ['update Front door 100 9']);
      expect(tts.interrupted, [true]);
      await cubit.close();
    });

    test('facing the target gives a tick', () async {
      final cubit = await guide();
      heading.emit(0);
      fix(_here);
      await _settle();

      expect(haptics.played, [HapticPattern.tap]);
      await cubit.close();
    });

    test('turning is announced after the gap', () async {
      final cubit = await guide();
      heading.emit(0);
      fix(_here);
      await _settle();

      now = now.add(const Duration(seconds: 5));
      heading.emit(90);
      await _settle();

      expect(tts.spoken.last, 'update Front door 100 9');
      await cubit.close();
    });

    test('arrival is announced and the sensors stop', () async {
      final cubit = await guide();
      fix(_door.point);
      await _settle();

      expect(tts.spoken, ['arrived Front door 0 null']);
      expect(haptics.played, [HapticPattern.success]);
      expect((cubit.state as NavigationGuiding).guidance!.arrived, isTrue);
      expect(location.hasListener, isFalse);
      expect(heading.hasListener, isFalse);
      await cubit.close();
    });

    test('weak GPS is announced with an error buzz', () async {
      final cubit = await guide();
      fix(_here, accuracy: 60);
      await _settle();

      expect(tts.spoken.single, startsWith('weakSignal'));
      expect(haptics.played, [HapticPattern.error]);
      await cubit.close();
    });

    test('repeat says the current guidance again', () async {
      final cubit = await guide();
      cubit.repeat(); // Nothing to repeat before the first fix.
      expect(tts.spoken, isEmpty);

      fix(_here);
      await _settle();
      cubit.repeat();

      expect(tts.spoken, hasLength(2));
      await cubit.close();
    });

    test('voice off guides by vibration only', () async {
      final cubit = await guide(voice: false);
      heading.emit(0);
      fix(_here);
      await _settle();

      expect(tts.spoken, isEmpty);
      expect(haptics.played, [HapticPattern.tap]);

      cubit
        ..updateVoice(voiceEnabled: true)
        ..repeat();
      expect(tts.spoken, hasLength(1));
      await cubit.close();
    });

    test('losing location stops guiding and says so', () async {
      final cubit = await guide();
      location.emitError(Exception('gps off'));
      await _settle();
      await _settle();

      expect(cubit.state, const NavigationLocationOff());
      expect(haptics.played, [HapticPattern.error]);
      expect(location.hasListener, isFalse);
      await cubit.close();
    });

    test('stop returns to the places and silences speech', () async {
      places.places.add(_door);
      final cubit = await guide();

      await cubit.stopGuiding();

      expect(cubit.state, NavigationPlaces([_door]));
      expect(tts.stops, 1);
      expect(screen.on, isFalse);
      expect(heading.hasListener, isFalse);
      await cubit.close();
    });

    test('closing the screen stops GPS and the compass', () async {
      final cubit = await guide();
      await cubit.close();
      expect(location.hasListener, isFalse);
      expect(heading.hasListener, isFalse);
    });
  });
}
