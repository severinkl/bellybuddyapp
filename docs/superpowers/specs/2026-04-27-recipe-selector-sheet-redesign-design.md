# Recipe selector sheet redesign — design

**Date:** 2026-04-27
**Status:** Approved, ready for implementation plan
**Scope:** Replace the meal-tracker's recipe selector bottom sheet (currently a fixed-height list of `ListTile`s with gray-square placeholder images) with a card-based, search-enabled, auto-sized sheet that includes a "+ Neues Rezept erstellen" affordance.

## Problem

The current sheet (`recipe_selector_sheet.dart`) has three visible weaknesses on a real device:

1. **Empty-image placeholder is a flat gray square.** Recipes without a saved image render with `Container(color: AppTheme.muted)`, which reads as "broken" rather than "no image set".
2. **Fixed 80% viewport height regardless of content.** With 2-3 saved recipes, most of the sheet is empty space; the screen feels under-populated.
3. **No search or "create new" affordance.** Once a user has many recipes the only navigation is scrolling, and from this sheet there is no path to create a new recipe — they must dismiss, navigate to the recipes tab, and start over.

## Goal

The sheet:

1. Renders each recipe as a card with shadow + ingredient chips.
2. Auto-sizes (60% initial, draggable 40-92%) so few recipes don't yield empty space.
3. Has a pinned `RecipesSearchField` at the top, reusing the same FTS-backed search the recipes tab uses.
4. Has a "+ Neues Rezept erstellen" row at the bottom of the list as an empty-state escape hatch and a general convenience.
5. Replaces the gray-square placeholder with a deterministic pastel background (`pastelForTitle`) plus a faded `Icons.menu_book_outlined` glyph.

## Approach

### Components & files

**Modify (1 file):**
- `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart` — replace the `ListTile`-based body with: pinned title + `RecipesSearchField` + scrollable list of `_RecipeRowCard` tiles + pinned "+ Neues Rezept erstellen" footer. Swap `FractionallySizedBox(heightFactor: 0.8)` for `DraggableScrollableSheet`.

**No new top-level widgets.** `_RecipeRowCard`, `_RecipeThumb`, `_IngredientChip`, and `_NewRecipeRow` stay private to the sheet file (single use). `RecipesSearchField`, `pastelForTitle`, and `SignedPathImage` are reused as-is from elsewhere in the codebase.

### Sheet skeleton

```dart
showModalBottomSheet<UserRecipe>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: AppTheme.card,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppConstants.radiusXl),
    ),
  ),
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 0.92,
    expand: false,
    builder: (_, scrollController) => SafeArea(
      top: false,
      child: _RecipeSelectorBody(scrollController: scrollController),
    ),
  ),
);
```

`_RecipeSelectorBody` accepts `final ScrollController scrollController;` and passes it to the inner `ListView.builder`.

### Body layout

Top-down, all inside a `Column(crossAxisAlignment: stretch)`:

1. **Drag handle** (existing project pattern: `dragHandleWidth × dragHandleHeight` pill, top-centered).
2. **Title** "Rezept auswählen" (existing copy + style).
3. **`RecipesSearchField`** wrapped in `Padding(horizontal: spacingMd)`. The widget already binds to `userRecipesProvider.notifier.setQuery(...)` and reactively filters via the FTS column the recipes tab uses.
4. **`Expanded(child: ListView.builder(controller: scrollController, padding: paddingMd, …))`** — one `_RecipeRowCard` per recipe, separated by `gap8`. Empty filtered list → centered "Keine Treffer". Empty library → centered "Noch keine Rezepte".
5. **`_NewRecipeRow`** as a fixed footer in `Padding(paddingMd)` below the list (always visible — does not scroll with the list).

### `_RecipeRowCard`

