# Belly Buddy — Developer Guidelines

## Design System

All visual constants live in `lib/config/app_theme.dart`. This is the single source of truth.

### Rules

- **Colors**: All colors must be defined as `static const Color` in `AppTheme`. Never hardcode `Color(0x...)` in widget files. Exceptions: `Colors.white`, `Colors.black`, `Colors.transparent` (Flutter built-ins).
- **Font sizes**: All font sizes must use `AppTheme.fontSize*` constants (e.g. `AppTheme.fontSizeBody`). Never hardcode `fontSize:` numeric literals in widget files.
- **Adding new values**: If a design requires a new color or font size not yet in `AppTheme`, add it there first, then reference it.
