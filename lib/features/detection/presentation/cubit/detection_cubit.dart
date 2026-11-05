import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/detection_result.dart';
import 'package:glide/features/detection/domain/entities/obstacle_alert.dart';
import 'package:glide/features/detection/domain/repositories/detection_repository.dart';
import 'package:glide/features/detection/domain/usecases/alert_policy.dart';
import 'package:glide/features/detection/domain/usecases/crossing_cue_policy.dart';
import 'package:glide/features/detection/domain/usecases/prioritize_detections.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/screen/screen_awake_service.dart';
import 'package:glide/services/tts/tts_service.dart';

enum DetectionStatus {
  idle,
  running,

  /// Running, but no frame has been processed for a while (camera frozen,
  /// detector failing). Never let silence look like a clear path.
  interrupted,
  modelUnavailable,
}

class DetectionState extends Equatable {
  const DetectionState({
    this.status = DetectionStatus.idle,
    this.detections = const [],
    this.processingTime,
  });

  final DetectionStatus status;

  /// Most dangerous first.
  final List<Detection> detections;

  /// Time to process the latest frame; null until one has been processed.
  final Duration? processingTime;

  @override
  List<Object?> get props => [status, detections, processingTime];
}

/// Turns an alert into words in the user's language.
typedef AlertPhrase = String Function(ObstacleAlert alert);

/// Runs object detection while the camera is live, and warns the user by
/// vibration and voice according to [AlertPolicy].
class DetectionCubit extends Cubit<DetectionState> {
  DetectionCubit({
    required this._repository,
    required this._tts,
    required this._haptics,
    AlertPolicy? policy,
    CrossingCuePolicy? crossingPolicy,
    this._prioritize = const PrioritizeDetections(maxResults: 10),
    this._screen = const NoScreenAwakeService(),
    this._stallTimeout = const Duration(seconds: 3),
    this._now = DateTime.now,
  }) : _policy = policy ?? AlertPolicy(),
       _crossingPolicy = crossingPolicy ?? CrossingCuePolicy(),
       super(const DetectionState());

  final DetectionRepository _repository;
  final TtsService _tts;
  final HapticService _haptics;
  final AlertPolicy _policy;
  final CrossingCuePolicy _crossingPolicy;
  final PrioritizeDetections _prioritize;
  final ScreenAwakeService _screen;
  final Duration _stallTimeout;
  Timer? _watchdog;
  final DateTime Function() _now;
  StreamSubscription<DetectionResult>? _results;
  double _confidenceThreshold = 0.6;
  bool _voiceEnabled = true;
  AlertPhrase _describe = _plainLabel;
  String _crossingPhrase = 'Possible street crossing ahead';
  String _interruptedPhrase = 'Obstacle detection is not working';
  String _resumedPhrase = 'Obstacle detection resumed';

  static String _plainLabel(ObstacleAlert alert) => alert.label;

  Future<void> start({
    required double confidenceThreshold,
    bool voiceEnabled = true,
    AlertPhrase describe = _plainLabel,
    String? crossingPhrase,
    String? interruptedPhrase,
    String? resumedPhrase,
  }) async {
    updateOptions(
      confidenceThreshold: confidenceThreshold,
      voiceEnabled: voiceEnabled,
    );
    _describe = describe;
    if (crossingPhrase != null) _crossingPhrase = crossingPhrase;
    if (interruptedPhrase != null) _interruptedPhrase = interruptedPhrase;
    if (resumedPhrase != null) _resumedPhrase = resumedPhrase;
    if (_isActive) return;
    _policy.reset();
    _crossingPolicy.reset();
    _results ??= _repository.watchDetections().listen(_onResult);
    try {
      await _repository.start();
    } on ModelLoadException {
      emit(const DetectionState(status: DetectionStatus.modelUnavailable));
      return;
    } on CameraUnavailableException {
      // The camera closed while starting (app paused); CameraCubit restarts us.
      return;
    }
    emit(const DetectionState(status: DetectionStatus.running));
    unawaited(_screen.keepOn());
    _armWatchdog();
  }

  Future<void> stop() async {
    _watchdog?.cancel();
    await _repository.stop();
    unawaited(_screen.allowOff());
    if (_isActive) emit(const DetectionState());
  }

  bool get _isActive =>
      state.status == DetectionStatus.running ||
      state.status == DetectionStatus.interrupted;

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_stallTimeout, _onStall);
  }

  void _onStall() {
    if (isClosed || state.status != DetectionStatus.running) return;
    emit(const DetectionState(status: DetectionStatus.interrupted));
    unawaited(_haptics.play(HapticPattern.error));
    if (_voiceEnabled) {
      unawaited(_tts.speak(_interruptedPhrase, interrupt: true));
    }
  }

  /// Applies settings changed while detection is running.
  void updateOptions({
    required double confidenceThreshold,
    required bool voiceEnabled,
  }) {
    _confidenceThreshold = confidenceThreshold;
    _voiceEnabled = voiceEnabled;
  }

  void _onResult(DetectionResult result) {
    if (!_isActive || isClosed) return;
    if (state.status == DetectionStatus.interrupted && _voiceEnabled) {
      unawaited(_tts.speak(_resumedPhrase));
    }
    _armWatchdog();
    final detections = _prioritize(
      result.detections,
      confidenceThreshold: _confidenceThreshold,
    );
    emit(
      DetectionState(
        status: DetectionStatus.running,
        detections: detections,
        processingTime: result.processingTime,
      ),
    );
    final now = _now();
    if (_policy.next(detections, now) case final alert?) {
      _deliver(alert);
    } else if (_crossingPolicy.next(detections, now)) {
      // Obstacles come first; the crossing cue waits for a quiet frame.
      unawaited(_haptics.play(HapticPattern.crossing));
      if (_voiceEnabled) unawaited(_tts.speak(_crossingPhrase));
    }
  }

  /// Vibration first (instant, works in noise), then speech. Neither is
  /// awaited, so the next frame is never held up by feedback.
  void _deliver(ObstacleAlert alert) {
    unawaited(
      _haptics.play(switch (alert.band) {
        DistanceBand.close => HapticPattern.close,
        DistanceBand.near => HapticPattern.near,
        DistanceBand.far => HapticPattern.far,
      }),
    );
    if (_voiceEnabled) {
      unawaited(_tts.speak(_describe(alert), interrupt: alert.urgent));
    }
  }

  @override
  Future<void> close() async {
    _watchdog?.cancel();
    unawaited(_screen.allowOff());
    await _results?.cancel();
    await _repository.stop();
    return super.close();
  }
}
