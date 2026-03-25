# Migrate Credentials to `--dart-define` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all hardcoded credentials (Google OAuth, Firebase, Supabase) to compile-time environment variables via `--dart-define-from-file`, remove `flutter_dotenv`, and inject native Firebase config files via CI secrets.

**Architecture:** Replace runtime `.env` loading (`flutter_dotenv`) with `--dart-define-from-file=env.json`. All Dart config values become compile-time constants via `String.fromEnvironment()`. Native Firebase files (`google-services.json`, `GoogleService-Info.plist`) are gitignored and injected from base64-encoded GitHub secrets during CI builds.

**Tech Stack:** Flutter `--dart-define-from-file`, `String.fromEnvironment()`, GitHub Actions secrets

**Spec:** `docs/superpowers/specs/2026-03-25-env-variables-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `env.example.json` | Create | Committed template with placeholder values |
| `lib/config/supabase_config.dart` | Modify | Supabase URL/key via `String.fromEnvironment` |
| `lib/config/firebase_config.dart` | Create | Firebase config via `String.fromEnvironment` |
| `lib/config/oauth_config.dart` | Create | Google OAuth client IDs via `String.fromEnvironment` |
| `lib/firebase_options.dart` | Modify | Reference `FirebaseConfig` instead of hardcoded strings |
| `lib/services/auth_service.dart` | Modify | Reference `OAuthConfig` instead of hardcoded strings |
| `lib/main.dart` | Modify | Remove dotenv, add `_validateEnv()` |
| `pubspec.yaml` | Modify | Remove `flutter_dotenv` dep and `.env` asset |
| `.gitignore` | Modify | Swap `.env` → `env.json`, add native config files |
| `android/app/google-services.example.json` | Create | Placeholder native Android Firebase config |
| `ios/Runner/GoogleService-Info.example.plist` | Create | Placeholder native iOS Firebase config |
| `.github/workflows/ci.yml` | Modify | Use `env.example.json`, add `--dart-define-from-file` to test |
| `.github/workflows/deploy.yml` | Modify | Inject secrets, add `--dart-define-from-file` to builds |

---

### Task 1: Create `env.example.json` and update `.gitignore`

**Files:**
- Create: `env.example.json`
- Modify: `.gitignore:52-55`

- [ ] **Step 1: Create `env.example.json` with placeholder values**

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-supabase-anon-key",
  "GOOGLE_WEB_CLIENT_ID": "your-web-client-id.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "your-ios-client-id.apps.googleusercontent.com",
  "FIREBASE_ANDROID_API_KEY": "your-android-api-key",
  "FIREBASE_ANDROID_APP_ID": "your-android-app-id",
  "FIREBASE_IOS_API_KEY": "your-ios-api-key",
  "FIREBASE_IOS_APP_ID": "your-ios-app-id",
  "FIREBASE_MESSAGING_SENDER_ID": "your-sender-id",
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_STORAGE_BUCKET": "your-project-id.firebasestorage.app",
  "FIREBASE_IOS_BUNDLE_ID": "com.bellybuddy.bellyBuddy"
}
```

- [ ] **Step 2: Update `.gitignore` — replace `.env` patterns with new entries**

Replace lines 52-55:
```
# Environment variables
.env
.env.*
!.env.example
```

