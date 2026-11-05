# Releasing Glide

Releases are built by [.github/workflows/release.yml](../.github/workflows/release.yml)
when a tag like `v0.2.0` is pushed. It runs the tests, then uploads a signed Android
App Bundle to the **Play internal testing track** and an iOS build to **TestFlight**.
Nothing reaches the public stores without a manual promotion in each console.

> Status: written but not yet run. It needs the accounts and secrets below, and the
> first run should be watched closely.

## Before the first release

1. **Confirm the app ID.** `com.glideapp.glide` is used on both platforms and can't
   change after the first upload.
2. **Confirm the model licence** (see `assets/models/README.md`).
3. **Publish the privacy policy** ([privacy-policy.md](privacy-policy.md)) at a public
   URL. Both stores require one.
4. **Native-speaker review** of every translation other than English. The Spanish
   ARB is a draft.
5. **Test on real phones with TalkBack and VoiceOver**, including blind testers, as
   listed in [tasks.md](tasks.md).
6. Set `version:` in `pubspec.yaml` (e.g. `0.2.0+1`). The build number is overridden
   by the workflow run number, so every upload is unique.

## Android

1. Create an upload key once and keep it safe (losing it means contacting Google):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. In Play Console create the app, enrol in Play App Signing, and complete the
   content rating, data safety form (answers: [privacy-policy.md](privacy-policy.md))
   and target audience sections.
3. Upload the first bundle by hand (Play requires it before the API can upload).
4. Create a Google Cloud service account with the "Release manager" permission
   for this app, and download its JSON key.

For local release builds, create `android/key.properties` (git-ignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

## iOS

1. In App Store Connect create the app with bundle ID `com.glideapp.glide`.
2. Create an Apple Distribution certificate (export as `.p12`) and an App Store
   provisioning profile named **Glide App Store** for that bundle ID.
3. Create an App Store Connect API key (Users and Access → Integrations) with the
   App Manager role.
4. Fill in the App Privacy questions from [privacy-policy.md](privacy-policy.md).

## GitHub secrets

Add these to a GitHub **environment** named `release` (Settings → Environments), so
only the release workflow can read them, and require a reviewer for that environment.

| Secret | What |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | e.g. `upload` |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | the service account JSON, as plain text |
| `IOS_DISTRIBUTION_CERT_P12_BASE64` | `base64 -i cert.p12` |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | `.p12` export password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i Glide_App_Store.mobileprovision` |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APP_STORE_CONNECT_ISSUER_ID` | from the API keys page |
| `APP_STORE_CONNECT_KEY_ID` | from the API keys page |
| `APP_STORE_CONNECT_API_KEY_P8` | contents of the `.p8` file |

## Cutting a release

```bash
git tag v0.2.0
```

```bash
git push origin v0.2.0
```

Then promote the build from internal testing in each console when testers are happy.
