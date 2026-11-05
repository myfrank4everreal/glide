import 'package:flutter/material.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/l10n/app_localizations.dart';

/// Replaces Flutter's red/grey error box in release builds: a widget that
/// failed to build says so, in words a screen reader can read.
class BrokenWidgetView extends StatelessWidget {
  const BrokenWidgetView({super.key});

  @override
  Widget build(BuildContext context) {
    // This can be built outside the app's localisations (e.g. while the app
    // itself fails), so fall back to English.
    final message =
        Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        )?.errorWidgetMessage ??
        'This part of the screen could not be shown.';
    return Semantics(
      label: message,
      child: const Center(child: Icon(Icons.error_outline, size: 48)),
    );
  }
}

/// Shown for an unknown route or a page that failed to open.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({required this.onGoHome, super.key});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.errorScreenMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 32),
              LargeActionButton(
                label: l10n.goHome,
                icon: Icons.home,
                onPressed: onGoHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
