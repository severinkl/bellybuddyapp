# Zutaten- und Getränkekatalog vervollständigen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The admin can give catalogue entries several names, merge duplicates reversibly, categorise entries, fill a category with reviewed AI proposals, check pasted name lists, promote names many users typed, mark FODMAP flags as reviewed, and use Open Food Facts' vocabulary; the app finds entries by synonym and takes drink icons from categories.

**Architecture:** Additive core migrations add synonym tables, categories, a merge log, a review marker and OFF terms; one resolution rule (own row > shared name > shared synonym) lives in SQL (`catalog_match`) and in Python (`IngredientCatalog.by_key`), checked by one shared case table. Cross-user and AI work are admin api routes (`/functions/v1/admin-catalog-*`); per-entry edits (synonyms, categories, „geprüft") go through PostgREST with admin RLS. The app reads the new tables through embeds and one search RPC; released apps keep working on the old columns.

**Tech Stack:** core: FastAPI, SQLAlchemy async, alembic, `app.ai.call_claude` (structured output), pytest + respx; admin: React + Vite + TS, vitest, bun. App: Flutter, Riverpod, supabase_flutter, freezed.

**Spec:** `docs/superpowers/specs/2026-11-27-catalogue-design.md` (app repo, branch `docs/plan-catalogue`). § numbers refer to it.

## Repos and commands

| | Core + admin frontend (CC1–CC13, CF1–CF7) | App (CA1–CA4) |
|---|---|---|
| Repo | `~/projects/bellybuddy-core` (the admin SPA is `frontend/` in this repo) | `~/projects/bellybuddy`, worktree `~/projects/bellybuddy/.worktrees/catalogue` |
| Branch | `feat/catalogue` from `origin/develop`, **after `feat/barcode` is merged** (CC12 extends its `app/off.py`, `app/domain/meal_ingredients.py`, `products`) | `feat/catalogue` from `origin/develop` |
| Stack | `sg docker -c "docker compose up -d --wait"`, then `sg docker -c "docker compose stop worker"` (api 18000, admin 18001, DB 54322; `scripts/dev-env.sh`) | — |
| Tests | `cd backend && TEST_DATABASE_URL=… uv run pytest <path>`; admin `cd frontend && ~/.bun/bin/bun run test <path>` | `flutter test <path>` |
| Gates | `uv run ruff check . && uv run black --check . && uv run mypy --strict app`; `bun run lint && bun run typecheck && bun run test` | `dart format --set-exit-if-changed . && flutter analyze` |

Order: by phase A→G as below (core and admin tasks of a phase together); app tasks after CC1–CC6 are deployed-ready (they read CC1's RPC and CC6's tables). Every phase boundary leaves both branches green; the controller may open the PR at any boundary. Migration numbers: the next free one at build time, one per phase (A, B, D, E, F; C needs none).

The app repo's pre-commit hook fails inside a worktree: run the app gates by hand and commit with `--no-verify`.

## Global Constraints

- Every schema change is additive; the released app (v1.4.0) and develop keep working: it reads `ingredients(id, name, added_by_user_id, image_url, fodmap_*)` directly with `ilike`, calls `ensure_ingredient(p_name)`, reads `drinks` with `select()` and inserts user drinks with `added_via 'user'`. None of these change shape.
- One resolution rule everywhere: **own row > shared canonical (exact spelling, then oldest) > shared synonym**, key `lower(trim(name))`.
- A private (`added_via 'user'`) name never reaches another user, a prompt for another user, the synonym tables, the merge history's names or an admin list; the gap list shows only keys with ≥ `GAP_MIN_USERS = 3` distinct owners, names and counts only, never an owner, private row id or date.
- AI output enters the catalogue only through an admin's accept. AI batches: categories 50 names per call, chunk 150, 1 s pause; fill one call per category, ≤ 60 items, one at a time per admin.
- **Monash:** no values, serving sizes, traffic lights, text or scraping; the pasted list is names only, checked deterministically, never stored, never sent to a model; prompts forbid reproducing third-party app/database content.
- Meals' stored text (`meal_entries.ingredients`, recipes' `ingredients`, `tolerance_tests.subject_*`) is never rewritten.
- Core: `mypy --strict`; synthetic test data only; route fixtures delete the `profiles` row as well as `auth.users` (existing `NewUser`/`Db` fixtures); no names, user text or ids of private rows in logs, exception messages or Sentry — counts and kinds only; German error texts, „du".
- New admin routes: `require_admin`, `@fallback_500(NAME)`, mounted like the others (`tests/routes/test_mounting.py` lists them); new AI routes get fixtures under `tests/fixtures/ai/<route>/` like `admin-enrich-ingredients`.
- App: German „du"; colours only `AppTheme`, font sizes `AppTheme.fontSize*`, spacing/radii `AppConstants`; Riverpod; `AppLogger`; vocabulary test (`test/utils/vocabulary_test.dart`, e.g. no „Getränk hinzufügen", „tracken", „Empfehlung"); „Belly Buddy".
- No privacy-policy change (spec §5). Conventional commits; PRs to `develop`; never merge or auto-merge; stop at `gh pr create`. Nothing here touches a production host, DNS, secrets or third-party accounts.

## Review Focus

