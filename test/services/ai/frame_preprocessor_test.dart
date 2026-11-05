import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/ai/frame_preprocessor.dart';
import 'package:glide/services/camera/camera_frame.dart';

/// 2×2 BGRA frame with a distinct colour in each corner (sensor orientation):
///   red    green
///   blue   white
CameraFrame _quadrants({int rotation = 0}) {
  const red = [0, 0, 255, 255];
  const green = [0, 255, 0, 255];
  const blue = [255, 0, 0, 255];
  const white = [255, 255, 255, 255];
  return CameraFrame(
    format: FrameFormat.bgra8888,
    width: 2,
    height: 2,
    rotation: rotation,
    planes: [
      FramePlane(
        bytes: Uint8List.fromList([...red, ...green, ...blue, ...white]),
        bytesPerRow: 8,
        bytesPerPixel: 4,
      ),
    ],
  );
}

List<int> _pixel(Uint8List rgb, int width, int x, int y) {
  final i = (y * width + x) * 3;
  return rgb.sublist(i, i + 3);
}

const _red = [255, 0, 0];
const _green = [0, 255, 0];
const _blue = [0, 0, 255];
const _white = [255, 255, 255];

void main() {
  group('BGRA', () {
    test('converts to RGB without rotation', () {
      final rgb = frameToRgb(_quadrants(), outWidth: 2, outHeight: 2);

      expect(_pixel(rgb, 2, 0, 0), _red);
      expect(_pixel(rgb, 2, 1, 0), _green);
      expect(_pixel(rgb, 2, 0, 1), _blue);
      expect(_pixel(rgb, 2, 1, 1), _white);
    });

    test('rotation 90 turns the image clockwise', () {
      final rgb = frameToRgb(
        _quadrants(rotation: 90),
        outWidth: 2,
        outHeight: 2,
      );

      // Clockwise: left column (red, blue) becomes the top row, reversed.
      expect(_pixel(rgb, 2, 0, 0), _blue);
      expect(_pixel(rgb, 2, 1, 0), _red);
      expect(_pixel(rgb, 2, 0, 1), _white);
      expect(_pixel(rgb, 2, 1, 1), _green);
    });

    test('rotation 180 flips both axes', () {
      final rgb = frameToRgb(
        _quadrants(rotation: 180),
        outWidth: 2,
        outHeight: 2,
      );

      expect(_pixel(rgb, 2, 0, 0), _white);
      expect(_pixel(rgb, 2, 1, 1), _red);
    });

    test('rotation 270 turns the image anticlockwise', () {
      final rgb = frameToRgb(
        _quadrants(rotation: 270),
        outWidth: 2,
        outHeight: 2,
      );

      expect(_pixel(rgb, 2, 0, 0), _green);
      expect(_pixel(rgb, 2, 1, 0), _white);
      expect(_pixel(rgb, 2, 0, 1), _red);
      expect(_pixel(rgb, 2, 1, 1), _blue);
    });

    test('scales to the requested size', () {
      final rgb = frameToRgb(_quadrants(), outWidth: 4, outHeight: 4);

      expect(rgb.length, 4 * 4 * 3);
      expect(_pixel(rgb, 4, 0, 0), _red);
      expect(_pixel(rgb, 4, 3, 0), _green);
      expect(_pixel(rgb, 4, 0, 3), _blue);
      expect(_pixel(rgb, 4, 3, 3), _white);
    });

    test('honours row padding', () {
      // 1×1 image whose row is padded to 8 bytes.
      final frame = CameraFrame(
        format: FrameFormat.bgra8888,
        width: 1,
        height: 2,
        rotation: 0,
        planes: [
          FramePlane(
            bytes: Uint8List.fromList([
              0, 0, 255, 255, 9, 9, 9, 9, // row 0: red + padding
              255, 0, 0, 255, 9, 9, 9, 9, // row 1: blue + padding
            ]),
            bytesPerRow: 8,
            bytesPerPixel: 4,
          ),
        ],
      );

      final rgb = frameToRgb(frame, outWidth: 1, outHeight: 2);

      expect(_pixel(rgb, 1, 0, 0), _red);
      expect(_pixel(rgb, 1, 0, 1), _blue);
    });
  });

  group('YUV420', () {
    CameraFrame yuv({required int y, required int u, required int v}) =>
        CameraFrame(
          format: FrameFormat.yuv420,
          width: 2,
          height: 2,
          rotation: 0,
          planes: [
            FramePlane(
              bytes: Uint8List.fromList([y, y, y, y]),
              bytesPerRow: 2,
              bytesPerPixel: 1,
            ),
            // Android commonly delivers interleaved chroma (pixel stride 2).
            FramePlane(
              bytes: Uint8List.fromList([u, v]),
              bytesPerRow: 2,
              bytesPerPixel: 2,
            ),
            FramePlane(
              bytes: Uint8List.fromList([v, u]),
              bytesPerRow: 2,
              bytesPerPixel: 2,
            ),
          ],
        );

    test('neutral chroma gives grey', () {
      final rgb = frameToRgb(
        yuv(y: 128, u: 128, v: 128),
        outWidth: 1,
        outHeight: 1,
      );
      expect(rgb, [128, 128, 128]);
    });

    test('black and white stay black and white', () {
      expect(frameToRgb(yuv(y: 0, u: 128, v: 128), outWidth: 1, outHeight: 1), [
        0,
        0,
        0,
      ]);
      expect(
        frameToRgb(yuv(y: 255, u: 128, v: 128), outWidth: 1, outHeight: 1),
        [255, 255, 255],
      );
    });

    test('high V is red, high U is blue (BT.601, clamped)', () {
      final red = frameToRgb(
        yuv(y: 76, u: 85, v: 255),
        outWidth: 1,
        outHeight: 1,
      );
      expect(red[0], greaterThan(240));
      expect(red[2], lessThan(20));

      final blue = frameToRgb(
        yuv(y: 29, u: 255, v: 107),
        outWidth: 1,
        outHeight: 1,
      );
      expect(blue[2], greaterThan(240));
      expect(blue[0], lessThan(20));
    });
  });

  test('float input is normalised to -1..1', () {
    final floats = rgbToFloat32(Uint8List.fromList([0, 128, 255]));
    expect(floats[0], closeTo(-1, 0.01));
    expect(floats[1], closeTo(0, 0.01));
    expect(floats[2], closeTo(1, 0.01));
  });

  test('display size swaps width and height for 90 and 270', () {
    expect(_quadrants(rotation: 90).displaySize, (width: 2, height: 2));
    final wide = CameraFrame(
      format: FrameFormat.bgra8888,
      width: 640,
      height: 480,
      rotation: 90,
      planes: const [],
    );
    expect(wide.displaySize, (width: 480, height: 640));
  });
}
