# Recipe button beside Kamera / Galerie — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** Move the meal-tracker's recipe-selector entry point from the AppBar into the `MealImageSection` empty-state card so users see all three "start with..." options (Kamera / Galerie / Rezept) in one place.

## Problem

Today the meal-tracker has two recipe-selector entry points:

- `MealImageSection._EmptyState` — a 4:3 dashed card with two circular buttons: Kamera (`AppTheme.primary`) and Galerie (`AppTheme.secondary`).
- `_buildRecipeSelectorFab` — an AppBar action `IconButton(Icons.menu_book_outlined)` that opens `RecipeSelectorSheet`, gated on `userRecipes.isNotEmpty`.

Two issues:

1. The AppBar entry point is discoverable, but disconnected from the "how do I want to populate this meal?" decision the user makes when they land on the screen — the same decision that the Kamera / Galerie buttons already address.
2. Visually scattering related actions (one in the AppBar, two in the body) hides the parity. A user who wants "start from a saved recipe" doesn't naturally look at the AppBar for it.

## Goal

Move the recipe-selector into the `MealImageSection` empty-state card as a third `_PickerButton` beside Kamera and Galerie, and remove the AppBar icon. Keep the existing `prefillFromRecipe` behaviour (sets title + ingredients + image when a recipe is picked).

## Approach

### Component layout

**Modify (2 files):**

- `lib/screens/trackers/meal/widgets/meal_image_section.dart` — `MealImageSection` accepts a new optional `onPickRecipe: VoidCallback?` prop. When non-null, `_EmptyState` renders a third `_PickerButton` (`Rezept`, `Icons.menu_book_outlined`, `AppTheme.info`) after Galerie, separated by the same vertical divider as today. When null, the row stays at two buttons.
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — delete `_buildRecipeSelectorFab` and the `appBarActions: [_buildRecipeSelectorFab()]` line. Pass `onPickRecipe` to `MealImageSection` via a small helper that returns `null` when the user has no recipes (so the third button doesn't render) and the recipe-sheet-opener closure otherwise.

**No router changes. No new files. No changes to `RecipeSelectorSheet` or `prefillFromRecipe`.**

### Widget plumbing

`MealImageSection` constructor:

```dart
const MealImageSection({
  super.key,
  required this.imageBytes,
  required this.isAnalyzing,
  required this.onImagePicked,
  required this.onClearImage,
  this.initialImageUrl,
  this.onPickRecipe,
});

final VoidCallback? onPickRecipe;
```

`_EmptyState` accepts `final VoidCallback? onPickRecipe;`. In its `Row`, after the existing Kamera + divider + Galerie, add:

```dart
if (onPickRecipe != null) ...[
  Container(
    width: 1,
    height: 48,
    margin: const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingLg,
    ),
    color: AppTheme.border,
  ),
  _PickerButton(
    icon: Icons.menu_book_outlined,
    label: 'Rezept',
    color: AppTheme.info,
    onTap: onPickRecipe!,
  ),
],
```

The 4:3 aspect ratio still fits three 64×64 buttons + two `spacingLg` dividers on every supported viewport (≈240 px wide for the row vs 360 px minimum viewport).

### Meal-tracker call site

Replace the existing `MealImageSection(...)` block in `_buildBody` so it passes `onPickRecipe: _onPickRecipe()`. Add a private helper to `_MealTrackerScreenState`:

```dart
VoidCallback? _onPickRecipe() {
  final hasRecipes =
      ref.watch(userRecipesProvider).value?.isNotEmpty ?? false;
  if (!hasRecipes) return null;
  return () async {
    final recipe = await showRecipeSelectorSheet(context);
    if (recipe == null || !mounted) return;
    ref.read(mealTrackerProvider.notifier).prefillFromRecipe(recipe);
  };
}
```

`_buildBody` is called from `build()`, which already has `ref`. Use `ref.watch` (not `ref.read`) so the third button appears as soon as the user's recipe list resolves — matching the AppBar-icon's previous reactivity via `Consumer`.

### Drop the AppBar action

Delete `_buildRecipeSelectorFab()` from `meal_tracker_screen.dart`. Remove the `appBarActions: [_buildRecipeSelectorFab()]` line from the `TrackerScreenScaffold(...)` call. `TrackerScreenScaffold.appBarActions` itself remains in the scaffold's API for future use; just not passed by this screen anymore.

## Tests

- Existing meal-tracker tests don't assert on the AppBar action, so dropping `_buildRecipeSelectorFab` doesn't break anything.
- Add one widget test in `test/screens/trackers/meal/widgets/meal_image_section_test.dart` (new file): pump `MealImageSection` with `onPickRecipe: () { tapped = true; }` and verify (a) the `Rezept` button renders, (b) tapping it fires the callback, and (c) when `onPickRecipe` is null the row contains exactly two `_PickerButton`s.

## Acceptance

- Empty-state image card shows three buttons in order: **Kamera** (red), **Galerie** (yellow), **Rezept** (`AppTheme.info`), separated by vertical dividers identical to the existing Kamera/Galerie divider.
- "Rezept" only appears when `userRecipesProvider.value?.isNotEmpty == true` (same gating as the old AppBar icon).
- Tapping "Rezept" opens `RecipeSelectorSheet`; tapping a recipe prefills title + ingredients + image (existing `prefillFromRecipe` flow, unchanged).
- The AppBar no longer shows the menu-book icon.
- Once any image OR recipe is picked, the empty-state card is replaced by the image preview — and the recipe-selector becomes unreachable until the user clears the image (accepted UX cost per the scope decision).
- `flutter analyze` clean. `dart format` clean.

## Out of scope

- Conditional in-card-vs-AppBar visibility (the rejected option C from brainstorm).
- A separate "change recipe after picking" affordance — accepted UX cost.
- Resizing the dashed-border card if three buttons feel cramped on tiny viewports — visual verification covers this; if it clips, follow-up.

## Risks

- The dashed-border card's intrinsic measurement was a Stack-related crash source in earlier work. Adding a third button doesn't change the layout primitive (still `Row` with `MainAxisAlignment.center`), so no new measurement hazard.
- The new button uses `AppTheme.info`. Visually verify it doesn't clash with the existing red+yellow combo — `AppTheme.info` is the meal-tracker's established blue ("Getränk hinzufügen" uses it), so it's already in the palette.
