# Glide — Tasks

Each milestone is 1–2 weeks and ends with something visible running on a real phone.
A task is ticked only when its tests pass and `flutter analyze` is clean.

## Milestone 0: Project foundation ✅

* [x] Flutter project with clean architecture folders
* [x] get_it DI, go_router, Cubit state management
* [x] Service interfaces + plugin implementations (camera, TTS, haptic, location, permissions, OCR)
* [x] TFLite detector scaffold (model loading; inference in M2)
* [x] Detection domain: entity, direction, distance bands, prioritisation
* [x] Settings feature end to end (persisted, applied to TTS/haptics, GDPR delete)
* [x] Light, dark and high-contrast themes; accessible base widgets
* [x] English ARB localisation
* [x] Lints, 82 unit/widget tests (95% coverage), GitHub Actions CI
* [x] Android (min 26, target 35) and iOS (15.5) permissions and versions
* [ ] Verify on a real Android phone and iPhone (not done: built on Windows, no device run yet)

## Milestone 1: Project Setup & Camera Integration

* [x] Setup Flutter project with clean architecture (done in M0)
* [x] Configure camera plugin with permission handling: spoken explanation before
  the OS prompt, retry after denial, system-settings route when permanently denied,
  re-check on return from settings
* [x] Display camera feed in app, released when the app goes to the background
  and reopened on return
* [x] Basic haptic feedback test: plays the far / near / very close patterns,
  naming each one aloud
* [ ] **Verify on a real Android phone and iPhone with TalkBack / VoiceOver**
  (not done: no Android SDK or Mac on the build machine)

## Milestone 2: Core AI Detection

* [x] Integrate TensorFlow Lite: model loads on the main isolate; frame
  conversion and inference run on a long-lived worker isolate
* [x] Load pre-trained detection model: EfficientDet-Lite0 int8 (COCO) in
  `assets/models/`, labels taken from its own metadata, output order checked
  against its metadata (see `assets/models/README.md`)
* [ ] Test it on a phone: `integration_test/detector_test.dart`
* [x] Process camera frames in real-time: YUV420/BGRA → upright RGB in one pass,
  drops frames while busy, capped at ~10 fps for battery
* [x] Display detection results with bounding boxes, coloured by distance band,
  with a spoken-friendly summary for screen readers
* [x] Rough distance estimate from box height (pulled forward from M3 because
  every detection needs one; M3 calibrates it)
* [ ] **On a real phone:** run `detector_test.dart`, record ms per frame against
  the 30 ms target, and check boxes line up with the preview
* [ ] Accuracy benchmark on real street photos (needs a labelled sample set)
* [ ] Known gap: the COCO model can't see poles, curbs, stairs or bins, which
  matter most to a cane user. See the model roadmap below
* [ ] Confirm the model's licence before public release (no official model card)

## Model roadmap (decided 2026-11-04)

Chosen path: keep EfficientDet (Apache-licensed tooling, no AGPL), fine-tune it.
YOLO trained on Open Images was rejected because its AGPL-3.0 licence would
require open-sourcing Glide or buying an Enterprise licence.

1. **Fine-tune EfficientDet-Lite0 with MediaPipe Model Maker** on:
   * Open Images classes: Stairs, Waste container, Street light, Traffic sign,
     Door (confirm the Open Images annotation licence first)
   * COCO classes we already use (person, bicycle, car, bench, ...)
   * Our own labelled photos of **poles and curbs**, which no ready-made
     dataset covers under a commercial licence. Collect them in the streets
     target users actually walk, ideally with them
2. **Depth model (Milestone 3):** class-agnostic "something is close in your
   path" from a monocular depth model, plus LiDAR on supported iPhones. This
   covers thin poles, curb drop-offs and anything the detector can't name.
3. **Benchmark** each model on a held-out set of real street photos before it
   replaces the current one; ship only if recall on close obstacles improves.

## Milestone 3: User Feedback System

* [x] Integrate TTS plugin (service since M0; speech rate and voice on/off
  from settings, applied live)
* [x] Implement haptic feedback patterns (far / near / close; intensity from settings)
* [x] Voice alerts for detected obstacles (`AlertPolicy`): only near and close
  obstacles; one alert per frame, most dangerous first; same object not repeated
  for 3 s unless it gets closer; 1.5 s gap between normal alerts; close-range
  alerts interrupt speech and skip the gap
* [ ] Distance estimation logic: first version done in M2; **calibrate on a real
  phone** against measured distances (person, bench, car at 1, 2, 4 m)
