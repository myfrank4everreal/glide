import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/geo/geo_point.dart';
import 'package:glide/features/navigation/domain/entities/guidance.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/features/navigation/presentation/pages/navigation_page.dart';
import 'package:glide/l10n/app_localizations_en.dart';
import 'package:glide/services/permissions/permission_service.dart';

import '../../../helpers/fakes.dart';

const _metersPerDegree = 111194.9;
const _here = GeoPoint(51.5, -0.12);
final _door = SavedPlace(
  id: 'door',
  name: 'Front door',
  point: GeoPoint(_here.latitude + 120 / _metersPerDegree, _here.longitude),
);

void main() {
  late FakeSavedPlacesRepository places;
  late FakeLocationService location;
  late FakeHeadingService heading;
  late FakePermissionService permissions;
  late FakeTtsService tts;

  setUp(() {
    places = FakeSavedPlacesRepository();
    location = FakeLocationService();
    heading = FakeHeadingService();
    permissions = FakePermissionService()
      ..current = AppPermissionStatus.granted;
    tts = FakeTtsService();
  });

  Future<NavigationCubit> pumpPage(WidgetTester tester) async {
    final settingsCubit = buildSettingsCubit(FakeSettingsRepository());
    final cubit = NavigationCubit(
      places: places,
      location: location,
      heading: heading,
      permissions: permissions,
      tts: tts,
      haptics: FakeHapticService(),
    );
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(value: cubit, child: const NavigationPage()),
        settingsCubit: settingsCubit,
      ),
    );
    await cubit.start();
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('explains location use before asking for it', (tester) async {
    permissions.current = AppPermissionStatus.denied;
    await pumpPage(tester);

    expect(find.textContaining('never sent anywhere'), findsOneWidget);
    await tester.tap(find.text('Allow location'));
    await tester.pumpAndSettle();

    expect(permissions.requests, 1);
    expect(find.text('Save this spot'), findsOneWidget);
  });

  testWidgets('permanent refusal sends the user to settings', (tester) async {
    permissions.current = AppPermissionStatus.permanentlyDenied;
    await pumpPage(tester);

    await tester.tap(find.text('Open settings'));
    expect(permissions.settingsOpened, 1);
  });

  testWidgets('a refusal can be retried', (tester) async {
    permissions
      ..current = AppPermissionStatus.denied
      ..onRequest = AppPermissionStatus.denied;
    final cubit = await pumpPage(tester);
    await cubit.requestPermission();
    await tester.pumpAndSettle();

    expect(find.textContaining('was not allowed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('says how to start when nothing is saved', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('No saved places yet'), findsOneWidget);
    expect(find.textContaining('straight line'), findsOneWidget);
  });

  testWidgets('saving asks for a name and lists the place', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Save this spot'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bus stop');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Guide me to Bus stop'), findsOneWidget);
    expect(tts.spoken.last, 'Saved Bus stop.');
  });

  testWidgets('cancelling the name saves nothing', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Save this spot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(places.places, isEmpty);
  });

  testWidgets('a place can be deleted', (tester) async {
    places.places.add(_door);
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Delete Front door'));
    await tester.pumpAndSettle();

    expect(find.text('Guide me to Front door'), findsNothing);
  });

  testWidgets('guiding shows and speaks the directions', (tester) async {
    places.places.add(_door);
    await pumpPage(tester);

    await tester.tap(find.text('Guide me to Front door'));
    await tester.pumpAndSettle();
    expect(find.text('Finding your position'), findsOneWidget);

    heading.emit(270);
    location.emit(const LocationFix(_here, accuracyMeters: 5));
    await tester.pumpAndSettle();

    expect(find.text("Front door, 120 metres, at 3 o'clock"), findsOneWidget);
    expect(tts.spoken.last, "Front door, 120 metres, at 3 o'clock");

    await tester.tap(find.text('Repeat directions'));
    expect(tts.spoken, hasLength(2));

    await tester.tap(find.text('Stop guiding'));
    await tester.pumpAndSettle();
    expect(find.text('Guide me to Front door'), findsOneWidget);
  });

  testWidgets('arrival offers Done', (tester) async {
    places.places.add(_door);
    await pumpPage(tester);
    await tester.tap(find.text('Guide me to Front door'));
    await tester.pumpAndSettle();

    location.emit(LocationFix(_door.point, accuracyMeters: 5));
    await tester.pumpAndSettle();

    expect(find.textContaining('You are near Front door'), findsOneWidget);
    expect(find.text('Repeat directions'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Guide me to Front door'), findsOneWidget);
  });

  testWidgets('lost location offers a retry', (tester) async {
    places.places.add(_door);
    await pumpPage(tester);
    await tester.tap(find.text('Guide me to Front door'));
    await tester.pumpAndSettle();

    location.emitError(Exception('off'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be found'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Guide me to Front door'), findsOneWidget);
  });

  testWidgets('meets tap target and labelling guidelines', (tester) async {
    places.places.add(_door);
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  group('wording', () {
    final l10n = AppLocalizationsEn();
    Guidance g(double meters, {int? hour}) =>
        Guidance(distanceMeters: meters, accuracyMeters: 30, clockHour: hour);

    test('distances are rounded for listening', () {
      expect(distancePhrase(l10n, 3), '5 metres');
      expect(distancePhrase(l10n, 47), '45 metres');
      expect(distancePhrase(l10n, 123), '120 metres');
      expect(distancePhrase(l10n, 1460), '1.5 kilometres');
    });

    test('each cue has its own sentence', () {
      expect(
        describeGuidance(l10n, _door, g(50, hour: 12), GuidanceCue.update),
        'Front door, 50 metres, straight ahead',
      );
      expect(
        describeGuidance(l10n, _door, g(50), GuidanceCue.update),
        'Front door, 50 metres',
      );
      expect(
        describeGuidance(l10n, _door, g(50), GuidanceCue.weakSignal),
        'GPS signal is weak. Directions may be up to 30 metres off.',
      );
      expect(
        describeGuidance(l10n, _door, g(5), GuidanceCue.arrived),
        startsWith('You are near Front door'),
      );
    });
  });
}
