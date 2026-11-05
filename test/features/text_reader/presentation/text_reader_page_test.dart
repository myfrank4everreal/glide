import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/features/text_reader/presentation/pages/text_reader_page.dart';
import 'package:glide/services/ai/text_recognition_service.dart';
import 'package:glide/services/permissions/permission_service.dart';

import '../../../helpers/fakes.dart';

class _FakeOcr implements TextRecognitionService {
  List<String> lines = const [];

  @override
  Future<List<String>> recognizeLines(String imagePath) async => lines;

  @override
  Future<void> close() async {}
}

void main() {
  late FakeCameraService camera;
  late FakeTtsService tts;
  late FakeHapticService haptics;
  late _FakeOcr ocr;

  setUp(() {
    camera = FakeCameraService();
    tts = FakeTtsService();
    haptics = FakeHapticService();
    ocr = _FakeOcr();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final settingsCubit = buildSettingsCubit(FakeSettingsRepository());
    final cameraCubit = CameraCubit(
      permissions: FakePermissionService()
        ..current = AppPermissionStatus.granted,
      camera: camera,
      haptics: haptics,
      tts: tts,
    );
    final reader = TextReaderCubit(
      camera: camera,
      ocr: ocr,
      tts: tts,
      haptics: haptics,
      deleteFile: (_) async {},
    );
    addTearDown(cameraCubit.close);
    addTearDown(reader.close);
    addTearDown(settingsCubit.close);
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cameraCubit),
            BlocProvider.value(value: reader),
          ],
          child: const TextReaderPage(),
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await cameraCubit.start();
    await tester.pumpAndSettle();
  }

  testWidgets('starts with instructions and a read button', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('Point the camera'), findsOneWidget);
    expect(find.text('Read text'), findsWidgets);
  });

  testWidgets('tapping read shows and speaks the text', (tester) async {
    ocr.lines = ['Platform 2', 'Exit'];
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Read text'));
    await tester.pumpAndSettle();

    expect(find.text('Platform 2\nExit'), findsOneWidget);
    expect(tts.spoken.last, 'Platform 2\nExit');
    expect(find.text('Stop reading'), findsOneWidget);
  });

  testWidgets('double-tapping the picture also reads', (tester) async {
    ocr.lines = ['Open'];
    await pumpPage(tester);

    final preview = find.byType(GestureDetector).first;
    await tester.tap(preview);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(preview);
    await tester.pumpAndSettle();

    expect(tts.spoken.last, 'Open');
  });

  testWidgets('no text found is said out loud', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Read text'));
    await tester.pumpAndSettle();

    expect(tts.spoken.last, startsWith('No text found'));
    expect(find.textContaining('No text found'), findsOneWidget);
  });

  testWidgets('meets tap target and labelling guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