* [x] Read text aloud (US-5): one photo, on-device OCR, spoken in reading
  order, photo deleted immediately; button plus double-tap for non-screen-reader users
* [x] Camera permission screens shared by both camera features (`CameraGate`)
* [ ] **Depth model** for obstacles the detector can't name (poles, curbs,
  drop-offs): needs a model download (approval) and on-device testing
* [ ] On a real phone with TalkBack / VoiceOver: are alerts timely, understandable
  and not too chatty? Tune `AlertPolicy` timings with blind testers

## Milestone 4: Navigation & GPS

Scope chosen: offline "guide me back to a saved place", with no routing
service and no network calls. Turn-by-turn directions along streets need a
routing provider, which is a product decision (cost, licence, privacy policy).

* [x] Integrate location plugin: `LocationService` returns a fix with its
  accuracy; distance and bearing are pure Dart in `core/geo`
* [x] Compass (`HeadingService`): tilt-compensated from accelerometer and
  magnetometer, using the camera direction when the phone is upright
* [x] Saved places: "Save this spot" with a spoken name, stored encrypted
  (Keystore / Keychain), erased by "Delete my data"
* [x] Basic outdoor navigation UI: places list, guiding screen with Repeat and
  Stop, permission screens with a spoken explanation first
* [x] Voice guidance (`GuidancePolicy`): "Front door, 120 metres, at 2 o'clock";
  turns announced at most every 4 s, reassurance every 30 s, weak GPS and
  arrival announced once; a tick when facing the target
* [x] Street crossing cue (`CrossingCuePolicy`): a traffic light or stop sign in
  view gives three long pulses and "possibly a street crossing" at most every
  20 s. It never says it is safe to cross
* [ ] **On a real phone:** compass accuracy upright and flat, near cars and
  steel; GPS arrival radius in a street; iOS uses the raw magnetometer
  (sensors_plus), which may need calibration or CoreLocation heading instead
* [ ] Turn-by-turn routing along streets: choose a provider (e.g. self-hosted
  OSRM or Valhalla on OpenStreetMap data, or a paid API), update the privacy
  policy, then add a `RouteService`
* [ ] "Where am I?" (street name): needs reverse geocoding, same decision
* [ ] Real crossing detection: crosswalk markings and pedestrian signal state
  need a purpose-trained model; test only with blind users and O&M instructors
* [ ] Obstacle detection while navigating (one screen running both)
* [ ] Magnetic declination: headings are magnetic, bearings true; a few
  degrees off in most places, fine for 30° clock directions

## Milestone 5: MVP Polish

* [x] Settings: language picker (each language named in itself), "Replay the
  tutorial". The speech voice follows the app language
* [x] Spanish translation, including spoken object names. **Draft:** must be
  reviewed by a native speaker (ideally a blind user) before release
* [x] Onboarding tutorial: five pages (what Glide does, safety notice that must be
  acknowledged, how to hold the phone, feel each vibration, privacy). Read aloud
  by Glide only when no screen reader is running. Shown again after "Delete my data"
* [x] Edge cases that could fail silently:
  * detection watchdog: no processed frame for 3 s says "obstacle detection is
    not working" with an error buzz, and announces when it resumes
  * screen kept on while detecting or guiding (a locked phone stops the camera)
  * a broken speech engine no longer breaks alerts or app start-up
* [x] Error handling: uncaught errors are logged in memory, not fatal; friendly
  error screen for bad routes; release builds describe broken widgets instead
  of a grey box. No crash reporting (would need a privacy policy change)
* [x] Release pipeline (`release.yml`, [release.md](release.md)): signed AAB to the
  Play internal track and IPA to TestFlight on `v*` tags; R8 rules for TFLite and
  ML Kit; CI now builds a release-mode APK. **Not run yet:** needs store accounts
  and secrets
* [x] Privacy policy draft ([privacy-policy.md](privacy-policy.md)), including what
  ML Kit and TTS engines may do
* [ ] **Performance:** needs a real phone. Profile frame time, battery drain per
  hour and heat with detection on; consider adaptive frame rate when standing still
* [ ] On-screen box labels are still English (spoken alerts are translated)
* [ ] Before release: everything marked "on a real phone" above, model licence,
  translation review, publisher details in the privacy policy

## Phase 2+ (not started)

* [ ] Indoor navigation (floor plans)
* [ ] QR code indoor positioning
* [ ] Personalised route learning
* [ ] Community venue maps
* [ ] LiDAR depth fusion (iOS)
