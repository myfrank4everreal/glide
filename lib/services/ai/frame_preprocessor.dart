import 'dart:typed_data';

import 'package:glide/services/camera/camera_frame.dart';

/// Converts a camera frame straight into a model input: upright, resized to
/// [outWidth]×[outHeight], packed RGB bytes.
///
/// Rotation, scaling and colour conversion happen in one pass that samples
/// only the output pixels (nearest neighbour). For a 320×320 model that is
/// ~100k samples instead of converting the whole 640×480 frame first, which
/// keeps preprocessing to a few milliseconds.
///
/// The image is stretched, not cropped, so objects at the edges of view are
/// still seen. Box coordinates from the model therefore map directly to the
/// upright frame.
Uint8List frameToRgb(
  CameraFrame frame, {
  required int outWidth,
  required int outHeight,
}) {
  final out = Uint8List(outWidth * outHeight * 3);
  final maxX = frame.width - 1;
  final maxY = frame.height - 1;
  var o = 0;
  for (var y = 0; y < outHeight; y++) {
    final v = (y + 0.5) / outHeight;
    for (var x = 0; x < outWidth; x++) {
      final u = (x + 0.5) / outWidth;
      // Map the upright (display) position back to the sensor image.
      final (su, sv) = switch (frame.rotation) {
        90 => (v, 1 - u),
        180 => (1 - u, 1 - v),
        270 => (1 - v, u),
        _ => (u, v),
      };
      final px = (su * frame.width).floor().clamp(0, maxX);
      final py = (sv * frame.height).floor().clamp(0, maxY);
      switch (frame.format) {
        case FrameFormat.bgra8888:
          final plane = frame.planes[0];
          final i = py * plane.bytesPerRow + px * plane.bytesPerPixel;
          out[o] = plane.bytes[i + 2];
          out[o + 1] = plane.bytes[i + 1];
          out[o + 2] = plane.bytes[i];
        case FrameFormat.yuv420:
          final yPlane = frame.planes[0];
          final uPlane = frame.planes[1];
          final vPlane = frame.planes[2];
          final luma =
              yPlane.bytes[py * yPlane.bytesPerRow + px * yPlane.bytesPerPixel];
          final cx = px >> 1;
          final cy = py >> 1;
          final cb =
              uPlane.bytes[cy * uPlane.bytesPerRow +
                  cx * uPlane.bytesPerPixel] -
              128;
          final cr =
              vPlane.bytes[cy * vPlane.bytesPerRow +
                  cx * vPlane.bytesPerPixel] -
              128;
          // BT.601 full range, fixed point (×1024).
          out[o] = (luma + ((1436 * cr) >> 10)).clamp(0, 255);
          out[o + 1] = (luma - ((352 * cb + 731 * cr) >> 10)).clamp(0, 255);
          out[o + 2] = (luma + ((1815 * cb) >> 10)).clamp(0, 255);
        case FrameFormat.nv21:
          // One plane: full-size Y, then interleaved V,U at half size.
          final plane = frame.planes[0];
          final stride = plane.bytesPerRow;
          final luma = plane.bytes[py * stride + px];
          final c = stride * frame.height + (py >> 1) * stride + (px >> 1) * 2;
          final cr = plane.bytes[c] - 128;
          final cb = plane.bytes[c + 1] - 128;
          out[o] = (luma + ((1436 * cr) >> 10)).clamp(0, 255);
          out[o + 1] = (luma - ((352 * cb + 731 * cr) >> 10)).clamp(0, 255);
          out[o + 2] = (luma + ((1815 * cb) >> 10)).clamp(0, 255);
      }
      o += 3;
    }
  }
  return out;
}

/// For float models: maps 0..255 to -1..1.
Float32List rgbToFloat32(Uint8List rgb) {
  final out = Float32List(rgb.length);
  for (var i = 0; i < rgb.length; i++) {
    out[i] = (rgb[i] - 127.5) / 127.5;
  }
  return out;
}
