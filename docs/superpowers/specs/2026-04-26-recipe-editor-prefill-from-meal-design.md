# Recipe editor prefilled from a recent meal — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** Change the "Aus kürzlicher Mahlzeit" flow on Rezepte to open the recipe editor pre-filled with the chosen meal, instead of saving the recipe immediately.

## Problem

Today, on Rezepte → `+` → "Aus kürzlicher Mahlzeit" → tap a meal, the picker sheet calls `userRecipesProvider.notifier.create(...)` directly and shows a "Zu Meine Rezepte hinzugefügt" SnackBar. Two issues:

1. The user has no chance to rename the recipe, edit ingredients, or change the image before saving — the meal's exact title, ingredients, and image become the recipe verbatim.
2. There's no way to back out: tapping a meal commits a `userRecipes.create` round-trip immediately.

## Goal

- Tapping a recent meal opens `/recipe/new` with the editor pre-filled from the meal (title, ingredients, image).
- The user can review and edit before tapping Speichern, or back out without saving.
- The "Neu erstellen" path of the chooser sheet stays unchanged (empty form + autofocused title).

## Approach

### Components & files

**Modify (3 files):**

- `lib/router/app_router.dart` — the `/recipe/new` route reads `state.extra` and forwards a `MealEntry` (if present) as `initialMeal` to `RecipeEditorScreen`.
- `lib/screens/recipes/recipe_editor_screen.dart` — add a constructor param `MealEntry? initialMeal`. Prefill `_title`, `_ingredients`, `_imageUrl` from it in `initState`. Disable `autofocusOnMount` when `initialMeal != null`.
- `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart` — replace `_saveMeal` (immediate `userRecipesProvider.create + SnackBar`) with `_openEditorWith(meal)` that pops the sheet and `context.push(RoutePaths.recipeNew, extra: meal)`.

**No new files. No new routes.**

### Editor change

```dart
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({
    super.key,
    this.recipeId,
    this.initialMeal,
  });

  /// Null → create mode (empty form). Non-null → edit mode (prefills via provider).
  final String? recipeId;

  /// When non-null and in create mode, pre-fills title/ingredients/image
  /// from this meal. Passed by the recent-meal picker sheet via GoRouter
  /// extra. Ignored in edit mode.
  final MealEntry? initialMeal;
}
```

In `initState`, after the existing `_isEditMode` branch:

```dart
if (!_isEditMode && widget.initialMeal != null) {
  final meal = widget.initialMeal!;
  _title = meal.title;
  _ingredients = List<String>.from(meal.ingredients);
  _imageUrl = meal.imageUrl;
}
```

This is a synchronous prefill (no async fetch needed) so it can run directly in `initState` — no post-frame callback. The first build paints the prefilled values.

In `build`, gate autofocus:

```dart
title: EditableAppBarTitle(
  initialTitle: _title,
  placeholder: 'Rezept benennen',
  autofocusOnMount: !_isEditMode && widget.initialMeal == null,
  onTextChanged: (v) => setState(() => _title = v),
),
```

The Save button enable-state already works correctly (`_title.trim().isEmpty` reads the prefilled `_title`).

### Sheet change

In `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`, replace `_saveMeal(BuildContext, MealEntry)` with:

```dart
void _openEditorWith(BuildContext context, MealEntry meal) {
  Navigator.of(context).pop(); // close the picker sheet
  context.push(RoutePaths.recipeNew, extra: meal);
}
```

The `ListTile.onTap: () => _saveMeal(context, meal)` becomes `onTap: () => _openEditorWith(context, meal)`.

The SnackBar ("Zu Meine Rezepte hinzugefügt") and the immediate `userRecipesProvider.notifier.create(...)` call are dropped, along with the surrounding `try/catch` and error SnackBar — nothing in the new flow throws, and the editor's existing `_save` already handles save errors.

### Router change

In `lib/router/app_router.dart`, the existing route:

```dart
GoRoute(
  path: RoutePaths.recipeNew,
  name: RouteNames.recipeNew,
  builder: (context, state) => const RecipeEditorScreen(),
),
```

becomes:

```dart
GoRoute(
  path: RoutePaths.recipeNew,
  name: RouteNames.recipeNew,
  builder: (context, state) => RecipeEditorScreen(
    initialMeal: state.extra is MealEntry ? state.extra as MealEntry : null,
  ),
),
```

The `is`-then-`as` pattern matches what `MealTrackerScreen`'s route already does for `initialRecipe`. The chooser sheet's "Neu erstellen" tap and any deep links to `/recipe/new` pass no `extra`, so `initialMeal` stays null and the form opens empty (unchanged behaviour).

## Tests

- **Update** `test/screens/recipes/recipe_editor_screen_test.dart`: add a "create mode prefilled from initialMeal" test that pumps `RecipeEditorScreen(initialMeal: testMealEntry(...))` and asserts:
  - title rendered in display mode (no `TextField` visible until tapped)
  - ingredient chips for each meal ingredient are present
  - tapping Speichern calls `repo.create` with the meal's title and ingredients
- **Update** any picker-sheet tests (search confirms there are none today; if added later, mock the GoRouter and assert `context.push(RoutePaths.recipeNew, extra: meal)` is invoked).
- The existing `cross_screen_ingredient_autocomplete_test.dart` and the editor's existing 4 tests should continue to pass — `initialMeal` defaults to `null`, so the no-prefill path is byte-identical.

## Acceptance

- Rezepte → `+` → "Aus kürzlicher Mahlzeit" → tap a meal opens the recipe editor (does NOT immediately create the recipe).
- Editor title, ingredients chips, and image are prefilled from the chosen meal.
- AppBar title is in display mode (not edit mode); tap to rename.
- Save button is enabled on first paint (prefilled title is non-empty).
- Backing out of the editor creates no recipe.
- Tapping Speichern calls `userRecipesProvider.notifier.create(...)` with the (possibly user-edited) values and pops to the recipes screen.
- Rezepte → `+` → "Neu erstellen" still opens an empty editor with the title autofocused.

## Out of scope

- A "Save & open editor" two-step from the chooser sheet — replaced wholesale.
- Discard-changes prompt on back-button. The recipe editor doesn't have one today; meal-tracker dirty-tracking depends on a seed baseline (a meal being edited). The prefill-from-meal flow has no recipe-side baseline (the recipe doesn't exist yet), so an unprompted back-out is acceptable.
- Carrying the meal `id` so the resulting recipe could later be "linked" to its source meal.

## Risks

- `MealEntry` and `UserRecipe` both expose `imageUrl: String?`. `MealImageSection` accepts `initialImageUrl: String?` and renders accordingly — same path used in edit mode, so the prefill works without further plumbing.
- `MealEntry.ingredients` is `List<String>` — same shape as `UserRecipe.ingredients`. Direct copy.
- The picker sheet's `Navigator.of(context).pop()` happens before `context.push`. If the modal-sheet pop scope and the route-push scope conflict, the push could land on a stale tree. The current code already does the equivalent in `_AddRecipeChooserSheet.onTap` (pop then `rootContext.push`), so this is the established pattern.
