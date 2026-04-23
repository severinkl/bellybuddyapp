# Recommendations Horizontal Swipe — Design

**Date:** 2026-04-22
**Status:** Approved, ready for implementation plan.

## Goal

Replace the "Verlauf" collapsible in the recommendations screen with a horizontal swipe that moves between recommendations, the same way the diary's day-swipe lets the user scan through days. The latest recommendation becomes the initial page; swiping right reveals older entries. A small position indicator ("X von Y Empfehlungen") plus prev/next chevrons sit in a pinned header above the swipable body.

## Non-goals

- Pagination of the recommendation list — all recommendations for the user load at once, same as today (typical count is small).
- Deep-linkable per-recommendation URLs.
- Changes to how recommendations are created, scored, or deleted.
- Visual overhaul of the summary/detail cards inside a recommendation.

## Architecture

`RecommendationsScreen` becomes a `ConsumerStatefulWidget` that owns a `PageController`. The body is a `PageView.builder` indexed by position in the recommendation list (latest at the highest index, right-most page = initial). A new `Notifier<int>` — `recommendationIndexProvider` — tracks the currently-visible index; `onPageChanged` writes to it, and a `ref.listen` on the notifier animates the controller when chevrons or programmatic calls move the index. This mirrors the established diary day-swipe pattern (`lib/screens/diary/diary_screen.dart`), adapted for a fixed-size list instead of a date-index.

The old `RecommendationHistory` collapsible widget is deleted, along with its call site.

## Layout

AppBar keeps its existing back arrow and static title "Für dich". No AppBar chevrons — they'd collide with the back arrow.

Below the AppBar, a pinned header row contains:

- Previous chevron on the left. Tapping it goes to the older recommendation (lower `pageIndex`). Hidden (replaced by `SizedBox(width: chevronSize)`) when `currentIndex == 0` (on the oldest — nothing further back).
- Centered text: "X von Y Empfehlungen", where `X = currentIndex + 1` and `Y = recommendations.length`. Note this is the PageView index counted from 1; the latest will show as "Y von Y".
- Next chevron on the right. Tapping it goes to the newer recommendation (higher `pageIndex`). Hidden when `currentIndex == recommendations.length - 1` (on the latest — nothing further forward).

Below the pinned header, the `PageView.builder` fills the remaining space. Each page is a `_RecommendationPage` widget containing:

- A date label at the top, formatted via the existing `formatDateWeekday` utility from `lib/utils/date_format_utils.dart`. The date slides with the page as the user swipes, matching the diary's sliding-date feel.
- The existing `RecommendationSummaryCard` for that recommendation.
- The existing detail cards for each `RecommendationItem`.
- All wrapped in a `RefreshIndicator` whose `onRefresh` invalidates `recommendationProvider` (same behavior as today's screen).

## Index direction and chevron labels

The list returned by `recommendationProvider` is newest-first (`ORDER BY created_at DESC`). We map that to the PageView so that **latest = rightmost page** (matches diary semantics):

- `PageView` index 0 → oldest recommendation → `recommendations.last`.
- `PageView` index N-1 → latest recommendation → `recommendations.first`.

To convert between PageView index and list index: `listIndex = (recommendations.length - 1) - pageIndex`.

Chevron directions under this mapping (mirrors the diary's `previousDayKey` / `nextDayKey` convention):

- Previous chevron (left arrow, `recommendationsPreviousKey`): moves to `pageIndex - 1` → leftward on the PageView → older recommendation. Hidden at the oldest (`currentIndex == 0`).
- Next chevron (right arrow, `recommendationsNextKey`): moves to `pageIndex + 1` → rightward on the PageView → newer recommendation. Hidden at the latest (`currentIndex == length - 1`).

Swipe directions (physical drag direction on the PageView) map the same way: drag rightward → lower `pageIndex` → older; drag leftward → higher `pageIndex` → newer. That is, the chevron arrow direction matches the swipe direction that produces the same result.

## Providers + state

- `recommendationProvider` (existing, in `lib/providers/recommendation_provider.dart`): unchanged. Still returns `AsyncValue<List<Recommendation>>` ordered newest-first.
- New `recommendationIndexProvider` — `NotifierProvider<RecommendationIndexNotifier, int>`:
  - Initial value: 0 (safe default; the screen will seed it to `length - 1` on first resolve of the list).
  - `set(int index)` writes the new index.
- `RecommendationsScreen` state:
  - Holds a `PageController`.
  - On the first successful resolve of `recommendationProvider`, sets `_controller` to `PageController(initialPage: length - 1)` and calls `indexNotifier.set(length - 1)`.
  - `onPageChanged` writes to the notifier and triggers `HapticService.light()` (matching diary).
  - A `ref.listen` on the index notifier runs `animateToPage` when the index changes externally (chevron taps).
  - If the list length changes (new recommendation arrives via refresh), the screen compares the new `recommendations.first.id` to the previously seeded value; if it changed, it jumps the controller to the new `length - 1` and reseeds the notifier — so the user lands on the freshly-added latest entry.

## Empty / single / loading / error

- Loading: show the existing loading indicator (`BbLoadingState` or equivalent the screen uses today).
- Error: show the existing error state (`BbErrorState`).
- Empty (zero recommendations): render the existing empty-state message. Do not render the pinned header or the PageView.
- Single (one recommendation): render the PageView with one page. Pinned header shows "1 von 1 Empfehlungen"; both chevrons hidden. Swipe does nothing (PageView has no neighbors).

## German copy

- "X von Y Empfehlungen" — position indicator. `X = currentIndex + 1`, `Y = length`.
- All existing strings on the recommendation cards are unchanged.

## Testing

**Widget tests — `RecommendationsScreen`:**
- Renders N pages for N recommendations. Initial page is the latest (rightmost).
- Swipe rightward (drag with positive X offset) from the initial page advances to the older recommendation (lower index); the notifier and controller both update.
- Swipe leftward at the initial page is a no-op (PageView at the last-index boundary).
- Tap the previous chevron when `currentIndex > 0` decrements the index (moves toward older).
- Tap the next chevron when `currentIndex < length - 1` increments the index (moves toward newer).
- Empty list → empty-state message, no PageView, no pinned header.
- Single-recommendation list → one page, both chevrons hidden, "1 von 1 Empfehlungen" visible.

**Notifier test — `RecommendationIndexNotifier`:**
- `set(n)` updates `state` to `n`.
- Initial state is 0.

## Files

- Rewrite: `lib/screens/recommendations/recommendations_screen.dart`.
- Delete: `lib/screens/recommendations/widgets/recommendation_history.dart`.
- Delete: `test/screens/recommendations/widgets/recommendation_history_test.dart` (if it exists).
- New: `lib/providers/recommendation_index_provider.dart`.
- New: `test/providers/recommendation_index_provider_test.dart`.
- Modify: `test/screens/recommendations/recommendations_screen_test.dart` — rewrite around the new PageView-based flow.

## Risks / open items

- **Identity tracking across refreshes.** Using `recommendations.first.id` to detect "a new latest arrived" after refresh assumes recommendations have stable ids and that a new one always lands at index 0. True per the current service ordering (`created_at DESC`). If ordering changes in the future, this heuristic will need revisiting.
- **Fling threshold.** The diary's right-swipe test uses `tester.fling(..., 1000)` rather than `tester.drag(..., 400)` because the 400 px drag sits on PageView's commit threshold. We may hit the same issue; the tests should prefer `fling` with a clear velocity for the directional swipe cases.
- **Refresh re-anchoring.** Re-anchoring on the freshly-added latest is the expected behavior when the user pulls to refresh. If we later want to keep the user on the page they were reading, we can swap to by-id anchoring — out of scope here.
