import 'dart:io';

import 'package:camera/camera.dart';
import 'package:glide/core/error/exceptions.dart';
import 'package:glide/services/camera/camera_frame.dart';

/// Owns the device camera. Frames are delivered in memory only and are never
/// written to disk (see docs/architecture.md, Security and privacy).
abstract interface class CameraService {
  bool get isInitialized;

  /// The plugin controller, needed by `CameraPreview`. Null until initialised.
  CameraController? get controller;

  Future<void> initialize();

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
    CameraController Function(CameraDescription camera);

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

  static CameraController _defaultController(CameraDescription camera) =>
      CameraController(
        camera,
        // Medium keeps per-frame conversion cheap; detection models take
        // ~300–640 px inputs anyway.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;
    final cameras = await _loadCameras();
    if (cameras.isEmpty) {
      throw const CameraUnavailableException('No camera found on this device');
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = _createController(back);
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw CameraUnavailableException(e.description ?? e.code);
    }
    _controller = controller;
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
  }

  CameraController _requireController() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraUnavailableException('Camera is not initialised');
    }
    return controller;
  }
}
