# Drink tracker pre-fills date from meal tracker — Design Spec

**Date:** 2026-05-03
**Status:** Approved (ready for plan)

## Goal

When the user launches the drink tracker from inside the meal tracker — via either the "Getränk tracken" button on the meal form or the "Getränk tracken" link inside the post-save success card — the drink tracker pre-fills its `trackedAt` with the meal's exact `trackedAt` (date + time, verbatim) instead of `DateTime.now()`. The user can still edit via the existing `DateTimeChips`.

## Why

The meal tracker lets the user pick any date/time for the meal. If they then add a drink, the drink tracker today resets to "now," forcing the user to re-pick the date for the drink. This loses the user's intent.

## Non-goals

- The bottom-nav `+`-button for drinks (triggered from the diary tab on a non-today date) is **not** wired in this change. The drink tracker will accept an `initialDate` route argument; if no caller passes one, behavior is unchanged. Wiring the diary `+`-button is a follow-up if desired.
- No change to the meal/toilet/gut-feeling trackers.
- No change to the `DateTimeChips` widget itself.

## Components

### 1. `DrinkTrackerScreen` (`lib/screens/trackers/drink/drink_tracker_screen.dart`)

- Add optional constructor param `final DateTime? initialDate;`.
- In the existing `initState` post-frame callback, after `notifier.reset()`, apply the date:

  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    notifier.reset();
    if (widget.initialDate != null) {
      notifier.setTrackedAt(widget.initialDate!);
    }
    notifier.loadDrinks();
    notifier.loadTodayTotal();
  });
  ```
- **No `buildTrackedAt` wrapping.** Per design choice B, we want the full timestamp through verbatim.

### 2. Router (`lib/router/app_router.dart`)

The current builder is:

```dart
GoRoute(
  path: RoutePaths.drinkTracker,
  name: RouteNames.drinkTracker,
  builder: (context, state) => const DrinkTrackerScreen(),
),
```

Update to read `state.extra` as a `DateTime?`:

```dart
GoRoute(
  path: RoutePaths.drinkTracker,
  name: RouteNames.drinkTracker,
  builder: (context, state) =>
      DrinkTrackerScreen(initialDate: state.extra as DateTime?),
),
```

This mirrors how the meal tracker route reads `extra` (`MealEntry` / `UserRecipe`).

### 3. Meal tracker callsites (`lib/screens/trackers/meal/meal_tracker_screen.dart`)

Two existing surfaces, both currently `context.push(RoutePaths.drinkTracker)` with no extra:

- **Form button** (`drinkTrackerButtonKey`, line ~412):
  ```dart
  onPressed: () => context.push(
    RoutePaths.drinkTracker,
    extra: ref.read(mealTrackerProvider).trackedAt,
  ),
  ```
- **Success-card link** (`successActions`, line ~213). The current `GestureDetector.onTap` uses `() => context.push(RoutePaths.drinkTracker)`. Same change — pass `state.trackedAt` (the closure already has access to `ref`/`state`).

Both pass the meal-tracker provider's full `trackedAt` (which is the meal's chosen timestamp in both create and edit mode).

## Data flow

```
MealTrackerScreen
  state.trackedAt (DateTime — date + user-picked time)
        │
        ▼  context.push(RoutePaths.drinkTracker, extra: trackedAt)
GoRouter
        │
        ▼  state.extra as DateTime? → DrinkTrackerScreen(initialDate: ...)
DrinkTrackerScreen.initState (post-frame)
        │
        ▼  notifier.reset(); notifier.setTrackedAt(initialDate)
DrinkTrackerNotifier.state.trackedAt = the meal's trackedAt
        │
        ▼  ref.watch(drinkTrackerProvider) → DateTimeChips renders that timestamp
```

## Edge cases

- **`initialDate == null`**: drink tracker behaves exactly as today (`DateTime.now()` from `DrinkTrackerNotifier.build`). All existing callers without `extra` keep their behavior.
- **Edit-mode meal**: `mealTrackerProvider.state.trackedAt` is the stored meal's timestamp, so the handoff carries it through.
- **Reset ordering**: `reset()` runs first (clears stale state), then `setTrackedAt(initialDate)` overrides the timestamp. Matches the meal tracker's `reset() → setTrackedAt(buildTrackedAt(...))` ordering.
- **Provider lifecycle**: `setTrackedAt` is called inside `addPostFrameCallback`, so we never mutate provider state during `initState`/`build`.

## Testing

### Unit / widget tests

1. **`drink_tracker_screen_test.dart` — initialDate seeds trackedAt.**
   Pump `DrinkTrackerScreen(initialDate: DateTime(2026, 5, 1, 12, 30))` inside a `ProviderScope` with the drink repository faked. After `pumpAndSettle`, assert that `ref.read(drinkTrackerProvider).trackedAt` equals `DateTime(2026, 5, 1, 12, 30)` exactly.

2. **`meal_tracker_screen_test.dart` — form button forwards trackedAt as `extra`.**
   Build a `GoRouter` with two routes: `/meal-tracker` mounting `MealTrackerScreen`, and a sentinel `/drink-tracker` route whose builder reads `state.extra as DateTime?` and renders e.g. `Text('drink:${extra?.toIso8601String() ?? "null"}')`. Set `mealTrackerProvider.trackedAt` to a fixed `DateTime`. Tap the button (`MealTrackerScreen.drinkTrackerButtonKey`). Assert the sentinel text matches the expected ISO string.

3. **`meal_tracker_screen_test.dart` — success-card link forwards trackedAt.**
   Same harness. Drive the meal-tracker state into `showSuccess: true`, find the success-card "Getränk tracken" `GestureDetector`, tap it, assert the same sentinel ISO string.

### Manual smoke

- Open meal tracker, change date/time via DateTimeChips to an arbitrary past day at e.g. 09:15. Tap "Getränk tracken". Drink tracker opens with chips showing that same date and 09:15.
- Save a meal whose `trackedAt` is non-today. From the success card, tap "Getränk tracken". Drink tracker opens prefilled with the meal's `trackedAt`.

## Files touched

- `lib/screens/trackers/drink/drink_tracker_screen.dart` — add `initialDate` param + apply in `initState`.
- `lib/router/app_router.dart` — read `state.extra as DateTime?` and forward.
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — pass `state.trackedAt` as `extra` from both callsites.
- `test/screens/trackers/drink/drink_tracker_screen_test.dart` — new or extended test.
- `test/screens/trackers/meal/meal_tracker_screen_test.dart` — new or extended test.
