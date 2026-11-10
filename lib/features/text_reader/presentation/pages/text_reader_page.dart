import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/features/camera/presentation/widgets/camera_gate.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/features/text_reader/domain/usecases/text_aiming_guide.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';

/// Point the camera at a sign or page and hear it. Expects a started
/// `CameraCubit` (text mode) and a [TextReaderCubit] above it (provided by
/// the router).
class TextReaderPage extends StatelessWidget {
  const TextReaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = context.read<TextReaderCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).homeReadText)),
      body: BlocListener<SettingsCubit, UserSettings>(
        listenWhen: (a, b) => a.voiceEnabled != b.voiceEnabled,
        listener: (_, s) => reader.updateVoice(speak: s.voiceEnabled),
        // Live guidance runs exactly while the preview is live.
        child: CameraGate(
          onReady: (context) {
            final l10n = AppLocalizations.of(context);
            reader.startLive(
              speak: context.read<SettingsCubit>().state.voiceEnabled,
              phrase: (hint) => aimPhrase(l10n, hint),
              lightOnPhrase: l10n.lightTurnedOn,
            );
          },
          onNotReady: (_) => reader.stopLive(),
          readyBuilder: (_, controller) => _Reader(controller: controller),
        ),
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  const _Reader({required this.controller});

  final CameraController controller;

  void _read(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    context.read<TextReaderCubit>().readText(
      speak: context.read<SettingsCubit>().state.voiceEnabled,
      noTextPhrase: l10n.noTextFound,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.titleLarge;
    final cubit = context.read<TextReaderCubit>();
    return BlocBuilder<TextReaderCubit, TextReaderState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            // Double-tap is for users who don't run a screen reader; screen
            // readers claim double-tap themselves and use the button instead.
            child: GestureDetector(
              onDoubleTap: () => _read(context),
              child: ExcludeSemantics(
                child: Center(child: CameraPreview(controller)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // Hints and results are already spoken by Glide, so these are
              // not live regions: the screen reader would say them twice.
              child: switch (state) {
                TextReaderAiming(hint: AimHint.none) => Text(
                  l10n.readTextInstructions,
                  style: textStyle,
                ),
                TextReaderAiming(:final hint) => Text(
                  aimPhrase(l10n, hint),
                  style: textStyle,
                ),
                TextReaderBusy() => Text(l10n.readingText, style: textStyle),
                TextReaderResult(:final lines) => SelectableText(
                  lines.join('\n'),
                  style: textStyle,
                ),
                TextReaderNoText() => Text(l10n.noTextFound, style: textStyle),
                TextReaderFailed() => Text(
                  l10n.readTextFailed,
                  style: textStyle,
                ),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (state is TextReaderResult) ...[
                    LargeActionButton(
                      label: l10n.stopReading,
                      icon: Icons.stop,
                      onPressed: cubit.stopReading,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state is TextReaderAiming || state is TextReaderBusy)
                    LargeActionButton(
                      label: l10n.readTextButton,
                      hint: l10n.readTextButtonHint,
                      icon: Icons.chrome_reader_mode,
                      onPressed: state is TextReaderBusy
                          ? null
                          : () => _read(context),
                    )
                  else
                    LargeActionButton(
                      label: l10n.readSomethingElse,
                      icon: Icons.document_scanner,
                      onPressed: cubit.scanAgain,
                    ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: cubit.torch,
                    builder: (_, on, _) => SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: cubit.toggleTorch,
                        icon: Icon(on ? Icons.flash_off : Icons.flash_on),
                        label: Text(on ? l10n.lightOff : l10n.lightOn),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spoken and shown wording for an aiming hint.
String aimPhrase(AppLocalizations l10n, AimHint hint) => switch (hint) {
  AimHint.none => l10n.readTextInstructions,
  AimHint.moveLeft => l10n.aimMoveLeft,
  AimHint.moveRight => l10n.aimMoveRight,
  AimHint.moveUp => l10n.aimMoveUp,
  AimHint.moveDown => l10n.aimMoveDown,
  AimHint.moveCloser => l10n.aimMoveCloser,
  AimHint.moveBack => l10n.aimMoveBack,
  AimHint.holdStill || AimHint.ready => l10n.aimHoldStill,
};
