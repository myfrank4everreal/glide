import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/domain/repositories/settings_repository.dart';

class GetSettings {
  const GetSettings(this._repository);

  final SettingsRepository _repository;

  Future<UserSettings> call() => _repository.load();
}

class SaveSettings {
  const SaveSettings(this._repository);

  final SettingsRepository _repository;

  /// Clamps out-of-range values before saving so a bad value can never make
  /// alerts silent or unusable.
  Future<UserSettings> call(UserSettings settings) async {
    final sanitized = settings.copyWith(
      speechRate: settings.speechRate.clamp(0.1, 1.0),
      hapticIntensity: settings.hapticIntensity.clamp(0.0, 1.0),
      confidenceThreshold: settings.confidenceThreshold.clamp(0.3, 0.9),
    );
    await _repository.save(sanitized);
    return sanitized;
  }
}

class DeleteUserData {
  const DeleteUserData(this._repository);

  final SettingsRepository _repository;

  Future<void> call() => _repository.deleteAllUserData();
}
