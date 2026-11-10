import 'dart:typed_data';

import 'package:camera/camera.dart';

enum FrameFormat {
  yuv420,
  bgra8888,

  /// Android's single-plane YUV, which ML Kit text recognition reads directly.
  nv21,
}

class FramePlane {
  const FramePlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

/// One camera frame in plain Dart types, so it can be sent to the inference
/// isolate and built in tests. Held in memory only; never written to disk.
class CameraFrame {
  const CameraFrame({
    required this.format,
    required this.width,
    required this.height,
    required this.rotation,
    required this.planes,
  });

  /// Wraps the plugin image without copying its pixel buffers. Returns null
  /// for formats the detector can't read.
  static CameraFrame? fromCameraImage(
    CameraImage image, {
    required int rotation,
  }) {
    final format = switch (image.format.group) {
      ImageFormatGroup.yuv420 when image.planes.length == 3 =>
        FrameFormat.yuv420,
      ImageFormatGroup.bgra8888 => FrameFormat.bgra8888,
      ImageFormatGroup.nv21 => FrameFormat.nv21,
      _ => null,
    };
    if (format == null) return null;
    return CameraFrame(
      format: format,
      width: image.width,
      height: image.height,
      rotation: rotation,
      planes: [
        for (final p in image.planes)
          FramePlane(
            bytes: p.bytes,
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel:
                p.bytesPerPixel ?? (format == FrameFormat.bgra8888 ? 4 : 1),
          ),
      ],
    );
  }

  final FrameFormat format;

  /// Size in sensor orientation.
  final int width;
  final int height;

  /// Clockwise degrees (0, 90, 180, 270) that turn the sensor image upright.
  final int rotation;

  final List<FramePlane> planes;

  /// Average brightness, 0 (black) to 255, from a sparse sample of pixels.
  /// Cheap enough to call on every frame.
  double meanLuma({int samples = 400}) {
    final plane = planes.first.bytes;
    if (plane.isEmpty) return 0;
    final step = format == FrameFormat.bgra8888 ? 4 : 1;
    final pixels = format == FrameFormat.bgra8888
        ? plane.length ~/ 4
        : width * height; // Y comes first in yuv420 and nv21.
    final stride = (pixels / samples).ceil().clamp(1, pixels);
    var sum = 0;
    var count = 0;
    for (var i = 0; i < pixels && i * step + 2 < plane.length; i += stride) {
      final o = i * step;
      // BGRA: approximate luma as (R + 2G + B) / 4.
      sum += step == 4
          ? (plane[o + 2] + 2 * plane[o + 1] + plane[o]) >> 2
          : plane[o];
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  /// Size as the user sees it, after rotation.
  ({int width, int height}) get displaySize => rotation % 180 == 0
      ? (width: width, height: height)
      : (width: height, height: width);
}
