import 'dart:io';
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/services/camera/camera_frame.dart';

/// What the camera is set up for. Detection wants small, fast frames; reading
/// text wants detail.
enum CameraUse { detection, text }

/// Owns the device camera. Frames are delivered in memory only and are never
/// written to disk (see docs/architecture.md, Security and privacy).
abstract interface class CameraService {
  bool get isInitialized;

  /// The plugin controller, needed by `CameraPreview`. Null until initialised.
  CameraController? get controller;

  /// Opens the back camera for [use]. Reopens it if it was open for a
  /// different use.
  Future<void> initialize({CameraUse use = CameraUse.detection});

  /// Asks the camera to focus and set exposure on the middle of the picture.
  /// Cameras without these controls ignore it.
  Future<void> focusOnCenter();

  /// Turns the light on or off. Returns false if the camera has no light.
  Future<bool> setTorch({required bool on});

  /// Streams frames, already tagged with the rotation that makes them
  /// upright. Frames in formats the app can't read are skipped.
  Future<void> startFrameStream(void Function(CameraFrame frame) onFrame);
  Future<void> stopFrameStream();

  /// Captures a single still for text reading. The caller must delete the
  /// file once it has been processed.
  Future<XFile> takePicture();

  Future<void> dispose();
}

typedef CameraListLoader = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory =
    CameraController Function(CameraDescription camera, CameraUse use);

class PluginCameraService implements CameraService {
  /// The parameters exist so tests can replace the plugin; the app uses the
  /// defaults.
  PluginCameraService({
    CameraListLoader? loadCameras,
    CameraControllerFactory? createController,
  }) : _loadCameras = loadCameras ?? availableCameras,
       _createController = createController ?? _defaultController;

  final CameraListLoader _loadCameras;
  final CameraControllerFactory _createController;
  CameraController? _controller;

  static CameraController _defaultController(
    CameraDescription camera,
    CameraUse use,
  ) => CameraController(
    camera,
    switch (use) {
      // Medium keeps per-frame conversion cheap; detection models take
      // ~300–640 px inputs anyway.
      CameraUse.detection => ResolutionPreset.medium,
      // Small print needs detail: 1080p for both live frames and photos.
      CameraUse.text => ResolutionPreset.veryHigh,
    },
    enableAudio: false,
    imageFormatGroup: switch ((use, Platform.isIOS)) {
      (_, true) => ImageFormatGroup.bgra8888,
      (CameraUse.detection, false) => ImageFormatGroup.yuv420,
      // ML Kit on Android reads NV21 frames without conversion.
      (CameraUse.text, false) => ImageFormatGroup.nv21,
    },
  );

  CameraUse? _use;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  Future<void> initialize({CameraUse use = CameraUse.detection}) async {
    if (isInitialized && _use == use) return;
    if (isInitialized) await dispose();
    final cameras = await _loadCameras();
    if (cameras.isEmpty) {
      throw const CameraUnavailableException('No camera found on this device');
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = _createController(back, use);
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw CameraUnavailableException(e.description ?? e.code);
    }
    _controller = controller;
    _use = use;
  }

  @override
  Future<void> focusOnCenter() async {
    final controller = _requireController();
    const center = Offset(0.5, 0.5);
    // Each control is optional hardware; try them one by one.
    for (final step in <Future<void> Function()>[
      () => controller.setFocusMode(FocusMode.auto),
      () => controller.setExposureMode(ExposureMode.auto),
      () => controller.setFocusPoint(center),
      () => controller.setExposurePoint(center),
    ]) {
      try {
        await step();
      } on CameraException {
        continue;
      }
    }
  }

  @override
  Future<bool> setTorch({required bool on}) async {
    try {
      await _requireController().setFlashMode(
        on ? FlashMode.torch : FlashMode.off,
      );
      return true;
    } on CameraException {
      return false;
    }
  }

  @override
  Future<void> startFrameStream(
    void Function(CameraFrame frame) onFrame,
  ) async {
    final controller = _requireController();
    if (controller.value.isStreamingImages) return;
    // The app is locked to portrait, so the sensor orientation alone says
    // how far to rotate each frame.
    final rotation = controller.description.sensorOrientation;
    await controller.startImageStream((image) {
      final frame = CameraFrame.fromCameraImage(image, rotation: rotation);
      if (frame != null) onFrame(frame);
    });
  }

  @override
  Future<void> stopFrameStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  @override
  Future<XFile> takePicture() => _requireController().takePicture();

  @override
  Future<void> dispose() async {
    await stopFrameStream();
    await _controller?.dispose();
    _controller = null;
    _use = null;
  }

  CameraController _requireController() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraUnavailableException('Camera is not initialised');
    }
    return controller;
  }
}