1. **A name that is a synonym of one entry and a user's own row** („paradeiser" own, „Paradeiser" synonym of Tomate): that user resolves to their own row in every path; other users to Tomate. Tests: CC2 (`test_own_row_beats_synonym` in the shared case table, run against SQL and Python) and CC3.
2. **Merge where re-pointing collides** (a user chose `try` for loser→X and `skip` for survivor→X; a suggestion has both as replacements; loser→survivor alternative): no unique or check violation, the collision is logged, undo restores both rows exactly. Test: CC4 `test_merge_collisions_dropped_and_restored`.
3. **A gap name exactly at the minimum, and one typed by 3 rows of which 2 belong to one user**: the first is listed, the second is not; promote re-counts on the server. Tests: CC10 `test_gap_needs_three_distinct_owners`, `test_promote_refuses_under_minimum`.
4. **The admin edits flags and ticks „geprüft" in one save, versus the FODMAP batch rewriting flags of a reviewed entry**: the first keeps the marker, the second clears it; a case-only rename keeps it. Test: CC11 `test_review_marker_rules`.
5. **Search for a word that is a synonym, in the released app vs. the new app**: released app shows no synonym hit and still works; new app shows „Paradeiser" with „= Tomate" and adds „Paradeiser" to the meal. Tests: CC1 `test_search_ingredients_synonym_tier`, CA1 `ranks by matchedName and keeps the picked word`.

---

## Phase A — Synonyms and merge

### Task CC1: Migration „catalogue names"

**Files:**
- Create: `backend/migrations/versions/<next>_catalogue_names.py`
- Modify: `backend/app/routes/delete_account.py` (`USER_ID_TABLES` + `catalog_merge_dropped`; explicit `delete from public.catalog_merges where loser_owner_id = :uid`), `backend/tests/db/test_baseline_inventory.py` (new tables/functions)
- Test: `backend/tests/db/test_catalogue_names.py`

**Interfaces — Produces** (spec §4.1, exact names): tables `ingredient_synonyms`, `drink_synonyms`, `catalog_merges`, `catalog_merge_dropped`; triggers `catalog_synonym_check`, `catalog_name_check` (+ AFTER rename keeps old name as synonym, removes a promoted synonym), recipe remap trigger and `recipe_ingredients_unmapped_idx`; drinks namespaces (`drinks_shared_rows_have_no_owner`, `drinks_shared_name_key`, `drinks_user_name_key`, `drinks_name_key` dropped); functions:

```sql
public.catalog_match(p_names text[], p_uid uuid) returns table(requested text, id uuid, via text)  -- via: own|name|synonym
public.drink_match(p_names text[]) returns table(requested text, id uuid, via text)              -- via: name|synonym
public.search_ingredients(p_query text, p_limit int default 10)
  returns table(id uuid, name text, matched_name text, added_by_user_id uuid)                   -- invoker, granted to authenticated
public.ensure_ingredient(p_name text) returns uuid                                               -- step 1 via catalog_match
```
RLS: synonyms SELECT to `authenticated`, INSERT/UPDATE/DELETE to admins; merge tables api-only (revoke all from anon, authenticated). `catalog_match`/`drink_match` EXECUTE revoked from public, anon, authenticated.

- [ ] **Step 1: Write the failing tests** (synthetic users via the existing fixtures; SQL run as `authenticated` with a JWT claim where RLS matters):

```python
test_synonym_unique_ignoring_case()              # 'Paradeiser' then 'paradeiser ' -> 23505 / check violation (trim)
test_synonym_only_on_shared_entry()              # synonym on a 'user' row -> error
test_synonym_may_not_equal_other_canonical()     # synonym 'Karotte' while shared 'Karotte' exists -> 23505
test_rename_keeps_old_name_as_synonym()          # Tomate -> Paradeiser: synonym 'Tomate' exists, 'Paradeiser' synonym removed
test_rename_to_other_entrys_synonym_refused()    # 23505
test_case_only_rename_adds_no_synonym()
test_catalog_match_precedence()                  # own > name (exact, then oldest) > synonym; p_uid null: shared only
test_catalog_match_not_executable_by_authenticated()
test_ensure_ingredient_resolves_synonym()        # returns Tomate's id, no new private row
test_search_ingredients_synonym_tier()           # 'parad' -> (Tomate.id, 'Tomate', 'Paradeiser', null); one row per entry; limit clamp 1..50
test_search_ingredients_hides_other_users_rows() # RLS: another user's private 'Paradeiserl' not returned
test_drink_namespaces()                          # two users insert private 'Hafermilch'; admin inserts shared 'Hafermilch'
test_shared_drink_owner_cleared()                # pre-migration admin row with owner -> owner null after upgrade
test_recipe_line_remapped_on_synonym_insert()    # recipe_ingredients 'Paradeiser' null -> Tomate.id after synonym insert
test_merge_tables_not_readable_by_authenticated()
test_downgrade_roundtrip()                       # upgrade -> downgrade -> upgrade on synthetic rows
```
- [ ] **Step 2: Run** `uv run pytest tests/db/test_catalogue_names.py` — expected: FAIL (tables missing).
- [ ] **Step 3: Implement** the migration as 0011 does (statement lists, docstring explaining each rule). Downgrade drops the new objects, restores `drinks_name_key` (fails while a name is in two namespaces — say so in the docstring, as 0011 does) and the old `ensure_ingredient`.
- [ ] **Step 4: Run** the tests, `tests/db/test_baseline_inventory.py`, `tests/routes/test_delete_account.py` — expected: PASS.
- [ ] **Step 5: Commit** `feat(catalogue): synonym tables, drink namespaces, catalog_match and merge log`.

