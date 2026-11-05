import 'package:flutter/material.dart';
import 'package:glide/l10n/app_localizations.dart';

/// Screen for a feature that is routed but not built yet. Says so plainly
/// (and to screen readers) instead of showing fake data.
class MilestonePlaceholder extends StatelessWidget {
  const MilestonePlaceholder({
    required this.title,
    required this.milestone,
    super.key,
  });

  final String title;
  final int milestone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.comingInMilestone(title, milestone),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
