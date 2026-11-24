# Runde 4 Stage 2: Rezepte (App) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entdecken's „Meine Rezepte" becomes „Rezepte":
- a ranked „Für dich" row from the curated collection, and „Meine Rezepte" (own recipes plus gemerkte);
- a filterable Rezepte list;
- a recipe detail with ✓/⚠ per ingredient, „Merken", „Quelle" and „Als Essen eintragen";
- „Für mich anpassen" through core's `adapt-recipe`, saved as an own recipe;
- optional preparation steps for own recipes.

**Architecture:**
- **Data:**
  - `RecipeService` reads the collection with core's PostgREST select (recipes + `recipe_ingredients` + the linked catalog FODMAP flags), the user's favourites with their dates, and `app_config.intolerance_rules`.
  - `Recipe`/`RecipeIngredient` become plain Dart (the old Freezed model typed `cook_time` as an int; the column is text).
  - `UserRecipe` gains `instructions`, `ingredient_amounts` and `adapted_from_recipe_id`.
- **Fit and ranking:** pure functions in `lib/services/recipes/`:
  - `fitOf` marks each line ✓, ⚠ or unknown with the published intolerance table;
  - `rankRecipes` filters by diet, scores by good-day and „Fällt mir auf" ingredients, and breaks ties by kritisch count, then newest.
  - Pre-unlock good ingredients come from a new `Insights.calmDayIngredients`.
- **Providers** (`recipe_collection_provider.dart`): the collection, the rules, the favourites (optimistic toggle), the ranked list, one recipe's fit, „Für dich", the gemerkte, and the merged „Meine Rezepte" items.
- **Screens:**
  - the Rezepte list `/discover/recipes` (inside the Entdecken branch);
  - the recipe detail `/collection/:id` and the adapt screen `/collection/:id/adapt` (pushed, without the bar);
  - the reworked Entdecken section, Meine Rezepte grid, own-recipe detail and editor.
- **Meal tracker:** takes a `MealPrefill` (title, ingredients, image) instead of a `UserRecipe`, so collection and adapted recipes prefill it too.
- **Stage 3 entry point:** `context.openRecipe(id)`.

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3.5 (`Notifier`/`AsyncNotifier`, `retry: noRetry`), GoRouter 18, Supabase (PostgREST + `functions.invoke`), Freezed/json_serializable (`UserRecipe` only), `cached_network_image` + `shimmer`, `url_launcher`, mocktail, integration_test. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-24-round4-home-recipes-tips-design.md`. This plan covers the app half of **Stage 2** (§6):
- §5.6.1 where recipes live;
- §5.6.3 ranking;
- §5.6.4 the app part of „Für mich anpassen";
- §5.6.5 the app part of Meine Rezepte;
- the Decisions log: builder-check answers 1–2 and refinement 6.

Binding alongside it:
- **Backend contract:** core plan `/Users/sevi/projects/bellybuddy-core-recipes-wt/docs/superpowers/plans/2026-11-24-round4-stage2-recipes-core.md` § „API contract for the app", as amended by core PR #11's review round (`cannot_judge`, amounts follow ingredients, `ai_detector` rows).
- **Mockup:** `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/round4-recipes.src.html` (published as https://claude.ai/artifact/8CqdhqNL983Gi1DZ54T9k7). Where the mockup and the spec differ, the spec wins.

## Global Constraints

From the spec, the contract and `CLAUDE.md`, verbatim where they give values:
- Follow the repo's `CLAUDE.md`:
  - colours, font sizes, spacing and radii only through `AppTheme`/`AppConstants` (add tokens there first);
  - German UI;
  - Riverpod, GoRouter, `AppLogger` (never `print`);
  - `CachedNetworkImage` with a `shimmer` placeholder for every network image;
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- „Belly Buddy" is never translated.
- **Vocabulary** (§5.9 of the app-structure spec): eintragen, Essen, Tipps (never „Empfehlung"), Alternativen, Tagebuch. `test/utils/vocabulary_test.dart` stays green with no new exemptions.
- **No health claims.** Badges say exactly „Passt zu dir", „1 Zutat ist für dich kritisch" / „N Zutaten sind für dich kritisch", or „Histamin bitte selbst prüfen". Never „hilft gegen …". „Für dich kritisch" is never a diagnosis.
- **No copied photos.** A recipe shows its `image_url` (null for every imported recipe) or the placeholder by meal type. Nothing is fetched from the source sites.
- **Privacy:**
  - `adapt-recipe` is called only after the user taps „Für mich anpassen".
  - The request body is exactly `{"recipe_id": "<uuid>"}`: the server reads intolerances and diet itself, and no diary data is sent.
- **„kritisch"** (contract, the same rule as core's): an ingredient is kritisch for a user when
  - it carries an allergen of one of their intolerances, **or**
  - its catalog row has a FODMAP flag of one of their intolerances **and** `low_at_amount` is false.

  An unmapped line (`ingredient` null) has no FODMAP flags; only its `allergens` can make it kritisch.
- **One intolerance table:**
  - The app reads `app_config` key `intolerance_rules` (JSON text, `{name: {"fodmaps": [...], "allergens": [...], "judgeable": bool}}`) and keeps no copy in `lib/`.
  - A profile value missing from the table hits nothing.
  - Test fixtures may hold a copy.
- **Histamin** (`judgeable` false):
  - it never yields „Passt zu dir"; the badge says „Histamin bitte selbst prüfen";
  - the „Passt zu mir" filter ignores it and says so in one line.
- **Graceful degrade:** a backend without core #11 must not break the existing recipe screens:
  - Meine Rezepte list, detail and editor, the meal tracker's „Rezept auswählen", and Entdecken's own recipes keep working;
  - only the collection parts show a quiet note.
- **Reduced motion:** every new animation respects it. The shimmer is disabled, and the adapt screen's Buddy follows the ambient seam.
- **Layout:** a 375×667 screen at text scale 1.3 does not overflow.
- **Scope:** app only, and core is untouched. Deploy order: core first. The release follows Stage 3. The Tipps' recipe link is Stage 3; this stage only provides `openRecipe(id)`.

Execution rules for this repo (carried over from Stage 1):
- **Commits:**
  - Run `dart format .` and `flutter analyze` (0 issues) first.
  - Then `git commit --no-verify` (the hook is broken in worktrees), with a conventional prefix and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - **Never push.**
- **Codegen:**
  - After changing `UserRecipe` (Task 4), run `dart run build_runner build --delete-conflicting-outputs`.
  - `Recipe` is no longer Freezed (Task 1): delete the local `lib/models/recipe.freezed.dart` and `lib/models/recipe.g.dart` (gitignored) so the analyzer doesn't see orphan parts.
- **Test seams:**
  - `test/flutter_test_config.dart` already calls `disableAmbientAnimationsForTests()`.
  - Screens that open links take a `UrlOpener openUrl` (default `launchUrl`); tests pass `RecordingUrlOpener`.
  - Ranking tests override `rankingSignalsProvider` instead of building insights.
  - Screen tests override `recipeRepositoryProvider` with `FakeRecipeRepository`, `entryRepositoryProvider` with `FakeEntryRepository` and `profileProvider` with `profileProviderSeededWith(...)`.
- **Mocktail:** every existing `when`/`verify` of `UserRecipeRepository.create/update` and `UserRecipeService.create/update` gets the new named arguments as `any(named: …)`, so the stubs keep matching.
- **Simulators:**
  - Integration tests run **only** on the iPhone Air `CB1F6232-482F-408F-ADF4-89FDA602E6A8`, one file at a time, and the simulator is shut down afterwards.
  - **Never** use `55746DB2…` (Severin's live session) or `7A26EDD4…`.
  - Never run `flutter clean`.
  - Never a bare `git stash`; use a temporary worktree to compare with the base commit.

## Review Focus

1. **The fit can't be judged.** Expected: no „Passt zu dir", no crash, nothing that reads like a verdict. The cases:
   - `intolerance_rules` is missing or unparsable;
   - the profile isn't loaded yet;
   - an ingredient is unmapped;
   - an older recipe has no `recipe_ingredients`.

   The behaviour:
   - Without rules or profile: no badges, no ✓/⚠, no „Für mich anpassen", no „Passt zu mir" toggle, and the list is still ranked.
   - With an unmapped line while the user has a FODMAP-judged intolerance (and every older recipe while they have any judgeable one): no badge, the line marked „nicht im Katalog", and the recipe outside „Passt zu mir".

   Pinned in:
   - Task 1: `fetchIntoleranceRules: no row → null`, `… not JSON → null`;
   - Task 2: `rules unknown`, `profile unknown`, `unmapped line with Fruktose`, `older recipe`;
   - Task 7: `rules missing: no badge, no marks, no adapt button`;
   - Task 8: `rules missing: no Passt-zu-mir toggle`.
2. **A Histamin user:**
   - never „Passt zu dir", but „Histamin bitte selbst prüfen";
   - kritisch lines from other intolerances still count and win the badge;
   - „Passt zu mir" ignores Histamin and shows the line „Histamin kann ich nicht prüfen, bitte schau da selbst.".

   Pinned in Task 2 (`Histamin only`, `Histamin and Fruktose`), Task 7 (`Histamin user`) and Task 8 (`Histamin line under the toggle`).
3. **No core #11, or offline.**
   - The collection fails → Entdecken shows „Rezepte konnten nicht geladen werden." under „Für dich" and still lists the own recipes.
   - Saving an own recipe without steps sends no new column.
   - A failed refresh keeps the shown collection.
   - Merken offline reverts with a message.
   - The list and the detail offer a retry.

   Pinned in:
   - Task 3: `refresh keeps the collection on failure`, `toggle reverts on failure`;
   - Task 4: `create without steps sends only the old columns`;
   - Task 7: `collection fails: retry`;
   - Task 9: `collection fails: own recipes still shown`.
4. **Adapt errors and odd answers:**
   - every error code maps to one neutral German message;
   - 429 (`throttled`, `ai_busy`) gets the „später" variant;
   - a transport failure gets the neutral message plus retry;
   - `nothing_to_adapt`/`cannot_judge` never say „passt" and offer no retry;
   - an answer with `unbekannt` lines never claims „Alle Zutaten … geprüft".

   Pinned in Task 10 (`error codes map`, `transport failure`) and Task 11 (`each failure's message`, `an unknown ingredient keeps the check line honest`).
5. **Duplicate titles and amounts.**
   - Saving an adapted recipe under an existing title saves „… (angepasst)", then „… (angepasst 2)".
   - Removing an ingredient in the editor keeps the other amounts aligned.
   - An update whose amounts the server's trigger dropped (same length, same values) writes them again.

   Pinned in Task 4 (`update: amounts the trigger dropped are written again`), Task 10 (`duplicate title`) and Task 12 (`removing an ingredient keeps the others' amounts`).

## Decisions (spec gaps ruled in this plan)

- **„Fällt mir auf" never marks ⚠.**
  - The mockup marks such items ⚠ („steht bei Fällt mir auf"). The spec makes kritisch intolerance-only and only ranks „Fällt mir auf" down.
  - The adapt route swaps only kritisch and diet lines, so a ⚠ it wouldn't swap would confuse.
- **Score:**
  - `2 ×` the distinct good keys hit, `− 3 ×` the distinct certain „Fällt mir auf" keys hit (the mockup's weights).
  - Kritisch is not in the score (spec step 4 makes it the first tie-break).
  - Order: score ↓, kritisch count ↑, `created_at` ↓, then title. The import inserted all rows in one transaction, so `created_at` ties and the title keeps the order stable.
  - Keys are the lower-cased, trimmed line `name` and catalog `name`, matched against lower-cased, trimmed entry ingredients.
- **Signals:**
  - **Unlocked:** good = `goodDays.often` names (when the column is shown); noticed = the non-„noch unsicher" `noticed` names (when shown).
  - **Locked:** good = `Insights.calmDayIngredients`, the ingredients of window meals on local days without a single „Schlecht" Bauchgefühl entry (days without any Bauchgefühl count); noticed = none.
  - **Insights not `AsyncData`:** no signals.
  - Stage 3's day-5 reward reuses `calmDayIngredients`.
- **„Für dich":** the first 3 ranked recipes that pass „Passt zu mir", topped up from the ranked rest (with their badges) when fewer pass. Without rules, the top 3.
- **Unknowns:** these get no badge and are outside „Passt zu mir" (mirroring core's `cannot_judge`, which must not say „passt schon"):
  - a recipe with an unmapped, non-kritisch line while the user has an intolerance with FODMAP flags;
  - an older recipe without `recipe_ingredients` while the user has any judgeable intolerance.

  An allergen-only user is judged by the lines' allergens.
