import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

typedef _PageText = ({String title, String body});

/// Five short pages: what Glide does, the safety notice (which must be
/// acknowledged), how to hold the phone, the vibration patterns, privacy.
/// Expects an [OnboardingCubit] above it.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onFinished, super.key});

  /// Called after the last page, e.g. to mark the tutorial done or go back.
  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _spokeFirst = false;

  static List<_PageText> _pages(AppLocalizations l10n) => [
    (title: l10n.onboardingWelcomeTitle, body: l10n.onboardingWelcomeBody),
    (title: l10n.onboardingSafetyTitle, body: l10n.onboardingSafetyBody),
    (title: l10n.onboardingHoldTitle, body: l10n.onboardingHoldBody),
    (title: l10n.onboardingFeelTitle, body: l10n.onboardingFeelBody),
    (title: l10n.onboardingPrivacyTitle, body: l10n.onboardingPrivacyBody),
  ];

  /// Glide's own voice only for users without a screen reader.
  String? _speech(BuildContext context, _PageText page) {
    final screenReader = MediaQuery.accessibleNavigationOf(context);
    final voice = context.read<SettingsCubit>().state.voiceEnabled;
    return screenReader || !voice ? null : '${page.title}. ${page.body}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spokeFirst) return;
    _spokeFirst = true;
    final cubit = context.read<OnboardingCubit>();
    final page = _pages(AppLocalizations.of(context))[cubit.state];
    cubit.goTo(cubit.state, speak: _speech(context, page));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pages = _pages(l10n);
    final cubit = context.read<OnboardingCubit>();
    return BlocBuilder<OnboardingCubit, int>(
      builder: (context, index) {
        final page = pages[index];
        final safetyPage = index == 1;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.onboardingProgress(index + 1, pages.length)),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      // Keyed by page so the screen reader moves to the new
                      // heading instead of staying on a stale node.
                      key: ValueKey(index),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              page.title,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(page.body, style: theme.textTheme.titleMedium),
                          if (index == 3) ...[
                            const SizedBox(height: 24),
                            LargeActionButton(
                              label: l10n.testVibration,
                              hint: l10n.testVibrationHint,
                              icon: Icons.vibration,
                              onPressed: () => cubit.playPatterns(
                                labels: {
                                  HapticPattern.far: l10n.distanceFar,
                                  HapticPattern.near: l10n.distanceNear,
                                  HapticPattern.close: l10n.distanceClose,
                                  HapticPattern.crossing:
                                      l10n.onboardingCrossingPattern,
                                },
                                speak: context
                                    .read<SettingsCubit>()
                                    .state
                                    .voiceEnabled,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  LargeActionButton(
                    label: cubit.isLastPage
                        ? l10n.onboardingStart
                        : safetyPage
                        ? l10n.onboardingUnderstand
                        : l10n.onboardingNext,
                    icon: cubit.isLastPage ? Icons.check : Icons.arrow_forward,
                    onPressed: () {
                      if (cubit.isLastPage) {
                        cubit.stopSpeaking();
                        widget.onFinished();
                      } else {
                        cubit.next(speak: _speech(context, pages[index + 1]));
                      }
                    },
                  ),
                  if (index > 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => cubit.back(
                          speak: _speech(context, pages[index - 1]),
                        ),
                        child: Text(l10n.onboardingBack),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
