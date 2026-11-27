# Zutaten- und Getränkekatalog vervollständigen — Design

**Status:** Severin approved the six parts and the Monash rule on 2026-11-27 (binding, §2 „Severin"); everything else is
Claude's call under the delegated autonomous run of 2026-11-26/27, labelled below with what it costs if wrong.
**Repos:** core `bellybuddy-core` (api, migrations **and the admin frontend `frontend/`**) and app `bellybuddyapp`, branch
`feat/catalogue` in each, from `origin/develop`. Builds **after** the barcode track (`feat/barcode`): it extends
`app/off.py`, `app/domain/meal_ingredients.py` and `products` from that track. Migrations: „next free" number at build
time (develop is at 0022; two earlier tracks take the next ones).

## 1. Intent

`ingredients` and `drinks` grew by accident: photo recognition (`ai_detector`), the enrich function (`ai_enrich`,
alternatives of what already exists), recipe imports, and what users typed. Common foods are missing, regional words
(Paradeiser, Topfen, Erdäpfel) and plural forms make separate rows with separate flags, and nobody knows which flags a
human has looked at. This track gives the admin the tools to fill the catalogue on purpose and keep it clean: one entry
with several names, categories, a category-by-category AI fill with review, a „what is missing" check for pasted name
lists, the names many users typed, a FODMAP review marker with a queue, and Open Food Facts' ingredient vocabulary as a
name source.

**Success:** the admin picks „Gemüse", gets 50 proposals of which the existing ones (and their synonyms) are marked,
accepts 30, and the FODMAP analysis fills their flags; a user who types „Paradeiser" in the meal tracker finds „Tomate"
(or the reverse), and the photo match, Muster flags, „Alternativen" and recipe fit treat both words as one food; two
duplicate rows become one with a merge that can be undone.
**Anti-goals:** any copy of Monash data (values, serving sizes, traffic lights, text, scraping); a name one user typed
reaching another user, a prompt for another user, or an admin list; AI output entering the catalogue without an admin's
accept; a measurement or analytics phase; portion sizes or graded FODMAP levels; rewriting what users wrote in their
diary.

## 2. Decisions

| # | Topic | Decision | Whose / cost if wrong |
|---|---|---|---|
| 1 | Parts | Synonyms + merge, categories, category fill + pasted-list check, user-typed names list, review marker + queue, OFF vocabulary | Severin |
| 2 | Monash | Names only, by a human: paste a list → the tool marks what is missing. No import, no scraping, AI prompts never ask for Monash data | Severin |
| 3 | Who typed a name | Never shown; names and counts only | Severin |
| 4 | Minimum distinct users | **3** distinct users before a typed name is listed. 1 can be personal (a name, a medication, a private recipe); 2 is often one household or a tester with a second account; 3 is the smallest group where the name says nothing about a person, and still low enough to surface names at today's user numbers | Claude; wrong: one constant (`GAP_MIN_USERS`) |
| 5 | Synonym model | **Names table per catalogue** (`ingredient_synonyms`, `drink_synonyms`), the canonical name stays in `ingredients.name` / `drinks.name` | Claude; wrong: a migration to an array column, nothing in the app depends on the table shape except CA1/CA2's selects |
| 6 | Synonyms only on shared entries | A private (user) row has exactly one name; synonyms belong to shared entries only (a trigger enforces it) | Claude; wrong: private synonyms later need their own namespace |
| 7 | Uniqueness | Within each catalogue's shared namespace a name (ignoring case and outer spaces) names at most one entry, canonical names and synonyms together. Private rows keep their own namespace; a user's own row still wins for that user | Claude; wrong: none known, it is what 0011 does for names |
| 8 | Displayed name | The **diary keeps the word the user picked** (meals store text). Search shows the word that matched and the entry's canonical name beside it. Server texts (Tipps, Alternativen, recipes, admin) show the canonical name. Canonical for **new** entries: the Austrian word (Paradeiser, Topfen, Marille, Erdäpfel), German/Swiss words as synonyms; existing canonical names are not renamed in bulk | Claude, from Severin's „Austrian usage first"; wrong: one admin swap per entry („Als Hauptname") — see Needs §1 |
| 9 | Merge | Re-points every id reference, drops what would collide (logged), makes the loser's name a synonym of the survivor, deletes the loser; undo restores all of it from a log. **No user text is rewritten** (meal names resolve through the synonym) | Claude; wrong: undo log grows, purge later |
| 10 | Categories | Fixed outline in code and in a table `catalog_categories`; several per entry via join tables | Claude; wrong: outline edits are a small data migration |
| 11 | Drink icon | `catalog_categories.drink_icon` (one of the app's six `DrinkIcon`s); the app takes the first iconed category of a drink, else the current name keywords | Claude; wrong: a keyword list stays the only source |
| 12 | Fill state | Stateless: proposals live in the admin page until accepted; nothing is stored before the accept | Claude; wrong: closing the tab costs one AI call |
| 13 | Pasted list | Deterministic check only (no AI), nothing stored | Claude; wrong: none, cheaper and keeps the list away from any model |
| 14 | Review marker | `fodmap_reviewed_at timestamptz` on both tables; who: not stored (only admins can set it, so the role is implied). Cleared by a trigger when a flag changes or the name changes beyond case/space, unless the same update sets the marker. Synonym added/removed: kept | Claude; wrong: one trigger condition |
| 15 | Unreviewed flags in Tipps/Muster | **No behaviour change in this track.** Recommended later: tips context marks flags of unreviewed entries as „ungeprüft" so the model words them more carefully; never hide flags | Claude (brief default) |
| 16 | Muster keys | Muster still keys by spelling (two lines for „Paradeiser" and „Tomate" stay two lines); only the **flags** behind a spelling resolve through synonyms. Keying Muster by entry is a follow-up | Claude; wrong: one follow-up in `insights.py`/`pattern_stats.py` |
| 17 | Admin lists of private rows | The catalogue tabs stop listing private rows (filter „User" removed, „verifizieren" of a single user row removed); private names reach the admin only through the gap list with the minimum | Claude, from Severin's #3; wrong: two filter options |
| 18 | OFF vocabulary | Downloaded once per admin action into an api-only table, used for proposals (links + German synonyms + missing names), every result reviewed; scanned products map through the links in the fallback path | Claude; wrong: table dropped, nothing else depends on it |
| 19 | Shipping | One branch `feat/catalogue` per repo; every phase boundary leaves the branch green and shippable, so the controller can open the PR at any boundary | Claude (brief) |

## 3. Approaches

**Synonyms.**
- **Names table, canonical stays on the row (picked).** A unique index on the key gives real uniqueness across entries;
  each synonym carries its source (`admin`, `merge`, `ai`, `off`) and time, which merge-undo and the ODbL export need; the
  app's existing reads of `name` stay correct.
- *Array column `synonyms text[]`:* rejected: uniqueness across rows needs a trigger with a table lock, no per-synonym
  source, and every reader of the row (the released app reads `drinks.*`) would carry the list.
- *All names in the table, canonical included:* rejected: two copies of the canonical name to keep in sync for every
  path that inserts rows (analyze-meal, imports, enrich, ensure_ingredient).

**Duplicates.**
- **Merge into one entry, the loser's name becomes a synonym (picked).** Meals keep their text; everything keyed by id
  moves; reversible from a log.
- *Rewrite the names in `meal_entries.ingredients`:* rejected: changes what the user wrote, touches every user's diary,
  and is not reversible without keeping their old text.
- *Mark duplicates as aliases but keep both rows:* rejected: two sets of flags for one food stays the bug.

**Fill.**
- **One category at a time, proposals reviewed, accepted rows analysed by the existing FODMAP batch (picked).**
- *Let enrich grow the catalogue:* that is association (alternatives of alternatives), the owner wants category coverage.
- *Import a public list:* no licensed-free German list exists that we may copy wholesale; OFF's vocabulary is used as a
  reviewed source in part 5.

## 4. Design

### 4.1 Schema (core migrations; additive)

**Phase A migration („catalogue names").**
- `ingredient_synonyms(id uuid pk, ingredient_id uuid not null references ingredients on delete cascade, name text not
  null check (char_length(name) between 1 and 200 and name = btrim(name)), source text not null check (source in
  ('admin','merge','ai','off')), created_at timestamptz default now())`, unique index `ingredient_synonyms_key` on
  `lower(name)`; index on `ingredient_id`. `drink_synonyms` the same with `drink_id references drinks on delete cascade`.
- Trigger `catalog_synonym_check` (BEFORE INSERT/UPDATE on each synonyms table): the entry must be shared
  (`ingredient_is_shared` / `drinks.added_via = 'admin'`), and the key must not equal the key of another **shared**
  entry's canonical name (23505, message `catalog: name taken`). The same key as the entry's own canonical name: 23514.
- Trigger `catalog_name_check` (BEFORE UPDATE OF name on shared `ingredients` / `drinks`): the new key must not be a
  synonym of **another** entry (23505). AFTER UPDATE OF name: when the key changed, the old name becomes a synonym of the
  row (`source 'admin'`, on conflict nothing); when the new name was one of the row's own synonyms, that synonym is
  removed. This is the admin's „Als Hauptname" (swap) and keeps old spellings resolving. INSERTs are not checked (the
  analyze-meal and import paths resolve first; a race leaves a duplicate the duplicate list shows).
- Drinks get 0011's namespaces: clear `added_by_user_id` on `added_via = 'admin'` rows, check
  `drinks_shared_rows_have_no_owner`, drop `drinks_name_key`, create `drinks_shared_name_key (name) where added_via =
  'admin'` and `drinks_user_name_key (added_by_user_id, name) where added_via = 'user'`. Why: today a drink a user typed
  takes the name from everyone (the catalogue cannot add it, a second user's insert fails 23505), and a shared drink with
  an owner can be deleted by that owner, which cascades to every user's `drink_entries`.
- `public.catalog_match(p_names text[], p_uid uuid) returns table(requested text, id uuid, via text)` (sql, stable,
  invoker, `search_path ''`): one row per distinct element of `p_names` (trimmed) that resolves, in this precedence:
  `own` (a `user` row of `p_uid` named so, ignoring case), `name` (a shared row, exact spelling first, then oldest),
  `synonym` (a shared row with that synonym). `p_uid` null: shared only. EXECUTE revoked from `public, anon,
  authenticated` (a caller could pass someone else's uid); the api (service session) and `ensure_ingredient` (definer)
  use it. `public.drink_match(p_names text[])` the same for shared drinks (no private precedence needed: drinks are picked
  by id).
- `ensure_ingredient` step 1 becomes `catalog_match(array[v_name], v_uid)`; so a typed „Paradeiser" no longer creates a
  private row when „Tomate" has that synonym. Signature, grants and errors unchanged (the released app calls it).
- `public.search_ingredients(p_query text, p_limit int default 10) returns table(id uuid, name text, matched_name text,
  added_by_user_id uuid)` (sql, stable, **invoker**: RLS of both tables applies), granted to `authenticated`: rows whose
  name or synonym contains `p_query` (ignoring case), the best tier per entry (exact, prefix, word start, contains), at
  most `p_limit` (1–50). The released app keeps its direct `ingredients` query (no synonyms there, nothing breaks).
- Merge log, api-only (RLS on, no policy, no grants to anon/authenticated):
  `catalog_merges(id uuid pk, kind text check in ('ingredient','drink'), reason text check in ('duplicate','fold'),
  survivor_id uuid not null, loser_id uuid not null, loser_row jsonb not null /* the row without added_by_user_id */,
  loser_owner_id uuid references auth.users on delete cascade, moved jsonb not null /* [{table, id, column}] */,
  added_synonym_id uuid, merged_at timestamptz default now(), undone_at timestamptz)` and
  `catalog_merge_dropped(id uuid pk, merge_id uuid references catalog_merges on delete cascade, table_name text not null,
  user_id uuid references auth.users on delete cascade, row jsonb not null)`. `delete_account.USER_ID_TABLES` lists
  `catalog_merge_dropped`; `catalog_merges` rows of the user go by the FK cascade (the inventory test is updated).
- Trigger on `ingredient_synonyms` INSERT and on shared `ingredients` INSERT/rename: `recipe_ingredients` rows with
  `ingredient_id` null whose `lower(name)` equals the new key get that id (recipes then show the fit instead of
  „unbekannt"). Partial index `recipe_ingredients_unmapped_idx on (lower(name)) where ingredient_id is null`.

**Phase B migration („catalogue categories").**
- `catalog_categories(key text pk check (key ~ '^[a-z_]{2,40}$'), kind text check in ('ingredient','drink'), label text
  not null, position int not null, drink_icon text null check (drink_icon in
  ('glass','hotCup','cup','bottle','carton','can')), check (kind = 'drink' or drink_icon is null))`, filled from the
  Python table `app/domain/catalog_categories.py::OUTLINE` (a test keeps DB == Python, as 0013 does for its rules).
- `ingredient_categories(ingredient_id references ingredients on delete cascade, category_key references
  catalog_categories on update cascade, primary key (ingredient_id, category_key))`, `drink_categories` the same.
  Trigger: only shared entries, and only a category of the matching kind.
- RLS: SELECT for `authenticated` on all three (the app embeds them), INSERT/DELETE for admins
  (`has_role(auth.uid(),'admin')`), no UPDATE on the join tables.

**Phase D migration („catalogue gaps").** `catalog_gap_dismissals(kind text, name_key text, dismissed_at timestamptz,
primary key (kind, name_key))`, api-only. Holds only keys that met the minimum (no user reference).

**Phase E migration („fodmap review").** `ingredients.fodmap_reviewed_at`, `drinks.fodmap_reviewed_at` (timestamptz
null) and the trigger of decision 14 (BEFORE UPDATE: if a `fodmap_*` column or `lower(btrim(name))` changed and
`new.fodmap_reviewed_at is not distinct from old.fodmap_reviewed_at`, set it null). The FODMAP batch (`analyze_pending`)
and analyze-meal therefore clear it whenever they rewrite flags.

**Phase F migration („off vocabulary").** `off_ingredient_terms(off_id text pk, name_de text not null, synonyms_de
text[] not null default '{}', fetched_at timestamptz)` and `ingredient_off_links(off_id text pk, ingredient_id uuid
references ingredients on delete cascade)`, both api-only; `products.off_ingredient_ids text[]` (the barcode track's
table; null on rows fetched before).

### 4.2 Category outline (Austrian usage first; labels are the admin's and the app's words)

Ingredients (`kind 'ingredient'`), in this order: `gemuese` Gemüse (Paradeiser, Erdäpfel, Karfiol, Fisolen,
Kohlsprossen, Melanzani, Kren) · `obst` Obst (Marille, Ribisel, Zwetschke, Kriecherl) · `kraeuter_gewuerze` Kräuter &
Gewürze · `getreide_brot` Getreide, Brot & Gebäck (Semmel, Kipferl, Weckerl, Grieß, Polenta) · `beilagen` Nudeln, Reis &
Beilagen (Nockerl, Knödel, Spätzle) · `huelsenfruechte` Hülsenfrüchte · `nuesse_samen` Nüsse, Kerne & Samen ·
`milchprodukte` Milch & Milchprodukte (Topfen, Schlagobers, Sauerrahm, Buttermilch) · `kaese` Käse ·
`pflanzliche_alternativen` Pflanzliche Alternativen (Haferdrink, Sojajoghurt) · `eier` Eier · `fleisch` Fleisch
(Faschiertes, Beiried, Tafelspitz) · `wurst` Wurst & Aufschnitt (Extrawurst, Leberkäse, Krakauer) · `fisch` Fisch &
Meeresfrüchte · `fleischersatz` Tofu & Fleischersatz · `fette_oele` Fette & Öle (Kürbiskernöl, Schmalz) ·
`saucen_wuerzmittel` Saucen & Würzmittel (Estragonsenf, Suppenwürze) · `suessungsmittel` Zucker & Süßungsmittel
(Staubzucker, Honig, Sorbit, Xylit) · `backzutaten_suesses` Backzutaten & Süßes (Germ, Vanillezucker, Kakao,
Schokolade) · `gerichte` Gerichte & Mehlspeisen (Kaiserschmarrn, Gulasch: users log dishes, they exist today).

Drinks (`kind 'drink'`, icon): `wasser` Wasser & Mineralwasser (glass) · `kaffee` Kaffee & Kaffeegetränke (cup;
Melange, Verlängerter, Einspänner) · `tee` Tee & Kräutertee (hotCup) · `kakao_heiss` Kakao & heiße Getränke (hotCup) ·
`suppen` Suppen & Brühen (hotCup) · `saefte` Säfte & Nektare (bottle) · `gespritzte` Gespritzte & Schorlen (glass;
Apfelsaft gespritzt) · `limonaden` Limonaden & Softdrinks (can; Almdudler, Kracherl, Skiwasser) · `sirupe` Sirupe (bottle;
Holundersirup) · `milchgetraenke` Milch & Milchgetränke (carton; Kefir, Buttermilch, Ayran) · `pflanzendrinks`
Pflanzendrinks (carton) · `smoothies_shakes` Smoothies & Shakes (bottle) · `energy_sport` Energy- & Sportgetränke
(can) · `fermentiert` Kombucha & Fermentiertes (bottle) · `bier` Bier & Radler (can) · `wein_sekt` Wein, Sekt & Most
(glass; G'spritzter, Sturm) · `spirituosen` Spirituosen & Liköre (glass; Obstler, Zirbe).

The examples are for the admin and the fill prompt's orientation only; they are not inserted by the migration.

### 4.3 Name resolution everywhere (part 3)

One rule, two implementations kept equal by a shared test table (`tests/domain/test_catalog_names.py` cases run against
both): **own row > shared canonical (exact spelling, then oldest) > shared synonym**, keys `lower(trim(name))`.
- SQL `catalog_match`: `ensure_ingredient`, `meal_ingredients.match_catalog` (photo and products), `adapt_recipe`'s
  catalogue read, `recommendation_core.fetch_ingredient_fodmap_data` (its `name in :names` becomes a join to
  `catalog_match`; rows are returned under the requested name), `admin_get_profiles`' flag lookup,
  `admin_analytics_fodmap`'s catalogue.
- Python `IngredientCatalog` (`load_catalog`, `load_catalogs`): also reads the synonyms of the shared rows; `by_key` maps
  synonym keys to their entry's row first and is then overwritten by canonical names, after `own_rows_win`. Everything
  that uses `by_key` — Muster flags (`pattern_stats_reads.ingredient_flags`), persona runner, share view, suggestions'
  `refresh_meals` — resolves synonyms with no further change. `low_fodmap_names` stays canonical names only.
- Recipe ingredients: the remap trigger (§4.1) plus the merge's re-pointing; future imports use `catalog_match`.
- OFF matching: products' parsed names go through `match_catalog` (above); the fallback additionally maps OFF ids via
  `ingredient_off_links` (§4.9).
- Admin duplicate check: the fill, the pasted list, the gap list and the duplicate list all classify with
  `app/domain/catalog_names.py::classify(names, kind) -> list[Classified]` (status `present` / `synonym` / `similar` /
  `missing`, with the entry).
- **Similar** (not equal, shown for the admin to decide): equal `variant_key` — lower-case, umlauts folded (ä→a, ö→o,
  ü→u, ß→ss), hyphens and spaces removed, then one trailing `en`, `er`, `n`, `e` or `s` cut when ≥ 3 letters remain.
  Tomate/Tomaten, Apfel/Äpfel, Erdapfel/Erdäpfel, Nuss/Nüsse, Ei/Eier fall together; Paradeiser/Tomate only through a
  synonym or the AI. Never merged automatically.

### 4.4 Merge tool (part 3)

`app/domain/catalog_merge.py`, route `admin-catalog-merge`:
- `POST {"action": "merge", "kind", "survivorId", "loserId"}`: both shared (reason `duplicate`). In one transaction under
  `pg_advisory_xact_lock(hashtext('bb-catalog-merge'))`, rows locked `for update`:
  1. Ingredient references re-pointed loser → survivor: `ingredient_suggestions.detected_ingredient_id`,
     `ingredient_suggestion_replacements.replacement_ingredient_id`, `recipe_ingredients.ingredient_id`,
     `alternative_choices.ingredient_id` and `.replacement_ingredient_id`, `ingredient_categories`,
     `ingredient_synonyms` (moved; one equal to the survivor's canonical key is dropped), `ingredient_off_links`.
     Drinks: `drink_entries.drink_id`, `drink_categories`, `drink_synonyms`.
  2. Collisions are deleted and their rows kept in `catalog_merge_dropped`: a replacement row whose suggestion already
     has the survivor; an `alternative_choices` row that would duplicate `(user, ingredient, replacement)` or point an
     ingredient at itself; a suggestion of the same `(user_id, meal_id)` as an existing survivor suggestion (with its
     replacements); a category pair the survivor already has.
  3. The loser's canonical name becomes a synonym of the survivor (`source 'merge'`) unless its key equals the
     survivor's; the survivor takes the loser's `image_url` if it has none; flags and `fodmap_reviewed_at` stay the
     survivor's.
  4. The loser row is deleted; `catalog_merges` holds its row, the moved ids and the added synonym.
  Response `{"mergeId", "moved": {"<table>": n}, "dropped": n}`.
- `POST {"action": "undo", "mergeId"}`: refused (409, „Der Name ist inzwischen wieder vergeben. Benenne erst den anderen
  Eintrag um.") when the loser's name key is now taken in its namespace; otherwise re-inserts the loser with its id,
  points the logged rows that still exist and still point at the survivor back, re-inserts dropped rows whose user still
  exists, removes the added synonym, sets `undone_at`. A merge can be undone once.
- `GET ?kind=&limit=50&offset=` history: `[{mergeId, reason, survivor: {id, name}, loserName, mergedAt, undoneAt,
  moved, dropped}]`. For `fold` rows the loser name is the shared spelling (never the private row's own spelling, which
  equals it ignoring case anyway).
- `fold` (used by part 4): a private row into a shared entry, same steps, no synonym added (step 3 skipped), loser owner in
  `loser_owner_id`. User-visible effect: none (their meals keep their text; their suggestions and choices now point at
  the shared entry).

`GET admin-catalog-duplicates?kind=`: groups of shared entries that look like one food: equal key (case-duplicates
the old case-sensitive key allowed), equal `variant_key`, or a canonical name equal to another's synonym after a race.
Each group `{reason: "same_name"|"similar"|"name_is_synonym", entries: [{id, name, synonyms, uses,
fodmapReviewedAt}]}`; `uses` is the entry's plain use count (§4.7).

### 4.5 Categories in use (part 4)

- Admin: the ingredient and drink forms get a category multi-select (chips) and a synonyms editor; rows show category
  chips.
- `POST admin-propose-categories {"kind", "offset"?, "limit"?}`: shared entries without any category, by name; batches
  of 50 to the AI (new route `CATALOG_CATEGORIES = AiRoute("catalog categories", "low", 8_000)`), 1 s pause, chunk
  default 150 (three calls) like enrich. Output per name: 1–3 keys of the outline (unknown keys dropped). Response
  `{"proposals": [{"id", "name", "categories": [key]}], "nextOffset", "done", "remaining"}`. Nothing stored; the admin
  ticks and saves (PostgREST insert into the join table).
- App: the drinks screen's icon (CA2).

### 4.6 Category fill and pasted list (part 2, Monash rule)

- `POST admin-catalog-fill {"kind", "category"}`: one AI call (new route `CATALOG_FILL = AiRoute("catalog fill",
  "medium", 16_000)`) with the category label and the names (canonical and synonyms) already in that category (at most
  400). Output `{"items": [{"name", "synonyms": [str], "categories": [key]}]}`, at most 60 items. Each item is classified
  (§4.3) on its name and synonyms; response `{"proposals": [{"name", "synonyms", "categories", "status", "entry":
  {"id","name"}|null, "newSynonyms": [str]}]}` — `newSynonyms` are the proposal's names that the matched entry lacks.
  Throttle: one fill at a time per admin (in-process lock), the admin page waits for the answer.
- Prompt rules (system prompt, German): common foods (or drinks) of that one category as people in Austria, Germany
  and Switzerland buy and name them; main name in Austrian usage, singular unless the plural is the usual name
  (Erdäpfel), synonyms only for the same food (regional, singular/plural, spelling); no brands, no dishes outside
  `gerichte`, no amounts, portion sizes, FODMAP statements, ratings or colours; **do not reproduce content of apps,
  databases or lists of third parties** (named: Monash University FODMAP app). The model's knowledge of food names is
  the only input; the existing names are passed only to avoid repeats.
- `POST admin-catalog-accept {"kind", "items": [{"name", "synonyms": [str], "categories": [key], "asSynonymOf":
  id|null}]}` (≤ 100): `asSynonymOf` null inserts a shared row (`added_via 'admin'`, flags false, `fodmap_analyzed_at`
  null, so the existing batch analyses it) with its synonyms (`source 'ai'`) and categories; otherwise only adds the
  synonyms to that entry. Every name is re-classified first; a name taken meanwhile is reported, not inserted. Response
  `{"created": [{id, name}], "synonymsAdded": n, "skipped": [{name, reason}]}`. The admin page then starts the existing
  „Batch analysieren" (`useBatchAnalyze`) for the kind; `analyze_pending` orders shared rows first
  (`order by added_via = 'user', created_at`) so new entries are analysed before private rows.
- `POST admin-catalog-check-names {"kind", "names": [str]}` (≤ 1000 lines, each cleaned like enrich's `clean_name`,
  empty and duplicate lines dropped): no AI, nothing stored, nothing logged but counts. Response `{"results": [{"input",
  "status", "entry"}]}`. The page shows „fehlt" lines with a checkbox and a category picker; „Übernehmen" sends them to
  `admin-catalog-accept`. The textarea's hint: „Nur Namen einfügen, eine pro Zeile. Keine Mengen, Portionsgrößen,
  Ampelfarben oder Texte aus anderen Apps."

### 4.7 Names users typed (part 1)

**What exists** (`IngredientGapsTab`): lists up to 500 ingredient rows of **any** source with `fodmap_analyzed_at` null,
each private row on its own (so a name typed by three users shows three times, and a name typed by one user is
listed); a usage count from `count_ingredient_usage`, which is granted to `service_role` only — the admin panel calls it
as `authenticated`, the error is ignored, so the column always shows „—"; „verifizieren" turns one user's row into a
shared row (409 when the shared name exists); delete; „Batch analysieren". A row disappears once analysed, whether or not
anyone looked at it. Nothing for drinks (DrinksTab has a „User" filter listing private drink names, and „verifizieren").

**Missing, planned:** drinks; grouping by name across users with a distinct-user count; the minimum of 3; marking names
that already resolve (synonym, case, plural); promote as new entry or as synonym, in bulk; folding the private rows into
the shared entry; dismissing a name; plain use counts that work.

- `GET admin-catalog-gaps?kind=&limit=100&offset=`: private rows (`added_via 'user'`, owner not null) grouped by key,
  `having count(distinct owner) >= GAP_MIN_USERS (3)`, minus dismissed keys; per group `{"key", "name" (the most
  frequent spelling, ties: the capitalised one), "users" (distinct count), "uses" (meal entries containing the key /
  drink entries of those rows), "status", "entry"}`, sorted by users then uses. Never an owner, an id of a private row
  or a date.
- `POST admin-catalog-promote {"kind", "items": [{"key", "action": "new"|"synonym"|"fold"|"dismiss", "name"?,
  "targetId"?, "categories"?}]}` (≤ 100): `new` inserts the shared entry (as accept does) then folds every private row
  with that key into it; `synonym` adds `name` as synonym of `targetId`, then folds; `fold` (the key already resolves)
  folds into the resolving entry; `dismiss` stores the key. The server recounts and refuses keys under the minimum (400).
  Response `{"promoted": n, "folded": n, "dismissed": n, "skipped": [{key, reason}]}`.
- The old tab becomes „Offene Analysen" (shared rows without analysis only, no verify); the new „Von Nutzern" tab
  covers both kinds. IngredientsTab and DrinksTab lose the „User" filter and the drink „verifizieren".
- Plain use counts (gap list, duplicate list, review queue) come from one SQL helper in `app/domain/catalog_usage.py`:
  ingredients = meal entries (all users) containing any of the entry's keys, plus recipe lines; drinks = drink entries.
  Only totals leave the database.

### 4.8 Review marker and queue (part 6)

- „Geprüft" in the admin forms and in the queue sets `fodmap_reviewed_at = now()` (PostgREST, admin policy); saving
  flags with „geprüft" ticked sets both in one update, so the trigger keeps it.
- `GET admin-fodmap-review-queue?kind=&limit=50&offset=`: shared entries with `fodmap_reviewed_at` null and
  `fodmap_analyzed_at` not null, sorted by uses desc, then name; `{"items": [{id, name, synonyms, categories, flags,
  uses}], "total"}`. The page edits flags inline (`FodmapCheckboxGrid`) and has „Geprüft" per row.
- Tipps/Muster: unchanged (decision 15).

### 4.9 Open Food Facts vocabulary (part 5)

Extends the barcode track; its `app/off.py` stays the only module that calls OFF (User-Agent, no user data).
- `off.fetch_ingredient_taxonomy() -> list[OffTerm] | OffUnavailable`: `GET {off_static_url}/data/taxonomies/ingredients.json`
  (new setting `off_static_url = "https://static.openfoodfacts.org"`; **verify the URL and shape at build time**),
  streamed with a 100 MB cap and 60 s timeout; `OffTerm(off_id, name_de, synonyms_de)` for entries with a German name,
  skipping additive ids (`en:e\d+…`).
- `POST admin-off-vocabulary {"action": "load"}`: upserts `off_ingredient_terms`, response `{"terms": n}`.
  `{"action": "propose", "offset", "limit"}`: for shared ingredients, terms whose German name or synonyms resolve to the
  entry → `{"links": [{"ingredientId", "name", "offId", "newSynonyms"}]}`; `{"action": "missing", "q"?, "offset"}`: terms
  that resolve to nothing (searchable) → `{"terms": [{offId, nameDe, synonymsDe}]}`, which the admin sends to
  `admin-catalog-accept`. `{"action": "accept", "links": [{"ingredientId", "offId", "synonyms"}]}` stores links and
  synonyms (`source 'off'`). `GET admin-off-vocabulary/export` returns the OFF-derived part (links and `off` synonyms) as
  JSON for the ODbL share-alike duty.
- Products: the barcode client also stores the structured ingredient ids (`products.off_ingredient_ids`); in the
  **fallback** path (AI down), ids with a link map straight to the entry before the split-names match. The AI path is
  unchanged (its names already resolve through synonyms).
- **Licence (as in the barcode spec §4.9, not legal advice):** OFF's taxonomy is part of its ODbL database. Links and
  synonyms taken from it make that part of our catalogue a Derivative Database; shown in the app (Produced Work) it
  needs the attribution and, on request, the export above under the ODbL. Every OFF-derived row carries `source 'off'`,
  so the part is separable. The Settings dialog „Produktdaten von Open Food Facts" (barcode §4.7) gets one sentence (CA3).

### 4.10 App (phase G)

- **Search by synonym (CA1):** `IngredientService.search` calls the `search_ingredients` RPC;
  `IngredientSearchResult` gets `matchedName` (and `name` stays the canonical one); `rank` ranks by `matchedName`;
  the row shows `matchedName`, and when it differs from `name` a muted second line „= Tomate"; picking it adds
  `matchedName` to the meal. `insertIfNew` unchanged (the server resolves). Released apps keep the old query.
- **Drinks (CA2):** `DrinkService.fetchAll` selects `*, drink_synonyms(name),
  drink_categories(catalog_categories(drink_icon, position))`; `Drink` gets `synonyms` and `categoryIcon`
  (`DrinkIcon?`, the lowest `position` with an icon); `DrinkHelpers.iconFor(Drink)` = `categoryIcon ?? iconForName(name)`
  (today's function renamed); the drink search matches synonyms and hides „neu" when a synonym equals the query; tile
  label stays the canonical name.
- **Attribution (CA3):** the barcode dialog text gains „… sowie ein Teil der Zutatennamen in unserem Katalog".

## 5. Privacy policy text

None. No new personal data, processor or purpose: the gap list shows aggregates of rows we already hold, the merge log
holds copies of a user's existing rows (deleted with the account), OFF receives nothing of the user. The barcode track's
paragraph already names Open Food Facts.

## 6. Non-goals

- Portion sizes, graded FODMAP levels; measurements or analytics of the catalogue (plain counts in admin lists only).
- Any automated use of Monash material.
- Keying Muster or tolerance tests by entry (decision 16); changing what tips say about unreviewed flags (decision 15).
- Private synonyms; per-user preferred names in server texts; renaming existing canonical names in bulk.
- Categories in the app beyond the drink icon (filters, browse-by-category) — the data is ready for a later track.

## 7. Left to the builder

- SQL shape of `catalog_match` / `search_ingredients` (CTE or lateral), as long as the shared test table passes and
  `EXPLAIN` on 10 000 synthetic rows uses the key indexes.
- How the admin pages are split into components, following `IngredientsTab`/`useIngredientActions`.
- The OFF taxonomy URL and field names (verify at build time; only `app/off.py` and fixtures change).
- Whether the advisory-lock name and the in-process fill lock reuse helpers from `app/throttle.py`.

## 8. Needs from Severin

1. **Canonical names of existing entries:** keep them (recommended; „Tomate" stays, „Paradeiser" becomes its synonym)
   or switch to the Austrian word in bulk (tips and Alternativen would then say „Paradeiser" to German users too).
2. **ODbL:** the legal check from the barcode spec (Needs §1 there) also covers the OFF-derived synonyms and links
   (§4.9) and the export.
3. Content sign-off: the category outline (§4.2) and the fill prompt's rules (§4.6) before the first real fill.

## 9. Manual checks for Severin

- Admin, after deploy: run one fill for „Gemüse" and one for „Tee & Kräutertee"; check the marking (existing, synonym,
  similar) and that accepted rows get flags after „Batch analysieren".
- Merge two real duplicates, check a user's „Alternativen" in the admin profile view still show, then undo once on a
  test pair.
- On a device: type „Paradeiser" in the meal tracker → the entry appears with „= Tomate" (if that synonym exists); the
  drinks screen shows a category icon for a drink whose name has no keyword (e.g. „Almdudler" → can).
