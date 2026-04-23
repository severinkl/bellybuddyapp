# Dashboard "Tipps" + Recommendations Header Polish — Design

## Goal

Tighten the dashboard card that opens the recommendations feature and the recommendations detail screen's AppBar:

- Rename the dashboard card to `"Tipps"` (from `"Für dich"`).
- Replace the `"Neu"` badge with `"ungelesen"` (lowercase).
- Pulse the badge pill while unread recommendations exist, so the user notices new content.
- On the recommendations detail screen, replace the current title text with the currently-viewed recommendation's date.
- Move prev/next chevrons from the inline row below the AppBar into the AppBar itself, visually distinguished from the back-to-dashboard affordance.

## Out of scope

- No changes to recommendation content, feedback pills, or dislike sheet.
- No new routes, no new data fields.
- No changes to `"Alternativen"` card, which shares `FeatureCard` but uses `badgeCount` (a number) and should not pulse.
- No rename of the dashboard section header `"Für dich erstellt"` — left as-is.

## Dashboard card

### Copy changes

- `dashboard_screen.dart` — card label: `'Für dich'` → `'Tipps'`.
- `feature_card.dart` — unread-badge text: `'Neu'` → `'ungelesen'` (for the `hasNew` branch only). The `'$badgeCount'` branch (used by `"Alternativen"`) is untouched.

### Pulse animation

`FeatureCard` gains one optional prop:

```dart
final bool pulse;          // default false
```

Dashboard wires `pulse: newRecommendationCount > 0` (same signal that drives `hasNew`). The `"Alternativen"` card does not set `pulse`; it stays static.

`FeatureCard` becomes a `StatefulWidget` (it's currently stateless). It owns an `AnimationController`:

- duration: 700 ms
- `repeat(reverse: true)` in `initState` when `pulse == true` — the full cycle (grow + shrink) is 1.4 s
- `didUpdateWidget` starts / stops the controller when `pulse` toggles
- disposed in `dispose`

The badge pill wraps in an `AnimatedBuilder` that applies a `Curves.easeInOut`-curved `t` (0→1) to:

- `Transform.scale(scale: 1.0 + 0.08 * t)` — grows to 1.08× at the apex, back to 1.0× on reverse
- `BoxShadow(color: primary.withOpacity(0.55 * (1 - t)), blurRadius: 0, spreadRadius: 6 * t)` — ring expands outward as the badge grows, fading to transparent at the apex (so the halo visibly radiates rather than sitting pinned to the pill)

**Reduced motion:** respect `MediaQuery.disableAnimations`. When true, the badge renders its base scale + no shadow; controller is not started. (Checked inside `build`, since `MediaQuery` changes should rebuild.)

### Existing behaviour preserved

- The 3px primary border still appears when `hasNew || badgeCount > 0`.
- Badge position / padding / pill color unchanged.
- Tap target unchanged; still navigates to `RoutePaths.recommendations`.

## Recommendations detail AppBar

### Layout

Three slots:

- **leading** — `TextButton.icon` with `Icons.arrow_back_ios_new` + `'Dashboard'`. `onPressed: () => context.pop()`. `leadingWidth: 128` so the word `"Dashboard"` fits without truncation.
- **title** — the currently-viewed recommendation's `createdAt` formatted via the existing `formatDateWeekday` util. Empty list / loading / error fall back to `'Empfehlungen'` (matches today's empty-state title).
- **actions** — two `IconButton`s. Left = `Icons.chevron_left`, right = `Icons.chevron_right`. Each fires `HapticService.light()` then writes the new index into `recommendationIndexProvider`. Disabled (`onPressed: null`, reduced opacity) at `isOldest` / `isLatest`.

### Widget restructure

Today's `_SwipeLayout` top row holds `[chevron_left] [date] [chevron_right]`. That row is removed entirely — all three elements are now in the AppBar.

- `_RecommendationsTitle` becomes date-only. Signature / ConsumerWidget shape unchanged; it just renders the date (or fallback).
- A new `_RecommendationsAppBarActions` ConsumerWidget watches `recommendationProvider` + `recommendationIndexProvider` and renders the two chevron `IconButton`s with the same clamp + index logic that the removed inline row used.
- `_SwipeLayout` shrinks to just the `PageView.builder` + its existing post-frame write-back for clamping. `currentIndex` / `isOldest` / `isLatest` are no longer needed there — they're computed inside `_RecommendationsAppBarActions`.

### Edge cases

- Loading / error / empty list → title falls back to `'Empfehlungen'`; chevrons both disabled (no recommendations to navigate). Leading button remains functional.
- Single recommendation → both chevrons disabled (same as today).
- Hide-clamp regression still holds — the clamp logic moves to the AppBar actions widget but the invariant (raw index ≥ list length → schedule post-frame write-back to a valid index) is preserved.

### Haptics

`HapticService.light()` on each chevron tap, matching today's inline row behaviour. No haptic on the leading button (also matches today — the back arrow doesn't haptic).

## Testing

### Dashboard / FeatureCard

- Add: `FeatureCard` with `pulse: true` → badge is wrapped in a `Transform.scale` with non-unit scale after pumping a frame; with `pulse: false` → base scale, no active controller.
- Add: dashboard test — `newRecommendationCount > 0` flows into FeatureCard's `pulse: true`; badge text reads `'ungelesen'`; label reads `'Tipps'`.
- Reduced-motion: wrap the widget in a `MediaQuery(disableAnimations: true)` and assert the controller is not active.

### Recommendations screen

Migrate the existing inline-row chevron tests to assert AppBar actions:

- Leading renders `'Dashboard'` text + arrow; tap pops the route.
- Title renders the formatted date for the current recommendation.
- Prev/next chevrons enabled/disabled at list ends; each tap advances the provider's index (via the existing `recommendationIndexProvider` wire-up).
- Hide-clamp regression test still passes after the restructure.

### Keys

Existing `RecommendationsScreen.previousRecommendationKey` / `nextRecommendationKey` keys move to the AppBar IconButtons so current tests keep working.

## Risks / trade-offs

- `leadingWidth: 128` eats title real estate — German date strings like `"Mi., 22. Apr."` should still fit on iPhone SE (320 pt). If truncation shows up in manual testing, shrink the leading label to `"Zurück"` instead of `"Dashboard"` (4 chars vs 9).
- `AnimationController` on the dashboard means the card rebuilds at 60 fps while unread exists. Scoped to `AnimatedBuilder` so only the badge subtree rebuilds, not the image / label.
- Moving the chevrons into the AppBar takes them out of the thumb zone on larger phones. Acceptable because page-swipe is the primary navigation; chevrons are a fallback.
