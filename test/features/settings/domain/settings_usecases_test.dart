import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/domain/repositories/settings_repository.dart';
import 'package:glide/features/settings/domain/usecases/settings_usecases.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockRepository repository;

  setUpAll(() => registerFallbackValue(const UserSettings()));

  setUp(() {
    repository = _MockRepository();
    when(() => repository.save(any())).thenAnswer((_) async {});
  });

  test('GetSettings returns what the repository loads', () async {
    const stored = UserSettings(speechRate: 0.7);
    when(() => repository.load()).thenAnswer((_) async => stored);

    expect(await GetSettings(repository)(), stored);
  });

  group('SaveSettings', () {
    test('saves valid settings unchanged', () async {
      const settings = UserSettings(speechRate: 0.7, hapticIntensity: 0.4);

      final saved = await SaveSettings(repository)(settings);

      expect(saved, settings);
      verify(() => repository.save(settings)).called(1);
    });

    test('clamps values that would make alerts unusable', () async {
      final saved = await SaveSettings(repository)(
        const UserSettings(
          speechRate: 0,
          hapticIntensity: 2,
          confidenceThreshold: 0.99,
        ),
      );

      expect(saved.speechRate, 0.1);
      expect(saved.hapticIntensity, 1);
      expect(saved.confidenceThreshold, 0.9);
      verify(() => repository.save(saved)).called(1);
    });
  });

  test('DeleteUserData asks the repository to erase everything', () async {
    when(() => repository.deleteAllUserData()).thenAnswer((_) async {});

    await DeleteUserData(repository)();

    verify(() => repository.deleteAllUserData()).called(1);
  });
}
