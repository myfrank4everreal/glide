import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/core/vision/recognized_line.dart';
import 'package:glide/features/text_reader/domain/usecases/text_aiming_guide.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/services/camera/camera_frame.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

import '../../../helpers/fakes.dart';

CameraFrame _frame({int brightness = 128}) => CameraFrame(
  format: FrameFormat.nv21,
  width: 4,
  height: 4,
  rotation: 90,
  planes: [
    FramePlane(
      bytes: Uint8List(24)..fillRange(0, 16, brightness),
      bytesPerRow: 4,
      bytesPerPixel: 1,
    ),
  ],
);

const _centered = [
  RecognizedLine('Platform 2', left: 0.2, top: 0.4, right: 0.8, bottom: 0.5),
];
const _cutLeft = [
  RecognizedLine('latform 2', left: 0, top: 0.4, right: 0.8, bottom: 0.5),
];

void main() {
  late FakeCameraService camera;
  late FakeOcr ocr;
  late FakeTtsService tts;
  late FakeHapticService haptics;
  late List<String> deleted;
  var now = DateTime(2026, 11, 10, 12);

  setUp(() async {
    camera = FakeCameraService();
    await camera.initialize();
    ocr = FakeOcr();
    tts = FakeTtsService();
    haptics = FakeHapticService();
    deleted = [];
    now = DateTime(2026, 11, 10, 12);
  });

  TextReaderCubit build() => TextReaderCubit(
    camera: camera,
    ocr: ocr,
    tts: tts,
    haptics: haptics,
    deleteFile: (path) async => deleted.add(path),
    focusSettle: Duration.zero,
    now: () => now,
  );

  Future<void> read(TextReaderCubit cubit, {bool speak = true}) =>
      cubit.readText(speak: speak, noTextPhrase: 'No text found');

  group('photo', () {
    blocTest<TextReaderCubit, TextReaderState>(
      'focuses, then reads recognised text aloud, in order',
      setUp: () => ocr.lines = ['Platform 2', 'Exit'],
      build: build,
      act: read,
      expect: () => [
        const TextReaderBusy(),
        const TextReaderResult(['Platform 2', 'Exit']),
      ],
      verify: (_) {
        expect(camera.focusCalls, 1);
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

    test('the photo is deleted after reading, and on failure', () async {
      ocr.lines = ['Open'];
      final cubit = build();
      await read(cubit);
      ocr.error = StateError('boom');
      await read(cubit);

      expect(deleted, ['photo.jpg', 'photo.jpg']);
      await cubit.close();
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
  });

  group('live guidance', () {
    Future<TextReaderCubit> live({bool speak = true}) async {
      final cubit = build();
      await cubit.startLive(speak: speak, phrase: (h) => h.name);
      return cubit;
    }

    Future<void> frame({int brightness = 128}) async {
      camera.emitFrame(_frame(brightness: brightness));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 1));
    }

    test('starts the frame stream after focusing', () async {
      final cubit = await live();
      expect(camera.focusCalls, 1);
      expect(camera.frameListener, isNotNull);
      expect(cubit.state, const TextReaderAiming());
      await cubit.close();
      expect(camera.frameListener, isNull);
    });

    test('says how to aim, then reads steady text by itself', () async {
      ocr.frameResults = [_cutLeft, _centered, _centered];
      final cubit = await live();

      await frame();
      expect(cubit.state, const TextReaderAiming(AimHint.moveLeft));
      expect(tts.spoken, ['moveLeft']);

      now = now.add(const Duration(seconds: 3));
      await frame();
      expect(cubit.state, const TextReaderAiming(AimHint.holdStill));
      expect(haptics.played, [HapticPattern.tap]);

      await frame();
      expect(cubit.state, const TextReaderResult(['Platform 2']));
      expect(tts.spoken.last, 'Platform 2');
      expect(camera.frameListener, isNull, reason: 'stops looking once read');
      await cubit.close();
    });

    test('frames arriving too quickly are skipped', () async {
      final cubit = await live();
      camera
        ..emitFrame(_frame())
        ..emitFrame(_frame())
        ..emitFrame(_frame());
      await Future<void>.delayed(Duration.zero);
      expect(ocr.framesSeen, 1);
      await cubit.close();
    });

    test('the same hint is not repeated every frame', () async {
      ocr.frameResults = [_cutLeft];
      final cubit = await live();
      for (var i = 0; i < 4; i++) {
        await frame();
      }
      expect(tts.spoken, ['moveLeft']);
      await cubit.close();
    });

    test('a dark picture turns the light on and says so', () async {
      final cubit = build();
      await cubit.startLive(
        speak: true,
        phrase: (h) => h.name,
        lightOnPhrase: 'light on',
      );
      await frame(brightness: 10);

      expect(camera.torchOn, isTrue);
      expect(cubit.torch.value, isTrue);
      expect(tts.spoken, ['light on']);

      await cubit.stopLive();
      expect(camera.torchOn, isFalse);
      await cubit.close();
    });

    test('no light on the camera: nothing is said', () async {
      camera.hasTorch = false;
      final cubit = await live();
      await frame(brightness: 10);
      expect(cubit.torch.value, isFalse);
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });

    test('the light can be switched by hand', () async {
      final cubit = await live();
      await cubit.toggleTorch();
      expect(cubit.torch.value, isTrue);
      await cubit.toggleTorch();
      expect(cubit.torch.value, isFalse);
      await cubit.close();
    });

    test('voice off: guidance by vibration only', () async {
      ocr.frameResults = [_centered];
      final cubit = await live(speak: false);
      await frame();
      await frame();
      expect(tts.spoken, isEmpty);
      expect(cubit.state, isA<TextReaderResult>());
      expect(haptics.played, contains(HapticPattern.success));
      await cubit.close();
    });

    test('scan again looks for new text', () async {
      ocr.frameResults = [_centered];
      final cubit = await live();
      await frame();
      await frame();
      expect(cubit.state, isA<TextReaderResult>());

      await cubit.scanAgain();

      expect(cubit.state, const TextReaderAiming());
      expect(camera.frameListener, isNotNull);
      expect(tts.stops, 1);
      await cubit.close();
    });

    test('an unreadable frame is skipped', () async {
      ocr.error = StateError('bad frame');
      final cubit = await live();
      await frame();
      expect(cubit.state, const TextReaderAiming());
      await cubit.close();
    });

    test('pressing Read text stops live guidance first', () async {
      ocr.lines = ['Open'];
      final cubit = await live();
      await read(cubit);
      expect(camera.frameListener, isNull);
      expect(cubit.state, const TextReaderResult(['Open']));
      await cubit.close();
    });
  });

  test('stopReading stops speech', () async {
    final cubit = build();
    await cubit.stopReading();
    expect(tts.stops, 1);
    await cubit.close();
  });
}
