import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:glide/services/tts/tts_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late _MockFlutterTts plugin;
  late FlutterTtsService service;

  setUp(() {
    plugin = _MockFlutterTts();
    when(() => plugin.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => plugin.setVolume(any())).thenAnswer((_) async => 1);
    when(() => plugin.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => plugin.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => plugin.speak(any())).thenAnswer((_) async => 1);
    when(() => plugin.stop()).thenAnswer((_) async => 1);
    service = FlutterTtsService(plugin);
  });

  test('initialize sets full volume, English and normal rate', () async {
    await service.initialize();

    verify(() => plugin.setVolume(1)).called(1);
    verify(() => plugin.setLanguage('en-US')).called(1);
    verify(() => plugin.setSpeechRate(0.5)).called(1);
  });

  test('speak passes text through without interrupting by default', () async {
    await service.speak('Pole ahead');

    verify(() => plugin.speak('Pole ahead')).called(1);
    verifyNever(() => plugin.stop());
  });

  test('urgent speech stops current speech first', () async {
    await service.speak('Stop', interrupt: true);

    verifyInOrder([() => plugin.stop(), () => plugin.speak('Stop')]);
  });

  test('blank text is ignored', () async {
    await service.speak('   ');

    verifyNever(() => plugin.speak(any()));
  });

  test('speech rate is clamped to 0–1', () async {
    await service.setSpeechRate(3);

    verify(() => plugin.setSpeechRate(1)).called(1);
  });

  test('setLanguage and stop delegate to the plugin', () async {
    await service.setLanguage('es-419');
    await service.stop();

    verify(() => plugin.setLanguage('es-419')).called(1);
    verify(() => plugin.stop()).called(1);
  });

  test('a failing speech engine does not throw', () async {
    when(() => plugin.speak(any())).thenThrow(PlatformException(code: 'tts'));

    await expectLater(service.speak('Pole ahead'), completes);
  });
}
