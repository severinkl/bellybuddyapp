# Recipes callout polish + editor layout fix — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** Four small UX/layout changes layered on top of `feat/recipes-ux-polish`

## Problem

Four issues surfaced after PR #68:

1. The explanation copy on the meal-success bottom callout uses "Tipp", which is German-ambiguous (gesture vs. hint).
2. Tapping "Als Rezept speichern" makes the entire callout collapse. The user gets no in-place feedback that the save succeeded — the button just disappears.
3. If a recipe with the same title already exists, the user can still tap save and create a duplicate. The button should pre-detect the duplicate and render in the saved state from the start.
4. Opening `RecipeEditorScreen` in edit mode crashes with `BoxConstraints forces an infinite width` at `recipe_editor_screen.dart:251` (the `OutlinedButton` "Hinzufügen"). The Stack/AspectRatio in `MealImageSection`'s `_UrlImagePreview` (only present in edit mode) triggers intrinsic-width measurement up the tree, which the `Row + Expanded(TextField)` pattern can't survive.

## Goal

- Replace "Tipp" with neutral copy.
- Keep the save button visible after save; swap label + disable.
- Detect duplicate titles before render.
- Restructure the ingredient input so the editor never crashes regardless of intrinsic measurement.

## Approach

### 1. Copy edit

In `lib/screens/trackers/meal/meal_tracker_screen.dart`, change the explanation `Text` inside `_buildSaveAsRecipeBottom` from:

> Speicher diese Mahlzeit als Rezept und trag sie später mit einem Tipp wieder ein.

to:

> Speicher diese Mahlzeit als Rezept, um sie später schneller wieder einzutragen.

Single-line edit. No structural change.

### 2. Button text swap + gray-out on save

Today the parent collapses the slot via `successBottomCallout: _savedAsRecipe ? null : _buildSaveAsRecipeBottom(state)`. The new shape: always render the callout when create mode is active; let the button itself reflect saved state.

Changes inside `_buildSaveAsRecipeBottom(state)`:

```dart
Widget _buildSaveAsRecipeBottom(MealTrackerState state) {
  final saved = _savedAsRecipe;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Speicher diese Mahlzeit als Rezept, um sie später schneller wieder einzutragen.',
          style: TextStyle(
            fontSize: AppTheme.fontSizeCaption,
            color: AppTheme.mutedForeground,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        AppConstants.gap8,
        BbButton(
          label: saved ? 'Als Rezept gespeichert' : 'Als Rezept speichern',
          icon: saved ? Icons.check : Icons.bookmark_add_outlined,
          isLoading: _savingAsRecipe,
          onPressed: saved ? null : () => _saveAsRecipe(state),
        ),
      ],
    ),
  );
}
```

The parent's `successBottomCallout:` line drops the `_savedAsRecipe ? null : …` ternary and just passes `_buildSaveAsRecipeBottom(state)`. The slot stays mounted; the button becomes the visible state indicator.

`BbButton` with `onPressed: null` already renders the disabled style (grayed surface). Confirm the contract by reading `BbButton`. If grayed-out treatment isn't visually distinct enough, wrap the BbButton in `Opacity(opacity: saved ? 0.55 : 1.0)` (post-implementation tweak).

The success SnackBar in `_saveAsRecipe` is dropped — the visible button state is the new feedback. Error SnackBar stays.

### 3. Pre-detect duplicate title

In `_MealTrackerScreenState`, the existing `_savedAsRecipe` flag is set only after a manual save inside `_saveAsRecipe`. Add pre-detection:

- Add a method `bool _hasMatchingRecipe(String title)` that consults `ref.read(userRecipesProvider).value` (a `List<UserRecipe>?`). Compare via `recipe.title.trim().toLowerCase() == title.trim().toLowerCase()`. Empty / null list → false.
- In the `successBottomCallout` build path: instead of `final saved = _savedAsRecipe;`, derive `final saved = _savedAsRecipe || _hasMatchingRecipe(state.title);`.
- Trigger `userRecipesProvider.notifier.fetch()` in `_MealTrackerScreenState.initState`'s post-frame callback (already exists for the FAB visibility). Confirm by reading the file. If absent, add — fetch is idempotent and the provider's `force: false` short-circuits when cached.