- **Rules or profile unknown → „not checked":**
  - no badges, marks, adapt button or toggle;
  - the diet filter only with a known diet.
- **Where the rules come from:**
  - `RecipeService.fetchIntoleranceRules` reads `app_config`, so `FakeRecipeRepository` covers it in widget and integration tests, which must not reach a real backend.
  - Network errors leave `intoleranceRulesProvider` in error (treated as unknown); Entdecken's pull-to-refresh and the list's retry invalidate it.
- **Older recipes** (the 10 from before):
  - the select adds the existing `ingredients` column, so their text lines show (unmarked);
  - no adapt button;
  - `MealPrefill` takes those lines as they are.
- **Dead code removed:** `RecipesNotifier`/`recipesProvider` (no UI used it), `RecipeDetailSheet`, `recipe_tag_mapping.dart` and their tests. The ranking replaces them.
- **Routes:**
  - list `/discover/recipes` as a sub-route of the Entdecken branch (bar stays);
  - detail `/collection/:id` and adapt `/collection/:id/adapt`, top-level (no bar);
  - `/recipe/:id` stays the own recipe.
  - The adapt route starts the AI call only when pushed with `extra: true` from the button. Opened any other way, it shows a „Für mich anpassen" prompt first.
- **Gemerkte in „Meine Rezepte":**
  - in the Entdecken row and the `/recipes` grid, merged with the own recipes newest first (favourite `created_at` vs recipe `created_at`), with a heart tag „Gemerkt";
  - they show whatever the diet (the user chose them);
  - the `/recipes` search filters them by title locally;
  - the meal tracker's „Rezept auswählen" stays own recipes only (§5.6.5).
