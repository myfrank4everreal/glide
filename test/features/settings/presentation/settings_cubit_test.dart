import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeSettingsRepository repository;

  setUp(() => repository = FakeSettingsRepository());

  blocTest<SettingsCubit, UserSettings>(
    'load emits stored settings',
    setUp: () => repository.stored = const UserSettings(highContrast: true),
    build: () => buildSettingsCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [const UserSettings(highContrast: true)],
  );

  blocTest<SettingsCubit, UserSettings>(
    'update saves and emits the changed settings',
    build: () => buildSettingsCubit(repository),
    act: (cubit) => cubit.update((s) => s.copyWith(voiceEnabled: false)),
    expect: () => [const UserSettings(voiceEnabled: false)],
    verify: (_) => expect(repository.stored.voiceEnabled, isFalse),
  );

  blocTest<SettingsCubit, UserSettings>(
    'update emits the sanitised value, not the raw input',
    build: () => buildSettingsCubit(repository),
    act: (cubit) => cubit.update((s) => s.copyWith(speechRate: 5)),
    expect: () => [const UserSettings(speechRate: 1)],
  );

  blocTest<SettingsCubit, UserSettings>(
    'deleteAllData erases storage and resets to defaults',
    build: () => buildSettingsCubit(repository),
    seed: () => const UserSettings(highContrast: true),
    act: (cubit) => cubit.deleteAllData(),
    expect: () => [const UserSettings()],
    verify: (_) => expect(repository.deleted, isTrue),
  );
}
