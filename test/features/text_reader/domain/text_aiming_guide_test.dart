import 'package:flutter_test/flutter_test.dart';
import 'package:glide/core/vision/recognized_line.dart';
import 'package:glide/features/text_reader/domain/usecases/text_aiming_guide.dart';

RecognizedLine _line(
  String text, {
  double left = 0.2,
  double top = 0.4,
  double right = 0.8,
  double bottom = 0.45,
}) => RecognizedLine(text, left: left, top: top, right: right, bottom: bottom);

void main() {
  late TextAimingGuide guide;

  setUp(() => guide = TextAimingGuide());

  test('no text, no hint', () {
    expect(guide.next(const []), AimHint.none);
  });

  test('text cut off at one edge says which way to move', () {
    expect(guide.next([_line('a', left: 0)]), AimHint.moveLeft);
    expect(guide.next([_line('a', right: 1)]), AimHint.moveRight);
    expect(guide.next([_line('a', top: 0)]), AimHint.moveUp);
    expect(guide.next([_line('a', bottom: 1)]), AimHint.moveDown);
  });

  test('text cut off on both sides means move back', () {
    expect(guide.next([_line('a', left: 0, right: 1)]), AimHint.moveBack);
    expect(guide.next([_line('a', top: 0, bottom: 1)]), AimHint.moveBack);
  });

  test('tiny text means move closer', () {
    expect(guide.next([_line('fine print', bottom: 0.41)]), AimHint.moveCloser);
  });

  test('complete text: hold still, then ready once it repeats', () {
    expect(guide.next([_line('Platform 2 to London')]), AimHint.holdStill);
    // Recognition jitters a little between frames; most words still match.
    expect(guide.next([_line('Platform 2 to Londen')]), AimHint.holdStill);
    expect(guide.next([_line('Platform 2 to Londen')]), AimHint.ready);
  });

  test('different text starts the count again', () {
    guide.next([_line('Exit')]);
    expect(guide.next([_line('Toilets this way')]), AimHint.holdStill);
  });

  test('losing the text resets the count', () {
    guide
      ..next([_line('Exit')])
      ..next(const []);
    expect(guide.next([_line('Exit')]), AimHint.holdStill);
  });

  test('reading order is top to bottom, then left to right', () {
    final lines = [
      _line('second', top: 0.6, bottom: 0.65),
      _line('right', left: 0.5, top: 0.3, bottom: 0.35),
      _line('left', left: 0.1, top: 0.31, bottom: 0.36),
    ]..sort(readingOrder);
    expect(lines.map((l) => l.text), ['left', 'right', 'second']);
  });
}
