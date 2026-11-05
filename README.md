# Glide

AI navigation assistant for blind and low-vision people. Glide uses the phone's
camera and on-device AI to warn about obstacles, read pedestrian signals and read
text aloud, through voice and vibration. Everything runs on the phone, so it works
anywhere in the world, offline, without pre-mapped locations.

> **Status:** project foundation (Milestone 0) is complete. Camera, detection and
> navigation screens are placeholders until their milestones land. See
> [docs/tasks.md](docs/tasks.md).

## Requirements

| Tool | Version |
|---|---|
| Flutter | 3.44.1 stable (Dart 3.12) |
| Android | Android Studio, SDK 35, JDK 17; devices on Android 8.0+ (API 26) |
| iOS | macOS with Xcode 16+, CocoaPods; devices on iOS 15.5+ |

iOS needs 15.5 rather than 13.0 because Google ML Kit (text recognition) requires it.

## Setup

```bash
git clone <repo-url> glide
cd glide
flutter pub get        # also generates lib/l10n/app_localizations*.dart
flutter run            # on a connected phone; the camera needs a real device
```

On iOS, the first build runs `pod install` automatically. If it doesn't:

```bash
cd ios && pod install && cd ..
```

## Everyday commands

```bash
flutter analyze                                   # must be clean
flutter test                                      # unit + widget tests
flutter test --coverage && bash tool/check_coverage.sh 80
flutter test integration_test                     # needs a device or emulator
dart format lib test integration_test
flutter gen-l10n                                  # after editing ARB files
```

## Project layout

```
lib/
├── main.dart, app.dart     bootstrap, MaterialApp.router, theme, l10n
├── core/                   constants, DI (get_it), router (go_router), themes, widgets
├── features/
│   ├── detection/          obstacles + crossing   (domain / data / presentation)
│   ├── text_reader/        OCR + read aloud
│   ├── navigation/         saved places + spoken compass guidance
│   ├── settings/           user preferences (complete example of every layer)
│   └── home/
├── services/               one wrapper per plugin, each behind an interface
│   ├── ai/                 TFLite object detector, ML Kit text recognition
│   ├── camera/  tts/  haptic/  location/  sensors/  permissions/
└── l10n/                   ARB files (English)
```

`features/settings` is the reference implementation: entity → repository interface
→ use cases → repository implementation → Cubit → page, with tests at each level.
Copy its shape for new features. Details are in [docs/architecture.md](docs/architecture.md).

## Docs

- [Requirements](docs/requirements.md): user stories, acceptance criteria, non-functional requirements
- [Architecture](docs/architecture.md): decisions, layers, data flow, privacy
- [Tasks](docs/tasks.md): milestones
- [Contributing](CONTRIBUTING.md): rules for code, tests and pull requests
- [Release](docs/release.md): signing, store setup, secrets
- [Privacy policy (draft)](docs/privacy-policy.md)

## CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`:
formatting, `flutter analyze --fatal-infos`, tests with an 80% coverage gate, a
release-mode Android APK, and an unsigned iOS build.

`.github/workflows/release.yml` runs on `v*` tags and uploads to the Play internal
track and TestFlight once the store accounts and secrets exist. See
[docs/release.md](docs/release.md).

## Adding the detection model

Put `detector.tflite` and `labels.txt` in `assets/models/` (see the README there).
Until then, `TfliteObjectDetector.load()` throws a `ModelLoadException`, and the app
handles it.
