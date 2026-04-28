# User-saved recipes — design

**Date:** 2026-04-24
**Status:** Approved, ready for implementation plan
**Scope:** New `user_recipes` table + UI for saving, browsing, editing, and reusing user meals as recipe templates

## Problem

Today, users who eat similar meals repeatedly have to re-enter the title and ingredients every time — the meal tracker has no notion of "this is something I eat often." The `Rezepte` tab shows only a placeholder ("Rezepte kommen bald!") and the existing curated-recipe layer (`recipes` table + `RecipeService` + `RecipeDetailSheet`) is built but dormant.

Users want to save meals they've tracked as reusable templates and select from them when adding a new meal.

## Goal

Introduce a first-class "user recipe" concept: a meal template the user owns, creates, edits, deletes, and consumes during meal tracking. Replace the Rezepte placeholder with a two-tab screen (Meine Rezepte / Inspiration — the latter keeps today's coming-soon UI). Wire a recipe selector into the meal tracker and a "save as recipe" action onto the meal success overlay.

Out of scope: curated / Inspiration recipes. The existing `recipes` table and its dormant service stay untouched for a future feature.

## Approach

### Data model

A new table, `user_recipes`, separate from the curated `recipes` table. Mixing user content with app-curated content in one table would require `user_id IS NULL` filtering on every curated query and complicate RLS; separation keeps both concepts simple.

```sql
create table user_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  ingredients text[] not null default '{}',
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table user_recipes enable row level security;

create policy "user_recipes: users read own"
  on user_recipes for select
  using (auth.uid() = user_id);

create policy "user_recipes: users insert own"
  on user_recipes for insert
  with check (auth.uid() = user_id);

create policy "user_recipes: users update own"
  on user_recipes for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_recipes: users delete own"
  on user_recipes for delete
  using (auth.uid() = user_id);

create index user_recipes_user_id_idx on user_recipes (user_id, created_at desc);
```

New Dart layer mirroring existing conventions:

- `lib/models/user_recipe.dart` — Freezed model with Supabase-column JSON keys.
- `lib/services/user_recipe_service.dart` — `fetchForUser`, `create`, `update`, `delete`. Thin Supabase wrapper, `AppLogger` for errors.
- `lib/repositories/user_recipe_repository.dart` — delegates to the service (follows `entry_repository.dart` pattern).
- `lib/providers/user_recipes_provider.dart` — `AsyncNotifier<List<UserRecipe>>` sorted by `created_at desc`. Exposes `create`, `update`, `delete` methods that refresh the list.

### Recipes screen — tab host

Replace the body of `lib/screens/recipes/recipes_screen.dart`:

- Keep the AppBar (title `Rezepte`, close icon).
- Below the AppBar, a `SegmentedButton`-style pill with segments `Meine Rezepte` / `Inspiration`. Matches the look used by the gut-feeling tracker's `Bauchgefühl` / `Stimmung` tabs.
- Segment state held in a local `StatefulWidget` (no provider — trivial local UI state).
- `Inspiration` segment → existing mascot + "Rezepte kommen bald!" block, verbatim.
- `Meine Rezepte` segment → `MyRecipesTab` widget.

### Meine Rezepte tab

New widget at `lib/screens/recipes/my_recipes_tab.dart`.

- Watches `userRecipesProvider`.
- **Empty state** (no recipes): mascot + "Noch keine Rezepte" heading + "Speichere Mahlzeiten als Rezepte, um sie schnell wieder einzutragen." body + `Erstes Rezept erstellen` button that opens the add-new chooser.
- **Non-empty**: `ListView.separated` of `RecipeListTile` rows. AppBar action `+` on `RecipesScreen` (shown only when the Meine Rezepte tab is active) opens the add-new chooser.
  - Each row: thumbnail (cached network image with shimmer; neutral placeholder if `imageUrl` null), title (semibold), first 3 ingredients joined with " · " truncated.
  - Tap → `context.push('/recipe/${recipe.id}')`.
- Loading / error states use the existing `AsyncValue.when` pattern shared with diary.

### Recipe detail screen

New route `/recipe/:id` rendered by `lib/screens/recipes/recipe_detail_screen.dart`.

- Scaffold with AppBar: back, pencil (opens edit), trash (opens confirm dialog → delete).
- Body (scrollable): hero image if present, title (display font), ingredients as chips.
- Sticky bottom `BbButton` `Mahlzeit jetzt tracken` → `context.push('/meal-tracker', extra: MealTrackerInitial.fromRecipe(recipe))`.
  - The meal tracker already accepts an `initial` parameter (used for the "edit existing meal" flow); extend it to accept a recipe-derived initial that sets title + ingredients + image but leaves `trackedAt` to now. A new constructor or helper on `MealEntry` (e.g. `MealEntry.templateFromRecipe(UserRecipe)`) that synthesizes a non-persisted `MealEntry`.
- On delete: confirm dialog ("Rezept löschen?"), then call provider's `delete`, then `context.pop()`.

### Recipe editor screen

New route `/recipe/new` and `/recipe/:id/edit` rendered by `lib/screens/recipes/recipe_editor_screen.dart`.

- Looks like the meal tracker body minus the date/time chips. Reuses the existing widgets `MealImageSection` and `IngredientSearch` by importing them directly — they're already independent of the `mealTrackerProvider`.
- Local state for title + imageBytes + imageName + ingredients.
- Save button: `BbButton` labeled `Speichern` — calls `userRecipesProvider.create(…)` or `.update(id, …)` and pops with a SnackBar.
- No "Was hat dir…" dialog or gut-feeling tabs — just form → save.

### Add-new chooser

New widget `lib/screens/recipes/widgets/add_recipe_chooser_sheet.dart`.

A `showModalBottomSheet(useSafeArea: true)` with `SafeArea(top: false)` inside (per the nav-bar fix pattern). Two tappable rows:

- **Aus kürzlicher Mahlzeit** (icon: `history`) → dismisses, opens `RecentMealPickerSheet`.
- **Neu erstellen** (icon: `add`) → dismisses, navigates to `/recipe/new`.

### Recent-meal picker sheet

New widget `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`.

- Bottom sheet fetching last 20 `meal_entries` for the current user via existing `entryQueryService.fetchMealsForUser(userId, limit: 20)` (add the limit parameter if absent).
- Each row: `formatDateTimeShort(trackedAt)` + title + first ingredients truncated.
- Tap → shows an inline title-confirm row below the list (or navigates to a small confirm screen) — simplest: just insert the recipe immediately with the meal's title and show a SnackBar "Zu Meine Rezepte hinzugefügt". No title-edit step in the picker — user can edit via the detail route's pencil.
- Why "just insert immediately": keeps the flow to 2 taps (pick meal, done) and avoids a redundant edit step since editing is already one tap away.

### Meal tracker integration

**Recipe selector row.** Modify `lib/screens/trackers/meal/meal_tracker_screen.dart`. Above the `DateTimeChips` row inside `_buildBody`, add a row rendered only when `userRecipesProvider` has ≥ 1 recipe:

```dart
if (userRecipesProvider has recipes)
  OutlinedButton.icon(
    onPressed: () => showRecipeSelectorSheet(context, onPick: _prefillFromRecipe),
    icon: const Icon(Icons.menu_book_outlined),
    label: const Text('Aus Rezept auswählen'),
  ),
```

The `_prefillFromRecipe` helper calls `notifier.prefillFromRecipe(recipe)` which sets title + ingredients + image via the existing `mealTrackerProvider` mutation methods. `_titleController.text` is synced too.

If `userRecipesProvider.isLoading` or `hasError`, hide the button (same as no recipes) — don't gate save on recipe list load.

**Recipe selector sheet.** New widget `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`. Bottom sheet listing recipes (thumbnail + title + truncated ingredients), onTap returns the selected `UserRecipe` via a `Navigator.pop(sheetContext, recipe)`.

**Save-as-recipe on success screen.** Change `lib/widgets/common/bb_success_overlay.dart`:

- Deprecate the singular `successAction` param in favor of `List<Widget>? successActions` rendered vertically with spacing between them.
  - Keep `successAction` as a one-element fallback for the short-term so any other call site stays compiled (audit: only `meal_tracker_screen` and `gut_feeling_tracker_screen` use it). If both are migrated in this PR, delete the singular param outright — no backwards-compat shim for non-public API.
- Meal tracker passes two actions:
  1. `Als Rezept speichern` (icon: `bookmark_add_outlined`) → tap creates a `user_recipe` via `userRecipesProvider.create({title, ingredients, imageUrl})` using the just-saved meal's data. Shows a SnackBar "Zu Meine Rezepte hinzugefügt". Disables itself after tap (idempotency).
  2. `Getränk hinzufügen` (existing behavior, unchanged).

`BbSuccessOverlay` signature change: replace `Widget? successAction` with `List<Widget> successActions = const []`. Migrate the two call sites.

### Routes

Add to `lib/router/route_paths.dart`:

```dart
static const recipeNew = '/recipe/new';
static const recipeDetail = '/recipe/:id';
static const recipeEdit = '/recipe/:id/edit';
```

And the corresponding `route_names.dart` entries + `app_router.dart` `GoRoute` declarations. Use path params for `:id` with a fallback "recipe not found" screen if the provider's list lacks it (same pattern as meal-not-found in the meal tracker).

## Files touched

New (11):
- `lib/models/user_recipe.dart` (+ 2 generated)
- `lib/services/user_recipe_service.dart`
- `lib/repositories/user_recipe_repository.dart`
- `lib/providers/user_recipes_provider.dart`
- `lib/screens/recipes/my_recipes_tab.dart`
- `lib/screens/recipes/recipe_detail_screen.dart`
- `lib/screens/recipes/recipe_editor_screen.dart`
- `lib/screens/recipes/widgets/recipe_list_tile.dart`
- `lib/screens/recipes/widgets/add_recipe_chooser_sheet.dart`
- `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`
- `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`
- `supabase/migrations/<ts>_add_user_recipes.sql`

Modified (7):
- `lib/screens/recipes/recipes_screen.dart` — placeholder → tab host.
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — recipe selector row + two successActions on the overlay.
- `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart` — migrate to `successActions` (single-element).
- `lib/widgets/common/bb_success_overlay.dart` — `successAction` → `successActions: List<Widget>`.
- `lib/providers/meal_tracker_provider.dart` — new `prefillFromRecipe(UserRecipe)` method.
- `lib/router/app_router.dart`, `lib/router/route_paths.dart`, `lib/router/route_names.dart`.
- `lib/services/entry_query_service.dart` (or equivalent) — add `limit` param to `fetchMealsForUser` if missing.

## Testing

- `UserRecipeService` — CRUD with mocked Supabase client; RLS policies are Postgres-side, so we test only that the client is called with the right filters.
- `UserRecipeRepository` — thin delegation tests (mirror `entry_repository_test.dart`).
- `userRecipesProvider` — load / create-refreshes-list / update-refreshes-list / delete-removes-row (riverpod_helpers).
- `RecipeListTile` — renders title, truncated ingredients, fires `onTap`.
- `MyRecipesTab` — empty state shows CTA; non-empty lists rows; loading spinner.
- `AddRecipeChooserSheet` — two options navigate where expected.
- `RecentMealPickerSheet` — on tap calls create and shows SnackBar (mocked provider).
- `RecipeEditorScreen` — create path (no id) and edit path (preloaded from provider).
- `RecipeDetailScreen` — renders recipe, Track button extras payload, Delete confirm dialog.
- `RecipeSelectorSheet` in meal tracker — tap returns recipe.
- `MealTrackerScreen` — recipe row hidden with no recipes, visible + prefills with ≥ 1 recipe.
- `BbSuccessOverlay` — renders multiple actions.
- Migration SQL syntactically valid (apply to a scratch DB via `supabase db reset` on the local stack as manual smoke).

## Rollout

Ship as one PR against `develop`. The feature is fully additive — no existing behavior changes for users who don't touch the new UI. After merge to develop → main, the Android + iOS deploy picks it up.

Manual smoke before merge:
1. Track a meal, confirm `Als Rezept speichern` appears on success and works.
2. Open Rezepte → Meine Rezepte → see the new recipe.
3. Open it, tap `Mahlzeit jetzt tracken`, confirm prefill.
4. Back to Meine Rezepte, `+` → `Aus kürzlicher Mahlzeit` → pick one → new recipe appears.
5. `+` → `Neu erstellen` → fill out → save → new recipe appears.
6. Open a recipe, edit title, save → updated.
7. Delete a recipe with confirm dialog.
8. Track another meal with the selector row → prefilled correctly.
9. Inspiration tab still shows the placeholder.

## Risk

Medium. Blast radius limited to new code plus two modified call sites of `BbSuccessOverlay` and one modified provider. The migration is additive (no alters on existing tables). The change to the success overlay is the only shared-widget API change — covered by migrating both consumers in the same PR.

## Acceptance

- `user_recipes` table exists in Supabase with correct RLS.
- `UserRecipe` model, service, repo, provider exist with tests.
- Rezepte screen has the two-tab layout; Inspiration unchanged.
- Meine Rezepte tab: empty state + list + `+` chooser + both entry points working.
- Recipe detail route: renders, Track button prefills meal tracker, Edit/Delete work.
- Recipe editor: create and edit flows save correctly.
- Meal tracker: recipe selector row visible iff recipes exist, prefills on select.
- Meal success overlay: shows both actions; save-as-recipe inserts a row and SnackBars.
- `flutter analyze` clean, `dart format` applied, test suite green.

## Out of scope

- Curated Inspiration recipes (still placeholder).
- Per-recipe tags / cook time / servings — start minimal; easy to add if users ask.
- Sharing recipes between users.
- Photo editing beyond what the meal tracker's image section already supports.
- Linking a meal back to the recipe it was tracked from (no foreign key on `meal_entries`). Tracked meals are independent of the source recipe by design — editing a recipe doesn't alter history.
