import 'package:flutter/material.dart';
import 'package:glide/core/router/app_router.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: Text(l10n.appTitle)),
        actions: [
          IconButton(
            tooltip: l10n.homeSettings,
            icon: const Icon(Icons.settings),
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LargeActionButton(
              label: l10n.homeDetect,
              hint: l10n.homeDetectHint,
              icon: Icons.visibility,
              onPressed: () => context.go(AppRoutes.detection),
            ),
            const SizedBox(height: 16),
            LargeActionButton(
              label: l10n.homeReadText,
              hint: l10n.homeReadTextHint,
              icon: Icons.chrome_reader_mode,
              onPressed: () => context.go(AppRoutes.textReader),
            ),
            const SizedBox(height: 16),
            LargeActionButton(
              label: l10n.homeNavigate,
              hint: l10n.homeNavigateHint,
              icon: Icons.directions_walk,
              onPressed: () => context.go(AppRoutes.navigation),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.safetyDisclaimer,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
