# App Display Name → "Belly Buddy" — Design

**Date:** 2026-04-24
**Status:** Approved
**Branch:** `feat/app-display-name-belly-buddy` → PR against `develop`

## Goal

On Android, the launcher shows `belly_buddy`. It should read `Belly Buddy`. On iOS the home-screen label is already correct (`CFBundleDisplayName = Belly Buddy`), but the internal short name (`CFBundleName`) still reads `belly_buddy` and surfaces in Settings → General → iPhone Storage, Spotlight fallback, and similar contexts. Harmonize both.

## Changes (2 files, 2 lines)

### Android

`android/app/src/main/AndroidManifest.xml:9`

```xml
android:label="belly_buddy"  →  android:label="Belly Buddy"
```

### iOS

`ios/Runner/Info.plist:18`

```xml
<string>belly_buddy</string>  →  <string>Belly Buddy</string>
```

(inside the `<key>CFBundleName</key>` pair — `CFBundleDisplayName` is already `Belly Buddy`).

## What this does NOT change

- **`pubspec.yaml:1 name: belly_buddy`** — Dart package identifier; must stay snake_case (Dart convention). Not user-visible.
- **`android/app/build.gradle.kts applicationId = com.bellybuddy.belly_buddy`** — Android package / bundle ID. Permission, Firebase, Play Console, and deep-link registration all key off this. Unchanged.
- **`ios/Runner/Info.plist CFBundleIdentifier` (`com.bellybuddy.belly_buddy`)** — iOS bundle ID. APNs, App Store Connect, TestFlight, entitlements all key off this. Unchanged.
- **`NS*UsageDescription` strings (camera, notifications, etc.)** — German sentences shown in permission prompts. Not the app name, not touched.
- **Play Console / App Store Connect listing names** — separate UI-side fields in the respective consoles. Out of scope; the code change does not propagate into store metadata.

## Considered and rejected

**Android `@string/app_name` via `res/values/strings.xml`.** Idiomatic Android pattern; enables per-locale overrides via `res/values-xx/strings.xml`. Rejected because the app is currently single-locale (German). Two-line inline change is simpler; migrate to a string resource only if a second locale is added.

## Safety analysis (permissions, notifications, etc.)

- **Permissions** (camera, notifications, photos, mic, push): all keyed to bundle/package ID. Unchanged.
- **Push notifications**: APNs topic / FCM registration keyed to bundle/package ID. Unchanged.
- **Permission-prompt text on iOS**: already reads `CFBundleDisplayName = Belly Buddy`. No observable change; this PR just makes the fallback (`CFBundleName`) match.
- **Google Services / `google-services.json`**: package-scoped. Unchanged.
- **Intent filters, deep links, `launchMode`, `taskAffinity`**: package-scoped. Unchanged.

No regression surface.

## Verification

| Check | Command | Expected |
|---|---|---|
| Dart unchanged | `flutter analyze` | No issues found |
| Format | `dart format --set-exit-if-changed .` | Clean |
| Tests | `flutter test` | All pass (baseline 649) |
| Manifest parses | `flutter build apk --debug --dart-define-from-file=env.json` | Build succeeds |
| Info.plist parses | `flutter build ios --debug --dart-define-from-file=env.json --no-codesign` | Build succeeds |

**Observational post-install (manual, not CI):**
- Android: install APK → launcher icon reads "Belly Buddy".
- iOS: install IPA → home-screen already read "Belly Buddy"; Settings → General → iPhone Storage now reads "Belly Buddy" instead of "belly_buddy".

## Rollback

Revert the two lines. No persisted state, no migration, no database change.

## Files touched

- `android/app/src/main/AndroidManifest.xml` — 1 line
- `ios/Runner/Info.plist` — 1 line
