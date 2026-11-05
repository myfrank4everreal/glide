import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/widgets/large_action_button.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:glide/l10n/app_localizations.dart';

/// Everything between "screen opened" and "live camera": the permission
/// explanation, denial and failure screens (each also spoken), and releasing
/// the camera while the app is in the background. Shows [readyBuilder] once
/// the camera is live.
///
/// Expects a started [CameraCubit] above it.
class CameraGate extends StatefulWidget {
  const CameraGate({
    required this.readyBuilder,
    this.onReady,
    this.onNotReady,
    super.key,
  });

  final Widget Function(BuildContext context, CameraController controller)
  readyBuilder;

  /// Called when the camera goes live, e.g. to start detection.
  final void Function(BuildContext context)? onReady;

  /// Called on every other state, e.g. to stop detection.
  final void Function(BuildContext context)? onNotReady;

  @override
  State<CameraGate> createState() => _CameraGateState();
}

class _CameraGateState extends State<CameraGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<CameraCubit>();
    // The camera must be released whenever the app isn't in front, or other
    // apps (and the OS) can't use it.
    _lifecycle = AppLifecycleListener(
      onInactive: cubit.pause,
      onResume: cubit.resume,
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
    final cubit = context.read<CameraCubit>();
    return BlocConsumer<CameraCubit, CameraState>(
      listener: (context, state) {
        final message = _announcement(l10n, state);
        if (message != null &&
            context.read<SettingsCubit>().state.voiceEnabled) {
          cubit.announce(message);
        }
        if (state is CameraReady) {
          widget.onReady?.call(context);
        } else {
          widget.onNotReady?.call(context);
        }
      },
      builder: (context, state) => switch (state) {
        CameraInitial() ||
        CameraStarting() ||
        CameraPaused() => _Starting(label: l10n.cameraStarting),
        CameraNeedsPermission() => _Message(
          text: l10n.cameraPermissionRationale,
          action: LargeActionButton(
            label: l10n.allowCamera,
            icon: Icons.photo_camera,
            onPressed: cubit.requestPermission,
          ),
        ),
        CameraPermissionDenied(permanently: true) => _Message(
          text: l10n.permissionDenied,
          action: LargeActionButton(
            label: l10n.openSettings,
            icon: Icons.settings,
            onPressed: cubit.openSettings,
          ),
        ),
        CameraPermissionDenied() => _Message(
          text: l10n.permissionDeniedRetry,
          action: LargeActionButton(
            label: l10n.tryAgain,
            icon: Icons.refresh,
            onPressed: cubit.requestPermission,
          ),
        ),
        CameraFailed() => _Message(
          text: l10n.cameraFailed,
          action: LargeActionButton(
            label: l10n.tryAgain,
            icon: Icons.refresh,
            onPressed: cubit.start,
          ),
        ),
        CameraReady(:final controller) => widget.readyBuilder(
          context,
          controller,
        ),
      },
    );
  }

  String? _announcement(AppLocalizations l10n, CameraState state) =>
      switch (state) {
        CameraNeedsPermission() => l10n.cameraPermissionRationale,
        CameraPermissionDenied(permanently: true) => l10n.permissionDenied,
        CameraPermissionDenied() => l10n.permissionDeniedRetry,
        CameraFailed() => l10n.cameraFailed,
        CameraReady() => l10n.cameraOn,
        _ => null,
      };
}

class _Starting extends StatelessWidget {
  const _Starting({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      liveRegion: true,
      child: const CircularProgressIndicator(),
    ),
  );
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
