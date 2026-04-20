# Diary Day Swipe — Design Spec

**Date:** 2026-04-20
**Status:** Approved design — ready for implementation plan
**Scope:** Let the user switch between days on the Diary screen by swiping horizontally on the body, in addition to the existing chevron buttons and date picker.

## Motivation

Today the only ways to switch days on the `Diary` screen are (a) the `[<]`/`[>]` chevron buttons flanking the date in the AppBar, and (b) tapping the date to open a `DatePicker`. Neither is as fluid as the "swipe to go back in time" affordance users expect from a journal-shaped view.

A horizontal swipe on the body currently doesn't switch days. Instead, the outer `SwipeablePages` widget (wrapping the `StatefulShellRoute`) interprets a swipe starting within 30px of the screen edge as "navigate to the adjacent shell branch" — on Diary, that means right-from-left-edge takes you back to Home. Users hitting this report it as unintentional: they wanted to see yesterday's diary, not lose their place.

## Goals

- Horizontal swipe on the diary body switches the displayed day by ±1 (left = next day, right = previous day).
- Preserves the existing delete-by-swipe gesture on individual `DiaryEntryCard` entries.
- Matches the visual motion of the existing `SwipeablePages` (same translation, same curves, same threshold constants) for consistency.
- Respects the same day-range bounds the existing UI already enforces: can't advance past today, can't swipe back before `2020-01-01`.

## Non-Goals

- Cross-month swipe or calendar-grid navigation.
- Pre-fetching or paging multiple days at once.
- Arrow / caret indicators on the body during drag — this is a primary gesture, not a discovery affordance.
- Changing the `SwipeablePages` shell gesture globally (Home still swipes to Diary via the edge).

## User-facing decisions

| Question | Decision |
|---|---|
| Does the existing edge-swipe back-to-Home still work on Diary? | No. Any horizontal swipe on the diary body switches days. Users reach Home via the bottom nav. The edge-swipe continues to work on the Home tab (swipe-right-edge-left to reach Diary). |
| What about day-range bounds? | Match the existing UI. Can swipe back to `2020-01-01` (mirrors `DatePicker.firstDate`). Can't swipe forward past today (mirrors the `isToday` check that hides the `[>]` chevron). Rubber-band feedback at bounds. |

## Gesture & state flow

A new `DiaryDaySwiper` widget wraps the diary body. It owns a `GestureDetector(behavior: HitTestBehavior.translucent, onPanStart/Update/End)` and is driven by the surrounding `DiaryScreen`.

**Rules:**

- `onPanStart`: record `startX`, `startY`. Do not claim the gesture yet. `HitTestBehavior.translucent` lets taps still reach the `ListView`, and horizontal swipes starting on a `Dismissible` are claimed by the card's own `HorizontalDragGestureRecognizer` first (unchanged delete behavior).
- `onPanUpdate`: the first 10px of movement decides direction. Horizontal → start translating the body by `dx`. Past `boundaryResistance` (`0.3`) when at a bound.
- `onPanEnd`: if `|dx| > 80px` and not at a bound in that direction → commit (haptic tick, animate out, flip date, animate in). Otherwise → spring back.
- Vertical drag → do nothing; the child's own scroll continues to work.

**State:** `diaryDateProvider` stays the single source of truth. Chevrons, DatePicker, and swipe all funnel through `diaryDateProvider.notifier.set(newDate)`. No new provider.

**Bounds (evaluated in the parent `DiaryScreen`, passed as flags into `DiaryDaySwiper`):**

- `canSwipeBack = date.isAfter(DateTime(2020, 1, 1))`
- `canSwipeForward = !isSameDay(date, DateTime.now())`

## Animation & transition

Uses a single `AnimationController` in `_DiaryDaySwiperState`, driving a `Transform.translate` around the `child`.

**During drag:**

- Body translates 1:1 with `dx` within the allowed direction.
- At a bound, `dx` is multiplied by `0.3` (rubber-band). Constant lifted from `SwipeablePages._boundaryResistance` so the two widgets feel identical.

**On commit (`|dx| > 80px`, not at a bound):**

1. 150ms, `Curves.easeOutCubic`: body slides to `±screenWidth` in the drag direction. `HapticService.light()` fires at the start.
2. Parent calls `diaryDateProvider.notifier.set(newDate)`; Riverpod rebuilds `DiaryDaySwiper.child` with the new day's data.
3. 150ms, `Curves.easeOutCubic`: new body enters from `∓screenWidth` back to `0`.

