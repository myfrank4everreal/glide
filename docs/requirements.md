# Glide — Requirements (MVP)

Glide is a navigation assistant for blind and low-vision people. It uses the phone's
camera and on-device AI to detect obstacles, crossings and text, and tells the user
about them through voice and vibration. It works anywhere in the world without
pre-mapped locations, because all recognition happens live on the device.

## Users

| Persona | Needs |
|---|---|
| **Primary: blind user** (screen-reader user, cane or guide dog) | Hands-free alerts, no visual UI dependency, works with TalkBack/VoiceOver |
| **Primary: low-vision user** | High contrast, large text and targets, optional visual overlay |
| **Secondary: older adults / mobility-impaired** | Simple controls, early warnings for steps and curbs |

## MVP user stories

Each story lists acceptance criteria (AC). A story is done only when every AC has a
passing automated test or a documented manual test on a real device.

### US-1 Camera and permissions
> As a user, I want Glide to ask for camera access clearly so that I understand why it needs it.

- AC1 On first launch the app explains, by voice and on screen, why camera access is needed before the OS prompt.
- AC2 If permission is denied, the app announces it and offers a single button that opens system settings.
- AC3 The camera preview starts within 2 seconds of permission being granted.
- AC4 Camera frames are never written to disk or sent over the network.

### US-2 Obstacle detection
> As a blind user walking outdoors, I want to be warned about obstacles in my path so that I can avoid them.

- AC1 Detects at least: person, pole, bench, trash can, bicycle, car, stairs, curb (classes depend on the shipped model; see architecture.md).
- AC2 Only detections with confidence ≥ the configured threshold (default 0.6) produce alerts.
- AC3 Each alert includes object type, rough direction (left / ahead / right) and estimated distance band (close < 1 m, near 1–3 m, far > 3 m).
- AC4 The same object is not announced again within the cooldown window (default 3 s) unless it moves into a closer band.
- AC5 Frame processing is ≤ 30 ms on the reference device (Pixel 6 / iPhone 12); frames are skipped when the detector is busy.

### US-3 Haptic and voice alerts
> As a user, I want alerts I can feel and hear so that I can react even in noisy streets.

- AC1 Each distance band has a distinct vibration pattern (close = rapid, near = double, far = single).
- AC2 Voice alerts can be turned off independently of haptics, and vice versa.
- AC3 A new close-band alert interrupts any voice alert in progress.
- AC4 Speech rate and vibration intensity are adjustable in settings.

### US-4 Street crossing assistance
> As a user at a crossing, I want to know the pedestrian signal state so that I can decide when to cross.

- AC1 Detects pedestrian signal state as walk, don't walk, or unknown.
- AC2 When the state is unknown or confidence is low, the app says "signal unclear" and never says it is safe.
- AC3 A state change is announced within 1 second.
- AC4 The app shows and speaks a disclaimer the first time: Glide assists and does not replace a cane, guide dog, or judgement.

### US-5 Read text aloud
> As a user, I want to point my phone at a sign or document and hear what it says.

- AC1 A single large button (and a double-tap gesture) captures one frame and reads recognised text aloud.
- AC2 Text is read in reading order (top to bottom, left to right for LTR scripts).
- AC3 If no text is found, the app says "No text found" within 2 seconds.
- AC4 Works offline using on-device recognition.

### US-6 Outdoor GPS navigation
> As a user, I want simple spoken directions to a destination.

- AC1 The user can set a destination by searching for an address or choosing a saved place.
- AC2 Spoken guidance gives direction relative to the user's heading ("turn left", "continue straight, 120 metres").
- AC3 Arrival is announced within 15 m of the destination.
- AC4 Losing GPS signal is announced; guidance resumes automatically.
- AC5 Obstacle detection keeps running during navigation.

### US-7 Settings
> As a user, I want to adjust voice, vibration and language.

- AC1 Settings: speech rate, voice on/off, haptic intensity, haptics on/off, language, detection sensitivity.
- AC2 Changes apply immediately and persist across restarts.
- AC3 "Delete my data" removes all locally stored data (GDPR).

### US-8 Onboarding
> As a new user, I want a short spoken tutorial.

- AC1 Onboarding is fully usable with a screen reader and can be skipped.
- AC2 It demonstrates each vibration pattern.
- AC3 It shows the safety disclaimer.

### US-9 Freemium
> As a user, I want the core safety features free.

- AC1 Obstacle detection, crossing assistance, text reading and basic navigation are free with no limits.
- AC2 Premium features (Phase 2+: indoor navigation, route learning) are clearly labelled; no paywall interrupts a safety alert.

## Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Inference ≤ 30 ms/frame on reference devices; cold start ≤ 3 s; UI at 60 fps |
| Battery | ≤ 15% per hour of continuous detection on reference devices (frame skipping, quantized model) |
| Offline | Detection, crossing, text reading and TTS work with no network |
| Accessibility | WCAG 2.1 AA where applicable; touch targets ≥ 48×48 dp; every control has a semantic label; supports TalkBack, VoiceOver, system font scaling up to 200%, high contrast |
| Privacy | No camera frames stored or transmitted; location kept in memory only during navigation, except places the user saves; local data encrypted |
| Platforms | Android 8.0+ (API 26), target API 34+; iOS 15.5+ (see architecture.md for why not 13.0) |
| Localisation | English at launch; ARB structure ready for es-419, zh-Hans, yue (zh-Hant-HK), fr, ar (RTL) |
| Quality | ≥ 80% line coverage on `lib/` excluding generated code; zero analyzer warnings |

## Out of scope for MVP (Phase 2+)

Indoor navigation, QR-code positioning, route learning, community venue maps,
cloud sync, user accounts, wearables.
