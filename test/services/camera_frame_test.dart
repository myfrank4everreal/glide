import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glide/services/camera/camera_frame.dart';

CameraImage _image(
  ImageFormatGroup group, {
  int planes = 1,
  int? bytesPerPixel,
}) => CameraImage.fromPlatformInterface(
  CameraImageData(
    format: CameraImageFormat(group, raw: 0),
    width: 4,
    height: 2,
    planes: [
      for (var i = 0; i < planes; i++)
        CameraImagePlane(
          bytes: Uint8List(8),
          bytesPerRow: 4,
          bytesPerPixel: bytesPerPixel,
        ),
    ],
  ),
);

void main() {
  test('wraps a three-plane YUV image', () {
    final image = _image(ImageFormatGroup.yuv420, planes: 3, bytesPerPixel: 1);

    final frame = CameraFrame.fromCameraImage(image, rotation: 90)!;

    expect(frame.format, FrameFormat.yuv420);
    expect((frame.width, frame.height, frame.rotation), (4, 2, 90));
    expect(frame.planes, hasLength(3));
    // No copy: the frame points at the plugin's buffer.
    expect(identical(frame.planes[0].bytes, image.planes[0].bytes), isTrue);
  });

  test('wraps a BGRA image and defaults its pixel stride to 4', () {
    final frame = CameraFrame.fromCameraImage(
      _image(ImageFormatGroup.bgra8888),
      rotation: 0,
    )!;

    expect(frame.format, FrameFormat.bgra8888);
    expect(frame.planes.single.bytesPerPixel, 4);
  });

  test('rejects formats the detector cannot read', () {
    expect(
      CameraFrame.fromCameraImage(_image(ImageFormatGroup.jpeg), rotation: 0),
      isNull,
    );
    // YUV must come as three planes, not packed NV21.
    expect(
      CameraFrame.fromCameraImage(_image(ImageFormatGroup.yuv420), rotation: 0),
      isNull,
    );
  });
}
