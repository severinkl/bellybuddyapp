# Recommendations Notice Dialog + Feedback URL Swap — Design

**Date:** 2026-06-01
**Status:** Approved (design)

## Summary

Two related changes:

1. Show an informational dialog when the user opens the **Tipps** (recommendations) screen.
   It thanks the user, explains that feedback from the testing phase is currently being
   reviewed and there will be no new recommendations for now, and links to the feedback form.
   The dialog appears **once per app session** (in-memory flag, resets on app restart).
2. Replace the shared feedback form URL with the new survey link. Because the URL lives in a
   single shared constant, the dashboard button, the settings button, and the new dialog all
   point to the new form.

## Motivation

The team is pausing new recommendations while it reviews tester feedback. Users opening the
Tipps screen should understand why no new recommendations appear and be nudged toward the
feedback form. The existing Google Form is being replaced by a Mailchimp survey.

## Scope

### In scope
- New `feedbackFormUrl` value (Mailchimp survey).
- New dialog shown on the recommendations screen, once per app session.
- In-memory session flag (Riverpod provider) to gate the dialog.

### Out of scope
- Persisting "seen" state across app restarts (SharedPreferences/Supabase) — intentionally
  not done; the notice should reappear each session.
- Changing the recommendations data flow. Existing recommendations still load and render
  behind the dialog.
- Any change to the settings-screen feedback button beyond the shared-constant URL update.

## Design

### 1. Feedback URL swap

`lib/config/constants.dart` — update the existing constant:

```dart
static const String feedbackFormUrl =
    'https://us20.list-manage.com/survey?u=526bdf1360ec4bf225504e006&id=d47032793c&attribution=false';
```

This is the single source of truth. Consumers already using it (dashboard header button,
settings screen feedback button) automatically pick up the new URL. The new dialog will also
reference this constant.

### 2. The notice dialog

New file: `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart`

Follows the existing modal pattern (`showWelcomeModal()` /
`showNotificationOptInDialog()`): a top-level `Future<void> showRecommendationsNoticeDialog(BuildContext context)`
that calls `showDialog<void>` and builds an `AlertDialog` styled with `AppTheme` / `AppConstants`.

**German copy:**

- **Title:** `Danke, dass du dabei bist! 💛`
- **Body:**
  > Danke, dass du Belly Buddy nutzt! Wir werten gerade das Feedback aus der bisherigen
  > Testphase aus. Deshalb gibt es vorerst keine neuen Empfehlungen.
  >
  > Dein Feedback hilft uns sehr weiter – teile es gerne über unser Formular.
- **Actions:**
  - `Feedback geben` — opens `AppConstants.feedbackFormUrl` via
    `launchUrl(..., mode: LaunchMode.externalApplication)`, then dismisses the dialog.
  - `Schließen` — dismisses the dialog.

Styling rules per CLAUDE.md: colors from `AppTheme`, font sizes from `AppTheme.fontSize*`,
spacing/radii from `AppConstants`. No hardcoded literals.

### 3. "Once per app session" trigger

New Riverpod provider holding an in-memory `bool`, e.g. in
`lib/providers/recommendation_provider.dart` (or a small dedicated file):

```dart
/// Tracks whether the "no new recommendations" notice has been shown this app
/// session. In-memory only — resets on app restart so the notice reappears each
/// session.
final recommendationsNoticeSeenProvider = StateProvider<bool>((ref) => false);
```

Trigger in `RecommendationsScreen` (`lib/screens/recommendations/recommendations_screen.dart`):

- In `initState`, schedule a post-frame callback (mirroring how the dashboard triggers its
  modals).
- In the callback: if `ref.read(recommendationsNoticeSeenProvider)` is `false`, set it to
  `true` and call `showRecommendationsNoticeDialog(context)`.
- Guard with `mounted` before using `context`.

This shows the dialog the first time the recommendations screen is opened in a given app
session and not again until the app is restarted.

## Files touched

- `lib/config/constants.dart` — update `feedbackFormUrl`.
- `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart` — new dialog.
- `lib/providers/recommendation_provider.dart` — new `recommendationsNoticeSeenProvider`.
- `lib/screens/recommendations/recommendations_screen.dart` — trigger in `initState`.

## Testing

- Widget test: `showRecommendationsNoticeDialog` renders title, body, and both action buttons;
  tapping `Schließen` dismisses it.
- Provider/trigger test: with `recommendationsNoticeSeenProvider == false`, opening the screen
  flips the flag to `true`; a second open does not re-show (flag already `true`).
- Manual: verify dashboard + settings feedback buttons and the dialog's `Feedback geben` button
  all open the new Mailchimp survey URL.

## Risks / notes

- `launchUrl` for the Mailchimp survey should be verified on a device (external browser).
- The in-memory flag means the notice reappears every cold start — intended behavior.
