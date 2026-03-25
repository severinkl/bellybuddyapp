# Belly Buddy

Dein Bauchgefühl Tracker — a digestive health tracking app for people with food intolerances and digestive issues.

## Features

- **Meal Tracker** — Log meals with ingredient search and photo capture
- **Drink Tracker** — Track beverages with size selection and custom drinks
- **Toilet Tracker** — Record bathroom patterns
- **Gut Feeling Tracker** — Monitor digestive comfort and mood
- **Diary** — Browse and edit all tracked entries by date
- **Ingredient Suggestions** — Smart alerts when a tracked ingredient may be causing issues
- **Recommendations** — Personalized dietary recommendations based on your tracking data
- **Recipes** — Recipe database filtered by your intolerances and diet
- **User Profile** — Gender, age, height/weight, intolerances, diet type, symptoms

## Tech Stack

- **Flutter** (SDK ^3.11.1)
- **Supabase** — Backend, auth, storage
- **Riverpod** — State management
- **GoRouter** — Navigation
- **Freezed + json_serializable** — Immutable models with code generation
- **Google & Apple Sign-In** — Social auth
- **CachedNetworkImage + Shimmer** — Image caching and loading placeholders

## Getting Started

### Prerequisites

- Flutter SDK ^3.11.1
- A Supabase project with the required tables

### Setup

```bash
# Install dependencies
flutter pub get

# Create env file and fill in your credentials
cp env.example.json env.json
# Edit env.json with real values (Supabase, Firebase, Google OAuth)

# Copy native Firebase config files (obtain from Firebase Console or team)
cp android/app/google-services.example.json android/app/google-services.json
cp ios/Runner/GoogleService-Info.example.plist ios/Runner/GoogleService-Info.plist
# Edit both with real Firebase values

# Run code generation (required before build/test)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run --dart-define-from-file=env.json
```

> **Note:** All `flutter run`, `flutter build`, and `flutter test` commands require `--dart-define-from-file=env.json`. Add it to your IDE run configuration to avoid forgetting.

### Environment Variables

Configured in `env.json` (gitignored). See `env.example.json` for the template.

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Your Supabase anonymous key |
| `GOOGLE_WEB_CLIENT_ID` | Google OAuth web client ID |
| `GOOGLE_IOS_CLIENT_ID` | Google OAuth iOS client ID |
| `FIREBASE_ANDROID_API_KEY` | Firebase API key (Android) |
| `FIREBASE_ANDROID_APP_ID` | Firebase app ID (Android) |
| `FIREBASE_IOS_API_KEY` | Firebase API key (iOS) |
| `FIREBASE_IOS_APP_ID` | Firebase app ID (iOS) |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase Cloud Messaging sender ID |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_STORAGE_BUCKET` | Firebase storage bucket |
| `FIREBASE_IOS_BUNDLE_ID` | iOS bundle identifier |

## Project Structure

```
lib/
├── config/       # Design system (AppTheme), constants, Supabase config
├── models/       # Data models (Freezed + JSON serialization)
├── providers/    # Riverpod state management
├── router/       # GoRouter navigation
├── screens/      # UI screens organized by feature
├── services/     # Backend services (auth, CRUD, storage)
├── utils/        # Helpers (logging, date formatting, signed URLs)
└── widgets/      # Reusable UI components
```

## Design System

`lib/config/app_theme.dart` is the single source of truth for colors and typography. All color values and font sizes are defined as constants in `AppTheme` — widget files reference these constants instead of hardcoding values.

## Pre-commit Hook

A pre-commit hook runs `dart format` and `flutter analyze` before each commit to catch issues locally:

```bash
# Install the hook (one-time setup)
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## CI/CD

### CI — feature branches & PRs ([`.github/workflows/ci.yml`](.github/workflows/ci.yml))

Runs two parallel jobs:

1. **Format & Analyze** — `dart format` + `flutter analyze`
2. **Unit Tests** — `flutter test`

### Deploy — push to main ([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml))

Runs format + test checks, then deploys in parallel:

- **Android** — Signed AAB → Google Play Internal Testing
- **iOS** — Signed IPA → TestFlight