- **Entdecken links:** the section's „Alle ›" opens the collection. „Meine Rezepte" keeps a small „Alle ›" (semantics „Alle meine Rezepte") to `/recipes`, since the row shows at most 6.
- **Merken** is optimistic. On failure the heart reverts and a SnackBar says „Das hat gerade nicht geklappt. Bitte versuch es nochmal.". The mockup's toasts: „Gemerkt. Du findest es unter „Meine Rezepte"." / „Nicht mehr gemerkt.".
- **Degrade on write:** `instructions`, `ingredient_amounts` and `adapted_from_recipe_id` are sent only when used: steps added, amounts present, or an adapted save. An edit sends `instructions` only when the steps changed.
- **Amount trigger caveat:** if an update sent amounts and the returned row has none, the service writes `ingredient_amounts` once more on its own (ingredients unchanged, so the trigger stays quiet).
- **Adapt:**
  - No client cache: the result lives while the adapt screen is open (autoDispose), so nothing is spent behind the user's back.
  - `Retry-After` is not read (`functions_client` doesn't expose headers).
  - `throttled`/`ai_busy`/any 429 → „Ich bin gerade ausgelastet. Versuch es bitte später nochmal." + retry.
  - `nothing_to_adapt` → „Hier muss ich für dich nichts tauschen." without retry.
  - `cannot_judge` → „Ob ich hier etwas tauschen muss, kann ich nicht prüfen: Mir fehlen Angaben zu den Zutaten." without retry.
  - Everything else (`adapt_failed`, `ai_error`, `recipe_not_found`, 400/401/500, transport) → „Das hat gerade nicht geklappt. Versuch es bitte nochmal." + „Nochmal versuchen".
  - The server's `error` text is never shown; copy stays in the app.
- **Adapted result:**
  - the server's `note` is the Buddy's bubble;
  - the check line is „Alle Zutaten mit dem FODMAP-Katalog geprüft" only when no line is `unbekannt`, otherwise „Mit dem FODMAP-Katalog geprüft. Nicht im Katalog: A und B";
  - `steps[].changed` highlights the whole step (the server gives no sentence spans);
  - `removed` lines show struck through with „weggelassen".
- **Duplicate title:** try `title`, then „title (angepasst)", then „title (angepasst 2)" … „(angepasst 9)", then fail with the save error. Adapted names are de-duplicated case-insensitively (keeping the first and its amount), so the editor's remove-by-name keeps amounts aligned.
- **After saving:** the button turns into „In Meine Rezepte gespeichert ✓"; tapping it opens the own recipe. No SnackBar.
- **Placeholder:** a soft tint per meal type plus a Material outline icon (Frühstück `free_breakfast`, Mittag `lunch_dining`, Abend `dinner_dining`, Snack `cookie`, none `menu_book`). Tints are from the mockup's illustration backgrounds. No new assets.
- **Meal from a collection recipe:**
  - names only, no image;
  - the success page still leaves to Home (as for own recipes; the mockup's „zurück zum Rezept" isn't taken);
  - no green outline on swapped chips (mockup open point 5 — the swapped names simply come along).
- **Own-recipe detail:**
  - ingredient rows with amounts replace the chips;
  - „Für dich angepasst" pill when adapted;
  - „Original: <title> ›" only while the original is in the collection;
  - „Zubereitung" with „Noch keine Schritte." + „Schritte hinzufügen" when empty.
- **Steps editor:**
  - at most `recipeStepsMax` (50) steps, the add button disabled at 50;
  - the total checked on save against `recipeStepsMaxChars` (20 000): „Die Zubereitung ist zu lang. Bitte kürze sie.";
  - empty steps dropped;
  - no reordering;
  - amounts aren't editable but follow their ingredient.
- **Copy (first person Buddy, like Stage 1):**
  - the adapt hint is „Ich tausche A und B und schreibe die Schritte passend um.";
  - loading is „Ich bau's für dich um …" plus „Ich tausche, was für dich kritisch ist, und prüfe jede Zutat im FODMAP-Katalog.".

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/recipe.dart` (rewrite, plain Dart) | `MealType`, `RecipeIngredient`, `Recipe`, `FavoriteRecipe` |
| `lib/models/intolerance_rules.dart` (create) | `IntoleranceRule`, `IntoleranceRules.parse` |
| `lib/models/fodmap_flags.dart` (modify) | `has(String key)` |
| `lib/services/recipe_service.dart`, `lib/repositories/recipe_repository.dart` (modify) | collection select, favourites, rules, adapt |
| `lib/utils/german_list.dart` (create), `lib/services/insights/insight_copy.dart` (modify) | `joinGerman` (moved out of `InsightCopy._joined`) |
| `lib/models/insights.dart`, `lib/services/insights/insights_engine.dart` (modify) | `Insights.calmDayIngredients` |
| `lib/services/recipes/recipe_copy.dart`, `recipe_fit.dart`, `recipe_ranking.dart` (create) | copy, `fitOf`, `rankRecipes`, `pickForYou`, `filterRecipes` |
| `lib/providers/recipe_collection_provider.dart`, `lib/models/my_recipe_item.dart` (create) | collection, rules, favourites, ranking, fit, „Für dich", gemerkte, merged items |
| `lib/models/user_recipe.dart`, `lib/services/user_recipe_service.dart`, `lib/repositories/user_recipe_repository.dart`, `lib/providers/user_recipes_provider.dart` (modify) | steps, amounts, origin, `createAdapted` |
| `lib/models/meal_prefill.dart` (create), meal tracker provider/screen, router (modify) | `MealPrefill` |
| `lib/config/app_theme.dart`, `lib/config/constants.dart` (modify) | recipe tints and the changed mark, sizes and limits |
| `lib/screens/recipes/widgets/recipe_image.dart`, `fit_badge_view.dart`, `ingredient_line_view.dart`, `recipe_steps.dart`, `recipe_collection_card.dart`, `recipe_list_tile.dart`, `recipe_steps_editor.dart` (create); `recipe_card.dart` (modify) | shared recipe widgets |
| `lib/screens/recipes/collection_recipe_screen.dart`, `collection_screen.dart`, `adapt_recipe_screen.dart` (create) | detail, list, adapt |
| `lib/router/route_names.dart`, `app_router.dart`, `navigation_extensions.dart`, `lib/screens/screens.dart` (modify) | routes, `openRecipe` |
| `lib/screens/discover/widgets/discover_recipes_section.dart` (rewrite), `discover_section.dart`, `discover_screen.dart`, `lib/screens/recipes/my_recipes_tab.dart` (modify) | Entdecken „Rezepte", gemerkte in Meine Rezepte |
| `lib/models/adapted_recipe.dart`, `lib/providers/adapt_recipe_provider.dart` (create) | adapt answer, errors, notifier |
| `lib/screens/recipes/recipe_detail_screen.dart`, `recipe_editor_screen.dart` (modify) | steps, amounts, origin |
| `test/helpers/fakes.dart`, `fixtures.dart`, `integration_test/helpers/test_app.dart` (modify) | fakes and fixtures |

---

### Task 1: The collection's data layer

**Files:**
- Rewrite: `lib/models/recipe.dart` (no Freezed; delete the local `recipe.freezed.dart`/`recipe.g.dart`)
- Create: `lib/models/intolerance_rules.dart`
- Modify:
  - `lib/models/fodmap_flags.dart`
  - `lib/services/recipe_service.dart`
  - `lib/repositories/recipe_repository.dart`
  - `test/helpers/fakes.dart`, `test/helpers/fixtures.dart`
- Delete:
  - `lib/providers/recipes_provider.dart`, `test/providers/recipes_provider_test.dart`
  - `lib/screens/recipes/widgets/recipe_detail_sheet.dart`
  - `lib/utils/recipe_tag_mapping.dart`, `test/utils/recipe_tag_mapping_test.dart`
- Test:
  - `test/models/recipe_test.dart`, `test/models/intolerance_rules_test.dart`, `test/models/fodmap_flags_test.dart` (create where missing)
  - `test/services/recipe_service_test.dart`, `test/repositories/recipe_repository_test.dart` (rewrite)

**Interfaces:**
- Produces (`recipe.dart`):
  ```dart
  enum MealType {
    breakfast('frühstück', 'Frühstück'), lunch('mittag', 'Mittag'),
    dinner('abend', 'Abend'), snack('snack', 'Snack');
    const MealType(this.key, this.label);
    final String key, label;
    static MealType? fromKey(String key);
  }
  class RecipeIngredient {
    const RecipeIngredient({required this.position, this.amount, required this.name,
      this.catalogId, this.catalogName, this.fodmaps, this.allergens = const {}, this.lowAtAmount = false});
    factory RecipeIngredient.fromJson(Map<String, dynamic> json); // a recipe_ingredients row
    final int position;
    final String? amount;              // amount_text; blank → null
    final String name;
    final String? catalogId, catalogName; // from `ingredient`; null = unmapped („unbekannt")
    final FodmapFlags? fodmaps;        // FodmapFlags.fromDbRow(ingredient); null when unmapped
    final Set<String> allergens;
    final bool lowAtAmount;
    bool get mapped => catalogId != null;
    Set<String> get matchKeys;         // name and catalogName, trimmed + lower-cased, no empties
  }
  class Recipe {
    const Recipe({required this.id, required this.title, this.description, this.cookTime, this.servings,
      this.imageUrl, this.mealTypes = const [], this.dietTags = const {}, this.sourceName, this.sourceUrl,
      this.instructions = const [], this.ingredients = const [], this.legacyIngredients = const [], this.createdAt});
    factory Recipe.fromJson(Map<String, dynamic> json);
    final String id, title;
    final String? description, cookTime, imageUrl, sourceName, sourceUrl;
    final int? servings;
    final List<MealType> mealTypes;    // enum order, unknown keys dropped
    final Set<String> dietTags;
    final List<String> instructions;
    final List<RecipeIngredient> ingredients; // sorted by position
    final List<String> legacyIngredients;     // the `ingredients` text[] column
    final DateTime? createdAt;
    bool get isLegacy => ingredients.isEmpty;
    String? get servingsLabel;          // 1 → '1 Portion', n → 'n Portionen'
    String get detailMeta;              // [cookTime, servingsLabel] non-null, joined ' · '
    String get listMeta;                // [cookTime, mealTypes.first.label] non-null, joined ' · '
  }
  class FavoriteRecipe { const FavoriteRecipe(this.recipeId, this.at); final String recipeId; final DateTime at; }
  ```
  `cook_time` is read as `json['cook_time']?.toString()`, and a blank value becomes null.
- `intolerance_rules.dart`:
  ```dart
  class IntoleranceRule {
    const IntoleranceRule({this.fodmaps = const {}, this.allergens = const {}, this.judgeable = true});
    final Set<String> fodmaps;   // FODMAP keys: fructans, gos, lactose, fructose, sorbitol, mannitol (others dropped)
    final Set<String> allergens;
    final bool judgeable;
  }
  class IntoleranceRules {
    const IntoleranceRules(this.byName);
    final Map<String, IntoleranceRule> byName;
    static IntoleranceRules? parse(String value); // null unless a JSON object; non-object entries skipped
    IntoleranceRule? operator [](String intolerance);
  }
  ```
- `FodmapFlags.has(String key)`: true when the flag named by the catalog column without `fodmap_` is set. An unknown key is false. It is a method in the class body, so no codegen is needed.
- `RecipeService`:
  ```dart
  static const collectionSelect =
    'id,title,description,cook_time,servings,image_url,meal_types,diet_tags,source_name,source_url,'
    'instructions,ingredients,created_at,'
    'recipe_ingredients(position,amount_text,name,allergens,low_at_amount,'
    'ingredient:ingredients(id,name,fodmap_fructans,fodmap_gos,fodmap_lactose,fodmap_fructose,fodmap_sorbitol,fodmap_mannitol))';
  Future<List<Recipe>> fetchCollection();
      // from('recipes').select(collectionSelect).isFilter('hidden', false)
      //   .order('created_at', ascending: false)
      //   .order('position', ascending: true, referencedTable: 'recipe_ingredients') // postgrest's default is descending
  Future<List<FavoriteRecipe>> fetchFavorites(String userId);
      // user_favorite_recipes: select('recipe_id,created_at').eq('user_id', …).order('created_at', ascending: false)
  Future<void> addFavorite(String userId, String recipeId);    // unchanged
  Future<void> removeFavorite(String userId, String recipeId); // unchanged
  Future<IntoleranceRules?> fetchIntoleranceRules();
      // app_config: select('value').eq('key', 'intolerance_rules').maybeSingle(); no row or parse null → null (warn)
  ```
- `RecipeRepository`: `fetchCollection()` (wrapped in `retryAsync`), `fetchFavorites`, `addFavorite`, `removeFavorite`, `fetchIntoleranceRules`. Task 10 adds `adapt`.
- Fixtures (`fixtures.dart`):
  - `testLine(String name, {int position = 0, String? amount, FodmapFlags fodmaps = const FodmapFlags(), Set<String> allergens = const {}, bool lowAtAmount = false, bool mapped = true})`. A mapped line has `catalogId: 'ing-$name'` and `catalogName: name`.
  - `testRecipe({String id = 'recipe-1', String title = 'Testrezept', List<RecipeIngredient>? ingredients, List<MealType> mealTypes = const [MealType.lunch], Set<String> dietTags = const {'vegan', 'vegetarisch'}, String? cookTime = '20 Min', int? servings = 2, List<String> instructions = const ['Alles kochen.'], String? sourceName, String? sourceUrl, DateTime? createdAt})`. The default ingredients are `[testLine('Reis')]`.
  - `const kTestIntoleranceRulesJson`: the contract's 13 entries verbatim, as migration 0013 writes them.
  - `IntoleranceRules testIntoleranceRules() => IntoleranceRules.parse(kTestIntoleranceRulesJson)!`.
- `FakeRecipeRepository`:
  - Data: `collection` (default `[testRecipe()]`), `rules` (default `testIntoleranceRules()`), `favorites`.
  - Failures: `Object? collectionError`, `Object? favoriteError` (thrown when set).
  - Calls are recorded in `added`/`removed`.

- [ ] **Step 1: Failing tests.**
  - **`Recipe.fromJson`**, on a contract-shaped row with:
    - meal types `['abend', 'mittag', 'brunch']`;
    - three `recipe_ingredients` given out of order:
      - position 1 „Knoblauch" (mapped, `fodmap_fructans: true`, `low_at_amount: false`);
      - position 0 „200 g" „Risottoreis" (mapped);
      - position 2 `amount_text: ' '` „Obst nach Wahl" with `ingredient: null`;
    - `cook_time: '35 Min'`, `servings: 2`, `created_at` ISO.

    Expect:
    - lines ordered Risottoreis, Knoblauch, Obst nach Wahl;
    - `mealTypes == [MealType.lunch, MealType.dinner]`;
    - the third line has `mapped == false`, `fodmaps == null` and `amount == null`;
    - Knoblauch: `fodmaps!.fructans`, `matchKeys == {'knoblauch'}`;
    - `detailMeta == '35 Min · 2 Portionen'`, `listMeta == '35 Min · Mittag'`.
  - **`servings 1 reads 1 Portion`**.
  - **`an older recipe`**: no `recipe_ingredients`, `ingredients: ['200 g Reis']`, empty tags → `isLegacy`, `legacyIngredients == ['200 g Reis']`, `dietTags` empty.
  - **`IntoleranceRules.parse`**:
    - the fixture JSON → `['Laktose']!.fodmaps == {'lactose'}`, `allergens` empty;
    - `['Gluten']!.allergens == {'gluten'}`, `fodmaps` empty;
    - `['Weizen']` has fructans + weizen;
    - `['Histamin']!.judgeable == false`;
    - `['FODMAPs']!.fodmaps.length == 6`;
    - `parse('nope') == null`, `parse('[1]') == null`;
    - `{"X": 3, "Laktose": {"fodmaps": ["lactose", "kohl"]}}` → X skipped, Laktose `{'lactose'}`, judgeable true.
  - **`FodmapFlags.has`**: `FodmapFlags(lactose: true).has('lactose')`; `.has('fructans')` false; `.has('kohl')` false.
  - **Service:**
    - `fetchCollection selects the contract's columns, hides hidden rows, orders`: verify `select(RecipeService.collectionSelect)`, `isFilter('hidden', false)`, `order('created_at', ascending: false)`, `order('position', ascending: true, referencedTable: 'recipe_ingredients')`;
    - `collectionSelect names every contract field`: for each of `meal_types, diet_tags, source_name, source_url, instructions, allergens, low_at_amount, ingredient:ingredients(, fodmap_fructans, fodmap_mannitol` → `contains`;
    - `fetchFavorites newest first` (parses `created_at`);
    - `fetchIntoleranceRules`:
      - a row with the fixture JSON → parsed;
      - `no row → null`;
      - `… not JSON → null`.
  - **Repository:** delegates. `fetchCollection` retries (existing `retryAsync` pattern).
- [ ] **Step 2:** Run `flutter test test/models test/services/recipe_service_test.dart test/repositories/recipe_repository_test.dart`. Expected: FAIL (undefined).
- [ ] **Step 3: Implement** per the interfaces. Delete the dead files listed. Remove the old `testRecipe` parameters (`tags`, string `ingredients`) and fix their callers.
- [ ] **Step 4:** Run the tests again, then `flutter analyze`. Expected: PASS, 0 issues.
- [ ] **Step 5: Commit** `feat(recipes): the collection's data layer (contract select, favourites, intolerance table)`

---

### Task 2: Fit and ranking

**Files:**
- Create:
  - `lib/utils/german_list.dart`
  - `lib/services/recipes/recipe_copy.dart`, `recipe_fit.dart`, `recipe_ranking.dart`
- Modify:
  - `lib/services/insights/insight_copy.dart` (use `joinGerman`)
  - `lib/models/insights.dart`, `lib/services/insights/insights_engine.dart`
- Test:
  - `test/utils/german_list_test.dart`
  - `test/services/recipes/recipe_fit_test.dart`, `test/services/recipes/recipe_ranking_test.dart`
  - `test/services/insights/insights_engine_test.dart`, `test/models/insights_test.dart`

**Interfaces:**
- Consumes: `Recipe`, `RecipeIngredient`, `IntoleranceRules`, `FodmapFlags.has` (Task 1); `Insights`.
- Produces:
  ```dart
  String joinGerman(List<String> items); // „A", „A und B", „A, B und C"

  abstract final class RecipeCopy {
    static const fits = 'Passt zu dir';
    static String kritisch(int n);          // 1 → '1 Zutat ist für dich kritisch', n → '$n Zutaten sind für dich kritisch'
    static String selfCheck(List<String> names); // '${joinGerman(names)} bitte selbst prüfen'
    static String because(List<String> names);   // 'wegen ${joinGerman(names)}'
    static const kritischSuffix = '— für dich kritisch';
    static const notInCatalog = 'nicht im Katalog';
    static String adaptHint(List<String> names);  // 'Ich tausche ${joinGerman(names)} und schreibe die Schritte passend um.'
    static String selfCheckFilter(List<String> names); // '${joinGerman(names)} kann ich nicht prüfen, bitte schau da selbst.'
  }

  enum LineMark { fits, kritisch, unknown }
  class LineFit { const LineFit(this.line, this.mark, {this.because = const []});
    final RecipeIngredient line; final LineMark mark; final List<String> because; } // because: intolerances hit, profile order
  sealed class FitBadge { const FitBadge(); String get label; }         // value equality
  final class FitsBadge extends FitBadge { const FitsBadge(); }
  final class KritischBadge extends FitBadge { const KritischBadge(this.count); final int count; }
  final class SelfCheckBadge extends FitBadge { const SelfCheckBadge(this.intolerances); final List<String> intolerances; }
  class RecipeFit {
    final Recipe recipe;
    final bool checked;            // rules and profile known
    final List<LineFit> lines;     // one per recipe.ingredients when checked; empty otherwise
    final List<String> selfCheck;  // the user's intolerances with judgeable false
    final bool judged;
    List<LineFit> get kritisch; int get kritischCount;
    FitBadge? get badge;
    bool get passtZuMir => checked && judged && kritischCount == 0;
  }
  RecipeFit fitOf(Recipe recipe, {required IntoleranceRules? rules, required List<String>? intolerances});

  class RankingSignals { const RankingSignals({this.good = const {}, this.noticed = const {}});
    factory RankingSignals.of(Insights? insights); final Set<String> good, noticed; } // lower-case keys
  bool fitsDiet(Recipe recipe, String? diet);
  int recipeScore(Recipe recipe, RankingSignals signals);
  class RankedRecipes { const RankedRecipes({required this.fits, required this.checked,
      this.selfCheck = const [], this.diet, this.hiddenByDiet = 0});
    final List<RecipeFit> fits; final bool checked; final List<String> selfCheck;
    final String? diet; final int hiddenByDiet; }
  RankedRecipes rankRecipes(List<Recipe> recipes, {required String? diet, required IntoleranceRules? rules,
      required List<String>? intolerances, required RankingSignals signals});
  List<RecipeFit> pickForYou(List<RecipeFit> ranked, {int count = AppConstants.recipeForYouCount});
  List<RecipeFit> filterRecipes(List<RecipeFit> ranked, {String query = '', MealType? mealType, bool fitsOnly = false});
  ```
  - `Insights` gains `final Set<String> calmDayIngredients` (default `const {}`), part of `==`/`hashCode`/`toString`.
  - `AppConstants.recipeForYouCount = 3` is added here.

**Rules:**
- **`fitOf`:**
  - `checked = rules != null && intolerances != null`. Unchecked → `lines` empty, `judged` false, `selfCheck` empty.
  - The user's rules: `rules[name]` for each intolerance, in profile order; missing names skipped.
  - `selfCheck` = names whose rule has `judgeable == false`. The judgeable rules decide the lines.
  - **Kritisch line:** some judgeable rule has `allergens ∩ line.allergens ≠ ∅`, or `!line.lowAtAmount && line.fodmaps != null && rule.fodmaps.any(line.fodmaps!.has)`. `because` = those rules' names.
  - **Unknown line:** otherwise, when `!line.mapped` and some judgeable rule has non-empty `fodmaps`.
  - **Fits:** otherwise.
  - `judged = checked && no unknown line && !(recipe.isLegacy && any judgeable rule)`.
  - **`badge`:**
    1. unchecked → null;
    2. `kritischCount > 0` → `KritischBadge`;
    3. `!judged` → null;
    4. `selfCheck` non-empty → `SelfCheckBadge`;
    5. else `FitsBadge`.
- **`fitsDiet`:** `'vegan'` → `dietTags.contains('vegan')`; `'vegetarisch'` → `contains('vegetarisch')`; anything else (incl. null, `'alles'`) → true.
- **`recipeScore`:** `keys` = union of `matchKeys` (none for legacy). Result `2 · |good ∩ keys| − 3 · |noticed ∩ keys|`.
- **`rankRecipes`:**
  - drop `!fitsDiet` (count them in `hiddenByDiet`), then `fitOf` each;
  - sort by score ↓, `kritischCount` ↑, `createdAt` ↓ (null last), title;
  - `checked`/`selfCheck` as `fitOf` computes them for this user.
- **`RankingSignals.of`:**
  - null → empty;
  - locked → `good = calmDayIngredients`;
  - unlocked → `good` = `goodDays.often` names lower-cased (when `goodDays.shown`), `noticed` = `noticed.where(!uncertain)` names lower-cased (when `showNoticed`).
- **`pickForYou`:** take passing fits (`passtZuMir`, or all when `!checked`) in rank order up to `count`, then top up from the remaining ranked fits.
- **`filterRecipes`:**
  - `mealType` must be in `recipe.mealTypes`;
  - `fitsOnly` keeps `passtZuMir`;
  - `query` (trimmed, lower-cased, empty = all) matches the title, any line `name`, or any legacy line.
- **`calmDayIngredients`:**
  - The keys (trimmed, lower-cased) of every ingredient of meals whose local day is inside the window and has no gut-feeling entry whose own class is hard (`_entryClassOf(e) == DayClass.hard`).
  - Days without entries count.

- [ ] **Step 1: Failing tests** (`testLine`/`testRecipe` from Task 1, rules from `testIntoleranceRules()`).
  - **`joinGerman`:** `[]` → `''`, `['A']` → `'A'`, `['A','B']` → `'A und B'`, `['A','B','C']` → `'A, B und C'`. `insight_copy_test` stays green.
  - **`fitOf`:**
    - **`Laktose`:**
      - Quark (lactose, not low) → kritisch `['Laktose']`;
      - Laktosefreier Joghurt → fits;
      - Parmesan (lactose, `lowAtAmount`) → fits;
      - Butter (`allergens: {'milch'}`) → fits.
      - Badge `KritischBadge(1)`, label `'1 Zutat ist für dich kritisch'`.
    - **`Gluten is allergen-only`:** Knoblauch (fructans) → fits; Dinkelmehl `{gluten, weizen}` → kritisch `['Gluten']`.
    - **`Weizen`:** Knoblauch (fructans, not low) → kritisch; Dinkelmehl (low) → kritisch (allergens always).
    - **`Gluten and Weizen hit one line`:** Weizenmehl → one kritisch line, because `['Gluten', 'Weizen']`, label `'1 Zutat ist für dich kritisch'`.
    - **`Histamin only`:** no kritisch → `SelfCheckBadge(['Histamin'])`, label `'Histamin bitte selbst prüfen'`, `passtZuMir` true.
    - **`Histamin and Fruktose`:** Honig (fructose, not low) → `KritischBadge(1)`.
    - **`no intolerances`:** an unmapped line fits; `FitsBadge`, `'Passt zu dir'`.
    - **`unmapped line with Fruktose`:** mark unknown, `judged` false, badge null, `passtZuMir` false.
    - **`allergen-only user, unmapped lines`** (Eier): unmapped `{eier}` → kritisch; unmapped without allergens → fits; `judged` true.
    - **`not in the table`:** `['Milch']` → `FitsBadge`.
    - **`rules unknown`** / **`profile unknown`** (`intolerances: null`): `checked` false, `lines` empty, badge null, `passtZuMir` false.
    - **`older recipe`:** Fruktose → badge null, `judged` false; no intolerances → `FitsBadge`.
    - Two kritisch lines → `'2 Zutaten sind für dich kritisch'`.
  - **Ranking:**
    - **`fitsDiet`:** vegan keeps `{vegan, vegetarisch}` only; vegetarisch keeps both kinds and drops `{}`; `'alles'` and null keep all.
    - `rankRecipes(diet: 'vegan')` reports `hiddenByDiet`.
    - **`recipeScore`:**
      - good `{'reis', 'karotte'}`, lines Reis + Karotte → 4;
      - plus noticed `{'zwiebel'}` with a Zwiebel line → 1;
      - a line named „Rote Paprika" with catalog name „Paprika" and good `{'paprika'}` → 2;
      - two Reis lines count once.
    - **`order`:**
      - score 2 beats score 0;
      - equal scores: 0 kritisch before 1;
      - then newer `createdAt` first;
      - then title.
    - **`RankingSignals.of`:**
      - null → empty;
      - locked → good = `calmDayIngredients`, noticed empty;
      - unlocked → shown good column names lower-cased; noticed without the uncertain;
      - a column not shown → empty.
    - **`pickForYou`:**
      - 2 passing + 3 kritisch → the 2 passing then the best kritisch;
      - unchecked → the first 3.
    - **`filterRecipes`:** by meal type; `fitsOnly`; query „knob" finds a Knoblauch line; „reis" finds a legacy line „200 g Reis".
  - **Insights:**
    - **`calm-day ingredients`:**
      - day A: `gut(…, 5)` and a meal „Zwiebel" → excluded;
      - day B: `gut(…, 1)` and „Reis" → included;
      - day C: no entry and „ Karotte " → included;
      - day D: `gut(…, 5)` and `gut(…, 1)` (mean medium) with „Brot" → excluded;
      - a meal before the window, „Nudeln" → excluded;
      - result `{'reis', 'karotte'}`.
    - `Insights` equality covers the new field.
- [ ] **Step 2:** Run `flutter test test/utils/german_list_test.dart test/services/recipes test/services/insights test/models/insights_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** per the interfaces and rules.
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): fit per ingredient and the personal ranking`

---

### Task 3: Recipe providers

**Files:**
- Create: `lib/providers/recipe_collection_provider.dart`, `lib/models/my_recipe_item.dart`
- Test: `test/providers/recipe_collection_provider_test.dart`, `test/models/my_recipe_item_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2; `profileProvider`, `insightsProvider`, `currentUserIdProvider`, `userRecipesProvider`.
- Produces:
  ```dart
  sealed class MyRecipeItem { DateTime get at; }
  final class OwnRecipe extends MyRecipeItem { const OwnRecipe(this.recipe); final UserRecipe recipe; } // at: createdAt ?? epoch
  final class SavedRecipe extends MyRecipeItem { const SavedRecipe(this.recipe, this.at); final Recipe recipe; }
  List<MyRecipeItem> mergeMyRecipes(List<UserRecipe> own, List<SavedRecipe> saved); // at ↓, stable (own first on ties)

  final recipeCollectionProvider = AsyncNotifierProvider<RecipeCollectionNotifier, List<Recipe>>(…, retry: noRetry);
  class RecipeCollectionNotifier extends AsyncNotifier<List<Recipe>> {
    // build: watches currentUserIdProvider; null → []; else repo.fetchCollection()
    Future<void> refresh(); // keeps shown data on failure (logs); without data, the error stays
  }
  final intoleranceRulesProvider = FutureProvider<IntoleranceRules?>(…, retry: noRetry);
  final recipeFavoritesProvider = AsyncNotifierProvider<RecipeFavoritesNotifier, List<FavoriteRecipe>>(…, retry: noRetry);
  class RecipeFavoritesNotifier extends AsyncNotifier<List<FavoriteRecipe>> {
    bool isSaved(String recipeId);
    Future<bool> toggle(String recipeId); // optimistic (new favourite first, at = now); false + revert on failure
    Future<void> refresh();
  }
  final rankingSignalsProvider = Provider<RankingSignals>;          // RankingSignals.of(insights only when AsyncData)
  final rankedRecipesProvider = Provider<AsyncValue<RankedRecipes>>; // collection.whenData(rankRecipes(…))
  final recipeFitProvider = Provider.family<AsyncValue<RecipeFit?>, String>; // any recipe by id, diet ignored
  final forYouRecipesProvider = Provider<AsyncValue<List<RecipeFit>>>;       // pickForYou(ranked.fits)
  final savedRecipesProvider = Provider<List<SavedRecipe>>;  // favourites found in the collection, newest first; [] while either has no data
  final myRecipeItemsProvider = Provider<AsyncValue<List<MyRecipeItem>>>; // userRecipesProvider.whenData(merge with saved)
  ```
- Inputs: profile = `ref.watch(profileProvider).value`, so `intolerances`/`diet` are null while it is unknown. Rules = `ref.watch(intoleranceRulesProvider).value`.

- [ ] **Step 1: Failing tests.** Use a `ProviderContainer` with `FakeRecipeRepository`, `profileProviderSeededWith(testUserProfile(intolerances: ['Fruktose'], diet: 'vegan'))`, `rankingSignalsProvider.overrideWithValue(…)` and `currentUserIdProvider.overrideWithValue(testUserId)`.
  - **`ranked: vegan profile, Fruktose`:** a non-vegan recipe is hidden (`hiddenByDiet == 1`), and the order follows the signals.
  - **`rules still loading, then loaded`:** first `checked == false`, then badges.
  - **`rules fail → unchecked, no throw`.**
  - **`refresh keeps the collection on failure`:** loaded, then `collectionError` set, `refresh()` → the same data, `hasError` false.
  - **`signed out → empty collection, no fetch`.**
  - **Favourites:**
    - `toggle adds first, then removes`: the repo records the calls and `isSaved` follows;
    - **`toggle reverts on failure`:** `favoriteError` set → `toggle` returns false and the state equals the one before.
  - **`savedRecipesProvider`:** favourites of ids missing from the collection (hidden) are skipped; newest favourite first.
  - **`myRecipeItems`:** own created 20.11. and 22.11. plus a favourite from 21.11. → own 22.11., saved, own 20.11. Own recipes loading → `AsyncLoading`.
  - **`recipeFitProvider`:** a known id → fit; unknown → null; collection error → `AsyncError`.
  - **`rankingSignals`:** an `insightsProvider` override in `AsyncLoading` → empty; `AsyncData` locked → calm-day keys.
- [ ] **Step 2:** Run `flutter test test/providers/recipe_collection_provider_test.dart test/models/my_recipe_item_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): providers for the collection, favourites and ranking`

---

### Task 4: Meine Rezepte data: steps, amounts, origin

**Files:**
- Modify:
  - `lib/models/user_recipe.dart` (+ `dart run build_runner build --delete-conflicting-outputs`)
  - `lib/services/user_recipe_service.dart`, `lib/repositories/user_recipe_repository.dart`, `lib/providers/user_recipes_provider.dart`
  - `test/helpers/fakes.dart` (`FakeUserRecipeRepository`, `testUserRecipe`)
  - the stubs in existing tests (see Global Constraints)
- Test:
  - `test/models/user_recipe_test.dart`
  - `test/services/user_recipe_service_test.dart`
  - `test/providers/user_recipes_provider_test.dart`

**Interfaces:**
- Produces:
  - `UserRecipe` fields:
    - `@Default([]) List<String> instructions`;
    - `@JsonKey(name: 'ingredient_amounts') List<String?>? ingredientAmounts`;
    - `@JsonKey(name: 'adapted_from_recipe_id') String? adaptedFromRecipeId`.
  - `UserRecipe` getters:
    - `String? amountOf(int index)`: the aligned amount, or null when absent, out of range or not aligned;
    - `bool get isAdapted => adaptedFromRecipeId != null`.
  - `UserRecipeService.create({required String userId, required String title, required List<String> ingredients, String? imageUrl, List<String> instructions = const [], List<String?>? ingredientAmounts, String? adaptedFromRecipeId})`:
    - sends `instructions` only if non-empty;
    - sends `ingredient_amounts` only if non-null;
    - sends `adapted_from_recipe_id` only if non-null.
  - `UserRecipeService.update({required String id, required String title, required List<String> ingredients, String? imageUrl, List<String>? instructions, List<String?>? ingredientAmounts})`:
    - null = not sent;
    - when `ingredientAmounts` was sent and the returned row's `ingredientAmounts` is null, it sends one more `update({'ingredient_amounts': ingredientAmounts}).eq('id', id).select().single()` and returns that row (the contract's trigger caveat).
  - The repository and `UserRecipesNotifier.create/update` pass the same parameters through. Task 10 adds `createAdapted`.
  - `FakeUserRecipeRepository` stores the new fields. `testUserRecipe` takes `instructions`, `ingredientAmounts` and `adaptedFromRecipeId`.

- [ ] **Step 1: Failing tests.**
  - **Model:**
    - `fromJson` with `ingredient_amounts: ['2 EL', null]` → `amountOf(1) == null`, `amountOf(0) == '2 EL'`;
    - **`a row from before core #11`** (no new keys) → `instructions` empty, amounts null, not adapted;
    - misaligned amounts → `amountOf(0) == null`.
  - **Service** (capture the insert/update maps with the file's existing mock helpers):
    - **`create without steps sends only the old columns`**: keys `{'user_id', 'title', 'ingredients', 'image_url'}`;
    - **`create an adapted recipe sends steps, amounts and origin`**;
    - **`update without steps or amounts leaves them out`**;
    - **`update: amounts the trigger dropped are written again`**: the first update returns `ingredient_amounts: null` → a second update with only `{'ingredient_amounts': ['2 EL', null]}`; the result has the amounts;
    - `update: amounts kept → one write`;
    - the duplicate title still throws `DuplicateRecipeTitleException` on both.
  - **Notifier:** `create(…, instructions: ['A'])` reaches the repository and refetches.
- [ ] **Step 2:** Run `flutter test test/models/user_recipe_test.dart test/services/user_recipe_service_test.dart test/providers/user_recipes_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**, run `build_runner`, and update the existing stubs (`any(named: 'instructions')`, …).
- [ ] **Step 4:** Run the whole `flutter test test/screens/recipes test/screens/trackers test/providers test/services`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): own recipes keep steps, amounts and their origin`

---

### Task 5: The meal tracker takes a `MealPrefill`

**Files:**
- Create: `lib/models/meal_prefill.dart`
- Modify:
  - `lib/providers/meal_tracker_provider.dart`
  - `lib/screens/trackers/meal/meal_tracker_screen.dart`
  - `lib/router/app_router.dart`
  - `lib/screens/recipes/recipe_detail_screen.dart`
- Test:
  - `test/models/meal_prefill_test.dart`
  - `test/providers/meal_tracker_provider_test.dart`
  - `test/screens/trackers/meal/meal_tracker_screen_test.dart`
  - `test/screens/recipes/recipe_detail_screen_test.dart`

**Interfaces:**
- Consumes: `Recipe` (Task 1), `UserRecipe`.
- Produces:
  ```dart
  class MealPrefill {
    const MealPrefill({required this.title, required this.ingredients, this.imageUrl});
    factory MealPrefill.ofUserRecipe(UserRecipe recipe); // title, ingredients, imageUrl as they are
    factory MealPrefill.ofRecipe(Recipe recipe);         // line names (legacy: its lines), trimmed, blanks dropped,
                                                         // de-duplicated case-insensitively keeping the first; no image
    final String title; final List<String> ingredients; final String? imageUrl;
  }
  ```
  - Task 10 adds `MealPrefill.ofAdapted`.
  - `MealTrackerNotifier.prefillFromRecipe(MealPrefill)` and `MealTrackerState.matchesRecipe(MealPrefill)` keep their logic.
  - `MealTrackerScreen.initialRecipe` is a `MealPrefill?`.
  - The router builds it from `extra is MealPrefill`.
  - The own-recipe detail pushes `MealPrefill.ofUserRecipe(recipe)`.
  - The selector sheet result goes through `ofUserRecipe`.

- [ ] **Step 1: Failing tests:**
  - `ofRecipe takes the names, trimmed, without duplicates, and no image`: Reis, „ reis ", Knoblauchöl → `['Reis', 'Knoblauchöl']`, `imageUrl` null;
  - `ofRecipe of an older recipe takes its lines`;
  - `ofUserRecipe keeps title, ingredients and image`;
  - the existing prefill, `matchesRecipe` and detail-to-tracker tests rewritten to `MealPrefill`.
- [ ] **Step 2:** Run `flutter test test/models/meal_prefill_test.dart test/providers/meal_tracker_provider_test.dart test/screens/trackers/meal test/screens/recipes`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(meal): the tracker is prefilled from a MealPrefill, not only an own recipe`

---

### Task 6: Recipe widgets and tokens

**Files:**
- Modify: `lib/config/app_theme.dart`, `lib/config/constants.dart`, `lib/screens/recipes/widgets/recipe_card.dart`
- Create (in `lib/screens/recipes/widgets/`):
  - `recipe_image.dart`
  - `fit_badge_view.dart`
  - `ingredient_line_view.dart`
  - `recipe_steps.dart`
  - `recipe_collection_card.dart`
  - `recipe_list_tile.dart`
- Test: one file per widget under `test/screens/recipes/widgets/`, plus `recipe_card_test.dart`

**Interfaces:**
- Produces:
  - `AppTheme`, from the mockup's illustration backgrounds and mark:
    ```dart
    recipeTintBreakfast = Color(0xFFFCF1CF); recipeTintLunch = Color(0xFFEEF4D2);
    recipeTintDinner = Color(0xFFFBE6CF);    recipeTintSnack = Color(0xFFF3EADF);
    recipeTintOther = Color(0xFFEAD9CB);     recipeChanged = Color(0xFFE2EDA9);
    ```
  - The badges reuse existing colours:
    - fits: `gutFeelingGoodSoft`/`gutFeelingGoodIcon`;
    - kritisch and self-check: `gutFeelingNeutralSoft`/`gutFeelingNeutralIcon`;
    - the heart: `buddyHeart`;
    - the „angepasst" pill: `primarySoft`/`primaryForegroundMuted`.
  - `AppConstants`: `recipeListThumbSize = 88.0`, `recipeMarkSize = 24.0`, `recipeStepsMax = 50`, `recipeStepsMaxChars = 20000`.
  - Widgets:
    ```dart
    class RecipePlaceholder extends StatelessWidget { const RecipePlaceholder({super.key, this.mealType});
      static const placeholderKey = Key('recipe_placeholder'); } // tint per type, outline icon (iconSizeLg, foreground α .45), no semantics
    class RecipeImage extends StatelessWidget { const RecipeImage({super.key, required this.recipe}); }
      // http(s) imageUrl → CachedNetworkImage(fit: cover, Shimmer placeholder enabled: !disableAnimations, error → placeholder);
      // else RecipePlaceholder(mealType: recipe.mealTypes.firstOrNull)
    class FitBadgeView extends StatelessWidget { const FitBadgeView(this.badge, {super.key, this.small = false}); }
      // pill: FitsBadge check_circle_outline, others warning_amber_rounded; label badge.label; small: fontSizeSM
    class IngredientLineView extends StatelessWidget {
      const IngredientLineView({super.key, this.amount, required this.name, this.mark, this.because = const [],
        this.replaces, this.removed = false, this.note});
    } // see the layout rules below
    class RecipeSteps extends StatelessWidget { const RecipeSteps({super.key, required this.steps, this.changed = const {}});
      static Key stepKey(int i) => ValueKey('recipe_step_$i'); }
    enum RecipeCardTag { saved, adapted }  // „Gemerkt" (favorite, buddyHeart), „Angepasst" (auto_awesome)
    class RecipeTagPill extends StatelessWidget { const RecipeTagPill(this.tag, {super.key}); }
    class RecipeCollectionCard extends StatelessWidget { const RecipeCollectionCard({super.key, required this.recipe,
      this.badge, this.tag, required this.onTap}); }  // like RecipeCard: image (aspect 1.1) with tag pill, title (2 lines), listMeta, small badge
    class RecipeListTile extends StatelessWidget { const RecipeListTile({super.key, required this.fit, required this.onTap}); }
      // row: RecipeImage thumb (recipeListThumbSize, radiusMd), title (2 lines), schedule icon + listMeta, badge
    ```
  - `RecipeCard` (own recipes) shows `RecipeTagPill(RecipeCardTag.adapted)` on its image when `recipe.isAdapted`.

**`IngredientLineView` layout:**
- A row: the mark (a `recipeMarkSize` circle), the amount (`mutedForeground`, fixed column, empty when null), then the name block.
- **Marks:**
  - `fits` → ✓ on `gutFeelingGoodSoft`;
  - `kritisch` → ⚠ in `gutFeelingNeutralIcon` on white with a border;
  - `unknown` → `help_outline` in `mutedForeground`;
  - null → no mark, and the amount column starts the row.
- **Name block:**
  - **kritisch:** name + ` ${RecipeCopy.kritischSuffix}` (w700, `gutFeelingNeutralIcon`), and below it `RecipeCopy.because(because)` (caption);
  - **unknown:** below it `RecipeCopy.notInCatalog`;
  - **`replaces`:** the struck `replaces` + „ → " + the name (w700) + a trailing „getauscht" caption, on a `primarySoft` row;
  - **`removed`:** the struck name + „weggelassen";
  - **`note`:** a muted caption („unbekannt").
- Semantics: one merged node:
  - `'$amount $name, für dich kritisch, wegen …'`;
  - `'$amount $name, passt'` (fits);
  - `'… $name, nicht im Katalog'`;
  - `'$replaces getauscht gegen $name'`.

- [ ] **Step 1: Failing tests:**
  - placeholder:
    - each `MealType` paints its tint;
    - null → `recipeTintOther`;
  - `RecipeImage`:
    - null url → `RecipePlaceholder`;
    - `https://…` → a `CachedNetworkImage`;
    - `ftp://x` → placeholder;
    - under `disableAnimations` the shimmer is disabled;
  - badges: labels for 1/2 kritisch, Histamin, fits;
  - line view:
    - kritisch shows „— für dich kritisch" and „wegen Fruktose";
    - unknown shows „nicht im Katalog";
    - swap shows the struck original, „getauscht", a `primarySoft` row and its semantics;
    - removed shows „weggelassen";
  - steps:
    - numbered 1..n;
    - a changed step's container has `recipeChanged` and its number `primary`;
  - collection card and list tile: title, meta, badge, tag pill; `fits 375×667 at text scale 1.3` (a list of 3 tiles; a row of 3 cards at `discoverRecipeCardWidth`);
  - `RecipeCard` of an adapted own recipe shows „Angepasst".
- [ ] **Step 2:** Run `flutter test test/screens/recipes/widgets test/config`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again, plus `flutter test test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): recipe image, fit badge, ingredient lines, steps and cards`

---

### Task 7: The recipe detail

**Files:**
- Create: `lib/screens/recipes/collection_recipe_screen.dart`
- Modify:
  - `lib/router/route_names.dart`, `lib/router/app_router.dart`, `lib/router/navigation_extensions.dart`
  - `lib/screens/screens.dart`
- Test: `test/screens/recipes/collection_recipe_screen_test.dart`, `test/router/navigation_extensions_test.dart`

**Interfaces:**
- Consumes: `recipeFitProvider`, `recipeFavoritesProvider`, `recipeCollectionProvider` (Task 3); `MealPrefill.ofRecipe` (Task 5); the widgets of Task 6; `openExternalUrl`.
- Produces:
  - `RouteNames.collectionRecipe = 'collection-recipe'`, `RouteNames.collectionRecipeAdapt = 'collection-recipe-adapt'`.
  - `RoutePaths.collectionRecipe = '/collection/:id'`, `RoutePaths.collectionRecipeAdapt = '/collection/:id/adapt'`, `collectionRecipeFor(id)`, `collectionRecipeAdaptFor(id)`. Task 11 registers the adapt route.
  - A top-level `GoRoute` for the detail.
  - On `BellyBuddyNavigation`: `Future<void> openRecipe(String recipeId) => push<void>(RoutePaths.collectionRecipeFor(recipeId));` — Stage 3's Tipps call this.
  - The screen:
    ```dart
    class CollectionRecipeScreen extends ConsumerWidget {
      const CollectionRecipeScreen({super.key, required this.recipeId, this.openUrl = launchUrl});
      static const adaptKey = Key('recipe_adapt'), saveKey = Key('recipe_save'),
        logKey = Key('recipe_log'), sourceKey = Key('recipe_source');
    }
    ```
- Messages: `static const sourceFailed = 'Die Quelle konnte nicht geöffnet werden.'`, `saved = 'Gemerkt. Du findest es unter „Meine Rezepte".'`, `unsaved = 'Nicht mehr gemerkt.'`, `saveFailed = 'Das hat gerade nicht geklappt. Bitte versuch es nochmal.'`.

**Layout** (mockup „Rezept", app bar „Rezept" with back via `popOrGoDashboard`, `screenBackground`):
- Hero: `RecipeImage`, 16:9, `radiusLg`.
- Title (`fontSizeDisplay`, w700).
- Schedule icon + `detailMeta`.
- `FitBadgeView` when the badge isn't null.
- Card „Zutaten":
  - right of the header: „für N Portionen" (`servingsLabel`);
  - one `IngredientLineView` per `LineFit` (mark, `because`; unchecked → no mark);
  - legacy → its lines, unmarked;
  - with `kritischCount > 0`:
    - a full-width tonal button „Für mich anpassen" (`auto_awesome`) → `context.push(RoutePaths.collectionRecipeAdaptFor(id), extra: true)`;
    - below it `RecipeCopy.adaptHint(names of the kritisch lines)`.
- Card „Zubereitung": `RecipeSteps(steps: instructions)`; hidden when there are none.
- „Quelle: <sourceName ?? Uri.host> ›" → `openExternalUrl(context, sourceUrl, failureMessage: sourceFailed, open: openUrl, mode: LaunchMode.inAppBrowserView)`. Hidden without `sourceUrl`.
- Bottom bar (SafeArea, `paddingMd`):
  - `BbButton` „Als Essen eintragen" → `context.push(RoutePaths.mealTracker, extra: MealPrefill.ofRecipe(recipe))`;
  - an outlined toggle „Merken" (`favorite_border`) / „Gemerkt" (`favorite`, `buddyHeart`) → `toggle`. SnackBar `saved`/`unsaved`, or `saveFailed` when it returns false.
- **States:**
  - loading → app bar + spinner;
  - error → `BbErrorState(message: 'Konnte das Rezept nicht laden', onRetry: refresh)`;
  - null → „Rezept nicht gefunden".

- [ ] **Step 1: Failing tests** (`FakeRecipeRepository` with a recipe of Reis + Honig (fructose, not low); a Fruktose profile):
  - **`marks each ingredient`:** Reis ✓, „Honig — für dich kritisch", „wegen Fruktose"; badge „1 Zutat ist für dich kritisch";
  - **`kritisch → Für mich anpassen with the hint`:** the hint reads „Ich tausche Honig und schreibe die Schritte passend um."; a tap pushes `/collection/recipe-1/adapt` with `extra == true` (stub route records `state.extra`);
  - **`nothing kritisch → no adapt button`;**
  - **`Histamin user`:** „Histamin bitte selbst prüfen", no „Passt zu dir";
  - **`rules missing: no badge, no marks, no adapt button`** (`rules = null`);
  - **`steps numbered`, `Quelle opens in the in-app browser`** (the recorded `mode == LaunchMode.inAppBrowserView`), and a failure → `sourceFailed`;
  - **`Merken`:**
    - toggles to „Gemerkt" with `saved`, then back with `unsaved`;
    - **`Merken offline reverts`** (`favoriteError`) with `saveFailed`;
  - **`Als Essen eintragen`:** pushes `/meal-tracker` with `MealPrefill` `['Reis', 'Honig']`;
  - **`collection fails: retry`:** `BbErrorState`; retry after clearing the error shows the recipe;
  - **`unknown id`:** „Rezept nicht gefunden";
  - **`fits 375×667 at text scale 1.3`;**
  - navigation: `openRecipe pushes /collection/<id>`.
- [ ] **Step 2:** Run `flutter test test/screens/recipes/collection_recipe_screen_test.dart test/router`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again, plus the vocabulary test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): the recipe detail with ✓/⚠, Merken, Quelle and Als Essen eintragen`

---

### Task 8: The Rezepte list

**Files:**
- Create: `lib/screens/recipes/collection_screen.dart`
- Modify: `lib/router/route_names.dart`, `lib/router/app_router.dart`, `lib/screens/screens.dart`
- Test: `test/screens/recipes/collection_screen_test.dart`, `test/router/navigation_shell_test.dart`

**Interfaces:**
- Consumes: `rankedRecipesProvider`, `recipeCollectionProvider`, `intoleranceRulesProvider` (Task 3); `filterRecipes`, `RecipeCopy` (Task 2); `RecipeListTile` (Task 6); `openRecipe` (Task 7).
- Produces:
  - `RouteNames.discoverRecipes = 'discover-recipes'`, `RoutePaths.discoverRecipes = '/discover/recipes'`, as the sub-route `'recipes'` of the discover `GoRoute` (next to `knowledge`).
  - The screen:
    ```dart
    class CollectionScreen extends ConsumerStatefulWidget {
      const CollectionScreen({super.key});
      static const searchKey = Key('collection_search'), fitToggleKey = Key('collection_fit');
      static Key chipKey(MealType t) => ValueKey('collection_chip_${t.key}');
      static const empty = 'Keine Rezepte gefunden. Probier einen anderen Filter oder Suchbegriff.';
    }
    ```

**Layout** (app bar „Rezepte", back: `canPop() ? pop() : go(RoutePaths.discover)`):
- A search field, hint „Rezept oder Zutat suchen" (local, no debounce).
- The chips Frühstück/Mittag/Abend/Snack: single choice, a second tap clears.
- When `ranked.checked`: a switch row „Passt zu mir" / „Nur Rezepte ohne kritische Zutaten". With `selfCheck` non-empty, a second line `RecipeCopy.selfCheckFilter(selfCheck)`.
- The count line: `'1 Rezept'`/`'N Rezepte'` + `' · für dich sortiert'`, plus with `hiddenByDiet > 0` `' · nur vegane, wie in deinem Profil'` (vegan) or `' · nur vegetarische, wie in deinem Profil'`.
- `RecipeListTile`s, or `empty`.
- **States:**
  - pull-to-refresh → collection `refresh()` and `ref.invalidate(intoleranceRulesProvider)`;
  - error without data → `BbErrorState(message: 'Rezepte konnten nicht geladen werden.', onRetry: …)`.

- [ ] **Step 1: Failing tests:**
  - **`chips filter by meal type`:** „Abend" shows only dinner recipes; a second tap shows all again;
  - **`Passt zu mir hides kritisch and unjudged recipes`;**
  - **`Histamin line under the toggle`;**
  - **`rules missing: no Passt-zu-mir toggle`;**
  - **`search finds titles and ingredients`** („honig");
  - **`count line with the vegan note`** (`'2 Rezepte · für dich sortiert · nur vegane, wie in deinem Profil'`);
  - **`nothing found`** → `empty`;
  - **`a tile opens the recipe`;**
  - **`fits 375×667 at text scale 1.3`;**
  - shell: **`Rezepte opens under Entdecken with the bar`** (push `RoutePaths.discoverRecipes` → `BbBottomNav` present, like the Wissen test).
- [ ] **Step 2:** Run `flutter test test/screens/recipes/collection_screen_test.dart test/router/navigation_shell_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again, plus the vocabulary test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): the Rezepte list with meal filter, Passt zu mir and search`

---

### Task 9: Entdecken „Rezepte" and gemerkte in Meine Rezepte

**Files:**
- Rewrite: `lib/screens/discover/widgets/discover_recipes_section.dart`
- Modify:
  - `lib/screens/discover/widgets/discover_section.dart` (`DiscoverAllLink.semanticsLabel`)
  - `lib/screens/discover/discover_screen.dart`
  - `lib/screens/recipes/my_recipes_tab.dart`
- Test:
  - `test/screens/discover/widgets/discover_recipes_section_test.dart` (create)
  - `test/screens/discover/discover_screen_test.dart`
  - `test/screens/recipes/my_recipes_tab_test.dart`

**Interfaces:**
- Consumes: `forYouRecipesProvider`, `myRecipeItemsProvider`, `savedRecipesProvider`, `recipeCollectionProvider`, `recipeFavoritesProvider`, `intoleranceRulesProvider`, `MyRecipeItem` (Task 3); `RecipeCollectionCard`, `RecipeCard` (Task 6); `openRecipe` (Task 7).
- Produces:
  ```dart
  class DiscoverRecipesSection extends StatelessWidget {
    const DiscoverRecipesSection({super.key, required this.forYou, required this.mine, required this.onOpenAll,
      required this.onOpenMine, required this.onOpenRecipe, required this.onOpenOwn});
    static const sectionKey = Key('discover_recipes');        // DiscoverScreen.recipesKey stays this
    static const forYouKey = Key('discover_recipes_for_you');
    static const mineKey = Key('discover_recipes_mine');
    static const shown = 6;
    final AsyncValue<List<RecipeFit>> forYou;
    final AsyncValue<List<MyRecipeItem>> mine;
    final VoidCallback onOpenAll, onOpenMine;
    final ValueChanged<String> onOpenRecipe;
    final ValueChanged<UserRecipe> onOpenOwn;
  }
  ```
  `DiscoverAllLink({super.key, required this.onTap, this.semanticsLabel})`.

**Layout:** `DiscoverSection(title: 'Rezepte', actions: [DiscoverAllLink(onTap: onOpenAll)])`, then:
- **„Für dich":**
  - sub-header: „Für dich" (`fontSizeSubtitle`, w700) + caption „passend zu deinen Angaben";
  - a horizontal row of `RecipeCollectionCard(badge: fit.badge)` at `discoverRecipeCardWidth`;
  - no data → `DiscoverNote.pending(forYou, 'Rezepte')`; empty → `DiscoverNote('Noch keine Rezepte.')`.
- **„Meine Rezepte":**
  - sub-header: „Meine Rezepte" + `IconButton(add, tooltip 'Rezept hinzufügen')` → `showAddRecipeChooserSheet`, plus, with items, `DiscoverAllLink(onTap: onOpenMine, semanticsLabel: 'Alle meine Rezepte')`;
  - a row of up to `shown` items: `OwnRecipe` → `RecipeCard`, `SavedRecipe` → `RecipeCollectionCard(tag: RecipeCardTag.saved)`;
  - empty → today's card („Noch keine Rezepte." + „Erstes Rezept erstellen"); no data → `DiscoverNote.pending(mine, 'Rezepte')`.

**`DiscoverScreen`:**
- Watches `forYouRecipesProvider` and `myRecipeItemsProvider`.
- `onOpenAll` → `context.push(RoutePaths.discoverRecipes)`; `onOpenMine` → `RoutePaths.recipes`; `onOpenRecipe` → `context.openRecipe`; `onOpenOwn` → `recipeDetailFor`.
- `_load(refresh: true)` also awaits the collection's and the favourites' `refresh()` and invalidates `intoleranceRulesProvider`.
- The class comment names the section „Rezepte".

**`MyRecipesTab`:**
- Items = `mergeMyRecipes(search results, saved)`. While a query is active, the saved are filtered by title (case-insensitive `contains` of the trimmed query).
- The grid builds `RecipeCard` or `RecipeCollectionCard(tag: saved)` (→ `openRecipe`).
- `_EmptyState` only when both are empty and no query is active.

- [ ] **Step 1: Failing tests.** `discover_screen_test`'s pump adds `recipeRepositoryProvider` (`FakeRecipeRepository`) and `entryRepositoryProvider` (`FakeEntryRepository`), and stub routes for `discoverRecipes` and `collectionRecipe`.
  - **`Rezepte: Für dich shows 3 ranked cards with badges`;**
  - **`Alle › opens the Rezepte list`;**
  - **`Meine Rezepte: own and gemerkte by date, the gemerkte with a heart`;**
  - **`Meine Rezepte' Alle › opens /recipes`** (by semantics label „Alle meine Rezepte"; replaces today's `page:/recipes` expectation);
  - **`collection fails: own recipes still shown`:** `collectionError` → „Rezepte konnten nicht geladen werden." under „Für dich", and the own recipe cards are present;
  - **`pull to refresh reloads the collection and the rules`;**
  - section `fits 375×667 at text scale 1.3`;
  - `MyRecipesTab`:
    - **`gemerkte appear with a heart`;**
    - **`a search filters the gemerkte by title`;**
    - **`only gemerkte → grid, not the empty state`.**
