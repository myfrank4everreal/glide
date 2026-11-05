import 'package:glide/features/detection/domain/entities/detection_result.dart';

/// Source of live detections from the camera.
abstract interface class DetectionRepository {
  /// One result per processed frame. Frames that arrive while the detector
  /// is busy are dropped, so this emits at most once per inference.
  Stream<DetectionResult> watchDetections();

  /// Loads the model (throws if it's missing) and starts processing frames.
  /// The camera must already be initialised.
  Future<void> start();

  Future<void> stop();
}
