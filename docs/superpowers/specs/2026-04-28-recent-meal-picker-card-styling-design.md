# Recent-meal picker card styling — design

**Date:** 2026-04-28
**Status:** Approved, ready for implementation plan
**Scope:** Make `RecentMealPickerSheet` (recipes tab → "+" → "Aus kürzlicher Mahlzeit") render meals with the same card-row styling as `RecipeSelectorSheet` (meal tracker → empty-state image card → "Rezept"). Extract the shared row primitives to `lib/widgets/common/`.

## Problem

The two sheets ask the user to pick from a list of titled-and-ingredient'd things, but render them with different chrome:

- `RecipeSelectorSheet` (after the redesign): card row with shadow, 56×56 thumbnail (image or `pastelForTitle` + book-icon), title (max 2 lines), ingredient chips (first 3).
- `RecentMealPickerSheet`: plain `ListTile` rows with `title` + a one-line subtitle of the form `'${date} · ${first3Ingredients}'`. No image, no chips, no card chrome.

The visual mismatch is jarring because both pickers serve the same intent: "pick one of these things to seed something else". The recipe sheet is the polished pattern; the meal picker should match.

## Goal

`RecentMealPickerSheet` rows look indistinguishable from `RecipeSelectorSheet` rows, with the date dropped (the picker title "Kürzliche Mahlzeiten" already conveys the temporal scope, and the precise date isn't load-bearing for the "pick a meal to convert into a recipe" task).

The shared row primitives move to `lib/widgets/common/` so both sheets — and any future third sheet with the same row pattern — import them.

## Approach

### Component layout

**Create (3 in `lib/widgets/common/`):**

- `bb_sheet_row.dart` — `BbSheetRow({required VoidCallback onTap, required Widget leading, required Widget child})`. Soft-elevated white card shell: `Material(color: AppTheme.background, borderRadius: radiusLg, clipBehavior: antiAlias, elevation: 1, shadowColor: Colors.black.withValues(alpha: 0.08)) > InkWell(onTap) > Padding(paddingSm) > Row(children: [leading, SizedBox(width: spacing12), Expanded(child: child)])`.
- `bb_pastel_thumb.dart` — `BbPastelThumb({required String title, String? imageUrl})`. 56×56 (`iconBadgeXl`) rounded thumbnail with `radiusMd`. When `imageUrl != null`: `SignedPathImage(pathOrUrl: imageUrl, width: 56, height: 56, placeholder: Container(color: AppTheme.muted), errorWidget: <pastel fallback>)`. Otherwise: `Container(color: pastelForTitle(title), borderRadius: radiusMd, alignment: center, child: Icon(Icons.menu_book_outlined, color: AppTheme.foreground.withValues(alpha: 0.45), size: iconSizeMd))`.
- `bb_ingredient_chip.dart` — `BbIngredientChip({required String label})`. `Container(padding: spacingSm horizontal, spacing2 vertical, decoration: BoxDecoration(color: AppTheme.muted, borderRadius: radiusSm)) > Text(label, style: fontSizeCaption + mutedForeground)`.

**Modify (2):**

- `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart` — delete the private `_SheetRow`, `_RecipeThumb`, `_IngredientChip`. `_RecipeRowCard.build` swaps to `BbSheetRow(leading: BbPastelThumb(title: recipe.title, imageUrl: recipe.imageUrl), child: Column[Text title, gap4 + Wrap of BbIngredientChip])`. `_NewRecipeRow.build` swaps the `Material+InkWell+Padding+Row` shell to `BbSheetRow` with its existing primary-tinted "+" badge as `leading` and the bold "Neues Rezept erstellen" `Text` as `child`. Behaviour unchanged.
- `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart` — replace the `ListView.builder` of `ListTile`s with a `ListView.separated` of `BbSheetRow`s, padding `paddingMd horizontal`, separators `gap8`. Each row shaped exactly like `_RecipeRowCard`: `BbPastelThumb(title: meal.title, imageUrl: meal.imageUrl)` leading + `Column[Text(meal.title, maxLines: 2, fontSizeBody + w600), if ingredients.isNotEmpty: gap4 + Wrap of BbIngredientChip for first 3]`. Drop the `_subtitle(MealEntry)` helper. Keep `_openEditorWith(meal)` as the tap handler, the empty/loading branches ("Keine kürzlichen Mahlzeiten" / spinner), the title "Kürzliche Mahlzeiten", and the drag-handle + sheet shell unchanged.

### Recipe sheet — concrete `_RecipeRowCard` after extraction

```dart
class _RecipeRowCard extends StatelessWidget {
  const _RecipeRowCard({required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbSheetRow(
      onTap: onTap,
      leading: BbPastelThumb(title: recipe.title, imageUrl: recipe.imageUrl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          if (recipe.ingredients.isNotEmpty) ...[
            AppConstants.gap4,
            Wrap(
              spacing: AppConstants.spacingXs,
              runSpacing: AppConstants.spacingXs,
              children: [
                for (final ingredient in recipe.ingredients.take(3))
                  BbIngredientChip(label: ingredient),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

### Recipe sheet — `_NewRecipeRow` after extraction

```dart
class _NewRecipeRow extends StatelessWidget {
  const _NewRecipeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbSheetRow(
      onTap: onTap,
      leading: Container(
        width: AppConstants.iconBadgeXl,
        height: AppConstants.iconBadgeXl,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.add, color: AppTheme.primary),
      ),
      child: const Text(
        'Neues Rezept erstellen',
        style: TextStyle(
          fontSize: AppTheme.fontSizeBody,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
```

### Meal picker — list body after the change

```dart
ListView.separated(
  padding: const EdgeInsets.symmetric(
    horizontal: AppConstants.spacingMd,
  ),
  itemCount: _meals!.length,
  separatorBuilder: (_, _) => AppConstants.gap8,
  itemBuilder: (context, i) {
    final meal = _meals![i];
    return BbSheetRow(
      onTap: () => _openEditorWith(meal),
      leading: BbPastelThumb(title: meal.title, imageUrl: meal.imageUrl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            meal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          if (meal.ingredients.isNotEmpty) ...[
            AppConstants.gap4,
            Wrap(
              spacing: AppConstants.spacingXs,
              runSpacing: AppConstants.spacingXs,
              children: [
                for (final ingredient in meal.ingredients.take(3))
                  BbIngredientChip(label: ingredient),
              ],
            ),
          ],
        ],
      ),
    );
  },
),
```

`_subtitle(MealEntry)` is deleted, along with the import of `formatDateTimeShort` if it becomes unused.

## Tests

- Existing tests in `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart` (5) and `test/screens/recipes/widgets/recent_meal_picker_sheet_test.dart` (2) should continue to pass — they assert text and navigation, not layout primitives. Inspect the picker test for any `find.byType(ListTile)` that needs swapping to `find.byType(BbSheetRow)`.
- No new tests for the extracted widgets — they are trivially structural and exercised by the two sheets that consume them. If a regression appears around `BbPastelThumb`'s image-vs-pastel branch, add a focused test then.

## Acceptance

- Tapping "+ → Aus kürzlicher Mahlzeit" on the recipes screen opens a sheet whose rows are visually indistinguishable from `RecipeSelectorSheet`'s rows: same card chrome, same thumbnail, same ingredient chips.
- No date is shown in the meal-picker rows.
- Meal selection still navigates to `/recipe/new` with the meal as `extra` (existing behaviour from PR #70).
- `RecipeSelectorSheet` looks identical to before the extraction.
- `flutter analyze` clean. `dart format` clean. Existing 7 sheet-related tests pass unchanged.

## Out of scope

- "+ Neues Rezept" footer on the meal picker — the chooser sheet's "Neu erstellen" tile already serves that intent.
- Migrating `add_recipe_chooser_sheet`'s tiles to `BbSheetRow` — those are intentionally low-density `ListTile`s.
- Generalising `BbPastelThumb` to accept a custom fallback icon — extend later when a caller needs it.
- Sharing the drag-handle pill across sheets — pre-existing duplication; out of scope.

## Risks

- `_NewRecipeRow` uses `BbSheetRow` but a custom non-`BbPastelThumb` leading. The `BbSheetRow` API takes any `Widget` for `leading`, so this works without API contortions.
- `MealEntry.imageUrl` and `UserRecipe.imageUrl` are both `String?`; `BbPastelThumb` is model-agnostic, takes raw `String title, String? imageUrl`.
