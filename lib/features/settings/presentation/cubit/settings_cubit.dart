import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/domain/usecases/settings_usecases.dart';

/// App-wide settings. Provided at the root so the theme and feedback services
/// react to changes immediately.
class SettingsCubit extends Cubit<UserSettings> {
  SettingsCubit({
    required this._getSettings,
    required this._saveSettings,
    required this._deleteUserData,
  }) : super(const UserSettings());

  final GetSettings _getSettings;
  final SaveSettings _saveSettings;
  final DeleteUserData _deleteUserData;

  Future<void> load() async => emit(await _getSettings());

  Future<void> update(
    UserSettings Function(UserSettings current) change,
  ) async {
    emit(await _saveSettings(change(state)));
  }

  Future<void> deleteAllData() async {
    await _deleteUserData();
    emit(const UserSettings());
  }
}
