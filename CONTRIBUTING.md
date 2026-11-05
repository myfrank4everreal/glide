# Contributing to Glide

People will rely on Glide to walk safely. Correctness and accessibility come first;
cleverness comes last.

## Workflow

1. Pick a task from [docs/tasks.md](docs/tasks.md) and branch from `main`:
   `feature/m1-camera-preview`, `fix/tts-interrupt`.
2. **Write the test first.** Watch it fail, then write the code.
3. Run locally before pushing:
   ```bash
   dart format lib test integration_test
   flutter analyze
   flutter test --coverage && bash tool/check_coverage.sh 80
   ```
4. Open a pull request. CI must be green. Tick the task in `docs/tasks.md` in the
   same PR once its tests pass.
5. Anything touching the camera, haptics or speech must also be checked on a real
   phone with TalkBack or VoiceOver turned on. Say in the PR which device you used.

## Architecture rules

| Layer | May import | Must not import |
|---|---|---|
| `features/*/domain` | Dart, `equatable`, `core/constants`, `core/geo`, other `domain/` code | Flutter, plugins, `data/`, `presentation/`, `services/` |
| `features/*/data` | its `domain/`, `services/`, storage packages | `presentation/` |
| `features/*/presentation` | its `domain/`, `core/`, `services/` interfaces, `flutter_bloc` | `data/` |
| `services/*` | one plugin each, `core/` | `features/` |

- Every service and repository is an `abstract interface class` plus one
  implementation. Only `lib/core/di/injection.dart` names the implementation.
- Dependencies come in through constructors. No `getIt<…>()` calls inside
  features; the composition root (`injection.dart`, `app.dart`, `app_router.dart`,
  which creates each screen's Cubit) is the only exception.
- State lives in Cubits. Widgets don't call repositories.
- Use `features/settings` as the template for a new feature.

## Tests

| What | Where | Tool |
|---|---|---|
| Entities, use cases | `test/features/<f>/domain` | `flutter_test` |
| Repositories | `test/features/<f>/data` | `mocktail`, fakes |
| Cubits | `test/features/<f>/presentation` | `bloc_test` |
| Pages and widgets | `test/features/<f>/presentation` | widget tests + `meetsGuideline` checks |
| Services | `test/services` | mock the plugin's platform interface |
| Full flows | `integration_test/` | real device |

- Shared fakes live in `test/helpers/fakes.dart`.
- Every new screen gets a test with `androidTapTargetGuideline`,
  `labeledTapTargetGuideline` and, where colours are custom, `textContrastGuideline`.
- Coverage must stay at or above 80% (generated l10n files excluded).

## Accessibility checklist (every UI change)

- [ ] Every control has a label a screen reader reads correctly (no "button, button")
- [ ] Touch targets are at least 48×48 dp
- [ ] Works at 200% system font size without clipping
- [ ] Works in the high-contrast theme
- [ ] Nothing is conveyed by colour alone
- [ ] Safety alerts are never blocked by dialogs, paywalls or animations

## Style

- Follow `analysis_options.yaml`; the analyzer must report no issues.
- Files `snake_case`, types `PascalCase`, members `camelCase`.
- Constants are `lowerCamelCase` (`AppConstants.alertCooldown`), which is the Dart
  convention and what the linter enforces. The original spec asked for
  `SCREAMING_SNAKE_CASE`; we follow Dart instead.
- All user-facing text goes in `lib/l10n/app_en.arb`, and the same key in every
  other ARB (`app_es.arb`). Never hard-code strings that are shown or spoken.
  Translations of safety wording need review by a native speaker.
- Comments explain *why*, not *what*.

## Privacy rules

- Never write camera frames to disk or send them anywhere. A still captured for
  text reading is deleted as soon as it has been processed.
- Never persist location history without a user-facing opt-in.
- Any new local store must be erased by `SettingsRepository.deleteAllUserData()`.
- No analytics or network calls without updating the privacy policy
  ([docs/privacy-policy.md](docs/privacy-policy.md)) first.
- Anything that can stop working mid-walk (camera, detector, GPS) must say so out
  loud. Silence must never look like a clear path.

## Commits

Short imperative subject (`Add camera permission flow`), body explaining why if
it isn't obvious. Reference the milestone task (`M1: …`).
