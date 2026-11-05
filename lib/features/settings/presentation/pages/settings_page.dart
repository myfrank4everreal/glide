import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/router/app_router.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettings)),
      body: BlocBuilder<SettingsCubit, UserSettings>(
        builder: (context, s) => ListView(
          children: [
            SwitchListTile(
              title: Text(l10n.settingsVoice),
              value: s.voiceEnabled,
              onChanged: (v) =>
                  cubit.update((c) => c.copyWith(voiceEnabled: v)),
            ),
            _PercentSlider(
              label: l10n.settingsSpeechRate,
              value: s.speechRate,
              min: 0.1,
              onChanged: s.voiceEnabled
                  ? (v) => cubit.update((c) => c.copyWith(speechRate: v))
                  : null,
            ),
            SwitchListTile(
              title: Text(l10n.settingsHaptics),
              value: s.hapticsEnabled,
              onChanged: (v) =>
                  cubit.update((c) => c.copyWith(hapticsEnabled: v)),
            ),
            _PercentSlider(
              label: l10n.settingsHapticIntensity,
              value: s.hapticIntensity,
              onChanged: s.hapticsEnabled
                  ? (v) => cubit.update((c) => c.copyWith(hapticIntensity: v))
                  : null,
            ),
            // Shown as sensitivity (inverse of the confidence threshold),
            // which is easier to understand than a threshold.
            _PercentSlider(
              label: l10n.settingsSensitivity,
              hint: l10n.settingsSensitivityHint,
              value: 1.2 - s.confidenceThreshold,
              min: 0.3,
              max: 0.9,
              onChanged: (v) =>
                  cubit.update((c) => c.copyWith(confidenceThreshold: 1.2 - v)),
            ),
            SwitchListTile(
              title: Text(l10n.settingsHighContrast),
              value: s.highContrast,
              onChanged: (v) =>
                  cubit.update((c) => c.copyWith(highContrast: v)),
            ),
            // Only offered once there is more than one language to pick.
            if (AppLocalizations.supportedLocales.length > 1)
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.settingsLanguage),
                subtitle: Text(l10n.languageName),
                onTap: () => _pickLanguage(context, cubit, s.languageCode),
              ),
            ListTile(
              leading: const Icon(Icons.school),
              title: Text(l10n.settingsReplayTutorial),
              onTap: () => context.push(AppRoutes.welcome),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: Text(l10n.settingsDeleteData),
              onTap: () => _confirmDelete(context, cubit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    SettingsCubit cubit,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final code = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.settingsLanguage),
        children: [
          for (final locale in AppLocalizations.supportedLocales)
            Semantics(
              selected: locale.languageCode == current,
              child: SimpleDialogOption(
                onPressed: () => Navigator.pop(context, locale.languageCode),
                child: ListTile(
                  // Each language is named in itself, so a user can find
                  // theirs even when the app is in another language.
                  title: Text(lookupAppLocalizations(locale).languageName),
                  trailing: locale.languageCode == current
                      ? const Icon(Icons.check)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
    if (code != null) await cubit.update((s) => s.copyWith(languageCode: code));
  }

  Future<void> _confirmDelete(BuildContext context, SettingsCubit cubit) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.settingsDeleteDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await cubit.deleteAllData();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsDeleteDataDone)),
    );
  }
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final String? hint;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = AppLocalizations.of(
      context,
    ).percentValue((value.clamp(min, max) * 100).round());
    return Semantics(
      label: label,
      hint: hint,
      child: ListTile(
        title: ExcludeSemantics(child: Text(label)),
        subtitle: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          label: percent,
          semanticFormatterCallback: (_) => percent,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