### Task CC2: Resolution and classification in Python

**Files:**
- Create: `backend/app/domain/catalog_names.py`, `backend/tests/domain/catalog_name_cases.py` (the shared case table)
- Modify: `backend/app/domain/ingredient_suggestions.py` (`IngredientCatalog`, `load_catalog`, `load_catalogs` read synonyms)
- Test: `backend/tests/domain/test_catalog_names.py`, `backend/tests/db/test_catalog_match_cases.py` (same cases against SQL)

**Interfaces — Produces:**

```python
Kind = Literal["ingredient", "drink"]
Status = Literal["present", "synonym", "similar", "missing"]

def name_key(name: str) -> str                      # == suggestion_key
def variant_key(name: str) -> str                   # spec §4.3 "similar"
@dataclass(frozen=True)
class EntryRef: id: str; name: str
@dataclass(frozen=True)
class Classified: input: str; status: Status; entry: EntryRef | None
async def classify(session: AsyncSession, kind: Kind, names: Sequence[str]) -> list[Classified]   # shared namespace only
# IngredientCatalog gains: synonyms: Sequence[Row] (ingredient_id, name); by_key = synonyms first, then names (after own_rows_win)
```

- [ ] **Step 1: Write the failing tests:**

```python
# catalog_name_cases.py: CASES = [(own_rows, shared_rows, synonyms, query, expected_id_label), ...] incl.
#   test_own_row_beats_synonym, exact spelling beats oldest, synonym only, trailing space, 'TOMATE'
test_python_catalog_matches_cases()        # IngredientCatalog.by_key over CASES
test_sql_catalog_match_matches_cases()     # catalog_match over CASES (tests/db)
test_variant_key()                         # Tomate/Tomaten, Apfel/Äpfel, Erdapfel/Erdäpfel, Nuss/Nüsse, Ei/Eier equal; Reis/Reise also equal (similar only, the admin decides); 'Tee' stays 'tee' (fewer than 3 letters after a cut)
test_classify_statuses()                   # present (canonical), synonym (via synonym, entry = owner entry), similar, missing
test_classify_ignores_private_rows()       # a 'user' row named like the input -> missing
test_pattern_flags_resolve_synonym()       # pattern_stats_reads.ingredient_flags: meal 'Paradeiser' gets Tomate's flags
```
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement.** `classify` reads with `catalog_match(:names, null)` / `drink_match`, then `variant_key` against all shared canonical names and synonyms for the `similar` rest.
- [ ] **Step 4: Run** these and `tests/routes/test_ingredient_suggestions.py tests/routes/test_pattern_stats.py tests/routes/test_persona_runner.py tests/routes/test_share_view.py` — expected: PASS.
- [ ] **Step 5: Commit** `feat(catalogue): one resolution rule in Python, classification`.

### Task CC3: SQL call sites use `catalog_match`

