import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/features/camera/presentation/widgets/camera_gate.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';

/// Point the camera at a sign or page and hear it. Expects a started
/// `CameraCubit` and a [TextReaderCubit] above it (provided by the router).
class TextReaderPage extends StatelessWidget {
  const TextReaderPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).homeReadText)),
    body: CameraGate(
      readyBuilder: (_, controller) => _Reader(controller: controller),
    ),
  );
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
              child: switch (state) {
                TextReaderIdle() => Text(
                  l10n.readTextInstructions,
                  style: textStyle,
                ),
                TextReaderBusy() => Semantics(
                  liveRegion: true,
                  child: Text(l10n.readingText, style: textStyle),
                ),
                // Already spoken, so not a live region; screen reader users
                // can still swipe to it to hear it again.
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
                  LargeActionButton(
                    label: l10n.readTextButton,
                    hint: l10n.readTextButtonHint,
                    icon: Icons.chrome_reader_mode,
                    onPressed: state is TextReaderBusy
                        ? null
                        : () => _read(context),
                  ),
                  if (state is TextReaderResult) ...[
                    const SizedBox(height: 12),
                    LargeActionButton(
                      label: l10n.stopReading,
                      icon: Icons.stop,
                      onPressed: context.read<TextReaderCubit>().stopReading,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