With:
```
# Environment variables
env.json

# Native Firebase config (injected via CI secrets)
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

- [ ] **Step 3: Commit**

```bash
git add env.example.json .gitignore
git commit -m "chore: add env.example.json and update gitignore for dart-define migration"
```

---

### Task 2: Create config classes (`FirebaseConfig`, `OAuthConfig`)

**Files:**
- Create: `lib/config/firebase_config.dart`
- Create: `lib/config/oauth_config.dart`

- [ ] **Step 1: Create `lib/config/firebase_config.dart`**

```dart
class FirebaseConfig {
  static const String androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String iosApiKey =
      String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String iosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
}
```

- [ ] **Step 2: Create `lib/config/oauth_config.dart`**

```dart
class OAuthConfig {
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
}
```

- [ ] **Step 3: Run `flutter analyze --dart-define-from-file=env.json`**

Run: `flutter analyze`
Expected: No issues (new files have no dependents yet)

- [ ] **Step 4: Commit**

```bash
git add lib/config/firebase_config.dart lib/config/oauth_config.dart
git commit -m "feat: add FirebaseConfig and OAuthConfig classes using String.fromEnvironment"
```

---

### Task 3: Migrate `supabase_config.dart` from dotenv to `String.fromEnvironment`

**Files:**
- Modify: `lib/config/supabase_config.dart`

- [ ] **Step 1: Rewrite `lib/config/supabase_config.dart`**

Replace the entire file contents with:

```dart
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```

This removes the `flutter_dotenv` import and changes from runtime getters to compile-time constants.

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues (the `flutter_dotenv` import is removed from this file; `main.dart` still imports it so the package is still resolvable)

- [ ] **Step 3: Commit**

```bash
git add lib/config/supabase_config.dart
git commit -m "refactor: migrate SupabaseConfig from dotenv to String.fromEnvironment"
```

---

### Task 4: Update `firebase_options.dart` to use `FirebaseConfig`

**Files:**
- Modify: `lib/firebase_options.dart`

- [ ] **Step 1: Rewrite `lib/firebase_options.dart`**

Replace the entire file with:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'config/firebase_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
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

Key changes: `static const FirebaseOptions android` → `static FirebaseOptions get android` (getters instead of const, since `String.fromEnvironment` can't be used in const constructors).

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/firebase_options.dart
git commit -m "refactor: migrate firebase_options.dart to use FirebaseConfig env vars"
```

---

### Task 5: Update `auth_service.dart` to use `OAuthConfig`

**Files:**
- Modify: `lib/services/auth_service.dart:61-65`

- [ ] **Step 1: Replace hardcoded client IDs in `signInWithGoogle()`**

In `lib/services/auth_service.dart`, add import at top of file:
```dart
import '../config/oauth_config.dart';
```

Then replace lines 62-65:
```dart
    const webClientId =
        '920554558032-3ca7aekg9ucfmek8cgrmtbmq86fsqjut.apps.googleusercontent.com';
    const iosClientId =
        '920554558032-m2curfdn4m6rd346okvaust9ngf3s2ht.apps.googleusercontent.com';
```

With:
```dart
    const webClientId = OAuthConfig.googleWebClientId;
    const iosClientId = OAuthConfig.googleIosClientId;
```

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "refactor: migrate auth_service.dart to use OAuthConfig env vars"
```

---

### Task 6: Remove `flutter_dotenv` and add `_validateEnv()` in `main.dart`

**Files:**
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml:24-25,88-89`

- [ ] **Step 1: Update `lib/main.dart`**

Remove the `flutter_dotenv` import (line 4):
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
```

Add new imports:
```dart
import 'config/firebase_config.dart';
```

Remove the dotenv.load() call (lines 28-29):
```dart
  // Load environment variables
  await dotenv.load(fileName: '.env');
```

Add `_validateEnv()` function at the bottom of the file:
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

Call `_validateEnv()` at the start of `main()`, after `WidgetsFlutterBinding.ensureInitialized()`:
```dart
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  _validateEnv();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
```

- [ ] **Step 2: Remove `flutter_dotenv` from `pubspec.yaml`**

Remove lines 24-25:
```yaml
  # Environment
  flutter_dotenv: ^6.0.0
```

Remove `.env` from the assets section (line 89):
```yaml
    - .env
```

- [ ] **Step 3: Run `flutter pub get` to update lockfile**

Run: `flutter pub get`
Expected: Resolves successfully without `flutter_dotenv`

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 5: Run tests**

Run: `flutter test --dart-define-from-file=env.json`
Expected: All tests pass (tests don't depend on config values directly)

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart pubspec.yaml pubspec.lock
git commit -m "refactor: remove flutter_dotenv, add env validation in main.dart"
```