**Files:**
- Modify: `backend/app/domain/meal_ingredients.py` (barcode track's moved `_MATCH_CATALOG`), `backend/app/routes/adapt_recipe.py` (catalogue read by keys), `backend/app/domain/recommendation_core.py` (`fetch_ingredient_fodmap_data`), `backend/app/routes/admin_get_profiles.py` (flag lookup by key), `backend/app/routes/admin_analytics_fodmap.py` (catalogue), `backend/app/domain/catalog_fodmaps.py` (`analyze_pending` orders `added_via = 'user', created_at`)
- Test: existing route tests plus one synonym case each

**Interfaces — Consumes:** `catalog_match`. **Produces:** unchanged signatures and response shapes; a row found via synonym is returned under the **requested** name.

- [ ] **Step 1: Write the failing tests:** `test_analyze_meal_matches_synonym` (AI says „Paradeiser" → `ingredientId` = Tomate, no new shared row), `test_product_lookup_matches_synonym`, `test_adapt_recipe_flags_synonym_line`, `test_fodmap_data_by_synonym_under_requested_name`, `test_admin_profile_flags_synonym`, `test_analyze_pending_shared_first`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** all of `tests/routes` touched — PASS.
- [ ] **Step 5: Commit** `feat(catalogue): photo, products, recipes and recommendations resolve synonyms`.

### Task CC4: Merge, fold and undo

**Files:**
- Create: `backend/app/domain/catalog_merge.py`, `backend/app/routes/admin_catalog_merge.py`
- Test: `backend/tests/domain/test_catalog_merge.py`, `backend/tests/routes/test_admin_catalog_merge.py`

**Interfaces — Produces:**

```python
@dataclass(frozen=True)
class MergeResult: merge_id: str; moved: dict[str, int]; dropped: int
async def merge(session: AsyncSession, kind: Kind, survivor_id: str, loser_id: str,
                *, reason: Literal["duplicate", "fold"]) -> MergeResult
async def undo(session: AsyncSession, merge_id: str) -> None      # raises MergeConflict (-> 409) / MergeNotFound (-> 404)
async def history(session: AsyncSession, kind: Kind, limit: int, offset: int) -> list[dict[str, Any]]
```
Route `admin-catalog-merge`: `POST {"action":"merge","kind","survivorId","loserId"}` → `{"mergeId","moved","dropped"}`; `POST {"action":"undo","mergeId"}` → `{"ok": true}`; `GET ?kind=&limit=50&offset=` → `{"items":[…]}` (spec §4.4). Errors (400 `{"error"}`): „Beide Einträge müssen geteilte Einträge sein.", „Ein Eintrag kann nicht mit sich selbst zusammengeführt werden.", „Unbekannte Art."; 409 undo text from §4.4; 409 „Schon rückgängig gemacht."

- [ ] **Step 1: Write the failing tests:**

```python
test_merge_repoints_every_reference()      # suggestions, replacements, recipe_ingredients, alternative_choices (both cols),
                                           # categories, synonyms, off links (tables created by later phases: test skips a table absent at that point)
test_merge_drinks_repoints_entries()       # drink_entries of two users now on survivor
test_merge_collisions_dropped_and_restored()   # Review Focus 2
test_loser_name_becomes_synonym()          # source 'merge'; not when keys equal
test_image_moves_only_if_survivor_has_none()
test_meal_text_untouched()                 # meal_entries.ingredients identical before/after
test_undo_restores_rows_and_ids()          # loser id back, refs back, dropped rows back, synonym gone, undone_at set
test_undo_skips_rows_deleted_since()       # a re-pointed suggestion deleted after merge -> undo still succeeds
test_undo_conflict_when_name_taken()       # 409 German text
test_fold_private_row()                    # reason 'fold', loser_owner_id set, no synonym, history shows shared spelling
test_merge_log_deleted_with_account()      # delete-account removes catalog_merge_dropped/catalog_merges of the user
test_route_requires_admin()                # 403 for a normal user
test_no_names_in_logs(caplog)              # synthetic names absent from caplog
```
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement** (advisory xact lock `hashtext('bb-catalog-merge')`, `for update` on both rows, one transaction; the table list as one constant `INGREDIENT_REFERENCES` / `DRINK_REFERENCES` of `(table, column, collision_rule)` so later phases append to it). **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(catalogue): reversible merge of catalogue entries`.

### Task CC5: Duplicate list and use counts

**Files:**
- Create: `backend/app/domain/catalog_usage.py`, `backend/app/routes/admin_catalog_duplicates.py`
- Test: `backend/tests/routes/test_admin_catalog_duplicates.py`

**Interfaces — Produces:**

```python
async def use_counts(session: AsyncSession, kind: Kind, entry_ids: Sequence[str] | None = None) -> dict[str, int]
    # ingredients: distinct meal entries (all users) with an element whose key is the entry's name or a synonym, + recipe lines; drinks: drink_entries
```
`GET admin-catalog-duplicates?kind=` → `{"groups":[{"reason":"same_name"|"similar"|"name_is_synonym","entries":[{"id","name","synonyms","uses","fodmapReviewedAt"}]}]}` (`fodmapReviewedAt` null until CC11; the key is read with `to_jsonb(row)->>'fodmap_reviewed_at'` or added in CC11 — builder's choice, test in CC11).

- [ ] **Step 1: Failing tests:** `test_case_duplicates_grouped` ('Tomate'/'tomate' shared), `test_plural_grouped_as_similar`, `test_private_rows_never_listed`, `test_use_counts_include_synonym_spellings` (meals 'Tomate', 'Paradeiser', 'paradeiser ' → 3), `test_drink_use_counts`.
- [ ] **Step 2–4:** run FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): duplicate list with plain use counts`.

### Task CF1: Synonyms in the admin forms

**Files:**
- Create: `frontend/src/pages/admin/shared/SynonymEditor.tsx`, `frontend/src/pages/admin/shared/catalogErrors.ts`
- Modify: `frontend/src/pages/admin/types.ts` (`synonyms: {id: string; name: string; source: string}[]` on `Ingredient`, `Drink`), `ingredients/IngredientForm.tsx`, `ingredients/IngredientRow.tsx`, `drinks/DrinkForm.tsx`, `drinks/DrinkRow.tsx`, `ingredients/useIngredientActions.ts`, `drinks/useDrinkActions.ts`, `IngredientsTab.tsx`/`DrinksTab.tsx` (select `*, ingredient_synonyms(id,name,source)`; remove the „User" filter and the drink „verifizieren")
- Test: `frontend/src/pages/admin/shared/SynonymEditor.test.tsx`, `catalogErrors.test.ts`, `ingredients/useIngredientActions.test.ts`

**Interfaces — Produces:** `<SynonymEditor kind="ingredient"|"drink" entryId synonyms onChange />` (chips with ×, input + Enter adds; PostgREST insert/delete); a chip menu „Als Hauptname" renames the entry to that synonym (the trigger keeps the old name). `catalogErrorMessage(error, fallback)`: 23505 → „Diesen Namen gibt es schon (als Name oder Synonym eines anderen Eintrags).", 23514 → „Das ist schon der Hauptname dieses Eintrags."

- [ ] **Step 1: Failing tests:** adding calls insert with trimmed name; 23505 shows the German text; „Als Hauptname" calls update of `name` and refetches; rows show synonyms after the name in muted text; the source filter has no „User" option.
- [ ] **Step 2–4:** `bun run test src/pages/admin` FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): synonyms on ingredients and drinks`.

### Task CF2: Duplicates and merge tab

**Files:**
- Create: `frontend/src/pages/admin/CatalogDuplicatesTab.tsx`, `frontend/src/pages/admin/catalog/MergeDialog.tsx`, `frontend/src/pages/admin/catalog/useCatalogApi.ts` (typed `functions.invoke` wrappers for all `admin-catalog-*` routes; later CF tasks add to it)
- Modify: `frontend/src/pages/admin/index.ts` and the admin tab list (tab „Doppelte")
- Test: `frontend/src/pages/admin/CatalogDuplicatesTab.test.tsx`

UI: kind toggle (Zutaten / Getränke); groups with reason badge („Gleicher Name", „Ähnlich", „Name ist Synonym"); per group pick „Behalten" (default: the reviewed one, else most uses) and „Zusammenführen" → `MergeDialog` (shows what moves: „Verweise werden umgehängt, der Name bleibt als Synonym erhalten. Rückgängig ist möglich."); manual merge by two search fields; section „Verlauf" with „Rückgängig".

- [ ] **Step 1: Failing tests:** default survivor rule; confirm calls merge with `{survivorId, loserId}`; undo 409 shows the server's text; history renders `undoneAt` as „rückgängig gemacht am …".
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): duplicate list and reversible merge`.

## Phase B — Categories

### Task CC6: Migration „catalogue categories" and the outline

**Files:**
- Create: `backend/app/domain/catalog_categories.py`, `backend/migrations/versions/<next>_catalogue_categories.py`
- Modify: `backend/app/domain/catalog_merge.py` (append `ingredient_categories`/`drink_categories` to the reference lists, collision = pair exists)
- Test: `backend/tests/db/test_catalogue_categories.py`

**Interfaces — Produces:**

```python
@dataclass(frozen=True)
class Category: key: str; kind: Kind; label: str; position: int; drink_icon: str | None
OUTLINE: Final[tuple[Category, ...]]       # spec §4.2, exact keys, labels, order, icons
def categories_of(kind: Kind) -> tuple[Category, ...]
```
Tables `catalog_categories`, `ingredient_categories`, `drink_categories` with RLS and triggers (spec §4.1 Phase B).

- [ ] **Step 1: Failing tests:** `test_db_outline_equals_python`; `test_category_kind_must_match` (drink key on ingredient → error); `test_only_shared_entries_categorised`; `test_authenticated_reads_categories_admin_writes`; `test_drink_icon_only_on_drinks`; `test_merge_moves_categories`.
- [ ] **Step 2–4:** FAIL → implement (migration inserts from a literal copy of `OUTLINE`, as 0013 does) → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): category outline, several per entry`.

### Task CC7: AI category proposals

**Files:**
- Create: `backend/app/routes/admin_propose_categories.py`, `backend/tests/fixtures/ai/admin-propose-categories/{input.json,expected_shape.json}`
- Modify: `backend/app/ai.py` (`CATALOG_CATEGORIES = AiRoute("catalog categories", "low", 8_000)`)
- Test: `backend/tests/routes/test_admin_propose_categories.py`

**Interfaces — Produces:** `POST admin-propose-categories {"kind","offset"?: 0,"limit"?: 150}` → `{"proposals":[{"id","name","categories":[key]}],"nextOffset","done","remaining"}`; `INVALID_RANGE` 400 as enrich. Output model `{"items":[{"name","categories":[str]}]}`; unknown keys and keys of the other kind dropped, at most 3 kept, names matched case-insensitively to the batch (unmatched → not proposed). AI errors: as enrich (`refusal`/`invalid` counted with no proposals; others skip the batch).

- [ ] **Step 1: Failing tests:** batches of 50 with a pause between (monkeypatched sleep records 1.0); only uncategorised shared entries; private rows never in the prompt (`assert private_name not in captured_prompt`); unknown key dropped; nothing written to the join tables.
- [ ] **Step 2–4:** FAIL → implement (system prompt lists the kind's keys with labels; German) → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): AI category proposals for review`.

