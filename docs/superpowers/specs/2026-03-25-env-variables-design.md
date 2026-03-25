# Move Hardcoded Credentials to Environment Variables via `--dart-define`

**Date:** 2026-03-25
**Status:** Approved

## Problem

Several credentials are hardcoded in source files:

- Google OAuth client IDs in `lib/services/auth_service.dart`
- Firebase config in `lib/firebase_options.dart`
- Native Firebase config files committed to git (`google-services.json`, `GoogleService-Info.plist`)

Supabase credentials are already env-var'd via `flutter_dotenv`, but this approach uses runtime loading. We want a unified compile-time approach.

## Approach

Use `--dart-define-from-file` with a JSON config file. All values become compile-time constants via `String.fromEnvironment()`. Remove `flutter_dotenv` entirely.

## Section 1: Local Config File

Replace `.env` with `env.json`:

```json
{
  "SUPABASE_URL": "https://sktsjihzrciyhyhlkgjt.supabase.co",
  "SUPABASE_ANON_KEY": "<anon-key>",
  "GOOGLE_WEB_CLIENT_ID": "<web-client-id>.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "<ios-client-id>.apps.googleusercontent.com",
  "FIREBASE_ANDROID_API_KEY": "<android-api-key>",
  "FIREBASE_ANDROID_APP_ID": "<android-app-id>",
  "FIREBASE_IOS_API_KEY": "<ios-api-key>",
  "FIREBASE_IOS_APP_ID": "<ios-app-id>",
  "FIREBASE_MESSAGING_SENDER_ID": "<sender-id>",
  "FIREBASE_PROJECT_ID": "<project-id>",
  "FIREBASE_STORAGE_BUCKET": "<project-id>.firebasestorage.app",
  "FIREBASE_IOS_BUNDLE_ID": "com.bellybuddy.bellyBuddy"
}
```

- `env.json` is gitignored
- `env.example.json` is committed with placeholder values
- `.env` and `flutter_dotenv` are removed

## Section 2: Dart Config Classes

All values read via `const String.fromEnvironment('KEY')`.

### `lib/config/supabase_config.dart` (modified)

```dart
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```

### `lib/config/firebase_config.dart` (new)

```dart
class FirebaseConfig {
  static const String androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
}
```

### `lib/config/oauth_config.dart` (new)

```dart
class OAuthConfig {
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
}
```

### `lib/firebase_options.dart` (modified)