**On cancel (drag below threshold, or at a bound):**

- 200ms `Curves.easeOutCubic` spring back to `offset: 0`. No haptic.

Commit phases use `AppConstants.animFast` (150ms) each; cancel uses `AppConstants.animNormal` (200ms). No new duration constants.

## Architecture

```
┌──────────────────────────────────────────┐
│ DiaryScreen (ConsumerWidget)             │
│  ├─ reads diaryDateProvider              │
│  ├─ computes canSwipeBack/Forward        │
│  └─ builds DiaryDaySwiper(...)           │
│                                          │
│ DiaryDaySwiper (StatefulWidget)          │
│  ├─ pure UI, no Riverpod                 │
│  ├─ GestureDetector + AnimationController│
│  └─ callbacks: onPrevious, onNext        │
│                                          │
│ diaryDateProvider (existing)             │
│  └─ single source of truth for the date  │
└──────────────────────────────────────────┘
```

**Why a standalone widget rather than inlining in `DiaryScreen`:** keeps the gesture + animation logic in one testable unit. `DiaryScreen` stays declarative: "today's date → body widget → wrap in swiper". The swiper knows nothing about providers and can be tested with pumped callbacks.

## Components

### `DiaryDaySwiper` (new — `lib/screens/diary/widgets/diary_day_swiper.dart`)

```dart
class DiaryDaySwiper extends StatefulWidget {
  final Widget child;
  final bool canSwipeBack;     // false when at firstDate (2020-01-01)
  final bool canSwipeForward;  // false when on today
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const DiaryDaySwiper({
    super.key,
    required this.child,
    required this.canSwipeBack,
    required this.canSwipeForward,
    required this.onPrevious,
    required this.onNext,
  });
}
```

- Internal state: `_dragDx` (double), `_startY` (double?), `_isHorizontal` (bool?), `AnimationController _slide`.
- Constants hoisted to the class:
  - `_swipeThreshold = 80.0` (commit threshold; matches `SwipeablePages`).
  - `_boundaryResistance = 0.3` (at-bound drag multiplier; matches `SwipeablePages`).
  - `_directionDecisionThreshold = 10.0` (px of movement before locking horizontal/vertical).
- On commit: playback is `_slide.forward()` from 0→1 driving `Transform.translate(offset: Offset(direction * width * value, 0))`, then callback, then reset to `-direction * width` and animate back to 0.

### `DiaryScreen` (modified — `lib/screens/diary/diary_screen.dart`)

- Extract the current `RefreshIndicator(Column(Expanded(when(...))))` body into a private `_DiaryBody(date)` widget (stateless) so the wrapping stays readable.
- Wrap `_DiaryBody(date)` in `DiaryDaySwiper(...)`:
  ```dart
  DiaryDaySwiper(
    canSwipeBack: date.isAfter(DateTime(2020, 1, 1)),
    canSwipeForward: !isSameDay(date, DateTime.now()),
    onPrevious: () {
      HapticService.light();
      ref.read(diaryDateProvider.notifier).set(date.subtract(const Duration(days: 1)));
    },
    onNext: () {
      HapticService.light();
      ref.read(diaryDateProvider.notifier).set(date.add(const Duration(days: 1)));
    },
    child: _DiaryBody(date: date),
  )
  ```
- Chevron buttons and DatePicker wiring are unchanged.

## Data flow