### Task CF3: Categories in admin

**Files:**
- Create: `frontend/src/pages/admin/shared/CategoryPicker.tsx`, `frontend/src/pages/admin/CatalogCategoriesTab.tsx`
- Modify: forms and rows of CF1 (picker + chips; select embeds `ingredient_categories(category_key)` / `drink_categories(category_key)`), `useCatalogApi.ts`, admin tab list (tab „Kategorien")
- Test: `CategoryPicker.test.tsx`, `CatalogCategoriesTab.test.tsx`

UI: picker shows the kind's categories in outline order (read once from `catalog_categories`); the tab shows „<n> Einträge ohne Kategorie", „KI-Vorschläge holen" (one chunk per click, progress like enrich), a table with checkboxes per proposed category, „Ausgewählte speichern" (bulk insert into the join table).

- [ ] **Step 1: Failing tests:** picker toggles insert/delete; saving proposals sends only ticked pairs; „Weitere holen" uses `nextOffset`.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): categories on entries and AI proposals`.

## Phase C — Category fill and pasted list

### Task CC8: Category fill proposals

**Files:**
- Create: `backend/app/routes/admin_catalog_fill.py`, `backend/tests/fixtures/ai/admin-catalog-fill/{input.json,expected_shape.json}`
- Modify: `backend/app/ai.py` (`CATALOG_FILL = AiRoute("catalog fill", "medium", 16_000)`)
- Test: `backend/tests/routes/test_admin_catalog_fill.py`

**Interfaces — Consumes:** `classify` (CC2), `categories_of` (CC6). **Produces:** `POST admin-catalog-fill {"kind","category"}` → `{"proposals":[{"name","synonyms","categories","status","entry","newSynonyms"}]}` (spec §4.6). 400 „Unbekannte Kategorie." for a key of another kind or unknown; 429 „Es läuft schon ein Vorschlag. Warte kurz." while the admin's previous call runs; AI errors as `catalog_fodmaps.ai_error` (500 with the existing German texts).

- [ ] **Step 1: Failing tests:**

```python
test_prompt_has_category_and_existing_names()   # ≤ 400 existing names of that category, canonical + synonyms
test_prompt_forbids_third_party_content()       # system prompt contains "Monash" and "keine Portionsgrößen"
test_prompt_has_no_private_names()
test_proposals_classified()                     # existing canonical -> present; via synonym -> synonym + newSynonyms; plural -> similar
test_at_most_60_items_and_names_cleaned()       # clean_name applied; empty dropped; duplicates within the reply merged
test_nothing_inserted()                         # row counts unchanged
test_second_concurrent_call_429()
```
- [ ] **Step 2–4:** FAIL → implement (system prompt per spec §4.6, German) → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): AI proposals for one category`.

### Task CC9: Accept and pasted-list check

**Files:**
- Create: `backend/app/routes/admin_catalog_accept.py`, `backend/app/routes/admin_catalog_check_names.py`
- Test: `backend/tests/routes/test_admin_catalog_accept.py`, `backend/tests/routes/test_admin_catalog_check_names.py`

**Interfaces — Produces:**

```python
async def create_shared_entry(session: AsyncSession, kind: Kind, name: str, synonyms: Sequence[str],
                              categories: Sequence[str], *, synonym_source: Literal["admin","ai","off"]) -> str | None
    # None when the name is taken meanwhile; flags false, fodmap_analyzed_at null, added_via 'admin'
