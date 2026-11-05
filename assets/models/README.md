# Detection model

| File | What it is |
|---|---|
| `detector.tflite` | EfficientDet-Lite0, int8, 320×320 input, trained on COCO (80 classes) |
| `labels.txt` | Label map extracted from the model's own metadata; 90 lines, `???` marks unused COCO ids |

**Source:** Google MediaPipe Object Detector
<https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/int8/latest/efficientdet_lite0.tflite>
(downloaded 2026-11-04, 4,602,795 bytes,
SHA-256 `0720bf247bd76e6594ea28fa9c6f7c5242be774818997dbbeffc4da460c723bb`)

**Published speed:** 29.3 ms per frame on a Pixel 6 CPU (Google's figure).

**Licence:** Google publishes no model card for this file. MediaPipe and the
original EfficientDet code (google/automl) are Apache 2.0, and the model is
widely treated as Apache 2.0, but **confirm this before a public release.**

**Output order** (from the model metadata): boxes, classes, scores, count. The
decoder also detects swapped classes/scores at runtime.

**Known gap:** COCO has no poles, curbs, stairs or bins. See "Model roadmap" in
`docs/tasks.md`.

Model files are large; when the repo is created, track them with Git LFS
(`git lfs track "*.tflite"`).

To swap in another model: any TFLite detector with standard detection
post-processing (4 outputs) and a `[1, h, w, 3]` uint8 or float32 input works.
Update `labels.txt` to match, and the obstacle list in
`lib/features/detection/domain/usecases/distance_estimator.dart`.
