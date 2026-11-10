import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/features/text_reader/domain/usecases/text_aiming_guide.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/tts/tts_service.dart';

sealed class TextReaderState extends Equatable {
  const TextReaderState();

  @override
  List<Object?> get props => [];
}

/// Looking for text and telling the user how to aim.
final class TextReaderAiming extends TextReaderState {
  const TextReaderAiming([this.hint = AimHint.none]);

  final AimHint hint;

  @override
  List<Object?> get props => [hint];
}

final class TextReaderBusy extends TextReaderState {
  const TextReaderBusy();
}

final class TextReaderResult extends TextReaderState {
  const TextReaderResult(this.lines);

  /// In reading order.
  final List<String> lines;

  @override
  List<Object?> get props => [lines];
}

final class TextReaderNoText extends TextReaderState {
  const TextReaderNoText();
}

final class TextReaderFailed extends TextReaderState {
  const TextReaderFailed();
}

typedef FileDeleter = Future<void> Function(String path);

/// Words for each hint, in the user's language.
typedef AimPhrase = String Function(AimHint hint);

/// Reads text aloud two ways:
///
/// * **Live:** a few times a second it looks for text in the camera picture,
///   says how to move the phone ("move left", "closer", "hold still"), and
///   reads the text once it has been complete and steady for two looks.
/// * **Photo:** the Read text button focuses, takes one high-resolution
///   photo and reads it. The photo is deleted as soon as it's processed.
///
/// Live frames are only held in memory.
class TextReaderCubit extends Cubit<TextReaderState> {
  TextReaderCubit({
    required this._camera,
    required this._ocr,
    required this._tts,
    required this._haptics,
    FileDeleter? deleteFile,
    TextAimingGuide? guide,
    this._analysisInterval = const Duration(milliseconds: 700),
    this._hintGap = const Duration(milliseconds: 2500),
    this._focusSettle = const Duration(milliseconds: 600),
    this._darkLuma = 45,
    this._now = DateTime.now,
  }) : _deleteFile = deleteFile ?? _deleteFromDisk,
       _guide = guide ?? TextAimingGuide(),
       super(const TextReaderAiming());

  final CameraService _camera;
  final TextRecognitionService _ocr;
  final TtsService _tts;
  final HapticService _haptics;
  final FileDeleter _deleteFile;
  final TextAimingGuide _guide;
  final Duration _analysisInterval;
  final Duration _hintGap;
  final Duration _focusSettle;
  final double _darkLuma;
  final DateTime Function() _now;

  bool _live = false;
  bool _analysing = false;
  DateTime? _lastAnalysis;
  DateTime? _lastHintAt;
  AimHint? _lastSpokenHint;
  bool _speak = true;
  AimPhrase _phrase = _hintName;
  String _lightOnPhrase = 'Light on';
  bool _autoTorchTried = false;

  /// Whether the camera light is on. Separate from [state] because it
  /// changes independently of reading.
  final torch = ValueNotifier<bool>(false);

  static String _hintName(AimHint hint) => hint.name;