- [ ] **Step 2:** Run `flutter test test/screens/discover test/screens/recipes/my_recipes_tab_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again, plus the vocabulary test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(discover): „Rezepte" with Für dich and Meine Rezepte; gemerkte in Meine Rezepte`

---

### Task 10: Adapting: the answer, the errors, saving

**Files:**
- Create: `lib/models/adapted_recipe.dart`, `lib/providers/adapt_recipe_provider.dart`
- Modify:
  - `lib/services/recipe_service.dart`, `lib/repositories/recipe_repository.dart`
  - `lib/providers/user_recipes_provider.dart` (`createAdapted`)
  - `lib/models/meal_prefill.dart` (`ofAdapted`)
  - `test/helpers/fakes.dart`
- Test:
  - `test/models/adapted_recipe_test.dart`
  - `test/services/recipe_service_test.dart`
  - `test/providers/adapt_recipe_provider_test.dart`
  - `test/providers/user_recipes_provider_test.dart`
  - `test/models/meal_prefill_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class AdaptedIngredient { const AdaptedIngredient({this.amount, required this.name, this.replaces, this.unknown = false});
    factory AdaptedIngredient.fromJson(Map<String, dynamic> json); // unknown = status == 'unbekannt'; blank amount → null
    final String? amount; final String name; final String? replaces; final bool unknown; }
  class AdaptedStep { const AdaptedStep(this.text, {this.changed = false}); final String text; final bool changed; }
  class AdaptedRecipe {
    const AdaptedRecipe({required this.recipeId, required this.title, required this.ingredients,
      this.removed = const [], required this.steps, this.note = ''});
    factory AdaptedRecipe.fromJson(Map<String, dynamic> json); // throws FormatException without title/ingredients
    final String recipeId, title, note; final List<AdaptedIngredient> ingredients;
    final List<String> removed; final List<AdaptedStep> steps;
    List<String> get unknownNames;
  }
  enum AdaptFailure { nothingToAdapt, cannotJudge, later, failed }
  class AdaptRecipeException implements Exception { const AdaptRecipeException(this.failure); final AdaptFailure failure; }

  // RecipeService / RecipeRepository
  Future<AdaptedRecipe> adapt(String recipeId);
    // _client.functions.invoke('adapt-recipe', body: {'recipe_id': recipeId})

  final adaptRecipeProvider = AsyncNotifierProvider.autoDispose
      .family<AdaptRecipeNotifier, AdaptedRecipe?, String>((id) => AdaptRecipeNotifier(id), retry: noRetry);
  class AdaptRecipeNotifier extends AsyncNotifier<AdaptedRecipe?> {
    AdaptRecipeNotifier(this.recipeId); final String recipeId;
    // build → null (idle): nothing is sent until start()
    Future<void> start();  // no-op while loading or with a result; AsyncLoading, then AsyncValue.guard(repo.adapt)
    Future<void> retry();  // start again regardless of a result
  }

  // UserRecipesNotifier
  Future<UserRecipe> createAdapted(AdaptedRecipe adapted);
  // MealPrefill
  factory MealPrefill.ofAdapted(AdaptedRecipe adapted); // title, ingredient names (same clean-up as ofRecipe), no image
  ```

