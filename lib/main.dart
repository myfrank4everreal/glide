import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glide/app.dart';
import 'package:glide/core/di/injection.dart';
import 'package:glide/core/error/error_reporter.dart';
import 'package:glide/core/widgets/error_views.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Detection maps camera frames assuming the phone is upright, which is
  // also how it's held while walking.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await configureDependencies();
  getIt<ErrorReporter>().install();
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const BrokenWidgetView();
  }
  // Loaded before the first frame, so a returning user never glimpses the
  // tutorial or the wrong theme.
  final settings = getIt<SettingsCubit>();
  await settings.load();
  runApp(GlideApp(settingsCubit: settings));
}