```dart
class _RecipeRowCard extends StatelessWidget {
  const _RecipeRowCard({required this.recipe, required this.onTap});
  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      elevation: AppConstants.elevationCardSm,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              _RecipeThumb(recipe: recipe),
              AppConstants.gap12,
              Expanded(
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
                            _IngredientChip(label: ingredient),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

If `AppConstants.elevationCardSm` doesn't exist, add it (`static const double elevationCardSm = 1.0;`).

### `_RecipeThumb`

```dart
class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.recipe});
  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.imageUrl != null) {
      return SizedBox(
        width: AppConstants.iconBadgeXl,
        height: AppConstants.iconBadgeXl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: SignedPathImage(
            pathOrUrl: recipe.imageUrl,
            width: AppConstants.iconBadgeXl,
            height: AppConstants.iconBadgeXl,
            placeholder: Container(color: AppTheme.muted),
            errorWidget: _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: AppConstants.iconBadgeXl,
      height: AppConstants.iconBadgeXl,
      decoration: BoxDecoration(
        color: pastelForTitle(recipe.title),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        color: AppTheme.foreground.withValues(alpha: 0.45),
        size: AppConstants.iconSizeMd,
      ),
    );
  }
}
```

### `_IngredientChip`

```dart
class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          color: AppTheme.mutedForeground,
        ),
      ),
    );
  }
}
```

If `AppConstants.spacingXxs` doesn't exist, use `2.0` via a new constant (`static const double spacingXxs = 2.0;`).

### `_NewRecipeRow`

```dart
class _NewRecipeRow extends StatelessWidget {
  const _NewRecipeRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              Container(
                width: AppConstants.iconBadgeXl,
                height: AppConstants.iconBadgeXl,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: AppTheme.primary),
              ),
              AppConstants.gap12,
              const Text(
                'Neues Rezept erstellen',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Tap handler:
```dart
() {
  Navigator.of(context).pop();
  context.push(RoutePaths.recipeNew);
}
```

This pops the sheet (returns `null` to the meal-tracker so it doesn't try to prefill from a non-existent recipe) and pushes the recipe editor on top of the meal tracker.

### Search-state lifecycle

`RecipesSearchField` writes to `userRecipesProvider.notifier.setQuery(...)`, which is shared with the recipes tab. If the user opens the sheet, types a query, and dismisses without picking, the recipes tab will show filtered results next time it's opened — surprising behaviour.

Fix: in `_RecipeSelectorBodyState.dispose`, clear the query:

```dart
@override
void dispose() {
  // Clear sheet-scoped search so the recipes tab isn't pre-filtered.
  ref.read(userRecipesProvider.notifier).setQuery(null);
  super.dispose();
}
```

This is safe — `setQuery(null)` triggers a re-fetch of the unfiltered list, which is what the recipes tab expects on its next mount.

## Tests

Create `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`:

- **Renders one card per recipe**: pump the sheet with `userRecipeRepositoryProvider` overridden to return 3 recipes; assert 3 `_RecipeRowCard`s (or simply `find.text(recipe.title)`).
- **Tapping a card pops with that recipe**: pump, tap the second card, assert the modal sheet popped with the matching `UserRecipe`.
- **Tapping "+ Neues Rezept erstellen" navigates to `/recipe/new`**: use the 2-route GoRouter pattern from `recent_meal_picker_sheet_test.dart` with a sentinel route. Tap → assert sentinel renders.
- **Typing in the search field calls `setQuery`**: override `userRecipesProvider` with a fake notifier that records `setQuery` calls; type into the search field; assert the call. (Or assert via the visible result list if the FTS path is easier to wire.)
- **Empty library shows "Noch keine Rezepte"**: pump with empty recipes, no search → expect that text + the "+ Neues Rezept erstellen" row still visible.
- **Empty filtered list shows "Keine Treffer"**: pump with recipes but a query that yields no matches → expect that text.
- **`dispose` clears active query**: pump, type a query, dismiss the sheet, verify `setQuery(null)` was the last call.

## Acceptance

- Sheet opens at 60% viewport height, drag-resizable between 40% and 92%.
- Each recipe is rendered as a card with rounded image (or pastel placeholder + book icon when `imageUrl == null`), title (max 2 lines), and up to 3 ingredient chips.
- Pinned `RecipesSearchField` at the top filters the list reactively via FTS.
- Pinned "+ Neues Rezept erstellen" row at the bottom pops the sheet and pushes `/recipe/new`.
- Empty filtered results show "Keine Treffer".
- Empty library shows "Noch keine Rezepte" with the "+ Neues Rezept erstellen" row still visible.
- Dismissing the sheet (any path) clears the active query so the recipes tab isn't pre-filtered.
- `flutter analyze` clean. `dart format` clean.

## Out of scope

- Keyboard-aware sheet height (`MediaQuery.viewInsets`) — `DraggableScrollableSheet` handles content scrolling; the keyboard takes the bottom inset.
- Multi-select to track multiple recipes — separate feature.
- Sort options (recently used, alphabetical) — premature.
- A `_RecipeRowCard` shared with the recipes tab — the tab uses a vertical-grid `RecipeCard`; the sheet's row layout differs enough that extracting now would force premature parameter sprawl.
- A custom shimmer for the thumb — reuse the existing `SignedPathImage.placeholder` mechanism.

## Risks

- `DraggableScrollableSheet` interacts oddly with keyboards on some Android versions if the inner `ListView` doesn't accept the controller correctly. Mitigation: pass `scrollController` into the `ListView.builder` and verify on the user's smoke pass.
- The "+ Neues Rezept" row uses `context.push(RoutePaths.recipeNew)` — the same pattern as the chooser sheet. The route is already wired (PR #70's earlier work) and accepts no `extra` for this entry, landing on the empty-form flow.
- `pastelForTitle` is deterministic per title, so re-renders don't flicker. Confirmed by inspection; no flicker risk.