```
`POST admin-catalog-accept` (spec §4.6; ≤ 100 items, 400 „Höchstens 100 Einträge auf einmal.") → `{"created","synonymsAdded","skipped"}`. `POST admin-catalog-check-names {"kind","names"}` (≤ 1000, 400 „Höchstens 1000 Zeilen auf einmal.") → `{"results":[{"input","status","entry"}]}`.

- [ ] **Step 1: Failing tests:** `test_accept_creates_unanalysed_shared_rows` (then `analyze_pending` picks them first); `test_accept_as_synonym`; `test_accept_reclassifies_and_skips_taken` (reason „gibt es schon"); `test_check_names_statuses_and_dedupe`; `test_check_names_stores_and_logs_nothing` (row counts unchanged; caplog has no input line); `test_check_names_makes_no_ai_call` (respx: no request).
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): accept proposals, check pasted name lists`.

### Task CF4: Fill tab

**Files:**
- Create: `frontend/src/pages/admin/CatalogFillTab.tsx`, `frontend/src/pages/admin/catalog/ProposalTable.tsx`, `frontend/src/pages/admin/catalog/NameListCheck.tsx`
- Modify: `useCatalogApi.ts`, admin tab list (tab „Auffüllen"), `shared/useBatchAnalyze.ts` (accept a kind if it does not already)
- Test: `ProposalTable.test.tsx`, `NameListCheck.test.tsx`

UI: kind toggle, category select, „Vorschläge holen"; `ProposalTable` rows: checkbox (default ticked only for „neu"), editable name, synonym chips, status badge („neu", „gibt es als X", „Synonym von X" with „Synonyme ergänzen", „ähnlich wie X"); „Übernehmen (n)" → accept, then „Batch analysieren" starts automatically for the kind with the progress bar. `NameListCheck`: textarea with the hint from spec §4.6, „Prüfen", result list grouped „fehlt / vorhanden / Synonym / ähnlich", „fehlt" lines → `ProposalTable` with a category picker.

- [ ] **Step 1: Failing tests:** default ticks; „ähnlich" unticked; accept payload shape (`asSynonymOf` for „Synonyme ergänzen"); analysis started after accept; textarea hint text exact; pasted lines trimmed and empty ones dropped client-side.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): fill a category and check a pasted list`.

## Phase D — Names users typed

### Task CC10: Gap list and promote

**Files:**
- Create: `backend/migrations/versions/<next>_catalogue_gaps.py` (`catalog_gap_dismissals`), `backend/app/routes/admin_catalog_gaps.py` (GET list, POST promote on `admin-catalog-promote`)
- Test: `backend/tests/routes/test_admin_catalog_gaps.py`

**Interfaces — Consumes:** `use_counts` (CC5), `merge(..., reason="fold")` (CC4), `create_shared_entry` (CC9), `classify` (CC2). **Produces:** `GAP_MIN_USERS: Final = 3`; `GET admin-catalog-gaps?kind=&limit=100&offset=` → `{"items":[{"key","name","users","uses","status","entry"}],"total"}`; `POST admin-catalog-promote` (spec §4.7) → `{"promoted","folded","dismissed","skipped"}`.

- [ ] **Step 1: Failing tests:**

```python
test_gap_needs_three_distinct_owners()     # Review Focus 3: 3 owners listed; 3 rows / 2 owners not
test_gap_rows_have_no_owner_or_ids()       # response keys exactly {"key","name","users","uses","status","entry"}
test_gap_display_spelling_most_frequent()  # 'hafermilch' x2, 'Hafermilch' x2 -> 'Hafermilch'
test_gap_marks_resolving_names()           # key resolves via synonym -> status 'synonym', entry set
test_promote_new_folds_private_rows()      # shared row created, all private rows gone, their drink_entries / suggestions re-pointed
test_promote_as_synonym()
test_promote_refuses_under_minimum()       # 400 "Diesen Namen haben zu wenige Personen eingetragen."
test_dismiss_hides_key()
test_owner_with_deleted_account_not_counted()   # owner null rows excluded
test_no_names_in_logs(caplog)
```
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): names several users typed, promote and fold`.

