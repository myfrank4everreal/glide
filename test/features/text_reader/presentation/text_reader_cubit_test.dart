import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

import '../../../helpers/fakes.dart';

class _FakeOcr implements TextRecognitionService {
  List<String> lines = const [];
  Object? error;
  Completer<List<String>>? pending;
  final List<String> paths = [];

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    paths.add(imagePath);
    if (error case final e?) throw e;
    return pending?.future ?? lines;
  }

  @override
  Future<void> close() async {}
}

void main() {
  late FakeCameraService camera;
  late _FakeOcr ocr;
  late FakeTtsService tts;
  late FakeHapticService haptics;
  late List<String> deleted;

  setUp(() async {
    camera = FakeCameraService();
    await camera.initialize();
    ocr = _FakeOcr();
    tts = FakeTtsService();
    haptics = FakeHapticService();
    deleted = [];
  });

  TextReaderCubit build() => TextReaderCubit(
    camera: camera,
    ocr: ocr,
    tts: tts,
    haptics: haptics,
    deleteFile: (path) async => deleted.add(path),
  );

  Future<void> read(TextReaderCubit cubit, {bool speak = true}) =>
      cubit.readText(speak: speak, noTextPhrase: 'No text found');

  blocTest<TextReaderCubit, TextReaderState>(
    'reads recognised text aloud, in order',
    setUp: () => ocr.lines = ['Platform 2', 'Exit'],
    build: build,
    act: read,
    expect: () => [
      const TextReaderBusy(),
      const TextReaderResult(['Platform 2', 'Exit']),
    ],
    verify: (_) {
      expect(tts.spoken, ['Platform 2\nExit']);
      expect(tts.interrupted, [true]);
      expect(haptics.played, [HapticPattern.tap, HapticPattern.success]);
    },
  );

  blocTest<TextReaderCubit, TextReaderState>(
    'says so when there is no text',
    build: build,
    act: read,
    expect: () => [const TextReaderBusy(), const TextReaderNoText()],
    verify: (_) {
      expect(tts.spoken, ['No text found']);
      expect(haptics.played.last, HapticPattern.error);
    },
  );

  blocTest<TextReaderCubit, TextReaderState>(
    'stays silent when voice is off, but still shows the text',
    setUp: () => ocr.lines = ['Open'],
    build: build,
    act: (cubit) => read(cubit, speak: false),
    expect: () => [
      const TextReaderBusy(),
      const TextReaderResult(['Open']),
    ],
    verify: (_) => expect(tts.spoken, isEmpty),
  );

  blocTest<TextReaderCubit, TextReaderState>(
    'a recognition error is reported, not thrown',
    setUp: () => ocr.error = StateError('ML Kit failed'),
    build: build,
    act: read,
    expect: () => [const TextReaderBusy(), const TextReaderFailed()],
    verify: (_) => expect(haptics.played.last, HapticPattern.error),
  );

  blocTest<TextReaderCubit, TextReaderState>(
    'a camera error is reported, not thrown',
    setUp: () => camera.pictureError = const CameraUnavailableException('x'),
    build: build,
    act: read,
    expect: () => [const TextReaderBusy(), const TextReaderFailed()],
  );

  group('privacy', () {
    test('the photo is deleted after reading', () async {
      ocr.lines = ['Open'];
      final cubit = build();

      await read(cubit);

      expect(deleted, ['photo.jpg']);
      expect(ocr.paths, ['photo.jpg']);
      await cubit.close();
    });

    test('the photo is deleted even when recognition fails', () async {
      ocr.error = StateError('boom');
      final cubit = build();

      await read(cubit);

      expect(deleted, ['photo.jpg']);
      await cubit.close();
    });
  });

  test('a second tap while busy is ignored', () async {
    ocr.pending = Completer();
    final cubit = build();

    unawaited(read(cubit));
    await Future<void>.delayed(Duration.zero);
    await read(cubit);
    ocr.pending!.complete(['Open']);
    await Future<void>.delayed(Duration.zero);

    expect(ocr.paths, hasLength(1));
    await cubit.close();
  });

  test('stopReading stops speech', () async {
    final cubit = build();
    await cubit.stopReading();
    expect(tts.stops, 1);
    await cubit.close();
  });
}
