import 'package:glide/features/settings/domain/entities/user_settings.dart';

abstract interface class SettingsRepository {
  Future<UserSettings> load();
  Future<void> save(UserSettings settings);

  /// Removes every piece of user data stored on the device (GDPR erasure).
  Future<void> deleteAllUserData();
}
