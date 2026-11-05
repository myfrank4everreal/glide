import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';
import 'package:glide/features/detection/domain/entities/detection_result.dart';
import 'package:glide/features/detection/domain/entities/obstacle_alert.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/services/haptic/haptic_pattern.dart';

import '../../../helpers/fakes.dart';

Detection _d(String label, {double confidence = 0.9, double distance = 2}) =>
    Detection(
      label: label,
      confidence: confidence,
      left: 0.4,
      top: 0.2,
      right: 0.6,
      bottom: 0.8,
      distanceMeters: distance,
    );

void main() {
  late FakeDetectionRepository repository;

  late FakeTtsService tts;
  late FakeHapticService haptics;
  var now = DateTime(2026, 11, 4, 12);

  setUp(() {
    repository = FakeDetectionRepository();
    tts = FakeTtsService();
    haptics = FakeHapticService();
    now = DateTime(2026, 11, 4, 12);
  });

  late FakeScreenAwakeService screen;
  setUp(() => screen = FakeScreenAwakeService());

  DetectionCubit build({Duration stall = const Duration(seconds: 3)}) =>
      DetectionCubit(
        repository: repository,
        tts: tts,
        haptics: haptics,
        screen: screen,
        stallTimeout: stall,
        now: () => now,
      );

  blocTest<DetectionCubit, DetectionState>(
    'start runs detection and shows results above the threshold, closest first',
    build: build,
    act: (cubit) async {
      await cubit.start(confidenceThreshold: 0.6);
      repository.results.add(
        DetectionResult(
          detections: [
            _d('far', distance: 6),
            _d('unsure', confidence: 0.4),
            _d('close', distance: 0.8),
          ],
          processingTime: const Duration(milliseconds: 21),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const DetectionState(status: DetectionStatus.running),
      DetectionState(
        status: DetectionStatus.running,
        detections: [_d('close', distance: 0.8), _d('far', distance: 6)],
        processingTime: const Duration(milliseconds: 21),
      ),
    ],
  );

  blocTest<DetectionCubit, DetectionState>(
    'a missing model is reported, not thrown',
    setUp: () => repository.startError = const ModelLoadException('missing'),
    build: build,
    act: (cubit) => cubit.start(confidenceThreshold: 0.6),
    expect: () => [
      const DetectionState(status: DetectionStatus.modelUnavailable),
    ],
  );

  blocTest<DetectionCubit, DetectionState>(
    'a camera that closed meanwhile leaves detection idle',
    setUp: () =>
        repository.startError = const CameraUnavailableException('closed'),
    build: build,
    act: (cubit) => cubit.start(confidenceThreshold: 0.6),
    expect: () => <DetectionState>[],
  );

  blocTest<DetectionCubit, DetectionState>(
    'starting twice only starts the repository once',
    build: build,
    act: (cubit) async {
      await cubit.start(confidenceThreshold: 0.6);
      await cubit.start(confidenceThreshold: 0.6);
    },
    verify: (_) => expect(repository.starts, 1),
  );

  blocTest<DetectionCubit, DetectionState>(
    'stop clears detections and stops the repository',
    build: build,
    act: (cubit) async {
      await cubit.start(confidenceThreshold: 0.6);
      repository.results.add(
        DetectionResult(
          detections: [_d('person')],
          processingTime: Duration.zero,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.stop();
    },
    skip: 2,
    expect: () => [const DetectionState()],
    verify: (_) => expect(repository.stops, greaterThanOrEqualTo(1)),
  );

  blocTest<DetectionCubit, DetectionState>(
    'results that arrive after stop are ignored',
    build: build,
    act: (cubit) async {
      await cubit.start(confidenceThreshold: 0.6);
      await cubit.stop();
      repository.results.add(
        DetectionResult(
          detections: [_d('person')],
          processingTime: Duration.zero,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const DetectionState(status: DetectionStatus.running),
      const DetectionState(),
    ],
  );

  test('close stops the repository', () async {
    final cubit = build();
    await cubit.start(confidenceThreshold: 0.6);

    await cubit.close();

    expect(repository.stops, 1);
  });

  group('alerts', () {
    Future<void> emit(DetectionCubit cubit, List<Detection> detections) async {
      repository.results.add(
        DetectionResult(detections: detections, processingTime: Duration.zero),
      );
      await Future<void>.delayed(Duration.zero);
    }

    String describe(ObstacleAlert a) =>
        '${a.label} ${a.direction.name} ${a.band.name}';

    test('a near obstacle vibrates and is spoken', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6, describe: describe);

      await emit(cubit, [_d('bench', distance: 2)]);

      expect(haptics.played, [HapticPattern.near]);
      expect(tts.spoken, ['bench ahead near']);
      expect(tts.interrupted, [false]);
      await cubit.close();
    });

    test('a close obstacle interrupts speech in progress', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6, describe: describe);

      await emit(cubit, [_d('car', distance: 0.6)]);

      expect(haptics.played, [HapticPattern.close]);
      expect(tts.interrupted, [true]);
      await cubit.close();
    });

    test('voice off still vibrates', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6, voiceEnabled: false);

      await emit(cubit, [_d('bench', distance: 2)]);

      expect(haptics.played, [HapticPattern.near]);
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });

    test('voice can be turned off while running', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6);
      cubit.updateOptions(confidenceThreshold: 0.6, voiceEnabled: false);

      await emit(cubit, [_d('bench', distance: 2)]);

      expect(tts.spoken, isEmpty);
      await cubit.close();
    });

    test('the same obstacle is not repeated every frame', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6);

      for (var i = 0; i < 5; i++) {
        await emit(cubit, [_d('bench', distance: 2)]);
        now = now.add(const Duration(milliseconds: 100));
      }

      expect(tts.spoken, hasLength(1));
      await cubit.close();
    });

    test('far obstacles are drawn but not announced', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6);

      await emit(cubit, [_d('bench', distance: 6)]);

      expect(cubit.state.detections, hasLength(1));
      expect(haptics.played, isEmpty);
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });

    test('restarting detection forgets earlier alerts', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6);
      await emit(cubit, [_d('bench', distance: 2)]);
      await cubit.stop();

      await cubit.start(confidenceThreshold: 0.6);
      await emit(cubit, [_d('bench', distance: 2)]);

      expect(tts.spoken, hasLength(2));
      await cubit.close();
    });

    test('a traffic light gives the crossing cue on a quiet frame', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6, crossingPhrase: 'crossing');

      await emit(cubit, [_d('traffic light', distance: 8)]);
      now = now.add(const Duration(seconds: 2));
      await emit(cubit, [_d('traffic light', distance: 8)]);

      expect(haptics.played, [HapticPattern.crossing]);
      expect(tts.spoken, ['crossing']);
      await cubit.close();
    });

    test('an obstacle alert goes before the crossing cue', () async {
      final cubit = build();
      await cubit.start(
        confidenceThreshold: 0.6,
        describe: describe,
        crossingPhrase: 'crossing',
      );

      await emit(cubit, [
        _d('car', distance: 0.8),
        _d('traffic light', distance: 8),
      ]);
      expect(tts.spoken, ['car ahead close']);

      await emit(cubit, [_d('traffic light', distance: 8)]);
      expect(tts.spoken.last, 'crossing');
      await cubit.close();
    });
  });

  group('safety', () {
    const stall = Duration(milliseconds: 40);

    Future<void> frame() async {
      repository.results.add(
        const DetectionResult(detections: [], processingTime: Duration.zero),
      );
      await Future<void>.delayed(Duration.zero);
    }

    test('the screen stays on only while detecting', () async {
      final cubit = build();
      await cubit.start(confidenceThreshold: 0.6);
      expect(screen.on, isTrue);

      await cubit.stop();
      expect(screen.on, isFalse);
      await cubit.close();
    });

    test('no frames for a while is announced, not silent', () async {
      final cubit = build(stall: stall);
      await cubit.start(
        confidenceThreshold: 0.6,
        interruptedPhrase: 'not working',
        resumedPhrase: 'resumed',
      );

      await Future<void>.delayed(stall * 2);

      expect(cubit.state.status, DetectionStatus.interrupted);
      expect(tts.spoken, ['not working']);
      expect(tts.interrupted, [true]);
      expect(haptics.played, [HapticPattern.error]);

      await frame();
      expect(cubit.state.status, DetectionStatus.running);
      expect(tts.spoken.last, 'resumed');
      await cubit.close();
    });

    test('steady frames keep the watchdog quiet', () async {
      final cubit = build(stall: stall);
      await cubit.start(confidenceThreshold: 0.6);

      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(stall ~/ 2);
        await frame();
      }

      expect(cubit.state.status, DetectionStatus.running);
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });

    test('stopping cancels the watchdog', () async {
      final cubit = build(stall: stall);
      await cubit.start(confidenceThreshold: 0.6);
      await cubit.stop();

      await Future<void>.delayed(stall * 2);

      expect(cubit.state.status, DetectionStatus.idle);
      expect(tts.spoken, isEmpty);
      await cubit.close();
    });
  });
}
