import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/camera/presentation/widgets/camera_gate.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/obstacle_alert.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/features/detection/presentation/object_names.dart';
import 'package:glide/features/detection/presentation/widgets/detection_overlay.dart';
import 'package:glide/features/settings/domain/entities/user_settings.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

/// Live camera screen with obstacle detection. Expects a started
/// [CameraCubit] and a [DetectionCubit] above it (provided by the router).
class DetectionPage extends StatelessWidget {
  const DetectionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).homeDetect)),
    // Settings changed mid-walk (e.g. voice off) apply immediately.
    body: BlocListener<SettingsCubit, UserSettings>(
      listener: (context, settings) =>
          context.read<DetectionCubit>().updateOptions(
            confidenceThreshold: settings.confidenceThreshold,
            voiceEnabled: settings.voiceEnabled,
          ),
      // Detection runs exactly while the preview is live.
      child: CameraGate(
        onReady: (context) {
          final settings = context.read<SettingsCubit>().state;
          final l10n = AppLocalizations.of(context);
          context.read<DetectionCubit>().start(
            confidenceThreshold: settings.confidenceThreshold,
            voiceEnabled: settings.voiceEnabled,
            describe: (alert) => describeAlert(l10n, alert),
            crossingPhrase: l10n.crossingCue,
            interruptedPhrase: l10n.detectionInterrupted,
            resumedPhrase: l10n.detectionResumed,
          );
        },
        onNotReady: (context) => context.read<DetectionCubit>().stop(),
        readyBuilder: (_, controller) => _Preview(controller: controller),
      ),
    ),
  );
}

/// Spoken form of an alert, e.g. "bench on your left, near".
String describeAlert(AppLocalizations l10n, ObstacleAlert alert) =>
    l10n.obstacleAlert(
      objectName(l10n, alert.label),
      directionPhrase(l10n, alert.direction),
      switch (alert.band) {
        DistanceBand.close => l10n.distanceClose,
        DistanceBand.near => l10n.distanceNear,
        DistanceBand.far => l10n.distanceFar,
      },
    );

String directionPhrase(AppLocalizations l10n, Direction direction) =>
    switch (direction) {
      Direction.left => l10n.directionLeft,
      Direction.ahead => l10n.directionAhead,
      Direction.right => l10n.directionRight,
    };

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<CameraCubit>();
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<DetectionCubit, DetectionState>(
            builder: (context, detection) => Stack(
              children: [
                Semantics(
                  label: l10n.cameraViewLabel(_summary(l10n, detection)),
                  image: true,
                  excludeSemantics: true,
                  child: Center(
                    child: CameraPreview(
                      controller,
                      child: DetectionOverlay(detections: detection.detections),
                    ),
                  ),
                ),
                if (detection.status == DetectionStatus.modelUnavailable)
                  _Banner(text: l10n.modelUnavailable),
                if (detection.status == DetectionStatus.interrupted)
                  _Banner(text: l10n.detectionInterrupted),
                if (!kReleaseMode && detection.processingTime != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: ExcludeSemantics(
                      child: _Banner(
                        text: l10n.processingTime(
                          detection.processingTime!.inMilliseconds,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LargeActionButton(
              label: l10n.testVibration,
              hint: l10n.testVibrationHint,
              icon: Icons.vibration,
              onPressed: () => cubit.testHaptics(
                labels: {
                  HapticPattern.far: l10n.distanceFar,
                  HapticPattern.near: l10n.distanceNear,
                  HapticPattern.close: l10n.distanceClose,
                },
                speak: context.read<SettingsCubit>().state.voiceEnabled,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _summary(AppLocalizations l10n, DetectionState state) {
    if (state.status != DetectionStatus.running) return l10n.detectionStarting;
    if (state.detections.isEmpty) return l10n.nothingDetected;
    return l10n.detectedSummary(
      state.detections
          .map(
            (d) => l10n.detectedObject(
              objectName(l10n, d.label),
              directionPhrase(l10n, d.direction),
            ),
          )
          .join(', '),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSurface)),
    );
  }
}
