# Recipes list redesign + search — design

**Date:** 2026-04-25
**Status:** Approved, ready for implementation plan
**Scope:** `MyRecipesTab` UI + Postgres FTS on `user_recipes`

## Problem

The current `MyRecipesTab` renders user recipes as a vertical list of small thumbnail rows. With a growing recipe set the list reads as a wall of small text. Users have no way to search, and recipes without an image render as a placeholder icon that visually flags the row as "broken" rather than as a normal item.

## Goal

1. Replace the row list with a 2-column image grid (chosen over dense rows / hero cards).
2. Pin a search bar above the grid backed by Postgres full-text search.
3. Drop the "broken-image" feel for missing thumbnails — render a deterministic pastel block with a title monogram instead.

Non-goals: changes to the detail screen, the editor, the chooser sheet, the recipe selector inside the meal tracker, or the Inspiration tab.

## Approach

### 1. Layout — 2-column image grid

`MyRecipesTab` body becomes a `GridView.builder`:
- `crossAxisCount: 2`
- `crossAxisSpacing: AppConstants.spacingSm`
- `mainAxisSpacing: AppConstants.spacingSm`
- `childAspectRatio: 0.78` (image takes a 1.1:1 block; body adds ~32% on top)
- `padding: AppConstants.paddingMd`

`RecipeListTile` is deleted. New widget `RecipeCard`:
- Top: `AspectRatio(aspectRatio: 1.1)` containing either `SignedPathImage` or the pastel fallback.
- Body: `Padding` (`AppConstants.paddingSm` horizontal, `spacingSm` vertical) with title (1 line, `AppTheme.fontSizeBody`, `FontWeight.w600`, ellipsis) and first 3 ingredients joined by ` · ` (1 line, `fontSizeCaption`, `mutedForeground`, ellipsis).
- Card chrome: `AppTheme.card`, `BorderRadius.circular(AppConstants.radiusLg)`, soft shadow.
- The whole card is an `InkWell` → `context.push(RoutePaths.recipeDetailFor(recipe.id))`.

The empty-state on `MyRecipesTab` (no recipes at all) is unchanged — mascot + "Erstes Rezept erstellen" CTA.

### 2. Pastel image fallback

New helper `lib/utils/title_color.dart`:

```dart
import 'package:flutter/material.dart';

Color pastelForTitle(String title) {
  final hash = title.hashCode.abs();
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.45, 0.86).toColor();
}
```

Deterministic per title; soft, low-saturation, light pastel that reads on the existing pink screen background.

`RecipeCard`'s fallback path renders a `Container(color: pastelForTitle(title))` whose child is the title's first letter (uppercased; empty-title fallback is `?`) centered in `FontWeight.w300` × `AppTheme.fontSizeTitleLG`, color `AppTheme.foreground.withValues(alpha: 0.45)`. Reads as a decorative tile with a monogram, not a missing-image error.

### 3. Postgres full-text search

New migration `supabase/migrations/20260425120000_user_recipes_fts.sql`:

```sql
alter table user_recipes
  add column search_tsv tsvector
  generated always as (
    to_tsvector(
      'german',
      coalesce(title, '') || ' ' || coalesce(array_to_string(ingredients, ' '), '')
    )
  ) stored;

create index user_recipes_search_tsv_idx on user_recipes using gin (search_tsv);
```

A generated column means Postgres maintains it on every write — no triggers, no app-side maintenance. The `'german'` config covers stemming + stopwords.

New `UserRecipeService.searchForUser(userId, query)`:

```dart
Future<List<UserRecipe>> searchForUser(String userId, String query) async {
  final tokens = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return fetchForUser(userId);
  final tsQuery = tokens.map((t) => '$t:*').join(' & ');
  try {
    final data = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .textSearch('search_tsv', tsQuery, config: 'german')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => UserRecipe.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e, st) {
    _log.error('searchForUser failed', e, st);
    rethrow;
  }
}
```

`:* ` per token gives prefix matching ("kart" matches "Kartoffel"), and `&` requires every token to match (multi-word query narrows). Empty query short-circuits to `fetchForUser`.

