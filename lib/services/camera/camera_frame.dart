import 'dart:typed_data';

import 'package:camera/camera.dart';

enum FrameFormat { yuv420, bgra8888 }

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

  /// Size as the user sees it, after rotation.
  ({int width, int height}) get displaySize => rotation % 180 == 0
      ? (width: width, height: height)
      : (width: height, height: width);
}