```
[User swipes left on body]
      ↓
_DiaryDaySwiperState._onPanUpdate — translates child by dx
      ↓ (on end, |dx| > 80)
animate off-screen → onNext() → diaryDateProvider.set(date + 1 day)
      ↓ Riverpod notifies
DiaryScreen rebuilds → new `_DiaryBody(date')` → wrapped in DiaryDaySwiper again
      ↓
_DiaryDaySwiperState starts entering-animation from ∓screenWidth → 0
```

## Error handling & edge cases

- **Drag started on a `Dismissible` card.** `HitTestBehavior.translucent` + the Dismissible's own horizontal recognizer win the arena for that card's hit rect. The swiper's translate never starts. Delete still works.
- **Drag on vertical scroll of the list.** The `_directionDecisionThreshold` (10px) picks up the vertical dominance first; the swiper does nothing; the list scrolls normally.
- **User swipes forward while on today.** `canSwipeForward = false` → `dx` is dampened by `boundaryResistance` (0.3) during drag; no commit regardless of distance; spring-back on release.
- **User swipes back while on 2020-01-01.** Same rubber-band; no commit.
- **User opens DatePicker mid-drag (impossible because the AppBar and body are separate tap zones, but defensively):** the gesture end still fires; swiper springs back without committing.
- **Day change from DatePicker or chevron while swiper is animating:** `diaryDateProvider` changes → `DiaryScreen` rebuilds → `DiaryDaySwiper` rebuilds with the new `child`. Internal `AnimationController` is re-initialized if the widget is re-created (normal Flutter lifecycle), or kept if the key is preserved. In practice each rebuild produces a new `DiaryDaySwiper` instance at the same location in the tree, so Flutter preserves the State. The currently-running animation completes, lands on `offset: 0`, and the new `child` is displayed. No visual glitch.

## Testing strategy

### Widget tests

**`test/screens/diary/diary_day_swiper_test.dart` (new):**

- Pump `DiaryDaySwiper` with a sentinel child containing a `GestureDetector(onTap)` and counting callbacks (`onPrev`, `onNext`).
- Left drag > 80px, `canSwipeForward=true` → `onNext` fires once, `onPrevious` zero times.
- Right drag > 80px, `canSwipeBack=true` → `onPrevious` fires once.
- Left drag > 80px, `canSwipeForward=false` → neither fires.
- Right drag > 80px, `canSwipeBack=false` → neither fires.
- Short drag (< 80px) → neither fires (cancel path).
- Vertical drag (primarily `dy`) → neither fires; child's `onTap` still works after.
- Sentinel tap → fires once (proves translucency).

Uses `tester.drag(find.byType(DiaryDaySwiper), Offset(±200, 0))`.

**`test/screens/diary/diary_screen_test.dart` (new or extend existing):**

- Seed `diaryDateProvider` at `DateTime.now()`, pump `DiaryScreen` via `pumpWithProviders` with a `FakeEntryRepository` returning an empty `EntryQueryResult`.
- Swipe left on the body → `diaryDateProvider.state` unchanged (can't advance past today).
- Seed date at `today - 3 days`, swipe left → state becomes `today - 2 days`.
- Seed date at `today`, swipe right → state becomes `today - 1 day`.

Integration coverage for the Dismissible coexistence is out of scope (the existing `integration_test/diary_flow_test.dart` already exercises entry deletion; if that test passes after this PR, coexistence is proven).

### Manual smoke

- Fresh install → sign in → open Diary.
- Left-swipe body → shows "gestern" (yesterday).
- Right-swipe → back to today.
- Left-swipe on today → rubber-bands and springs back; AppBar still reads today.
- Right-swipe a diary entry card → delete dialog appears (unchanged).
- Vertical scroll of the entry list → unaffected by the new handler.
- Swipe from the left edge of the screen (within the 30px strip where `SwipeablePages` also listens) → day-switch happens instead of routing to Home. Users reach Home via the bottom nav.

## File inventory

**New:**

- `lib/screens/diary/widgets/diary_day_swiper.dart`
- `test/screens/diary/diary_day_swiper_test.dart`

**Modified:**

- `lib/screens/diary/diary_screen.dart` — extract `_DiaryBody` private widget; wrap it in `DiaryDaySwiper`; compute `canSwipeBack` / `canSwipeForward`.

**Possibly new:**

- `test/screens/diary/diary_screen_test.dart` — check whether this already exists; if not, create a minimal one covering the three bound-and-commit swipe cases.

**Untouched:**

- `lib/widgets/common/swipeable_pages.dart` — continues to drive Home ↔ Diary edge-swipe on the Home side. Diary-side edge-swipes are intercepted by `DiaryDaySwiper` first because it's deeper in the tree.
- `diaryDateProvider`, `diaryEntriesProvider`, `DiaryEntryCard`, chevron buttons, DatePicker.

## Rollout

No feature flag. No migration. Behavior is additive on the day-switching side; users who already rely on the chevrons or DatePicker see no change. The single user-visible regression is the loss of the edge-swipe-back-to-Home on Diary — mitigated by the bottom nav already providing that route.

## Open questions

None.