**Error mapping** in `adapt`. `code` = `(e.details as Map?)?['code']`:

| Exception | Failure |
|---|---|
| `FunctionException` 409 `nothing_to_adapt` | `nothingToAdapt` |
| `FunctionException` 409 `cannot_judge` | `cannotJudge` |
| any 429 (`throttled`, `ai_busy`) | `later` |
| anything else (`adapt_failed`, `ai_error`, `recipe_not_found`, `invalid_request`, 401, 500, `FunctionsFetchException`) | `failed` |
| a 200 body that isn't a map or fails `fromJson` | `failed` |

- Logging: `warn` for 409/429, `error` otherwise.

**`createAdapted`:**
- Names: trimmed, de-duplicated case-insensitively (first wins), each with its amount.
- `ingredientAmounts`: the aligned amounts, or null when all are null.
- `instructions`: the steps' trimmed non-empty texts, at most `recipeStepsMax`.
- `adaptedFromRecipeId: recipeId`, `imageUrl: null`.
- Titles tried in order: `title`, `'$title (angepasst)'`, `'$title (angepasst 2)'` … `'$title (angepasst 9)'`. Only `DuplicateRecipeTitleException` moves on; after the last it rethrows.
- Refetches like `create`.

`FakeRecipeRepository` gains `Future<AdaptedRecipe> Function(String recipeId)? onAdapt` (default: a fixture `testAdaptedRecipe()`) and an `adaptCalls` counter. The fixture swaps Honig → Ahornsirup with `changed` step 2 and the note „Ich hab Honig gegen Ahornsirup getauscht.".

