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

# Create env file and fill in your Supabase credentials
cp .env.example .env

# Run code generation (required before build/test)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Environment Variables

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Your Supabase anonymous key |

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

## CI

Runs on push to `main` and pull requests ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)):

1. Code generation (`build_runner`)
2. Format check (`dart format`)
3. Static analysis (`flutter analyze`)
4. Tests (`flutter test`)
5. Debug APK build
