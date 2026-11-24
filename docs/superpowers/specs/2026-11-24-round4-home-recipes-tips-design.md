# Runde 4: Home & Motivation, Rezepte, bessere Tipps — Design

Brainstormed with Severin on 2026-11-24. Mockups:
- „Runde 4 · Home & Motivation": https://claude.ai/artifact/C4i1ZNb6vj6PBm43Vzm9u9
- „Runde 4 · Rezepte": https://claude.ai/artifact/8CqdhqNL983Gi1DZ54T9k7

This round builds on the app-structure redesign (spec `2026-11-23-app-structure-redesign-design.md`, PRs #84–#86) and on core PRs #7–#9 (weekly tips, AI models and prompts, shared ingredient catalog).

## 1. Intent: why

Severin tested Stages 1–3 and found three problems:

1. **The care ring's counts don't match how people log.** „Trinken 5/6" makes no sense for someone who logs 6 l of water once in the evening, and the same is true for Essen. The ring should show **how long ago something was logged**, not a daily quota.
2. **The app gives too little back early on.** The first patterns come after 7 days. Until then a user gets nothing personal and doesn't understand why those first days of entries matter. The 7-day wait stays, but the days should feel like a journey with small rewards, and the app should explain that these entries are what make the first individual tips possible.
3. **Recipes are thin.**
   - „Meine Rezepte" are only meal templates: a title, ingredients and an image, with no preparation.
   - The curated `recipes` table holds 10 recipes and has had no UI since Stage 1.
   - Severin wants personalised recipes and a real recipe collection.

He also asked to reconsider the **Tipps**. They don't use the user's patterns, they repeat themselves, and they overlap with the Alternativen.

**Success:**
- A user logs whenever suits them and the ring still makes sense.
- Every one of the first 7 days gives something back.
- Entdecken has recipes worth cooking that fit the user, and they can be adjusted with one tap.
- The weekly Tipps feel personal and don't repeat.

## 2. Goals, non-goals, anti-goals

**Goals:**
- Ring 2.0: need meters that fill when something is logged and drain with time.
- A charging moment on the success page.
- A streak flame that grows with the streak and ignites with the first entry of the day.
- A preview of what a Tipp looks like, shown while weekly tips are off.
- A 7-day journey with a reward on each day and a short feedback line after the day's Bauchgefühl.
- A curated recipe collection of about 100+ recipes, ranked for the user, with „Für mich anpassen" (AI rewrite, checked against the catalog), „Als Essen eintragen" and „Merken".
- „Meine Rezepte" get optional preparation steps.
- Tipps built on the user's patterns, with a memory of earlier sets and ratings: at most 3 per week, one marked as the focus of the week, a short weekly letter from the Buddy, and clear separation from the Alternativen.

**Non-goals (this round):**
- Per-user, from-scratch AI recipe generation („Was koche ich heute?"). Severin chose the curated collection plus „Für mich anpassen".
- The Tipps follow-up („Hast du X probiert?"). Severin didn't choose it.
- New Home tap targets beyond today's.
- Buddy outfits or other cosmetic rewards.

**Anti-goals:**
- **Guilt or punishment.** Meters never drop to empty, the Buddy never scolds, and a dim flame is neutral.
- **Health claims, invented statistics or anything that reads like a diagnosis.** Recipes say „passt zu dir" or „1 Zutat ist für dich kritisch", never „hilft gegen …". Patterns-based Tipps never claim a cause.
- **Copied photos.** Recipe photos from the sources are never used.
- **Sending a user's data to the AI service without the weekly-tips opt-in.** This also covers the day-3 tip.

## 3. Constraints

- **Code rules:** the repo's `CLAUDE.md` applies in both repos: design tokens only, German UI, `CachedNetworkImage` with shimmer, `AppLogger`, Riverpod `AsyncNotifier`, conventional commits.
- **Vocabulary (§5.9 of the app-structure spec):** eintragen, Essen/Trinken/Bauchgefühl/Klo, Tipps (never „Empfehlung" in the UI), Alternativen, Streak, Tagebuch. „Belly Buddy" is never translated. The vocabulary guard test stays green.
- **Reduced motion:** every animation (meter drain and charge, flame, ignite burst, journey dots) respects it, and the reduced-motion versions are instant.
- **Layout:** a 375×667 screen at text scale 1.3 does not overflow.
- **Privacy:**
  - AI calls with user data only after the user asks: the weekly-tips opt-in, or tapping „Für mich anpassen", which is an explicit request.
  - „Für mich anpassen" sends only the recipe and the user's intolerances, diet and the ingredient names marked critical. It sends no diary data.
  - Prompts never contain another user's private ingredient names (core #9).
- **Deploy order:** core first, app after.
- **Cost:** recipe adaptation and Tipps run on the models core #8 set up (Opus 5.5 / Fable 5.2). Measure cost with the eval harness (`backend/scripts/ai_eval.py`) before shipping prompt changes. Live eval spend needs Severin's go-ahead.

## 4. Approaches (decided in the brainstorm)

- **Ring:**
  - A: need meters that drain with time ← **chosen**.
  - B: „vor 2 Std" labels with a fading colour.
  - C: one well-being ring of 4 arcs.
- **After saving:**
  - A: back to Home with the charge animation there.
  - B: today's success page plus a charging circle ← **chosen by Severin**.
- **Flame:**
  - a: grows with the streak.
  - b: grows, glows dimly until the day's first entry, then ignites ← **chosen**.
  - c: a flame with a face.
- **The first 7 days:**
  - A: the insight card as a 7-dot journey, plus C: a short feedback line after the day's Bauchgefühl ← **chosen**.
  - B: a one-time „Warum 7 Tage?" sheet. Not chosen.
  - Severin added rewards on individual days.
- **Recipe source:**
  - Per-user AI.
  - Curated collection.
  - **Curated collection + „Für mich anpassen"** ← **chosen**.
  - Recipes inside the Tipps.
- **„Für mich anpassen":**
  - **AI rewrites ingredients and steps, each ingredient checked against the catalog** ← **chosen**.
  - Swap ingredients only.
  - Mark only.
- **Growing the collection:** import ready-made recipes from online sources ← **chosen by Severin**. „KI drafts + approval" and „write by hand" were not chosen.
- **Which sources:** all candidates, Monash and FODMAP Everyday included ← **Severin's decision** (see §5.6.2 on the risk).
- **Tipps:** patterns as input, memory and ratings, at most 3 with a focus, roles clarified ← **chosen**. The follow-up question was not chosen.
- **Where patterns come from for server-side Tipps** *(my call)*: port the insights engine to Python in core and keep the Dart and Python versions in step with shared JSON test vectors. Rejected alternatives:
  - The app uploading an insights snapshot: it is stale when the app wasn't opened, and the server has to trust it.
  - Moving the engine server-side only: Muster would then need the network, and Stage 2 is client-side.

## 5. Design

### 5.1 Ring 2.0: need meters (app)

Each of the 4 bubbles around the Buddy shows a **fill level** instead of a count:
- **Essen:** full after any meal entry, drains to the floor over about **5 h**.
- **Trinken:** full after any drink entry, whatever the amount (6 l in one entry fills it), drains over about **3 h**.
- **Bauchgefühl:** full after an entry, drains over about **24 h**.
- **Klo:** no meter. It shows „vor X Std" („heute noch nicht" before the first entry), because the timing of bowel movements is not a need to top up.

Rules *(my calls, tunable constants in AppConstants)*:
- Drain is linear from the last entry's `tracked_at`.
- It **pauses overnight** (22:00–07:00 local).
- It never goes below a **floor of 15 %**.
- A future-dated entry counts from its time.
- The level is computed from the last entry per type, using the same data Home already loads. Entries from yesterday count too, so the meters don't reset at midnight.

**Look:** each meter is an arc or circle filling in the need's colour. Proposed tokens (from the mockup, ≥3:1 on white, added to `AppTheme`): `careWater` blue, `careFood` orange, `careGut` green, `careLoo` brown, each with a soft tint. This swaps Essen's and Bauchgefühl's current colours; the mockup shows the result. The glow still highlights the suggested need.

**Behaviour:**
- Tapping a bubble opens its tracker (as now).
- The next-action button and the Buddy's mood come from the meters. Lowest meter first, with time-of-day meal logic kept for Essen.
- The Buddy's lines stay gentle („Hast du Durst? 💧"), never guilt.
- Counts move to the Tagebuch: a day's totals stay visible there, they just aren't goals on Home.

### 5.2 Saving: success page with a charging circle (app)

The existing full-screen success page stays (Severin chose B):
- Its centre shows the logged need's circle **charging from the old level to the new one** in the need's colour, in about 1.2 s.
- The Buddy says the existing line („Prost! 💧").
- „Tippen zum Fortfahren" stays.
- Reduced motion: the circle shows the new level at once.

If this is the day's first entry, the page also shows the flame igniting (§5.3) next to „Tag n". Milestones keep their own full-screen celebration (§5.5).

### 5.3 Streak flame (app)

- A drawn flame replaces the 🔥 emoji in the streak chip and in „Dein Streak". It is drawn in Flutter (CustomPainter or path animation) in the Buddy's style: black outline, flat colours, a slight wobble. No new dependency.
- **Size tiers by streak:** 0–2 small, 3–6 medium, 7–29 large, 30+ large with a blue core and sparks. Exact breakpoints are left to the builder within that shape.
- **Glimmt:**
  - Until the first entry of the current day, the flame shows dim, as embers.
  - With the first entry it **ignites** with a small burst and the count ticks up.
  - The glow state is neutral: no warning colour, no text.
- New tokens `streakFlame` and `streakEmber`.

### 5.4 Tipps preview while weekly tips are off (app)

The Tipps section on Entdecken (state „off") shows, above the switch, an example tip card:
- Labelled **„Beispiel"**, with a dashed border and a footer saying the content is made up.
- The content is a generic low-FODMAP swap idea with no claims. The mockup's „Frühlingszwiebel-Grün statt Zwiebel" is fine.
- Below it comes the existing switch with the subline „Jeden Montag 2–3 Tipps" and the KI-Dienst sentence.

### 5.5 The first 7 days: journey, feedback, rewards (app; day 3 uses core)

**Journey card.** While the insights are locked, Home's insight card becomes a 7-dot journey:
- One dot per **active day** (a day with any entry, the Stage 2 unlock rule). Dots for days with a Bauchgefühl entry are green.
- The Buddy stands on the current dot.
- The two counters stay (aktive Tage n/7, Bauchgefühl n/3).
- Under the dots, one line says what today's reward is or was.
- A tap opens Muster, as now.

**Feedback line.** After the first Bauchgefühl entry of a day, while locked, the success page's Buddy line becomes: „Notiert! Noch N Tage, dann schau ich nach ersten Mustern." It promises nothing.

**Rewards:**
- One reward per active day, unlocked when that day's dot fills.
- It shows as a one-time Buddy announcement on Home through the existing queue, and stays reachable from the journey card.
- Rewards are per user and device (like the other announcement flags).
- They are **never** taken away.

| Active day | Reward |
|---|---|
| 1 | Willkommen + **dein erstes Rezept für dich**: the top-ranked recipe from the collection for the profile (§5.6.3), opening the recipe |
| 2 | **Wissen-Häppchen:** a short Buddy line plus a link to a fitting blog article (Wissen, §Stage 3); a fixed article chosen by tag or link *(builder picks; if no article fits, a short Buddy explanation)* |
| 3 | **Dein erster Tipp:** the weekly-tips offer moves from „after unlock" (Stage 3) to day 3. „Dein erster Tipp ist fertig, soll ich ihn dir machen?" Yes turns weekly tips on and immediately requests a first tip from the user's first days (core `diet-recommendations`, which reads the last 3 days; it is the user's explicit request); weekly tips then follow on Mondays. No gives a recipe instead, and the offer isn't repeated (the switch stays in Entdecken and Settings). |
| 4 | **Ein Spruch vom Buddy:** a short encouraging line from a fixed list in the app, no health claims |
| 5 | **Ein Rezept mit deinen guten Zutaten:** the top recipe ranked by ingredients from the user's entries so far on days without a bad Bauchgefühl |
| 6 | **Vorschau:** „Morgen zeig ich dir deine ersten Muster" with a blurred, clearly fake preview of the Muster page |
| 7 | **Muster frei:** full-screen milestone celebration, then Muster. This happens only when the Stage 2 unlock rule is met (7 active days **and** 3 Bauchgefühl entries). If day 7 arrives with fewer than 3 Bauchgefühl entries, the card says what's missing, and the celebration comes when the rule is met. |

Users who already passed day 7 before this release see no journey, and their offer logic stays as in Stage 3. *(my call)*

### 5.6 Rezepte (core + app)

#### 5.6.1 Where they live (app)
- **Entdecken:** „Meine Rezepte" becomes **„Rezepte"**, with two rows: „Für dich" (3 cards from the collection, ranked) and „Meine Rezepte". The header link is „Alle ›".
- **Rezepte list** (`/discover/recipes`, inside the Entdecken branch, bar stays):
  - filter chips Frühstück / Mittag / Abend / Snack;
  - a toggle „Passt zu mir";
  - search;
  - cards with image, title, time and a fit badge („Passt zu dir" or „1 Zutat ist für dich kritisch").
- **Recipe detail:**
  - Image (an illustrated placeholder until generated images exist), title, „35 Min · 2 Portionen".
  - Ingredients with ✓ (fits) or ⚠ (critical for you, e.g. „Knoblauch — für dich kritisch").
  - **„Für mich anpassen"** when any ⚠.
  - Zubereitung steps.
  - „Quelle: <site> ›" (opens in the in-app browser).
  - **„Als Essen eintragen"** (opens the Essen tracker pre-filled with the ingredients) and **„♡ Merken"** (the existing `user_favorite_recipes`).
- Home gets nothing new.
- *(my calls, from the recipes mockup)* Recipes saved with „Merken" also appear in „Meine Rezepte", marked with a heart. The recipe detail is a pushed page without the bottom bar, as today.

#### 5.6.2 The collection (core)
**Schema:** extend `recipes`, keeping existing rows.

| Column | Purpose |
|---|---|
| `source_name`, `source_url` | where the recipe came from |
| `meal_types text[]` | frühstück / mittag / abend / snack |
| `diet_tags text[]` | vegan, vegetarisch |
| `hidden boolean default false` | admin can take a recipe out |
| `image_url` | stays nullable |

Plus a new `recipe_ingredients` table (recipe_id, position, amount_text, name, ingredient_id → `ingredients`). The ingredient must be a shared catalog row; unmapped names are stored without the id and count as „unbekannt" in the fit check. `instructions` stays.

RLS:
- read for authenticated users;
- `hidden` rows invisible to non-admins;
- admin write.

**Admin panel:** a recipes list with a hide/unhide toggle. Editing and creating recipes are left to the builder.

**Import:** a one-off script in core (`backend/scripts/import_recipes.py`).
1. It reads the recipe pages listed in a committed source list, fetched politely: small volume, one page at a time, no images.
2. It extracts ingredients, amounts, time, servings and meal type, from schema.org `Recipe` JSON-LD where present and by AI extraction otherwise.
3. It **rewrites the steps in our own words in German** (AI), translating English sources.
4. It maps each ingredient to the shared catalog. AI matching against catalog names is allowed; `ensure_ingredient` is not used for shared rows.
5. It flags recipes whose ingredients are high-FODMAP for everyone (reject, or keep only if the source marks the recipe low-FODMAP with a stated portion).
6. It writes a reviewable JSON file, which is then loaded into the DB.
7. A recipe without at least 80 % mapped ingredients is dropped.

**Sources** (from the research in `recipe-sources.md`, target about 120):

| Source | Approx. recipes |
|---|---|
| Reizdarmblog.de | 45 |
| Weglasserei.de | 25 |
| Karlijn's Kitchen (EN → DE) | 30 |
| myfodmap.at | 5 |
| Monash and FODMAP Everyday | about 15 |

Covering Frühstück, Mittag, Abend and Snack and vegan/vegetarian. **Severin's decision:** include Monash and FODMAP Everyday although their terms of use restrict reuse. Ingredients and amounts are facts, the steps are rewritten, the source is linked, and no photos are used. The remaining risk lies with those sites' terms, and he accepted it.

**Images:** none at import. Recipes show an illustrated placeholder by meal type until the existing Gemini image route (core #8, `gemini-3-pro-image`) runs with billing enabled. Generating recipe images is a later step.

#### 5.6.3 „Für dich": personal ranking (app)
The ranking is computed in the app from the profile and the insights (Stage 2):
1. Hide recipes that don't match the diet (vegan or vegetarian).
2. **Critical ingredients** are mapped ingredients whose FODMAP flags hit the user's intolerances; their count drives the badge.
3. Rank up recipes containing ingredients from the user's good days (insights `goodDays` „oft dabei", or before unlock their entries on days without a bad Bauchgefühl). Rank down recipes containing „Fällt mir auf" items.
4. Break ties by fewer critical ingredients, then by newest.

The „Passt zu mir" toggle shows only recipes with 0 critical ingredients.

#### 5.6.4 „Für mich anpassen" (core + app)
- **Core:** a new route `POST /functions/v1/adapt-recipe {recipe_id}` (authenticated). Its user-turn input is the recipe, the user's intolerances and diet, and the critical ingredient names.
  - The model (Opus 5.5, effort and max tokens per the AI route registry) returns: a changed ingredient list (each swap `from → to`), rewritten steps that mention the new ingredients, and a short note.
  - **Every returned ingredient** is checked against the catalog (shared + the user's own rows) for the user's intolerances. Unknown ingredients are allowed only when marked „unbekannt".
  - One retry on a failed check, then an error.
  - Prompt text is constant per route (cacheable). No diary data is sent.
  - It is rate-limited per user (the existing throttle pattern) and logged like the other AI routes.
- **App:**
  - Tapping the button shows a Buddy loading state („Ich bau's für dich um …").
  - The result shows the swaps highlighted and the changed sentences marked, with the note „Alle Zutaten mit dem FODMAP-Katalog geprüft".
  - **„In Meine Rezepte speichern"** stores it as a user recipe with steps and `adapted_from_recipe_id`.
  - Errors: a neutral message plus retry.

#### 5.6.5 Meine Rezepte (core + app)
- `user_recipes` gets optional `instructions text[]` and `adapted_from_recipe_id`.
- The editor gets an optional steps list.
- The existing meal-template behaviour (the recipe selector in the Essen tracker) is unchanged.

### 5.7 Better Tipps (core; app shows them)

**Input**, added to the existing per-user data:
1. The user's **patterns** from the Python port of the insights engine (§4): good and hard days, „oft dabei" on each, „Fällt mir auf" and „noch unsicher". Thresholds are identical to the app's `InsightRules`, guarded by shared JSON test vectors in both repos.
2. The **last 3 tip sets** with their ratings and dislike comments.

**Output:**
- **At most 3 items.** Exactly one is flagged `focus` („Fokus der Woche").
- `summary` becomes a short **weekly letter in the Buddy's voice** (ich, du, 2–3 sentences).
- Each `substitute` item may carry `alternative`, plus a `recipe_id` for a collection recipe that uses the alternative, chosen server-side by matching mapped ingredients, never invented by the model.

**Rules in the prompt:**
- Don't repeat a disliked tip.
- Build on liked ones.
- Phrase patterns as observations („an deinen schweren Tagen war oft …"), never as causes.

**Roles:**
- **Tipps** are the weekly coaching.
- **Alternativen** are the swap catalog.
- A Tausch-Tipp links to the matching Alternative and, when one exists, to the recipe.

**App:** the Tipps screen shows the letter, the focus item first with a „Fokus der Woche" label, then the rest. A Tausch-Tipp shows „Passendes Rezept: … ›" and opens the recipe detail. The schema change is additive; older sets without the fields render as today.

**Measure:** extend the eval harness with patterns and memory cases, run it before shipping with a budget agreed with Severin, and keep or improve the scores of core #8.

## 6. Stages *(my call; each: plan → build → /simplify → /code-review → fixes → PR; Severin tests locally)*

1. **Home & Motivation** (app): §5.1, 5.2, 5.3, 5.4, plus the 5.5 journey card and feedback line. The reward slots that need recipes or tips stay hidden until Stage 3.
2. **Rezepte** (core + app): §5.6, covering the schema, the import (run, reviewed and committed), the adapt route, the app list, detail, ranking, adapt and Meine Rezepte steps.
3. **Tipps & Belohnungen** (core + app): §5.7, the Python insights port with shared vectors, and the §5.5 rewards (day 3 offer + first tip, recipes on days 1 and 5, Wissen on day 2, saying on day 4, preview on day 6, the day 7 celebration).

**Release:** after Stage 3. Deploy core first.

## 7. Left to the builder
- Exact drain curves, colours within the token proposal, animation timings and flame drawing, all within this spec.
- Widget and file structure, provider shapes, and the import script's internals.
- The exact Wissen article for day 2 and the saying list for day 4. The sayings are short and claim nothing.
- Recipe admin UI beyond hide/unhide.

## 8. Decisions log
- 2026-11-24 Severin:
  - Ring A.
  - Saving B (success page + circle).
  - Flame b.
  - 7 days: A + C + rewards per day; the day-3 offer moves from day 7.
  - Tipps preview A (proposed, not objected to).
  - Recipes: curated + „Für mich anpassen" (AI rewrite + catalog check), collection imported from online sources, all sources including Monash and FODMAP Everyday.
  - Tipps: patterns, memory and ratings, at most 3 + focus + letter, roles clarified, no follow-up.
- Builder-check answers (2026-11-24, **my calls** while Severin slept; he approved building without reading and asked for the list in the morning):
  1. **Intolerances the FODMAP flags can't represent.**
     - At import, every recipe ingredient gets an `allergens text[]` tag from {gluten, weizen, milch, nuesse, eier, soja}. It is set by a deterministic German keyword list (e.g. Ei/Eigelb; Mandel/Haselnuss/Walnuss/Cashew/Pistazie, but not Kokos/Muskat; Weizen/Dinkel/Roggen/Gerste/Bulgur/Couscous/Grieß/Seitan/Paniermehl unless „glutenfrei"; Soja/Tofu/Tempeh/Edamame/Miso) and cross-checked by the AI during import. Disagreements go to the review file.
     - Mapping of the app's intolerance options:
       - Laktose → FODMAP lactose **and** milch;
       - Gluten → gluten;
       - Weizen → weizen (+ fructans);
       - Nüsse/Eier/Soja → their tag;
       - Fruktose/Sorbit → FODMAP flags as in core.
     - **Histamin cannot be judged.** For a Histamin user the badge never says „Passt zu dir". It says „Histamin bitte selbst prüfen", and the „Passt zu mir" filter ignores Histamin and says so in one line.
     - The adapt route checks FODMAP flags and allergens.
  2. **Portions and „kritisch".**
     - `recipe_ingredients` gets `low_at_amount boolean`: the import's AI judgement whether the stated amount is low-FODMAP (Monash-style portion thinking; the sources are low-FODMAP recipe sites).
     - An ingredient is **kritisch** for a user only if it hits one of their intolerances (FODMAP flag or allergen) **and** it is not `low_at_amount`. Allergens are always kritisch.
     - The „high-FODMAP for everyone" filter is replaced by: drop a recipe if any FODMAP-flagged ingredient is judged not low at its amount.
     - The import may add missing low-FODMAP variants (Knoblauchöl, Lauchgrün, laktosefreier Joghurt …) as **shared** catalog rows (`added_via = 'ai_enrich'`), with flags from the existing catalog-FODMAP classification.
  3. **Catalog access and loading.**
     - The import does not read the production catalog. The reviewed JSON (committed in core, generated from public recipe pages only, so no user data) carries normalised German ingredient names plus their FODMAP flags, allergens and `low_at_amount`.
     - An alembic **data migration** loads it. It resolves each name to an existing shared row (case-insensitive), or creates a shared `ai_enrich` row with the JSON flags, so IDs are resolved per environment at deploy.
     - The source research is committed to core `docs/recipes/sources.md`.
  4. **The KI-Dienst sentence** changes, since the new Tipps send more and nobody has consented to the old wording yet (#86 unreleased): „Dafür schicke ich deine Einträge der letzten Wochen, die Muster daraus und deine Bewertungen meiner Tipps an unseren KI-Dienst." **For Severin to check:** whether the privacy policy's description of requested recommendations covers patterns and ratings, or needs a line.
  5. **Live AI spend:** the recipe import and the Tipps eval together stay within the approved **20 €**, tracked in the eval ledger.
