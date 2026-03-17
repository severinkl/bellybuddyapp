# Belly Buddy — Developer Guidelines

## Language

The app UI is in **German**. All user-facing strings (labels, errors, placeholders) must be in German.

## Design System

All visual constants live in `lib/config/app_theme.dart`. Spacing, radii, and reusable widgets live in `lib/config/constants.dart`.

### Rules

- **Colors**: All colors must be defined as `static const Color` in `AppTheme`. Never hardcode `Color(0x...)` in widget files. Exceptions: `Colors.white`, `Colors.black`, `Colors.transparent` (Flutter built-ins).
- **Font sizes**: All font sizes must use `AppTheme.fontSize*` constants (e.g. `AppTheme.fontSizeBody`). Never hardcode `fontSize:` numeric literals in widget files.
- **Spacing & radii**: Use `AppConstants` for spacing (`spacingSm`, `gap16`, `paddingMd`) and border radii (`radiusSm`, `radiusMd`, `radiusLg`). Never hardcode padding/margin/radius numeric literals.
- **Adding new values**: If a design requires a new color, font size, or spacing not yet defined, add it to `AppTheme` or `AppConstants` first, then reference it.

## Code Quality

- **Formatting**: Run `dart format` before committing. CI enforces `dart format --set-exit-if-changed`.
- **Analysis**: `flutter analyze` must pass with zero issues (info, warning, and error all fail CI).
- **Code generation**: Freezed/json_serializable models require `dart run build_runner build --delete-conflicting-outputs` after model changes. Generated files (`*.freezed.dart`, `*.g.dart`) are gitignored.
- **Images**: Use `CachedNetworkImage` (not `Image.network`) for all network images. Add shimmer placeholders via the `shimmer` package.

## Architecture

- **State management**: Riverpod (`flutter_riverpod`) with `AsyncNotifier` pattern.
- **Backend**: Supabase (auth, database, storage). Services in `lib/services/` wrap Supabase calls.
- **Routing**: GoRouter with route paths defined in `lib/router/`.
- **Logging**: Use `AppLogger` from `lib/utils/logger.dart` — never use bare `print()`.
