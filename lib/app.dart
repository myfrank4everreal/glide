import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/di/injection.dart';
import 'package:glide/core/router/app_router.dart';
import 'package:glide/core/themes/app_theme.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/tts/tts_service.dart';
import 'package:go_router/go_router.dart';

class GlideApp extends StatefulWidget {
  /// [settingsCubit] is normally created and loaded in `main`; without it the
  /// app creates its own and loads it.
  const GlideApp({this.settingsCubit, super.key});

  final SettingsCubit? settingsCubit;

  @override
  State<GlideApp> createState() => _GlideAppState();
}

class _GlideAppState extends State<GlideApp> {
  final GoRouter _router = createRouter();
  late final SettingsCubit _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsCubit ?? (getIt<SettingsCubit>()..load());
    _applyToServices(_settings.state);
  }

  @override
  void dispose() {
    _router.dispose();
    _settings.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _settings,
      child: BlocConsumer<SettingsCubit, UserSettings>(
        listener: (_, settings) => _applyToServices(settings),
        builder: (context, settings) {
          return MaterialApp.router(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: settings.highContrast
                ? AppTheme.highContrast
                : AppTheme.light,
            darkTheme: settings.highContrast
                ? AppTheme.highContrast
                : AppTheme.dark,
            locale: supportedLocale(settings.languageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _router,
          );
        },
      ),
    );
  }

  void _applyToServices(UserSettings settings) {
    final tts = getIt<TtsService>()..setSpeechRate(settings.speechRate);
    // The voice follows the app language, so alerts aren't read in an
    // English voice with Spanish words.
    tts.setLanguage(
      lookupAppLocalizations(
        supportedLocale(settings.languageCode),
      ).ttsLanguageTag,
    );
    getIt<HapticService>().setIntensity(
      settings.hapticsEnabled ? settings.hapticIntensity : 0,
    );
  }
}

/// The saved language if Glide has it, otherwise English.
Locale supportedLocale(String languageCode) =>
    AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == languageCode,
      orElse: () => const Locale('en'),
    );
