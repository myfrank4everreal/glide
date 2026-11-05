import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late SharedPreferences prefs;
  late _MockSecureStorage secureStorage;
  late SettingsRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secureStorage = _MockSecureStorage();
    when(() => secureStorage.deleteAll()).thenAnswer((_) async {});
    repository = SettingsRepositoryImpl(prefs, secureStorage);
  });

  test('returns defaults when nothing is stored', () async {
    expect(await repository.load(), const UserSettings());
  });

  test('round-trips every field', () async {
    const settings = UserSettings(
      voiceEnabled: false,
      speechRate: 0.8,
      hapticsEnabled: false,
      hapticIntensity: 0.3,
      confidenceThreshold: 0.75,
      highContrast: true,
      languageCode: 'es',
      onboardingDone: true,
    );
    await repository.save(settings);
    expect(await repository.load(), settings);
  });

  test('deleteAllUserData clears preferences and secure storage', () async {
    await repository.save(const UserSettings(highContrast: true));

    await repository.deleteAllUserData();

    expect(prefs.getKeys(), isEmpty);
    expect(await repository.load(), const UserSettings());
    verify(() => secureStorage.deleteAll()).called(1);
  });
}
