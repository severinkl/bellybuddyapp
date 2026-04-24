# System-nav SafeArea overlap fix — design

**Date:** 2026-04-24
**Status:** Approved, ready for implementation plan
**Scope:** Two Flutter widgets — tracker scaffold + recommendation dislike sheet

## Problem

On Android 15 (target API 35), Flutter's default rendering is edge-to-edge: the canvas extends under the system nav bar (three-button, gesture, or pill). Screens that place bottom-anchored action buttons at the edge of the body now clip into the nav region.

Affected surfaces (user-confirmed via screenshots):

1. Toilet tracker — `Speichern` button clipped under nav bar.
2. Meal tracker — `Speichern` button clipped under nav bar.
3. Recommendation "Was hat dir nicht gefallen?" bottom sheet — `Fertig` button and `Empfehlung ausblenden` action clipped under nav bar.
4. Mood tracker — `speichern` button clipped under nav bar.
5. Gut-feeling tracker — `weiter` button clipped under nav bar.

Screens 1, 2, 4, 5 all render through `lib/widgets/common/tracker_screen_scaffold.dart`, which places its `body` directly into `Scaffold.body:` with no `SafeArea`. Screen 3 is a `showModalBottomSheet` call that already passes `useSafeArea: true`, but Flutter's implementation of that flag explicitly sets `bottom: false` on its internal `SafeArea` (it covers top/left/right only) — so the sheet's content still needs its own bottom safe-area inset.

## Goal

Stop the overlap on these five surfaces without opting out of Android 15 edge-to-edge and without redesigning button placement.

## Approach

Two one-line wraps. No new widgets, no shared helper, no global config.

### Fix 1 — `lib/widgets/common/tracker_screen_scaffold.dart`

Currently:

```dart
return Scaffold(
  key: trackerKey,
  backgroundColor: AppTheme.screenBackground,
  resizeToAvoidBottomInset: true,
  appBar: AppBar(...),
  body: body,
);
```

Change to:

```dart
return Scaffold(
  key: trackerKey,
  backgroundColor: AppTheme.screenBackground,
  resizeToAvoidBottomInset: true,
  appBar: AppBar(...),
  body: SafeArea(top: false, child: body),
);
```

`top: false` is load-bearing — the `AppBar` already consumes the status-bar inset, and a second SafeArea there would double-pad. Left/right default to `true`, which is a no-op on portrait phones and correctly handles any future landscape orientation.

### Fix 2 — `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart`

The sheet is opened with `useSafeArea: true`, which handles top/left/right. The builder's returned widget needs its own `SafeArea(top: false, ...)` to cover the bottom inset. Wrap the root widget returned by `_RecommendationDislikeSheetState.build(context)` in `SafeArea(top: false, child: ...)`.

Do not remove `useSafeArea: true` from the `showModalBottomSheet` call — it still does useful work for the non-bottom edges.

## Files touched

- `lib/widgets/common/tracker_screen_scaffold.dart` — one-line change inside the returned `Scaffold`.
- `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart` — wrap the state's `build` return in `SafeArea(top: false, ...)`.

## Out of scope

- **Other `showModalBottomSheet` callers** (`meal_title_sheet.dart`, `ingredient_suggestions_screen.dart`, `intolerance_trigger_modal.dart`, `recipe_detail_sheet.dart`, `diary_detail_sheets.dart`, `bb_bottom_sheet.dart`). All have the same latent asymmetry (bottom not covered by `useSafeArea`) but none are reported as overlapping today. Fix identically — one SafeArea wrap inside the builder — if one surfaces.
- **Other full-screen `Scaffold` widgets** (auth, welcome, settings, recipes, dashboard, diary, recommendations, registration wizard, reset password, not-found). Grepped — none use the tracker pattern of a bottom-anchored button at the edge of a scrolling body. Leaving as-is.
- **`BbSuccessOverlay`** (shown by `TrackerScreenScaffold` when `showSuccess: true`). Not reported as overlapping; no change.
- **Promoting save buttons to a pinned action area** (the Material `bottomNavigationBar` / `persistentFooterButtons` pattern). Discussed and declined — that's a UX change, this is a bug fix.
- **Opting out of Android 15 edge-to-edge** via `android:windowOptOutEdgeToEdgeEnforcement="true"`. Declined — Google has signaled that flag will be removed in a future targetSdk, so it's a short-term shortcut that defers the real fix.

## Tests

- No unit test. Asserting the widget tree contains a `SafeArea` node would be tautological — the assertion is that it's applied at the right spot with the right `top: false` config, which is better verified by eye on a real device.
- **Manual smoke.** On an Android 15 emulator (or target device), open each of the five affected screens and confirm no overlap:
  1. Dashboard → Am Klo gewesen? (toilet tracker) — `speichern` button visible.
  2. Dashboard → Mahlzeit tracken → save a meal — `Speichern` button visible.
  3. Recommendations → dislike (thumbs-down) a tip — "Was hat dir nicht gefallen?" sheet, both `Fertig` and `Empfehlung ausblenden` visible.
  4. Dashboard → Wie geht es dir? → `Stimmung` tab — `speichern` button visible.
  5. Same screen, `Bauchgefühl` tab — `weiter` button visible.

## Risk

Zero app-logic risk. `SafeArea` computes to 0-height on devices without a system bottom region (Android with physical nav buttons; most emulators with legacy skin). On iOS with a home indicator, the trackers' buttons also gain appropriate breathing room — positive side effect, no existing iOS reports but the new padding is consistent with iOS HIG.

No change to existing `PopScope` / discard-confirm behavior, no change to tracker state-management, no change to the success-overlay swap at `TrackerScreenScaffold:34-43`.

## Acceptance

- `TrackerScreenScaffold.build` returns a `Scaffold` whose `body` is `SafeArea(top: false, child: body)`.
- `_RecommendationDislikeSheetState.build` returns a widget tree whose root (inside the sheet builder) is `SafeArea(top: false, child: ...)`.
- `flutter analyze` clean; `dart format` applied.
- Manual smoke confirms all five affected screens no longer clip into the nav bar.
