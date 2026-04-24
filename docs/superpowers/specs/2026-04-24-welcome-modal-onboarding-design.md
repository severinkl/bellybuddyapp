# Welcome Modal — Onboarding Guide Introduction

**Date:** 2026-04-24
**Status:** Approved

## Goal

Show a one-time welcome modal on first dashboard visit that introduces Belly Buddy's purpose and frames the onboarding guide. The modal is the first stage of the tutorial — sequenced immediately before the existing spotlight tour — and is gated by the same `profile.tutorialSeenAt == null` check.

## Copy

German, exactly:

**Title:** `Willkommen bei Belly Buddy!`

**Body (two paragraphs):**

> Finde heraus, welche Lebensmittel deine Verdauungsprobleme auslösen – und was dir wirklich guttut.
>
> Tracke dein Essen und dein Wohlbefinden regelmäßig, erhalte persönliches Feedback und entdecke passende Alternativen. So verstehst du deinen Körper besser und triffst im Alltag leichter die richtigen Entscheidungen 💛

**CTA:** `Los geht's`

## UX

- **Trigger:** `dashboard_screen.dart:_maybeShowTutorial()` — same gate as the spotlight (`TutorialNotifier.shouldShow()` → `tutorialSeenAt == null`).
- **Order on first dashboard visit:**
  1. Welcome modal
  2. Spotlight tour (existing)
  3. Notification opt-in modal (existing; separate `SharedPreferences` gate)
- **Single CTA**, no close icon. `barrierDismissible: false`. Tapping `Los geht's` dismisses the modal and immediately triggers the existing spotlight.
- **Persistence:** none of its own. Rides on `tutorialSeenAt` via the existing `TutorialNotifier.markSeen()`, which fires after the spotlight completes or is skipped. If the app is killed between the welcome modal and the spotlight, the user sees the welcome modal again next time — deliberate (the spotlight didn't complete, so the tutorial isn't "seen" yet).

## Layout

Matches `notification_opt_in_dialog.dart` for visual consistency:

- `AlertDialog`, `RoundedRectangleBorder(radius: AppConstants.radiusLg)`.
- `contentPadding: AppConstants.paddingLg`.
- Column (mainAxisSize.min):
  - `MascotImage(assetPath: AppConstants.mascotHappy, width/height: AppConstants.mascotSizeMd)`.
  - `AppConstants.gap16`.
  - Title `Text` — `fontSize: AppTheme.fontSizeTitle, fontWeight: w600`, centered.
  - `AppConstants.gap12`.
  - Body `Text` — two paragraphs via `\n\n`, `fontSize: AppTheme.fontSizeBody`, centered.
  - `AppConstants.gap24`.
  - `ElevatedButton` full-width, `height: AppConstants.buttonHeight`, `backgroundColor: AppTheme.primary`, `foregroundColor: Colors.white`, `radius: AppConstants.radiusMd`, label `Los geht's`.

No close icon, no `Align(topRight)` block (the notifications modal's X is there because "opt out" is a legitimate choice; welcome is purely informational).

## Files

**New:**
- `lib/screens/dashboard/widgets/welcome_modal.dart` — stateless widget + `Future<void> showWelcomeModal(BuildContext)` helper.
- `test/screens/dashboard/widgets/welcome_modal_test.dart` — one widget test: renders title + body substring, tapping `Los geht's` resolves the future.

**Modified:**
- `lib/screens/dashboard/dashboard_screen.dart` — 2-line insert in `_maybeShowTutorial()`, between the `shouldShow` gate and the spotlight call.

**Untouched:**
- `TutorialNotifier` / `tutorial_provider.dart` — no contract change.
- `NotificationOptInDialog` and its trigger — unchanged.
- `UserProfile` model — no new fields; `tutorialSeenAt` continues to gate.

## Safety analysis

- **Re-show risk:** if the user closes the app after the welcome modal but before the spotlight completes, they see the welcome modal again. Intentional: `tutorialSeenAt` only marks after the *whole* tutorial. The welcome modal is idempotent and stateless on the device side.
- **Notification modal ordering:** unchanged — still fires *after* `_maybeShowTutorial()` awaits its full completion. So: welcome → spotlight → notifications.
- **Mounted checks:** the dashboard's microtask already has a `mounted` guard after `_maybeShowTutorial()`. We add another one inside `_maybeShowTutorial()` between the welcome-modal await and the spotlight call, so a mid-tutorial screen teardown doesn't reach into the spotlight with a dead context.
- **No new permissions, no new dependencies, no backend changes.**

## Out of scope

- Localization (app is single-locale German).
- A/B testing copy — single variant.
- Remote-config-driven copy — copy lives in the widget file.
- Analytics event for "welcome modal shown" — can be added as a follow-up once there's a dashboard for onboarding funnels.

## Testing

1. **Widget test** — `test/screens/dashboard/widgets/welcome_modal_test.dart`: pump a `MaterialApp` + button that calls `showWelcomeModal(ctx)`, tap to open, assert title is visible, assert body substring is visible, tap `Los geht's`, assert the awaited future resolves and the dialog is gone.
2. **Manual smoke** — fresh signup → first dashboard visit shows welcome modal → tap `Los geht's` → spotlight starts → complete or skip spotlight → `tutorialSeenAt` persisted in Supabase → restart app → no modal, no spotlight, no notifications (unless notifications still pending).

## Rollback

Revert the two commits (modal + dashboard wire-up). No persisted state, no migration, no data change.
