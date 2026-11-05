import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class TtsService {
  Future<void> initialize();

  /// Speaks [text]. With [interrupt], anything currently being spoken is cut
  /// off first; use it for urgent (close-range) alerts.
  Future<void> speak(String text, {bool interrupt = false});

  Future<void> stop();

  /// 0.0 (slowest) to 1.0 (fastest). 0.5 is the platform's normal rate.
  Future<void> setSpeechRate(double rate);

  /// BCP-47 tag, e.g. `en-US`, `es-419`, `zh-CN`, `zh-HK`.
  Future<void> setLanguage(String languageTag);
}

class FlutterTtsService implements TtsService {
  FlutterTtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> initialize() async {
    await _tts.awaitSpeakCompletion(false);
    await _tts.setVolume(1);
    await setLanguage('en-US');
    await setSpeechRate(0.5);
  }

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (text.trim().isEmpty) return;
    // A broken or missing speech engine must not break alerts: the
    // vibration has already been played by the caller.
    try {
      if (interrupt) await _tts.stop();
      await _tts.speak(text);
    } on PlatformException {
      return;
    }
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> setSpeechRate(double rate) =>
      _tts.setSpeechRate(rate.clamp(0.0, 1.0));

  @override
  Future<void> setLanguage(String languageTag) => _tts.setLanguage(languageTag);
}
