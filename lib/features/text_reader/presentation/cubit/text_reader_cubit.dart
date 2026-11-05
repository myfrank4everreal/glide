import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';
import 'package:glide/services/haptic/haptic_service.dart';
import 'package:glide/services/tts/tts_service.dart';

sealed class TextReaderState extends Equatable {
  const TextReaderState();

  @override
  List<Object?> get props => [];
}

final class TextReaderIdle extends TextReaderState {
  const TextReaderIdle();
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

/// Takes one photo, finds the text on the device and reads it aloud. The
/// photo is deleted as soon as it has been processed, whatever happens.
class TextReaderCubit extends Cubit<TextReaderState> {
  TextReaderCubit({
    required this._camera,
    required this._ocr,
    required this._tts,
    required this._haptics,
    FileDeleter? deleteFile,
  }) : _deleteFile = deleteFile ?? _deleteFromDisk,
       super(const TextReaderIdle());

  final CameraService _camera;
  final TextRecognitionService _ocr;
  final TtsService _tts;
  final HapticService _haptics;
  final FileDeleter _deleteFile;

  static Future<void> _deleteFromDisk(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// [noTextPhrase] is spoken when nothing is found; it comes from the page
  /// so it's in the user's language.
  Future<void> readText({
    required bool speak,
    required String noTextPhrase,
  }) async {
    if (state is TextReaderBusy) return;
    emit(const TextReaderBusy());
    unawaited(_haptics.play(HapticPattern.tap));

    List<String> lines;
    String? photoPath;
    try {
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
    emit(TextReaderResult(lines));
    await _haptics.play(HapticPattern.success);
    // A new line gives the speech engine a natural pause between lines.
    if (speak) await _tts.speak(lines.join('\n'), interrupt: true);
  }

  Future<void> stopReading() => _tts.stop();
}