Replace hardcoded `const FirebaseOptions` with values from `FirebaseConfig`:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'config/firebase_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // ... same platform switch ...
  }

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: FirebaseConfig.androidApiKey,
    appId: FirebaseConfig.androidAppId,
    messagingSenderId: FirebaseConfig.messagingSenderId,
    projectId: FirebaseConfig.projectId,
    storageBucket: FirebaseConfig.storageBucket,
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: FirebaseConfig.iosApiKey,
    appId: FirebaseConfig.iosAppId,
    messagingSenderId: FirebaseConfig.messagingSenderId,
    projectId: FirebaseConfig.projectId,
    storageBucket: FirebaseConfig.storageBucket,
    iosBundleId: FirebaseConfig.iosBundleId,
  );
}
```

Note: `android` and `ios` change from `static const` to `static get` since `String.fromEnvironment` values cannot be used in `const` constructors.

### Other Dart changes

- `lib/services/auth_service.dart` — reference `OAuthConfig` instead of hardcoded strings
- `lib/main.dart` — remove `dotenv.load()` call and `flutter_dotenv` import (no replacement needed — `String.fromEnvironment` is compile-time)
- `pubspec.yaml` — remove `flutter_dotenv` dependency **and** remove `.env` from the `flutter: assets:` section (line 89)

### Runtime validation

`String.fromEnvironment` silently returns `''` when a key is missing (e.g. developer forgets `--dart-define-from-file`). Add a startup check in `main.dart` using `throw` (not `assert`, which is stripped in release builds):

```dart
void _validateEnv() {
  final missing = <String>[];
  if (SupabaseConfig.url.isEmpty) missing.add('SUPABASE_URL');
  if (SupabaseConfig.anonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
  if (FirebaseConfig.projectId.isEmpty) missing.add('FIREBASE_PROJECT_ID');
  if (missing.isNotEmpty) {
    throw StateError(
      'Missing env vars: ${missing.join(', ')}. '
      'Did you forget --dart-define-from-file=env.json?',
    );
  }
}
```

Call `_validateEnv()` early in `main()` to fail fast with a clear message.

## Section 3: Native Firebase Config Files

Native SDKs consume `google-services.json` and `GoogleService-Info.plist` at build time — these can't use `--dart-define`.

1. **Gitignore both files**: add `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` to `.gitignore`
2. **Add example files**: `android/app/google-services.example.json` and `ios/Runner/GoogleService-Info.example.plist` with placeholder values
3. **CI injection**: decode from base64 GitHub secrets at build time
4. **Local dev**: developers copy example files and fill in real values (or receive real files via secure channel)

### `ios/Runner/Info.plist` — REVERSED_CLIENT_ID

`Info.plist` line 32 contains a hardcoded reversed Google client ID used as a URL scheme:
```
com.googleusercontent.apps.920554558032-m2curfdn4m6rd346okvaust9ngf3s2ht
```

This is not a secret (it's a public identifier derived from the iOS client ID), but for consistency with gitignoring `GoogleService-Info.plist`, we will leave it as-is. It is required for the Google Sign-In redirect flow and must match the iOS client ID. If the iOS client ID changes, this must be updated manually.

### `.gitignore` changes

Replace the current `.env` patterns:
```
# Before
.env
.env.*
!.env.example

# After
env.json
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

## Section 4: CI/CD Changes (`deploy.yml`)

### Quality & test jobs

`flutter analyze` does not need `--dart-define-from-file` (static analysis only). `flutter test` does — without it, all `String.fromEnvironment` values resolve to empty strings.

```yaml
- name: Create env.json
  run: cp env.example.json env.json

- run: flutter analyze

- run: flutter test --dart-define-from-file=env.json
```

### Deploy Android job

```yaml
- name: Create env.json
  run: echo "${{ secrets.ENV_JSON_BASE64 }}" | base64 --decode > env.json

- name: Create google-services.json
  run: echo "${{ secrets.GOOGLE_SERVICES_JSON_BASE64 }}" | base64 --decode > android/app/google-services.json

- name: Build AAB
  run: flutter build appbundle --release --dart-define-from-file=env.json --build-number=${{ github.run_number }}
```

### Deploy iOS job

```yaml
- name: Create env.json
  run: echo "${{ secrets.ENV_JSON_BASE64 }}" | base64 --decode > env.json

- name: Create GoogleService-Info.plist
  run: echo "${{ secrets.GOOGLE_SERVICE_INFO_PLIST_BASE64 }}" | base64 --decode > ios/Runner/GoogleService-Info.plist

- name: Build IPA
  run: flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }}
```

### New GitHub secrets

| Secret | Content |
|---|---|
| `ENV_JSON_BASE64` | base64-encoded `env.json` with real values |
| `GOOGLE_SERVICES_JSON_BASE64` | base64-encoded `google-services.json` |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | base64-encoded `GoogleService-Info.plist` |

### Secrets to remove after migration

| Secret | Reason |
|---|---|
| `ENV_FILE` | Replaced by `ENV_JSON_BASE64` |

## Local Development

Every `flutter run`, `flutter build`, and `flutter test` command now requires `--dart-define-from-file=env.json`. To avoid forgetting:

- **VS Code**: add `"args": ["--dart-define-from-file=env.json"]` to `.vscode/launch.json`
- **Android Studio**: add `--dart-define-from-file=env.json` to Run Configuration → Additional run args
- **CLI**: consider a Makefile or shell alias

## Files Changed

| File | Action |
|---|---|
| `env.example.json` | Create (committed, placeholder values) |
| `env.json` | Create (gitignored, real values) |
| `.env` | Delete |
| `.env.example` | Delete |
| `.gitignore` | Update (swap `.env` patterns for `env.json`, add native config files) |
| `lib/config/supabase_config.dart` | Modify (use `String.fromEnvironment`) |
| `lib/config/firebase_config.dart` | Create |
| `lib/config/oauth_config.dart` | Create |
| `lib/firebase_options.dart` | Modify (use `FirebaseConfig`, `const` → getter) |
| `lib/services/auth_service.dart` | Modify (use `OAuthConfig`) |
| `lib/main.dart` | Modify (remove dotenv, add `_validateEnv()`) |
| `pubspec.yaml` | Modify (remove `flutter_dotenv` dep **and** `.env` from assets) |
| `android/app/google-services.json` | Gitignore |
| `android/app/google-services.example.json` | Create |
| `ios/Runner/GoogleService-Info.plist` | Gitignore |
| `ios/Runner/GoogleService-Info.example.plist` | Create |
| `.github/workflows/deploy.yml` | Modify (inject secrets, add `--dart-define-from-file`) |
| `.github/workflows/ci.yml` | Modify (add `--dart-define-from-file` to test) |