`UserRecipeRepository` delegates `searchForUser` to the service.

### 4. Provider — `setQuery` with debounce

`UserRecipesNotifier` gains:

```dart
String? _query;
Timer? _debounce;

void setQuery(String? q) {
  final next = (q == null || q.trim().isEmpty) ? null : q.trim();
  if (_query == next) return;
  _query = next;
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    fetch(force: true);
  });
}
```

`fetch({bool force = false})` is updated to branch on `_query`:

```dart
final repo = ref.read(userRecipeRepositoryProvider);
final recipes = (_query == null)
    ? await repo.fetchForUser(userId)
    : await repo.searchForUser(userId, _query!);
```

`dispose()` (or `onDispose` callback in Riverpod's `Notifier`) cancels the timer:

```dart
@override
AsyncValue<List<UserRecipe>> build() {
  ref.onDispose(() => _debounce?.cancel());
  return const AsyncValue.loading();
}
```

`_query` deliberately lives on the notifier (not in `AsyncValue<List<UserRecipe>>`) — it's input state, not output state, and putting it in the value would force every list-rendering screen to thread it through manually.

### 5. Search bar widget

New `lib/screens/recipes/widgets/recipes_search_field.dart`:

- `ConsumerStatefulWidget` owning a `TextEditingController`.
- Material `TextField` with `prefixIcon: Icons.search`, `hintText: 'Rezept suchen…'`, `OutlineInputBorder` with `BorderRadius.circular(AppConstants.radiusRound)`, `filled: true`, `fillColor: AppTheme.card`.
- `onChanged` → `ref.read(userRecipesProvider.notifier).setQuery(value)` (provider handles the debounce).
- `suffixIcon` is an `IconButton(Icons.clear)` shown when the controller text is non-empty; tap clears the controller and calls `setQuery(null)`.
- Disposes the controller on `dispose()`.

`MyRecipesTab` puts the search field in a `Padding(padding: AppConstants.paddingMd, child: RecipesSearchField())` ABOVE the grid. The search field stays pinned (not part of `GridView`'s scroll) — `MyRecipesTab` becomes a `Column([RecipesSearchField, Expanded(GridView...)])`.

### 6. Empty states

Three states for the data branch of `userRecipesProvider`:
- **No recipes at all** (user has never saved one): existing mascot + "Erstes Rezept erstellen" CTA. The search bar is hidden in this state — searching empty data is meaningless.
- **Recipes exist, query returns nothing**: search bar visible, grid replaced with centered "Keine Treffer für „<query>"" text in `AppTheme.mutedForeground`.
- **Recipes exist, results present**: grid as described above.

The "no recipes" check uses the underlying *unfiltered* count, which is not currently available on the provider state. Two options:
- (chosen) Track a separate `bool _hasAnyRecipes` derived from the most recent unfiltered fetch — set true after `fetchForUser` returns ≥ 1 recipe and never falls back to false until the user deletes all of them. The mascot empty-state shows when `_hasAnyRecipes == false` AND `_query == null`. Inspect implementation when wiring; simplest may be to keep it as a side-effect of `fetchForUser` returning a result.
- Re-fetch the unfiltered list alongside any search — wasteful.

If implementation finds (chosen) too messy, fall back to: always show the search bar; render the mascot empty-state only when `_query == null && data.isEmpty`. The trade-off is that a user who has 1 recipe and types "xyz" briefly sees the mascot CTA instead of "Keine Treffer". Decide at implementation time; both behaviors are acceptable and the mascot fallback is the simpler default.

### 7. RecipeSelectorSheet (meal tracker)

Unchanged. The selector keeps the unfiltered fetch and renders rows (the dropped `RecipeListTile` is replaced with a slimmed-down inline `ListTile` inside the sheet body — not a widget extraction). Selector users want the full list right now; search there is overkill.

## Files touched

New (5):
- `lib/utils/title_color.dart`
- `lib/screens/recipes/widgets/recipe_card.dart`
- `lib/screens/recipes/widgets/recipes_search_field.dart`
- `supabase/migrations/20260425120000_user_recipes_fts.sql`
- Tests for each: `test/utils/title_color_test.dart`, `test/screens/recipes/widgets/recipe_card_test.dart`, `test/screens/recipes/widgets/recipes_search_field_test.dart`.

Modified (5):
- `lib/screens/recipes/my_recipes_tab.dart` — grid layout + search field wiring.
- `lib/services/user_recipe_service.dart` — `searchForUser`.
- `lib/repositories/user_recipe_repository.dart` — `searchForUser` delegation.
- `lib/providers/user_recipes_provider.dart` — `_query` + `setQuery` + debounce + branched fetch.
- `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart` — drop the `RecipeListTile` import; inline a minimal `ListTile` row.

Deleted (2):
- `lib/screens/recipes/widgets/recipe_list_tile.dart`
- `test/screens/recipes/widgets/recipe_list_tile_test.dart`

## Tests

- `pastelForTitle` — deterministic across runs; distinct titles produce distinct hues; empty string returns a valid color (no crash).
- `RecipeCard` — renders title, ingredient line; renders image branch when imageUrl provided; renders pastel + monogram branch when null; tap fires onTap.
- `recipes_search_field` — pumping a query calls `setQuery`; suffix clear icon appears when text is non-empty and clears + calls `setQuery(null)`.
- `UserRecipeService.searchForUser` — multi-token query becomes `'tok1:* & tok2:*'`; single token gets `:*`; blank query short-circuits to `fetchForUser`. (We can't easily mock the Supabase chained builder, so the assertion is on the produced `tsQuery` string — extract the formatting into a small private static method `_buildTsQuery(query)` that's directly testable.)
- `UserRecipesNotifier.setQuery` — debounces (300ms), repeated rapid calls only fire once, last value wins; identical query is a no-op; `dispose` cancels the pending timer.
- `MyRecipesTab` — renders the grid for non-empty data; renders "Keine Treffer" copy when `_query` is set and data is empty; renders mascot CTA when no recipes exist (whichever empty-state path was chosen at implementation time — the test should match the implementation).
- Migration applies cleanly on `supabase db reset` (manual smoke).

## Rollout

Ship as one PR against `develop`. The migration runs server-side on deploy. The FTS index covers small lists efficiently and only matters once recipe counts grow. Clients on older builds that don't yet call `searchForUser` continue to use `fetchForUser` and see no change.

Manual smoke before merge:
1. With ≥ 5 recipes: open Rezepte → Meine Rezepte. Confirm 2-column grid renders, mix of imaged + pastel-monogram cards.
2. Type a partial title token (e.g. "kart"). Grid filters; results match prefix. Hold typing — confirm debounce (no flicker / no per-key fetch storm).
3. Tap clear icon → grid returns to full set.
4. Search a non-existent token → "Keine Treffer für „xyz"".
5. Delete all recipes → mascot empty-state reappears.
6. Track a meal, confirm the recipe selector still works (unchanged).

## Risk

Low. The migration is additive (generated column + index, no `alter` on existing data). The grid + card swap is contained to `MyRecipesTab` and one widget. Provider gains a `Timer` that's cleaned up on `onDispose`. FTS query formatting is testable in isolation.

## Acceptance

- 2-column `GridView` of `RecipeCard` widgets on `MyRecipesTab`, sorted newest-first.
- Image branch uses `SignedPathImage`; null-imageUrl branch uses `pastelForTitle` + monogram.
- Pinned `RecipesSearchField` above the grid; debounced `setQuery` flows through to Postgres FTS.
- `searchForUser` uses prefix-match per token (`token:*`) joined with `&`; empty query falls back to `fetchForUser`.
- Migration adds `search_tsv` generated column + GIN index.
- "Keine Treffer" copy on empty result; mascot CTA on truly-empty recipe set.
- `flutter analyze` clean; `dart format` applied; new + existing tests green.

## Out of scope

- Result ranking (`textSearch` returns matches in the existing `created_at desc` order; ranking by `ts_rank_cd` is a follow-up).
- Synonym dictionaries / fuzzy spell tolerance.
- Sort / filter chips on the grid.
- Search on the Inspiration tab (placeholder).
- Search inside the meal-tracker recipe selector sheet.
