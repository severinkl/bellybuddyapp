# Recipe-driven meal save returns to dashboard — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** When the meal tracker is opened via a recipe (Dashboard → Rezepte → recipe detail → "Zu Mahlzeit übernehmen"), saving and dismissing the success overlay should land on the dashboard, not bounce back through the pushed recipe-detail screen.

## Problem

The meal tracker's success overlay defaults its dismiss action to `context.popOrGoDashboard()`. That helper does `canPop() ? pop() : go(RoutePaths.dashboard)`. The three entry points yield different stacks:

| Entry point | Stack at success | Pop result |
|-------------|------------------|------------|
| Dashboard → `+` center button | dashboard → meal-tracker | pops to dashboard ✓ |
| Dashboard → Tagebuch → `+` | dashboard → diary → meal-tracker | pops to diary (intended) ✓ |
| Dashboard → Rezepte → recipe detail → "Zu Mahlzeit übernehmen" | dashboard → recipes → recipe-detail → meal-tracker | pops to recipe detail ✗ |

The third path is the bug — the user lands back on the recipe they came from instead of the dashboard.

## Goal

When the user dismisses the success overlay after a recipe-driven save, the navigation lands on the dashboard. Other entry points keep their current pop semantics.

## Approach

### Component layout

**Modify (1 file):**
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — pass `onSuccessDismissed` to the `TrackerScreenScaffold(...)` call in `build()`. When `widget.initialRecipe != null`, the override goes to dashboard. Otherwise pass `null` to preserve the existing default fall-through.

`TrackerScreenScaffold` already has an `onSuccessDismissed: VoidCallback?` slot with the correct null-coalesce: `onDismissed: onSuccessDismissed ?? context.popOrGoDashboard`. No widget-level change needed.

### The diff

In `MealTrackerScreen.build()`'s `TrackerScreenScaffold(...)` argument list, add a new property next to `successBottomCallout:`:

```dart
onSuccessDismissed: widget.initialRecipe != null
    ? () => context.go(RoutePaths.dashboard)
    : null,
```

`context.go(...)` (rather than `context.push`) clears the back-stack, so the user lands on a fresh dashboard with no recipes / recipe-detail / meal-tracker frames left to bounce back into.

### Acceptance

- Dashboard → Rezepte → recipe detail → "Zu Mahlzeit übernehmen" → save → tap dismiss (or wait for auto-dismiss) → **lands on dashboard**, not recipe detail.
- Dashboard → `+` center button → save → dismiss → lands on dashboard (unchanged: `popOrGoDashboard` already pops once back to dashboard).
- Dashboard → Tagebuch → `+` → save → dismiss → lands on Tagebuch (unchanged: pop returns to the diary entry the user was viewing).
- Edit-mode meal saves are unaffected — they don't show the success overlay (`showSuccess` is create-mode-only on `MealTrackerState`).

## Tests

No new test. The success-overlay dismiss path is documented as brittle to test via `MealTrackerScreen` (per the comment in `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart`: "forcing TrackerScreenScaffold into showSuccess=true via provider overrides is brittle"). The change is a single ternary on a documented input (`widget.initialRecipe`); manual smoke is the natural verification.

## Out of scope

- The diary `+` → meal-tracker → save flow's pop-target — preserved as-is. The user is viewing a specific date in the diary; popping back keeps them in context.
- Adding a "back to recipe" affordance on the success overlay — the user wants dashboard, not the recipe.
- Generalising into an `afterSaveDestination`-style prop on `TrackerScreenScaffold` — premature, one branch on one screen doesn't justify a wider API.

## Risks

- `context.go(RoutePaths.dashboard)` clears the back-stack including any diary tab date state. In this flow the user came from dashboard, so there is no diary state to lose. If the user navigates to diary after landing on dashboard, the diary date resets to today — already the dashboard's normal behavior on cold-arrive.
