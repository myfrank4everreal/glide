import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs, this._secureStorage);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  static const _voiceEnabled = 'settings.voiceEnabled';
  static const _speechRate = 'settings.speechRate';
  static const _hapticsEnabled = 'settings.hapticsEnabled';
  static const _hapticIntensity = 'settings.hapticIntensity';
  static const _confidenceThreshold = 'settings.confidenceThreshold';
  static const _highContrast = 'settings.highContrast';
  static const _languageCode = 'settings.languageCode';
  static const _onboardingDone = 'settings.onboardingDone';

  @override
  Future<UserSettings> load() async {
    const defaults = UserSettings();
    return UserSettings(
      voiceEnabled: _prefs.getBool(_voiceEnabled) ?? defaults.voiceEnabled,
      speechRate: _prefs.getDouble(_speechRate) ?? defaults.speechRate,
      hapticsEnabled:
          _prefs.getBool(_hapticsEnabled) ?? defaults.hapticsEnabled,
      hapticIntensity:
          _prefs.getDouble(_hapticIntensity) ?? defaults.hapticIntensity,
      confidenceThreshold:
          _prefs.getDouble(_confidenceThreshold) ??
          defaults.confidenceThreshold,
      highContrast: _prefs.getBool(_highContrast) ?? defaults.highContrast,
      languageCode: _prefs.getString(_languageCode) ?? defaults.languageCode,
      onboardingDone:
          _prefs.getBool(_onboardingDone) ?? defaults.onboardingDone,
    );
  }

  @override
  Future<void> save(UserSettings settings) async {
    await Future.wait([
      _prefs.setBool(_voiceEnabled, settings.voiceEnabled),
      _prefs.setDouble(_speechRate, settings.speechRate),
      _prefs.setBool(_hapticsEnabled, settings.hapticsEnabled),
      _prefs.setDouble(_hapticIntensity, settings.hapticIntensity),
      _prefs.setDouble(_confidenceThreshold, settings.confidenceThreshold),
      _prefs.setBool(_highContrast, settings.highContrast),
      _prefs.setString(_languageCode, settings.languageCode),
      _prefs.setBool(_onboardingDone, settings.onboardingDone),
    ]);
  }

  @override
  Future<void> deleteAllUserData() async {
    // Saved places live in the secure store, so deleteAll erases them too.
    // Add any new local store (e.g. a Hive box) here.
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }
}