### Task CF5: „Von Nutzern" tab and „Offene Analysen"

**Files:**
- Create: `frontend/src/pages/admin/CatalogUserNamesTab.tsx`
- Modify: `frontend/src/pages/admin/IngredientGapsTab.tsx` (title „Offene Analysen", query `.neq('added_via','user')`, no verify, no `count_ingredient_usage`), `useCatalogApi.ts`, admin tab list
- Test: `CatalogUserNamesTab.test.tsx`, `IngredientGapsTab.test.tsx`

UI: kind toggle; explainer line „Namen, die mindestens 3 Personen selbst eingetragen haben. Wer sie eingetragen hat, siehst du nicht."; columns Name, Personen, Verwendungen, Status; per row and in bulk: „Als neuen Eintrag" (with category picker), „Als Synonym von …" (entry search), „Zusammenführen" (status already resolving), „Ausblenden".

- [ ] **Step 1: Failing tests:** bulk selection sends one promote call; explainer text exact; Offene Analysen requests exclude `user` rows.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): names users typed, for both catalogues`.

## Phase E — Review marker

### Task CC11: Marker, trigger, queue

**Files:**
- Create: `backend/migrations/versions/<next>_fodmap_review.py`, `backend/app/routes/admin_fodmap_review_queue.py`
- Modify: `backend/app/routes/admin_catalog_duplicates.py` (`fodmapReviewedAt`)
- Test: `backend/tests/db/test_fodmap_review.py`, `backend/tests/routes/test_admin_fodmap_review_queue.py`

**Interfaces — Produces:** columns `fodmap_reviewed_at` on both tables, trigger `fodmap_review_reset`; `GET admin-fodmap-review-queue?kind=&limit=50&offset=` → `{"items":[{"id","name","synonyms","categories","flags":{"fructans":bool,…},"uses"}],"total"}`.

- [ ] **Step 1: Failing tests:**

```python
test_review_marker_rules()      # Review Focus 4: flags+marker in one update keep it; flag-only update clears;
                                # analyze_pending rewrite clears; 'Tomate'->'tomate ' keeps; 'Tomate'->'Paradeiser' clears; synonym insert keeps
test_queue_sorted_by_uses()     # unreviewed, analysed, shared only; uses desc then name
test_queue_excludes_unanalysed_and_private()
test_released_app_drink_select_still_parses()   # select * from drinks as authenticated returns the old columns plus the new one
```
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(catalogue): FODMAP review marker and queue`.

### Task CF6: Review queue and „geprüft"

**Files:**
- Create: `frontend/src/pages/admin/FodmapReviewTab.tsx`
- Modify: forms/rows (checkbox „Geprüft"; badge „geprüft am …" / „ungeprüft"), `useIngredientActions.ts`, `useDrinkActions.ts` (update sends `fodmap_reviewed_at` with the flags when ticked), `useCatalogApi.ts`, admin tab list (tab „Prüfen")
- Test: `FodmapReviewTab.test.tsx`, `useIngredientActions.test.ts`

- [ ] **Step 1: Failing tests:** saving with „Geprüft" ticked sends flags and `fodmap_reviewed_at` in one update; „Geprüft" in the queue removes the row; inline flag edit without ticking leaves the row in the queue.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): FODMAP review queue`.

## Phase F — Open Food Facts vocabulary

### Task CC12: Taxonomy, links, product fallback

**Files:**
- Create: `backend/migrations/versions/<next>_off_vocabulary.py`, `backend/app/routes/admin_off_vocabulary.py`, `backend/tests/fixtures/off/taxonomy_ingredients.json` (synthetic, shaped like OFF's file)
- Modify: `backend/app/off.py` (`fetch_ingredient_taxonomy`, `OffTerm`; product fetch also returns structured ingredient ids), `backend/app/settings.py` (`off_static_url`), the barcode track's product cache write (`products.off_ingredient_ids`) and fallback path (links first), `backend/app/domain/catalog_merge.py` (append `ingredient_off_links`)
- Test: `backend/tests/lib/test_off.py` (extend), `backend/tests/routes/test_admin_off_vocabulary.py`, `backend/tests/routes/test_product_lookup.py` (extend)

**Interfaces — Produces:**

```python
@dataclass(frozen=True)
class OffTerm: off_id: str; name_de: str; synonyms_de: tuple[str, ...]
async def fetch_ingredient_taxonomy() -> list[OffTerm] | OffUnavailable
```
Route actions and shapes as spec §4.9; `GET admin-off-vocabulary/export` → `{"licence":"ODbL-1.0","source":"Open Food Facts","links":[{"offId","name"}],"synonyms":[{"name","entry"}]}` (only `source 'off'` rows and links; no user data).

- [ ] **Step 1: Failing tests:** taxonomy parse keeps only entries with a German name, skips `en:e…` additives, caps size (fixture over cap → `OffUnavailable`), sends the User-Agent and no user data; `propose` links Tomate ↔ `en:tomato` and offers 'Paradeiser' only if not present; `missing` excludes resolving terms; `accept` writes links + `off` synonyms; export lists only `off` rows; product fallback maps a linked OFF id without inserting a shared row.
- [ ] **Step 2–4:** FAIL → implement → PASS. Verify the taxonomy URL and shape against OFF's docs first; note the result in the PR.
- [ ] **Step 5: Commit** `feat(catalogue): Open Food Facts vocabulary as reviewed name source`.

### Task CF7: OFF vocabulary section

**Files:**
- Create: `frontend/src/pages/admin/catalog/OffVocabularySection.tsx` (inside the „Auffüllen" tab)
- Modify: `useCatalogApi.ts`
- Test: `OffVocabularySection.test.tsx`

UI: „Vokabular laden" (shows the term count), „Verknüpfungen vorschlagen" (table: entry, OFF term, new synonyms with checkboxes, „Übernehmen"), „Fehlende Begriffe" (search, rows → `ProposalTable` with category picker), „Export (ODbL)" download; note line „Daten: Open Food Facts, Lizenz ODbL".

- [ ] **Step 1–4:** tests for accept payload and the missing → proposal hand-over; FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(admin): Open Food Facts vocabulary`.

