import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/constants/app_constants.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/features/navigation/domain/entities/guidance.dart';
import 'package:glide/features/navigation/domain/entities/saved_place.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';

/// Saved places and spoken guidance back to them. Expects a started
/// [NavigationCubit] above it (provided by the router).
class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<NavigationCubit>().onResume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NavigationCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeNavigate)),
      body: BlocListener<SettingsCubit, UserSettings>(
        listenWhen: (a, b) => a.voiceEnabled != b.voiceEnabled,
        listener: (_, s) => cubit.updateVoice(voiceEnabled: s.voiceEnabled),
        child: BlocBuilder<NavigationCubit, NavigationState>(
          builder: (context, state) => switch (state) {
            NavigationLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            NavigationNeedsPermission() => _Message(
              text: l10n.locationPermissionRationale,
              action: LargeActionButton(
                label: l10n.allowLocation,
                icon: Icons.location_on,
                onPressed: cubit.requestPermission,
              ),
            ),
            NavigationPermissionDenied(permanently: true) => _Message(
              text: l10n.locationPermissionDenied,
              action: LargeActionButton(
                label: l10n.openSettings,
                icon: Icons.settings,
                onPressed: cubit.openSettings,
              ),
            ),
            NavigationPermissionDenied() => _Message(
              text: l10n.locationPermissionDeniedRetry,
              action: LargeActionButton(
                label: l10n.tryAgain,
                icon: Icons.refresh,
                onPressed: cubit.requestPermission,
              ),
            ),
            NavigationLocationOff() => _Message(
              text: l10n.locationOff,
              action: LargeActionButton(
                label: l10n.tryAgain,
                icon: Icons.refresh,
                onPressed: cubit.start,
              ),
            ),
            NavigationPlaces() => _Places(state: state),
            NavigationGuiding() => _Guiding(state: state),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 32),
          action,
        ],
      ),
    ),
  );
}

class _Places extends StatelessWidget {
  const _Places({required this.state});

  final NavigationPlaces state;

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NavigationCubit>();
    final speak = context.read<SettingsCubit>().state.voiceEnabled;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    await cubit.saveCurrentLocation(
      name,
      savedPhrase: l10n.placeSaved,
      failedPhrase: l10n.placeSaveFailed,
      speak: speak,
    );
  }

  void _guide(BuildContext context, SavedPlace place) {
    final l10n = AppLocalizations.of(context);
    context.read<NavigationCubit>().guideTo(
      place,
      describe: (place, guidance, cue) =>
          describeGuidance(l10n, place, guidance, cue),
      voiceEnabled: context.read<SettingsCubit>().state.voiceEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.navigationIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          LargeActionButton(
            label: state.saving ? l10n.savingSpot : l10n.saveThisSpot,
            hint: l10n.saveThisSpotHint,
            icon: Icons.add_location_alt,
            onPressed: state.saving ? null : () => _save(context),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              l10n.savedPlacesHeading,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          if (state.places.isEmpty)
            Text(l10n.noSavedPlaces, style: theme.textTheme.bodyLarge)
          else
            for (final place in state.places)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: LargeActionButton(
                        label: l10n.guideToPlace(place.name),
                        icon: Icons.navigation,
                        onPressed: () => _guide(context, place),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l10n.deletePlace(place.name),
                      iconSize: 32,
                      constraints: const BoxConstraints(
                        minWidth: AppConstants.primaryButtonHeight,
                        minHeight: AppConstants.primaryButtonHeight,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          context.read<NavigationCubit>().deletePlace(place.id),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.saveThisSpot),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.placeNameLabel),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _Guiding extends StatelessWidget {
  const _Guiding({required this.state});

  final NavigationGuiding state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<NavigationCubit>();
    final guidance = state.guidance;
    final arrived = guidance?.arrived ?? false;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                // Not a live region: the same words are already spoken by
                // Glide, and the screen reader would say them twice.
                child: Text(
                  guidance == null
                      ? l10n.findingPosition
                      : describeGuidance(
                          l10n,
                          state.place,
                          guidance,
                          arrived ? GuidanceCue.arrived : GuidanceCue.update,
                        ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
            ),
            if (!arrived) ...[
              LargeActionButton(
                label: l10n.repeatDirections,
                icon: Icons.replay,
                onPressed: guidance == null ? null : cubit.repeat,
              ),
              const SizedBox(height: 12),
            ],
            LargeActionButton(
              label: arrived ? l10n.done : l10n.stopGuiding,
              icon: arrived ? Icons.check : Icons.stop,
              onPressed: cubit.stopGuiding,
            ),
          ],
        ),
      ),
    );
  }
}

/// Spoken and shown wording, e.g. "Front door, 120 metres, at 2 o'clock".
String describeGuidance(
  AppLocalizations l10n,
  SavedPlace place,
  Guidance guidance,
  GuidanceCue cue,
) => switch (cue) {
  GuidanceCue.arrived => l10n.guidanceArrived(place.name),
  GuidanceCue.weakSignal => l10n.guidanceWeakSignal(
    distancePhrase(l10n, guidance.accuracyMeters),
  ),
  GuidanceCue.update => switch (guidance.clockHour) {
    null => l10n.guidanceNoHeading(
      place.name,
      distancePhrase(l10n, guidance.distanceMeters),
    ),
    final hour => l10n.guidanceUpdate(
      place.name,
      distancePhrase(l10n, guidance.distanceMeters),
      hour == 12 ? l10n.straightAhead : l10n.atClockHour(hour),
    ),
  },
};

/// Rounded so it's quick to hear: GPS isn't more precise than this anyway.
String distancePhrase(AppLocalizations l10n, double meters) {
  if (meters >= 1000) {
    return l10n.distanceKilometres((meters / 1000).toStringAsFixed(1));
  }
  final step = meters < 100 ? 5 : 10;
  final rounded = ((meters / step).round() * step).clamp(step, 990).toInt();
  return l10n.distanceMetres(rounded);
}