---

### Task 7: Create native Firebase example files and gitignore originals

**Files:**
- Create: `android/app/google-services.example.json`
- Create: `ios/Runner/GoogleService-Info.example.plist`

- [ ] **Step 1: Create `android/app/google-services.example.json`**

```json
{
  "project_info": {
    "project_number": "YOUR_PROJECT_NUMBER",
    "project_id": "YOUR_PROJECT_ID",
    "storage_bucket": "YOUR_PROJECT_ID.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "YOUR_ANDROID_APP_ID",
        "android_client_info": {
          "package_name": "com.bellybuddy.belly_buddy"
        }
      },
      "oauth_client": [
        {
          "client_id": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
          "client_type": 3
        }
      ],
      "api_key": [
        {
          "current_key": "YOUR_ANDROID_API_KEY"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": [
            {
              "client_id": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
              "client_type": 3
            },
            {
              "client_id": "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com",
              "client_type": 2,
              "ios_info": {
                "bundle_id": "com.bellybuddy.bellyBuddy"
              }
            }
          ]
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

- [ ] **Step 2: Create `ios/Runner/GoogleService-Info.example.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CLIENT_ID</key>
	<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
	<key>REVERSED_CLIENT_ID</key>
	<string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
	<key>API_KEY</key>
	<string>YOUR_IOS_API_KEY</string>
	<key>GCM_SENDER_ID</key>
	<string>YOUR_SENDER_ID</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.bellybuddy.bellyBuddy</string>
	<key>PROJECT_ID</key>
	<string>YOUR_PROJECT_ID</string>
	<key>STORAGE_BUCKET</key>
	<string>YOUR_PROJECT_ID.firebasestorage.app</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
	<key>GOOGLE_APP_ID</key>
	<string>YOUR_IOS_APP_ID</string>
</dict>
</plist>
```

- [ ] **Step 3: Remove originals from git tracking (they're now gitignored)**

```bash
git rm --cached android/app/google-services.json
git rm --cached ios/Runner/GoogleService-Info.plist
```

Note: `--cached` removes from git tracking only; the local files remain for your development use.

- [ ] **Step 4: Commit**

```bash
git add android/app/google-services.example.json ios/Runner/GoogleService-Info.example.plist
git commit -m "chore: gitignore native Firebase configs, add example templates"
```

---

### Task 8: Delete old `.env` and `.env.example` files

**Files:**
- Delete: `.env.example`

- [ ] **Step 1: Remove `.env.example` from git**

```bash
git rm .env.example
```

Note: `.env` is already gitignored so it won't be tracked. The local `.env` file can be deleted manually by developers after they set up `env.json`.

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove .env.example, replaced by env.example.json"
```

---

### Task 9: Update CI workflow (`ci.yml`)

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Update the quality job**

Replace line 27-28:
```yaml
      - name: Create .env
        run: cp .env.example .env
```

With:
```yaml
      - name: Create env.json
        run: cp env.example.json env.json
```

- [ ] **Step 2: Update the test job**

Replace lines 57-58:
```yaml
      - name: Create .env
        run: cp .env.example .env
```

With:
```yaml
      - name: Create env.json
        run: cp env.example.json env.json
```

Replace line 65:
```yaml
      - run: flutter test
```

With:
```yaml
      - run: flutter test --dart-define-from-file=env.json
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: update CI workflow to use env.json and --dart-define-from-file"
```

---

### Task 10: Update deploy workflow (`deploy.yml`)

**Files:**
- Modify: `.github/workflows/deploy.yml`

- [ ] **Step 1: Update deploy.yml quality job (lines 23-24)**

Replace:
```yaml
      - name: Create .env
        run: cp .env.example .env
```