  static Future<void> _deleteFromDisk(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Starts live guidance. Call when the camera preview is ready.
  Future<void> startLive({
    required bool speak,
    AimPhrase? phrase,
    String? lightOnPhrase,
  }) async {
    _speak = speak;
    if (phrase != null) _phrase = phrase;
    if (lightOnPhrase != null) _lightOnPhrase = lightOnPhrase;
    await _camera.focusOnCenter();
    await _resumeLive();
  }

  /// Stops live guidance and the light. Call when the camera goes away.
  Future<void> stopLive() async {
    _live = false;
    await _camera.stopFrameStream();
    if (torch.value) await setTorch(on: false);
  }

  /// After a result: look for the next piece of text.
  Future<void> scanAgain() async {
    await _tts.stop();
    await _resumeLive();
  }

  void updateVoice({required bool speak}) => _speak = speak;

  Future<void> setTorch({required bool on}) async {
    if (await _camera.setTorch(on: on) && !isClosed) torch.value = on;
  }

  Future<void> toggleTorch() => setTorch(on: !torch.value);

  Future<void> _resumeLive() async {
    _guide.reset();
    _lastSpokenHint = null;
    _lastAnalysis = null;
    if (!isClosed) emit(const TextReaderAiming());
    _live = true;
    await _camera.startFrameStream(_onFrame);
  }

  void _onFrame(CameraFrame frame) {
    if (!_live || _analysing || isClosed) return;
    final now = _now();
    final last = _lastAnalysis;
    if (last != null && now.difference(last) < _analysisInterval) return;
    _lastAnalysis = now;
    _analysing = true;
    unawaited(_analyse(frame).whenComplete(() => _analysing = false));
  }

  Future<void> _analyse(CameraFrame frame) async {
    if (!_autoTorchTried && frame.meanLuma() < _darkLuma) {
      _autoTorchTried = true;
      await setTorch(on: true);
      if (torch.value && _speak) unawaited(_tts.speak(_lightOnPhrase));
    }

    final List<String> lines;
    final AimHint hint;
    try {
      final found = await _ocr.recognizeFrame(frame);
      hint = _guide.next(found);
      lines = [for (final l in found) l.text];
    } on Object {
      return; // One unreadable frame: try the next one.
    }
    if (!_live || isClosed) return;

    if (hint == AimHint.ready) {
      _live = false;
      await _camera.stopFrameStream();
      await _deliver(lines);
      return;
    }
    if (state != TextReaderAiming(hint)) emit(TextReaderAiming(hint));
    _sayHint(hint);
  }

  /// Hints change often; speak a new one at most every [_hintGap], and
  /// repeat the same one only after twice that.
  void _sayHint(AimHint hint) {
    if (hint == AimHint.none) return;
    final now = _now();
    final last = _lastHintAt;
    final gap = hint == _lastSpokenHint ? _hintGap * 2 : _hintGap;
    if (last != null && now.difference(last) < gap) return;
    _lastHintAt = now;
    if (hint == AimHint.holdStill && _lastSpokenHint != AimHint.holdStill) {
      unawaited(_haptics.play(HapticPattern.tap));
    }
    _lastSpokenHint = hint;
    if (_speak) unawaited(_tts.speak(_phrase(hint), interrupt: true));
  }

  /// Takes one focused, high-resolution photo and reads it. [noTextPhrase]
  /// is spoken when nothing is found.
  Future<void> readText({
    required bool speak,
    required String noTextPhrase,
  }) async {
    if (state is TextReaderBusy) return;
    _live = false;
    emit(const TextReaderBusy());
    unawaited(_haptics.play(HapticPattern.tap));

    List<String> lines;
    String? photoPath;
    try {
      await _camera.stopFrameStream();
      await _camera.focusOnCenter();
      await Future<void>.delayed(_focusSettle);
      final photo = await _camera.takePicture();
      photoPath = photo.path;
      lines = await _ocr.recognizeLines(photo.path);
    } on Object {
      await _haptics.play(HapticPattern.error);
      emit(const TextReaderFailed());
      return;
    } finally {
      if (photoPath != null) await _deleteFile(photoPath);
    }

    if (lines.isEmpty) {
      emit(const TextReaderNoText());
      await _haptics.play(HapticPattern.error);
      if (speak) await _tts.speak(noTextPhrase, interrupt: true);
      return;
    }
    _speak = speak;
    await _deliver(lines);
  }

  Future<void> _deliver(List<String> lines) async {
    if (isClosed) return;
    emit(TextReaderResult(lines));
    await _haptics.play(HapticPattern.success);
    // A new line gives the speech engine a natural pause between lines.
    if (_speak) await _tts.speak(lines.join('\n'), interrupt: true);
  }

  Future<void> stopReading() => _tts.stop();

  @override
  Future<void> close() async {
    _live = false;
    await _camera.stopFrameStream();
    if (torch.value) await _camera.setTorch(on: false);
    torch.dispose();
    return super.close();
  }
}