- [ ] **Step 1: Failing tests:**
  - `fromJson of the contract's example` (3 ingredients, `removed: ['Zwiebel']`, the first step changed, `unknownNames == ['Sumach']`);
  - **`error codes map`** (table-driven over the rows above, with `FunctionsHttpException(status:, details: {'code': …, 'error': '…'})`);
  - **`transport failure`** (`FunctionsFetchException`) → `failed`;
  - `the body is exactly the recipe id` (captured `body == {'recipe_id': 'recipe-1'}`);
  - notifier:
    - `idle until start` (`adaptCalls == 0` after the first read);
    - `start once` (a second `start` while loading doesn't call again);
    - `retry after a failure calls again`;
  - `createAdapted`:
    - **`duplicate title`**: the fake throws on „Risotto" → saved as „Risotto (angepasst)"; with both taken → „Risotto (angepasst 2)";
    - `amounts aligned with nulls`;
    - `all amounts null → none sent`;
    - `steps and origin sent`;
    - `duplicate names keep the first`;
  - `ofAdapted` names.
- [ ] **Step 2:** Run `flutter test test/models/adapted_recipe_test.dart test/services/recipe_service_test.dart test/providers/adapt_recipe_provider_test.dart test/providers/user_recipes_provider_test.dart test/models/meal_prefill_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): adapt-recipe answers, errors and saving as an own recipe`

---

### Task 11: The adapt screen

**Files:**
- Create: `lib/screens/recipes/adapt_recipe_screen.dart`
- Modify: `lib/router/app_router.dart`, `lib/screens/screens.dart`
- Test: `test/screens/recipes/adapt_recipe_screen_test.dart`

**Interfaces:**
- Consumes: `adaptRecipeProvider`, `createAdapted`, `MealPrefill.ofAdapted` (Task 10); `recipeFitProvider` (the original's image, meta and source, Task 3); `RecipeImage`, `IngredientLineView`, `RecipeSteps`, `RecipeTagPill` (Task 6); `BuddyStage`/`BuddySideHeader` + `BuddyController`.
- Produces:
  - A top-level `GoRoute(path: RoutePaths.collectionRecipeAdapt, name: RouteNames.collectionRecipeAdapt)` → `AdaptRecipeScreen(recipeId: id, requested: state.extra == true)`.
  - The screen:
    ```dart
    class AdaptRecipeScreen extends ConsumerStatefulWidget {
      const AdaptRecipeScreen({super.key, required this.recipeId, this.requested = false, this.openUrl = launchUrl});
      static const saveKey = Key('adapt_save'), logKey = Key('adapt_log'), retryKey = Key('adapt_retry'), startKey = Key('adapt_start');
      static const loading = 'Ich bau’s für dich um …';
      static const loadingSub = 'Ich tausche, was für dich kritisch ist, und prüfe jede Zutat im FODMAP-Katalog.';
      static const allChecked = 'Alle Zutaten mit dem FODMAP-Katalog geprüft';
      static String someUnknown(List<String> names); // 'Mit dem FODMAP-Katalog geprüft. Nicht im Katalog: ${joinGerman(names)}'
      static String messageFor(AdaptFailure f);      // the Decisions' four texts
      static const saveFailed = 'Speichern hat nicht geklappt. Bitte versuch es nochmal.';
    }
    ```

**Behaviour** (app bar „Für dich angepasst", back pops):
- **Start:** `initState` calls `start()` on the first frame when `requested`. Otherwise an idle view: the Buddy, „Soll ich das Rezept für dich umbauen?" and a „Für mich anpassen" button (`startKey`).
- **Loading:** `BuddyStage` (a `BuddyController(mood: BuddyMood.zen)` that `say`s `loading` with no duration), then `loadingSub` below.
- **Failure:**
  - `messageFor(f)` beside the Buddy (`BuddyMood.empathetic`);
  - `later`/`failed` → „Nochmal versuchen" (`retryKey`) → `retry()`;
  - `nothingToAdapt`/`cannotJudge` → only „Zurück zum Rezept" (pop).
- **Result:**
  - the hero: the original's `RecipeImage` (or `RecipePlaceholder`) with a „Für dich angepasst" pill;
  - the adapted `title`; the original's `detailMeta`;
  - the Buddy with `note` in a side bubble (skipped when blank);
  - the check line: `allChecked` on `gutFeelingGoodSoft`, or `someUnknown` on `gutFeelingNeutralSoft`;
  - card „Zutaten" („für N Portionen"):
    - `IngredientLineView` per ingredient: `mark: unknown ? LineMark.unknown : LineMark.fits`, `replaces`, `note: unknown ? 'unbekannt' : null`;
    - then each `removed` with `removed: true`;
  - card „Zubereitung" with a „geändert" legend (a `recipeChanged` swatch) when any step changed: `RecipeSteps(steps: texts, changed: {indices})`;
  - „Original: <title>" + `' · <sourceName>'` + `' ›'` → the source URL in the in-app browser. Without `sourceUrl` it is plain text with no „›".
- **Actions** (a column at the bottom):
  - `BbButton` „In Meine Rezepte speichern" (`saveKey`, loading while saving):
    - success → it reads „In Meine Rezepte gespeichert" with a check, and a tap opens `RoutePaths.recipeDetailFor(saved.id)`;
    - failure → SnackBar `saveFailed`;
  - an outlined `BbButton` „Als Essen eintragen" (`logKey`) → the meal tracker with `MealPrefill.ofAdapted`.

- [ ] **Step 1: Failing tests** (`FakeRecipeRepository.onAdapt` backed by a `Completer`; `FakeUserRecipeRepository` for the save):
  - `requested: the Buddy says the loading line, then the result`;
  - `not requested: nothing is sent until „Für mich anpassen"` (`adaptCalls` 0 → 1);
  - result:
    - `the swap is shown`: struck „Honig", „Ahornsirup", „getauscht";
    - `a changed step is highlighted` (`RecipeSteps.stepKey(1)` with `recipeChanged`);
    - the note in the bubble;
  - **`an unknown ingredient keeps the check line honest`**: „Nicht im Katalog: Sumach" and no `allChecked`;
  - **`each failure's message`**, table-driven:
    - `later` → the „später" text + retry;
    - `failed` → the neutral text + retry;
    - `nothingToAdapt`/`cannotJudge` → their texts, no retry, and `find.textContaining('passt')` finds nothing;
  - `retry calls again`;
  - **`save`:**
    - `createAdapted` reaches the fake with the amounts, steps and origin;
    - the button turns to „In Meine Rezepte gespeichert" and opens `/recipe/rec-1`;
    - `save fails → SnackBar`;
  - `Als Essen eintragen pushes the adapted names`;
  - `fits 375×667 at text scale 1.3` (a result with 8 ingredients and 6 steps).
- [ ] **Step 2:** Run `flutter test test/screens/recipes/adapt_recipe_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again, plus the vocabulary test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): Für mich anpassen — the Buddy rebuilds it, swaps marked, saved to Meine Rezepte`

---

### Task 12: Own recipes: steps in the detail and the editor

**Files:**
- Create: `lib/screens/recipes/widgets/recipe_steps_editor.dart`
- Modify: `lib/screens/recipes/recipe_detail_screen.dart`, `lib/screens/recipes/recipe_editor_screen.dart`
- Test:
  - `test/screens/recipes/recipe_detail_screen_test.dart`
  - `test/screens/recipes/recipe_editor_screen_test.dart`
  - `test/screens/recipes/widgets/recipe_steps_editor_test.dart`

**Interfaces:**
- Consumes: `UserRecipe.instructions/amountOf/isAdapted/adaptedFromRecipeId` and the service's null-means-not-sent parameters (Task 4); `IngredientLineView`, `RecipeSteps`, `RecipeTagPill` (Task 6); `recipeFitProvider`, `openRecipe`.
- Produces:
  ```dart
  class RecipeStepsEditor extends StatefulWidget {
    const RecipeStepsEditor({super.key, required this.initial, required this.onChanged});
    final List<String> initial; final ValueChanged<List<String>> onChanged; // raw texts, in order
    static const addKey = Key('steps_add');
    static Key fieldKey(int i) => ValueKey('steps_field_$i');
    static Key removeKey(int i) => ValueKey('steps_remove_$i');
  }
  ```
  - Header „Zubereitung" + „optional".
  - Per step: its number, a multi-line `TextField` (hint „Schritt beschreiben"), and a remove `IconButton` (tooltip „Schritt entfernen").
  - `TextButton.icon(add)` „Schritt hinzufügen", disabled at `AppConstants.recipeStepsMax`.
  - The widget owns one controller per step and disposes them.

**Detail:**
- Ingredients: `IngredientLineView(amount: recipe.amountOf(i), name: …)` rows, no mark, replacing the chips.
- With `isAdapted`: a „Für dich angepasst" pill under the title.
- Card „Zubereitung":
  - `RecipeSteps(steps: instructions)`;
  - when empty: header suffix „optional", „Noch keine Schritte." and `TextButton.icon` „Schritte hinzufügen" → `recipeEditFor(id)`.
- With `adaptedFromRecipeId` and `recipeFitProvider(that id)` holding a recipe: „Original: <title> ›" → `openRecipe`.

**Editor:**
- `_steps` starts from `recipe.instructions` (edit) or `[]`.
- `_amounts`: name → amount from the loaded recipe; `_hadAmounts = recipe.ingredientAmounts != null`.
- **On save:**
  - steps = the trimmed non-empty texts;
  - a total length over `recipeStepsMaxChars` → SnackBar „Die Zubereitung ist zu lang. Bitte kürze sie." and no save.
- **Create:** `instructions: steps`.
- **Update:**
  - `instructions: steps` only when they differ from the loaded ones, else null;
  - `ingredientAmounts`: with `_hadAmounts`, the list `_ingredients.map((n) => _amounts[n])` (null when all null), else null.

- [ ] **Step 1: Failing tests:**
  - detail:
    - `steps numbered`;
    - `no steps → „Noch keine Schritte." and Schritte hinzufügen opens the editor`;
    - `amounts beside the ingredients`;
    - `adapted: the pill and Original › open the collection recipe`;
    - `original not in the collection → no link`;
  - editor:
    - `add and remove steps`;
    - `create sends the steps`;
    - **`edit without touching the steps sends none`** (`instructions: null` verified);
    - `edited steps are sent`;
    - **`removing an ingredient keeps the others' amounts`**: loaded `['Knoblauchöl', 'Reis', 'Salz']` / `['2 EL', '200 g', null]`, remove Reis → update with `ingredientAmounts == ['2 EL', null]`;
    - `a template sends no amounts`;
    - `too long → message, no save`;
    - `50 steps → add disabled`;
  - `editor fits 375×667 at text scale 1.3 with 3 steps`.
- [ ] **Step 2:** Run `flutter test test/screens/recipes`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again, plus the vocabulary test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(recipes): own recipes get optional steps; amounts follow their ingredients`

---

### Task 13: Integration flows and the stage check

**Files:**
- Modify: `integration_test/helpers/test_app.dart` (`recipeRepo` parameter, default `FakeRecipeRepository()`)
- Create: `integration_test/recipe_collection_flow_test.dart`

**Flows:**
- `setUp`: `setNotificationModalShown`. The profile: `intolerances: ['Fruktose']`, `diet: 'vegetarisch'`.
- The fake collection:
  - „Reis-Bowl" (mittag, fits);
  - „Honig-Porridge" (frühstück, Honig kritisch);
  - „Hähnchen-Curry" (abend, no diet tags → hidden).
1. **Collection and adapt:**
   - Entdecken shows „Rezepte" with „Für dich" → „Alle ›";
   - the list keeps the bottom bar and reads `2 Rezepte · für dich sortiert · nur vegetarische, wie in deinem Profil`;
   - „Passt zu mir" hides „Honig-Porridge"; turn it off and open it;
   - „Honig — für dich kritisch" → „Für mich anpassen";
   - the result shows „getauscht" → „In Meine Rezepte speichern" → „In Meine Rezepte gespeichert";
   - back to Entdecken: „Meine Rezepte" shows the adapted card with „Angepasst".
2. **Merken:**
   - in „Reis-Bowl", „Merken" → „Gemerkt" and the SnackBar;
   - back: the heart card is in „Meine Rezepte"; un-merk → it is gone.
3. **Als Essen eintragen:**
   - „Reis-Bowl" → the tracker shows its ingredient chips → „Speichern" → the success page;
   - dismiss by the message (like `recipes_flow_test`) → Home.
4. **Steps:**
   - an own recipe → „Schritte hinzufügen" → the editor, type one step → „Speichern";
   - the detail shows „1" and the step.

- [ ] **Step 1:** Write the flows and the helper parameter.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze` (0 issues) and the full `flutter test`. Expected: all pass.
- [ ] **Step 3: Only on the iPhone Air**, one file at a time:
  ```bash
  SIM=CB1F6232-482F-408F-ADF4-89FDA602E6A8
  xcrun simctl boot $SIM || true
  for f in recipe_collection_flow_test recipes_flow_test discover_flow_test meal_tracking_flow_test home_motivation_flow_test insights_flow_test tutorial_flow_test diary_flow_test drink_tracking_flow_test auth_flow_test registration_flow_test; do
    flutter test integration_test/$f.dart -d $SIM --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown $SIM
  ```
  Expected: every file `EXIT 0`. If a case fails, run the same file on the base commit in a temporary worktree before calling it pre-existing.
- [ ] **Step 4: Commit** `test(integration): the recipe collection, adapt, Merken, logging and steps`

---

## Self-Review notes

**Spec coverage:**

| Spec / contract | Task(s) |
|---|---|
| §5.6.1 Entdecken „Rezepte": „Für dich" (3, ranked), „Meine Rezepte", „Alle ›" | 3, 9 |
| §5.6.1 list `/discover/recipes` in the branch: chips, „Passt zu mir", search, cards with image, title, time, badge | 6, 8 |
| §5.6.1 detail: placeholder image, „35 Min · 2 Portionen", ✓/⚠ („Knoblauch — für dich kritisch"), „Für mich anpassen" on any ⚠, Zubereitung, „Quelle ›" in-app browser, „Als Essen eintragen" pre-filled, „♡ Merken" | 5, 6, 7 |
| §5.6.1 gemerkte in „Meine Rezepte" with a heart; detail without the bar | 3, 7, 9 |
| §5.6.3 diet filter, kritisch count drives the badge, good days up / „Fällt mir auf" down, ties by kritisch then newest, „Passt zu mir" = 0 kritisch | 2, 3, 8 |
| §5.6.4 app: Buddy loading „Ich bau's für dich um …", swaps and changed sentences marked, „Alle Zutaten mit dem FODMAP-Katalog geprüft", „In Meine Rezepte speichern" with steps and `adapted_from_recipe_id`, neutral errors + retry | 10, 11 |
| §5.6.5 `instructions`, editor steps list, the meal-template behaviour unchanged | 4, 12 |
| Decisions 1: allergens and the intolerance mapping, Histamin „bitte selbst prüfen" + the filter line | 1, 2, 7, 8 |
| Decisions 2: kritisch only when not `low_at_amount`, allergens always | 2 |
| Decisions 6: Laktose = lactose only; `ingredient_amounts`; „(angepasst)" on duplicates; the app reads `intolerance_rules` | 1, 2, 4, 10, 12 |
| Contract: select, `hidden=is.false`, the trigger caveat, adapt body and codes, `cannot_judge` must not say „passt" | 1, 4, 10, 11 |
| §3 privacy (tap only, recipe id only), reduced motion, 375×667 @1.3, vocabulary, no copied photos | 6, 7, 8, 9, 11, 12 |
| Graceful degrade without core #11 | 3, 4, 9 |
| Stage 3 entry point `openRecipe(id)`; day 1/5 rewards can reuse `rankRecipes`/`pickForYou`/`calmDayIngredients` | 2, 7 |

**Interfaces across tasks:**
- `Recipe`, `RecipeIngredient`, `MealType`, `FavoriteRecipe`, `IntoleranceRules`, `FodmapFlags.has`, `testRecipe`/`testLine`/`testIntoleranceRules`, `FakeRecipeRepository`: T1 → T2–T13.
- `joinGerman`, `RecipeCopy`, `LineMark`, `LineFit`, `FitBadge`, `RecipeFit`, `fitOf`, `RankingSignals`, `RankedRecipes`, `rankRecipes`, `pickForYou`, `filterRecipes`, `Insights.calmDayIngredients`: T2 → T3, T6–T9, T11.
- `recipeCollectionProvider`, `intoleranceRulesProvider`, `recipeFavoritesProvider`, `rankingSignalsProvider`, `rankedRecipesProvider`, `recipeFitProvider`, `forYouRecipesProvider`, `savedRecipesProvider`, `myRecipeItemsProvider`, `MyRecipeItem`, `mergeMyRecipes`: T3 → T7–T9, T11, T12.
- `UserRecipe.instructions/ingredientAmounts/adaptedFromRecipeId/amountOf/isAdapted`, the service's `create`/`update` parameters: T4 → T6, T10, T12.
- `MealPrefill` (`ofUserRecipe`, `ofRecipe`; `ofAdapted` from T10): T5 → T7, T11, T13.
- `RecipeImage`, `RecipePlaceholder`, `FitBadgeView`, `IngredientLineView`, `RecipeSteps`, `RecipeCardTag`, `RecipeTagPill`, `RecipeCollectionCard`, `RecipeListTile`: T6 → T7–T9, T11, T12.
- `RoutePaths.collectionRecipe(For)`, `collectionRecipeAdapt(For)`, `openRecipe`: T7 → T8, T9, T11, T12. `RoutePaths.discoverRecipes`: T8 → T9.
- `AdaptedRecipe`, `AdaptFailure`, `AdaptRecipeException`, `adaptRecipeProvider`, `createAdapted`: T10 → T11.

**Known, accepted:**
- **„Merken" and Meine Rezepte across devices:** favourites are server rows, so they follow the user. The merged order uses the favourite's date, so a recipe merk'd again moves to the front.
- **Rules cached for the session:** `intolerance_rules` is read once per session (and on refresh). A core migration that changes it reaches open apps after a pull-to-refresh or restart.
- **Older recipes:** their text lines („200 g Reis") go into a meal as they are; only the 10 older recipes are affected.
- **The adapt result isn't kept:** leaving the adapt screen without saving drops it, and adapting again is a new (throttled, 10/h) call.
- **For Severin:** the spec's privacy-policy question (Decisions log item 4) is unchanged by this stage. „Für mich anpassen" sends only the recipe id; the server adds intolerances and diet.