With:
```yaml
      - name: Create env.json
        run: cp env.example.json env.json
```

- [ ] **Step 2: Update deploy.yml test job (lines 46-47, 51)**

Replace:
```yaml
      - name: Create .env
        run: cp .env.example .env
```

With:
```yaml
      - name: Create env.json
        run: cp env.example.json env.json
```

Replace:
```yaml
      - run: flutter test
```

With:
```yaml
      - run: flutter test --dart-define-from-file=env.json
```

- [ ] **Step 3: Update deploy-android job (lines 81-82, 100-101)**

Replace:
```yaml
      - name: Create .env
        run: echo "${{ secrets.ENV_FILE }}" > .env
```

With:
```yaml
      - name: Create env.json
        run: echo "${{ secrets.ENV_JSON_BASE64 }}" | base64 --decode > env.json

      - name: Create google-services.json
        run: echo "${{ secrets.GOOGLE_SERVICES_JSON_BASE64 }}" | base64 --decode > android/app/google-services.json
```

Replace:
```yaml
      - name: Build AAB
        run: flutter build appbundle --release --build-number=${{ github.run_number }}
```

With:
```yaml
      - name: Build AAB
        run: flutter build appbundle --release --dart-define-from-file=env.json --build-number=${{ github.run_number }}
```

- [ ] **Step 4: Update deploy-ios job (lines 133-134, 169-170)**

Replace:
```yaml
      - name: Create .env
        run: echo "${{ secrets.ENV_FILE }}" > .env
```

With:
```yaml
      - name: Create env.json
        run: echo "${{ secrets.ENV_JSON_BASE64 }}" | base64 --decode > env.json

      - name: Create GoogleService-Info.plist
        run: echo "${{ secrets.GOOGLE_SERVICE_INFO_PLIST_BASE64 }}" | base64 --decode > ios/Runner/GoogleService-Info.plist
```

Replace:
```yaml
      - name: Build IPA
        run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }}
```

With:
```yaml
      - name: Build IPA
        run: flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }}
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: update deploy workflow to use env.json, dart-define, and inject native Firebase configs"
```

---

### Task 11: Final verification

- [ ] **Step 1: Create local `env.json` with real values**

Copy `env.example.json` to `env.json` and fill in real values from the existing `.env` file and the hardcoded values that were removed:

```bash
cp env.example.json env.json
```

Then edit `env.json` with the actual values (Supabase URL/key from `.env`, Firebase values from the old `firebase_options.dart`, OAuth IDs from the old `auth_service.dart`).

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 3: Run all tests**

Run: `flutter test --dart-define-from-file=env.json`
Expected: All tests pass

- [ ] **Step 4: Delete the old `.env` file**

```bash
rm .env
```

This file is gitignored so it has no git implications, but should be removed to avoid confusion now that `env.json` is the source of truth.

- [ ] **Step 5: Verify `env.json` is not tracked**

Run: `git status`
Expected: `env.json` does NOT appear in untracked files (it's gitignored)

- [ ] **Step 6: Verify native Firebase files are untracked**

Run: `git status`
Expected: `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` do NOT appear

---

## Post-Implementation: Manual Steps (not automated)

After merging this branch, you need to configure GitHub secrets:

1. **Create `ENV_JSON_BASE64`**: `base64 -i env.json | pbcopy` → paste into GitHub → Settings → Secrets → New repository secret
2. **Create `GOOGLE_SERVICES_JSON_BASE64`**: `base64 -i android/app/google-services.json | pbcopy` → paste
3. **Create `GOOGLE_SERVICE_INFO_PLIST_BASE64`**: `base64 -i ios/Runner/GoogleService-Info.plist | pbcopy` → paste
4. **Remove old secret**: Delete `ENV_FILE` from GitHub secrets
5. **Update IDE config**: Add `--dart-define-from-file=env.json` to VS Code `launch.json` or Android Studio run config