### Task CC13: Core and admin gates, PR

- [ ] **Step 1:** Backend gates and the whole backend suite with the worker stopped; `cd frontend && bun run lint && bun run typecheck && bun run test && bun run build`; regenerate `frontend/src/integrations/supabase/types.ts` the way the repo does (or hand-add the new tables/RPC) so `typecheck` covers them. Expected: all PASS.
- [ ] **Step 2:** `alembic upgrade head && alembic downgrade -5 && alembic upgrade head` on the local stack (synthetic data) — PASS.
- [ ] **Step 3:** After the owner's routine (simplify → code review → fix), open the PR `feat/catalogue` → `develop` with `gh pr create`; body lists the migrations, the new admin routes, the „verify at build time" results and spec Needs §1–3. Do not merge.

## Phase G — App

### Task CA1: Search by synonym

**Files:**
- Modify: `lib/services/ingredient_service.dart` (`search` → `rpc('search_ingredients', params: {'p_query': query, 'p_limit': limit})`), `lib/models/ingredient_search_result.dart` (`matchedName`), `lib/widgets/common/ingredient_search.dart` (second line), the meal-tracker add path that takes the picked result's text
- Test: `test/models/ingredient_search_result_test.dart`, `test/widgets/common/ingredient_search_test.dart`

**Interfaces — Produces:** `IngredientSearchResult({required String id, required String name, required String matchedName, required bool isOwn})`; `rank` tiers on `matchedName`, dedupes by `id`; picking adds `matchedName`.

- [ ] **Step 1: Failing tests:** `ranks by matchedName and keeps the picked word` (query 'parad' → 'Paradeiser' row, second line '= Tomate', chip text 'Paradeiser'); no second line when `matchedName == name`; own rows still flagged `isOwn`; a PostgREST error is logged with `AppLogger` and rethrown as today.
- [ ] **Step 2–4:** FAIL → implement (style of the second line: `AppTheme.fontSizeCaption` and the muted text colour already used in the search; add a constant only if missing) → PASS; vocabulary test passes.
- [ ] **Step 5: Commit** `feat(meal): find ingredients by their other names`.

### Task CA2: Drinks: synonyms and icon from category

**Files:**
- Modify: `lib/models/drink.dart` (`synonyms: List<String>`, `categoryIcon: DrinkIcon?` from the embeds in `fromDbRow`), `lib/services/drink_service.dart` (`select('*, drink_synonyms(name), drink_categories(catalog_categories(drink_icon, position))')`), `lib/utils/drink_helpers.dart` (`iconFor(Drink)`, `iconForName(String)` = today's keyword logic), `lib/screens/trackers/drink/widgets/drink_search.dart` (match synonyms; hide „neu" when a synonym equals the query), `quick_drink_grid.dart`, `last_drink_row.dart`
- Test: `test/utils/drink_helpers_test.dart`, `test/models/drink_test.dart`, `test/screens/trackers/drink/drink_search_test.dart`

- [ ] **Step 1: Failing tests:** `fromDbRow` with `drink_categories` [`{catalog_categories: {drink_icon: 'can', position: 7}}`, `{…'glass', 1}`] → `glass` (lowest position); unknown icon string → null; no embed (older server) → `synonyms == []`, `categoryIcon == null`; `iconFor` falls back to the name keywords; search 'Kracherl' finds the drink with that synonym and offers no „neu"; tile label is the canonical name.
- [ ] **Step 2–4:** FAIL → implement → PASS (`dart run build_runner build` after the model change).
- [ ] **Step 5: Commit** `feat(drinks): other names in search, icon from category`.

### Task CA3: Attribution sentence

**Files:**
- Modify: the barcode track's Settings dialog „Produktdaten von Open Food Facts" (its text constant)
- Test: its existing widget test

- [ ] **Step 1–4:** test expects „Name, Marke und Zutaten von Produkten, die du scannst oder suchst, sowie ein Teil der Zutatennamen in unserem Katalog stammen aus Open Food Facts, einer freien Lebensmitteldatenbank. Die Daten stehen unter der Open Database License (ODbL)."; FAIL → change → PASS.
- [ ] **Step 5: Commit** `feat(settings): name Open Food Facts as a source of catalogue names`.

### Task CA4: App gates and PR

- [ ] **Step 1:** `dart format --set-exit-if-changed . && flutter analyze && flutter test` — PASS.
- [ ] **Step 2:** After the owner's routine, `gh pr create` `feat/catalogue` → `develop`, noting it needs core's Phase A and B deployed (the RPC and embeds) and listing the spec's §9 device checks. Do not merge.