This means: a meal with title "Curry mit Reis" tracked when a `Curry mit Reis` recipe already exists will show "Als Rezept gespeichert" (disabled) the moment the success screen mounts.

Subtlety: title comparison is case-insensitive + trim-insensitive. A more robust comparison would Unicode-normalize, but trim+lowercase covers 99% of real-world overlap (and the user owns both rows).

### 4. Editor layout fix — vertical stack ingredient input

In `lib/screens/recipes/recipe_editor_screen.dart`'s `_buildIngredientSection`, the current shape is:

```dart
Row(
  children: [
    Expanded(child: TextField(...)),
    SizedBox(width: AppConstants.spacingSm),
    OutlinedButton(...),
  ],
)
```

Replace with a vertical stack — TextField on its own line, "Hinzufügen" button right-aligned below:

```dart
TextField(
  controller: _ingredientController,
  decoration: const InputDecoration(
    hintText: 'Zutat eingeben',
    isDense: true,
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppConstants.spacingMd,
      vertical: AppConstants.spacingSm,
    ),
  ),
  style: const TextStyle(fontSize: AppTheme.fontSizeBody),
  onSubmitted: (_) => _addIngredient(),
  textInputAction: TextInputAction.done,
),
AppConstants.gap8,
Align(
  alignment: Alignment.centerRight,
  child: OutlinedButton(
    onPressed: _addIngredient,
    child: const Text('Hinzufügen'),
  ),
),
```

No `Row`, no `Expanded` — immune to intrinsic-width measurement. The TextField fills the parent Column (`crossAxisAlignment: stretch`), the button right-aligns via `Align`.

The `if (_ingredients.isNotEmpty)` Wrap of Chips below is unchanged.

### Files touched

Modified (3):
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — copy edit (#1), button-state swap inside `_buildSaveAsRecipeBottom` (#2), pre-detect helper + always-render slot (#3), drop the success SnackBar.
- `lib/screens/recipes/recipe_editor_screen.dart` — restructure `_buildIngredientSection`'s input row to a vertical stack (#4).
- (Possibly) `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart` if any case asserts the SnackBar string or the slot collapse.

### Tests
- Existing meal-tracker tests should continue to pass; only assertions tied to the dropped success SnackBar or the collapse-to-null behavior need updates.
- No new widget test specifically for the duplicate-title detection — covered indirectly by the visible button state. If you want explicit coverage: a notifier-level test that pumps the meal tracker with a saved meal whose title matches an existing recipe and asserts `find.text('Als Rezept gespeichert')`. Optional.

### Acceptance

- Bottom callout text reads `'Speicher diese Mahlzeit als Rezept, um sie später schneller wieder einzutragen.'`
- After successful save: button label is `'Als Rezept gespeichert'`, icon is `Icons.check`, button is grayed/disabled. Callout doesn't disappear.
- If the just-saved meal's title (case-insensitive, trimmed) matches any existing user recipe at success-screen mount, the button starts in the saved state.
- Editing an existing recipe (`/recipe/:id/edit`) opens without a `BoxConstraints forces an infinite width` crash. Adding an ingredient still works (tap the right-aligned "Hinzufügen" button or hit return on the field).

### Risk
- The button-style "disabled" rendering depends on `BbButton.onPressed: null` painting a grayed surface. If the visual difference is too subtle, the spec allows wrapping in `Opacity(0.55)` as a follow-up. Verify on a real device during smoke.
- Title comparison is case+trim-only — a user who titles a recipe "Curry  mit Reis" (double space) creates a false negative. Acceptable.
- Removing the SnackBar removes a non-visual cue; the visible state change replaces it.

### Out of scope
- Unicode normalization of titles for duplicate detection.
- Animating the button label/icon transition between "speichern" and "gespeichert".
- Hunting down the upstream intrinsic-measurement source in `MealImageSection._UrlImagePreview` (the editor fix sidesteps it).
- Refactoring `_buildSaveAsRecipeBottom` into a private widget class — kept inline for now.
