import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';

/// Shows the tutorial until it has been completed once, then [child].
/// "Delete my data" resets it, so the safety notice is shown again.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<SettingsCubit, UserSettings, bool>(
        selector: (s) => s.onboardingDone,
        builder: (context, done) => done
            ? child
            : OnboardingPage(
                onFinished: () => context.read<SettingsCubit>().update(
                  (s) => s.copyWith(onboardingDone: true),
                ),
              ),
      );
}
