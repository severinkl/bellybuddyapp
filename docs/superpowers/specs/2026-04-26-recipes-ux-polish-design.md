# Recipes UX polish — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** Four small UX changes layered on top of `feat/recipes-grid-search`

## Problem

Four pieces of friction surfaced after the grid + FTS PR (#67):

1. The "Als Rezept speichern" action sits as one of two stacked secondary chips on the meal-success screen. Users miss it (it reads as just-another shortcut), and there's no in-app explanation of what saving a recipe does for them.
2. `MyRecipesTab` empty state has a one-liner explanation, but the wording could be sharper around the "wiederkehrend" use case the feature is built for.
3. `RecipesScreen` uses `SegmentedButton` to switch between Meine Rezepte / Inspiration. Material's segmented button renders a checkmark inside the active segment by default — meaningless here because the user is switching views, not confirming a choice.
4. The "Aus Rezept auswählen" entry-point in the meal tracker is a heavy `OutlinedButton.icon` row above the date/time chips. It competes with the date chips for visual weight and feels like a primary action when it's discovery sugar.

## Goal

Four targeted changes — no data-layer impact:

- 1 / Promote the recipe-save action with a dedicated bottom callout and a one-line explanation.
- 2 / Sharpen the empty-state copy.
- 3 / Replace `SegmentedButton` with a checkmark-free pill toggle.
- 4 / Replace the OutlinedButton row with a small floating book-icon button in the top-right of the meal-tracker body.

Out of scope: reusing the new tab widget elsewhere, animation polish on the FAB show/hide, accessibility tooltips beyond Flutter's defaults.

## Approach

### 1. Save-as-recipe bottom callout (meal success screen)

**`BbSuccessOverlay`** gains an optional `Widget? bottomCallout`. Rendered inside the existing `SafeArea(top: false, …)`, after the actions list, separated by `AppConstants.gap16`. No layout change for callers that don't pass it.

**`MealTrackerScreen`** stops including the recipe action in `successActions` (which now contains only the existing `Getränk hinzufügen` shortcut). The recipe action moves into a new helper `_buildSaveAsRecipeBottom(MealTrackerState)` passed as `bottomCallout`:

- Wrapping `Column` (`crossAxisAlignment: stretch`, `mainAxisSize: min`):
  - `Text` explanation: `'Speicher diese Mahlzeit als Rezept und trag sie später mit einem Tipp wieder ein.'`
    - `AppTheme.fontSizeCaption`, `AppTheme.mutedForeground`, `textAlign: center`, `maxLines: 2`.
  - `AppConstants.gap8`.
  - `BbButton` (primary style, full-width) labeled `'Als Rezept speichern'` with `Icons.bookmark_add_outlined`.
- Disabled / hidden after the first successful save (`_savedAsRecipe == true` → `bottomCallout: null` so the slot disappears entirely; the success overlay's vertical rhythm collapses cleanly).
- Existing flags `_savingAsRecipe` / `_savedAsRecipe` and SnackBars stay as-is — only the rendering moves.

The drink shortcut continues to render through `successActions` so its existing centered-link-with-icon treatment is unchanged.

### 2. Empty-state copy

`MyRecipesTab._EmptyState` body text changes from

> Speichere Mahlzeiten als Rezepte, um sie schnell wieder einzutragen.

to

> Speichere wiederkehrende Mahlzeiten als Rezepte, um sie später schneller wieder einzutragen.

Single-line edit. No layout, no test churn unless an existing assertion pins the old copy verbatim — in which case update the matcher.

### 3. Tab style — pill toggle without checkmark

New widget `lib/screens/recipes/widgets/recipes_tab_toggle.dart`:

- `StatelessWidget` with `value`, `onChanged`, `segments: List<String>` (used here as a 2-segment pill but stays general).
- Outer pill: `Container(decoration: BoxDecoration(color: AppTheme.muted, borderRadius: BorderRadius.circular(AppConstants.radiusRound)))` with `AppConstants.spacingXs` inner padding.
- `Row` of `Expanded` `_Segment` children (one per label). Active segment paints `AppTheme.card` background with `AppConstants.radiusRound` corners + light shadow, label in `AppTheme.foreground` `FontWeight.w600`. Inactive segments: transparent background, label in `AppTheme.mutedForeground` `FontWeight.w500`.
- Tap on a segment fires `onChanged(index)`.

`RecipesScreen` swaps `SegmentedButton<_RecipesView>` for `RecipesTabToggle(value: _view.index, segments: const ['Meine Rezepte', 'Inspiration'], onChanged: (i) => setState(() => _view = _RecipesView.values[i]))`. State machinery unchanged.

### 4. Recipe selector — floating book-icon top-right

Replace the visible `Consumer + OutlinedButton.icon` row at the top of `_buildBody` in `MealTrackerScreen`. The provider-watch logic that hides the entry-point when no recipes exist stays — only the visual changes.

- Wrap the body's `SingleChildScrollView` in a `Stack(clipBehavior: Clip.none)`. The scroll view is the first stack child.
- Second stack child: a `Positioned(top: AppConstants.spacingSm, right: AppConstants.spacingSm)` containing a `Consumer` that returns `SizedBox.shrink()` when no recipes, otherwise a `Tooltip(message: 'Aus Rezept übernehmen', child: …)` wrapping a `Material(shape: CircleBorder(), color: AppTheme.card, elevation: 2, child: InkWell(customBorder: const CircleBorder(), onTap: …, child: SizedBox(width: 32, height: 32, child: Icon(Icons.menu_book_outlined, size: AppConstants.iconSizeSm, color: AppTheme.foreground))))`.
- `onTap` opens `RecipeSelectorSheet` and on result calls `notifier.prefillFromRecipe(recipe)` + syncs `_titleController.text` — same handler as today, just relocated.

The OutlinedButton row + its surrounding `Padding(bottom: spacingMd)` go away. The `_buildBody` content shifts up by that amount, which is the intended visual change.

## Files touched

New (2):
- `lib/screens/recipes/widgets/recipes_tab_toggle.dart`
- `test/screens/recipes/widgets/recipes_tab_toggle_test.dart`

Modified (5):
- `lib/widgets/common/bb_success_overlay.dart` — `bottomCallout` named param + slot.
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — move recipe action to `bottomCallout`; replace OutlinedButton row with the Stack-positioned FAB; tooltip + circular surface.
- `lib/screens/recipes/my_recipes_tab.dart` — empty-state copy.
- `lib/screens/recipes/recipes_screen.dart` — swap tab widget.
- `test/widgets/common/bb_success_overlay_test.dart` — add a `bottomCallout` rendering case.
- `test/screens/recipes/recipes_screen_test.dart` — update tab-switch assertions if any pinned the SegmentedButton class.
- `test/screens/recipes/my_recipes_tab_test.dart` — update if it pins the old copy.
- `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart` — update if it pins the action's location inside `successActions`.

## Tests

- `recipes_tab_toggle_test.dart`: renders both labels; tapping the inactive label fires `onChanged(otherIndex)`; active segment has visually distinct background (assert via descendant Container color).
- `bb_success_overlay_test.dart`: renders `bottomCallout` when provided; layout still works with no actions + no callout.
- `recipes_screen_test.dart`: tab labels still findable; tapping `Inspiration` swaps the body to the placeholder block; default view is Meine Rezepte.
- Meal-tracker integration: tap the floating icon → recipe selector sheet opens. (If no integration test reaches this code path, a widget-level test on the meal tracker with provider overrides covers it.)

## Risk

Low. The `BbSuccessOverlay.bottomCallout` param defaults to `null` — every existing call site renders identically. The pill-toggle widget is structurally simpler than `SegmentedButton`, no semantic difference. The Stack-positioned FAB sits OVER the scroll content but inside the existing `SafeArea`-padded body; no overlap with appbar or bottom edges.

## Acceptance

- Meal-tracker success screen shows: success message → drink shortcut (existing) → bottom callout with explanation + `Als Rezept speichern` primary button. After tapping save: bottom callout collapses entirely (no awkward disabled state lingering).
- `MyRecipesTab` empty state shows the new wording.
- `RecipesScreen`'s tabs render as a pill toggle without a checkmark; tap-to-switch unchanged.
- Meal-tracker top-right shows a 32×32 floating circular book-icon button when the user has ≥ 1 recipe; hidden otherwise. Tap opens the existing `RecipeSelectorSheet`.
- `flutter analyze` clean, `dart format` applied, all existing + new tests green.

## Out of scope

- Reusing `RecipesTabToggle` elsewhere in the app.
- Show/hide animation on the floating recipe-icon when the recipe count crosses 0 ↔ 1.
- Custom hover/long-press tooltip styling beyond Flutter's `Tooltip` defaults.
- A11y label review across the four touched widgets (the new code uses standard Material widgets that ship with sensible defaults).
- Adapting the success-overlay layout for landscape / very small phones (the bottom callout adds ~80 px of height; if a Pixel 3a in landscape clips, that's a follow-up).
