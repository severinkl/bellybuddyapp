# Muster v2: Vergleich, Verträglichkeits-Test, eigene Alternativen — Design

**Status:** direction by Severin 2026-11-26 („better statistics, guided tests, alternatives ranked by the user's own
history; no embeddings, no model training"); everything else is Claude's call, labelled below, for the controller to
accept or overrule.
**Repos:** app `severinkl/bellybuddyapp` and core `bellybuddy-core`, branch `feat/insights-v2` in each, stacked on
`feat/share-link` (stage 1).
**Track id:** `I` (`IC` core, `IA` app). Phases: 1 statistics → 2 guided tests → 3 ranking → 4 tips context; each phase
ships working software, the controller can stop after any of them.

## 1. Intent

The business plan promises „Trigger-Food-Erkennung" and „Alternativen, die mitlernen". A single user's diary has a few
dozen rated days, far too few for a learned model. What the data does support:

1. **A fair comparison** per FODMAP group and per ingredient: how often a hard day followed eating it, against how often
   a hard day followed not eating it (the user's own base rate), over up to 90 days, shrunk so that „2 von 2" never looks
   certain.
2. **A guided test** („Verträglichkeits-Test"): leave one thing out for 5 days, eat it again for 3, and compare the gut
   feeling of the two phases. This is the only thing in the app that turns a coincidence into something like evidence,
   and it is what dietitians do anyway (in a much more careful form).
3. **Alternativen in the user's own order:** what they liked or ate afterwards first, what they rejected last.
4. **Tipps that know all of this**, so the weekly letter stops suggesting what the user just tested badly or rejected.

**Success:** a user with six weeks of entries sees on the Muster page, in plain words, which groups and foods stand out
over the longer stretch and how sure the Buddy is; the Buddy offers at most one test at a time and only when it is safe
to; after a test the user reads a two-line result; Alternativen they rejected never show first; the Tipps do not
contradict a finished test.
**Anti-goals:** anything that reads like a diagnosis or a verdict („Zwiebel ist dein Auslöser"); pushing someone who
already eats very little to cut more; a second copy of the new maths in the app; a learned model.

## 2. Decisions

| # | Topic | Decision | Whose |
|---|---|---|---|
| 1 | Approach | Statistics + guided tests + per-user ranking; no ML | Severin |
| 2 | Where the statistics run | **Core only**, one route `pattern-stats`; the mirrored 30-day engine stays untouched | Claude (cost if wrong: offline users see no Vergleich, the 30-day Muster still show) |
| 3 | Measure | Difference of two shrunk rates (Beta prior centred on the user's own hard-day rate, strength 4 days) | Claude (cost: a little more or less caution; thresholds are constants) |
| 4 | Window | Up to 90 local days; needs 14 rated days | Claude (cost: 90 days may mix seasons; shorter windows show less) |
| 5 | Minimums | exposed ≥ 4 days, unexposed ≥ 5 days, ≥ 2 hard days after exposure | Claude |
| 6 | Levels | „noch unsicher" / „auffällig" / „deutlich auffällig", plus „unauffällig" for well-eaten foods | Claude (cost: label wording; copy-only change) |
| 7 | Group vs ingredient | Groups first; ingredients nested under their strongest shown group; computed independently | Claude |
| 8 | Test length | 5 days without, 3 days with; fixed in the UI, columns allow 3–7 / 2–5 | Claude (cost: 8 days is short; the result says so) |
| 9 | Test start | Always the next local day | Claude (cost: one day's delay for someone starting in the morning) |
| 10 | Compliance | A leave-out day with the item in its exposure window is „nicht eingehalten" and not counted; no scolding, no interruption while logging | Claude |
| 11 | Restrictive eaters | No test at all (proposed or picked) while the restrictive rule holds; the page says why, kindly | Claude (cost: a few users who could test safely cannot) |
| 12 | Proposals | Ingredient before group; never in the first 7 days; never while a test runs | Claude |
| 13 | Where tests live | Muster page (card + „Testen" on rows), own page `/patterns/test`, Home via the Buddy's cue queue | Claude |
| 14 | Reminders | Two local notifications per test (reintroduction day, result day) at 09:00; no push | Claude |
| 15 | Alternative feedback | New per-replacement verdict „Passt für mich" / „Nicht für mich"; ordering in the app, rejected ones also excluded from new suggestions in core | Claude |
| 16 | Tips | Three new sections (Vergleich, Tests, „Nicht für mich") behind the existing opt-in gate; three fixed rules in the constant system prompt | Claude |
| 17 | Gating | None here; the subscription track gates the screens listed in §9 | controller |

## 3. Approaches considered

- **Extend both mirrored engines (app Dart + core Python) with the new maths.** Rejected: doubles every change and every
  test vector, and the new statistics need the FODMAP catalog (the app's insight source has only names). The existing
  engine's „offline Muster" value is kept by leaving it alone.
- **Compute in the app only.** Rejected: the Tipps need the same numbers on the server, so it would be a mirror again.
- **Core only, served by one route (picked).** One implementation; the app renders JSON. The 30-day engine stays
  mirrored and offline-capable; the new section simply says „gerade nicht verfügbar" offline.
- **A Bayesian posterior probability („zu 87 % schlechter").** Rejected: a percentage reads like a medical finding and is
  hard to explain; the shrunk difference is shown as two plain counts and a level.
- **A free-form „Elimination diet" with several groups.** Rejected (safety): one item at a time, short, with a doctor
  line.

## 4. Design: statistics (phase 1)

### 4.1 Days, exposure, outcome
All in the user's local wall clock (`tracked_at` is wall clock in the UTC slot; `wall_clock.user_zone(profiles.timezone)`;
never `astimezone`).

- **Window:** today's local day and the 89 before it (`STATS_WINDOW_DAYS = 90`). Meals from 24 h before the window on.
- **Rated day:** a local day with at least one gut-feeling entry, classed exactly like the existing engine
  (`insights.classify_days`: mean of the entries' worst-gut-symptom scores; hard = „Schlecht").
  Outcome: **hard** or **not hard** (good and medium together).
- **Anchor:** the day's first entry of the day's class (the existing rule); for a medium day, its first entry.
- **Exposed to ingredient X:** some meal in `[anchor − 24 h, anchor)` lists X (ingredient key = the engine's key:
  trimmed, case-insensitive).
- **Exposed to group G:** some meal in that window lists an ingredient whose catalog row (the user's catalog,
  `ingredient_suggestions.load_catalog`, matched by `suggestion_key`) has `fodmap_G`. An ingredient not in the catalog
  has no groups (stated limit).

### 4.2 The measure
For an item: `E` exposed rated days, `hE` hard among them; `U` unexposed rated days, `hU` hard among them; `N = E + U`,
`H = hE + hU`, base rate `p0 = H / N`.

```
rE = (hE + K·p0) / (E + K)        rU = (hU + K·p0) / (U + K)        d = rE − rU        K = 4
```
Exact arithmetic (`fractions.Fraction`), so thresholds and sorting are deterministic. With `K = 4` a „2 von 2" after a
20 % base rate moves the exposed rate from 20 % to 47 %, not to 100 %; the minimums below keep such an item hidden
anyway.

### 4.3 Who is shown at what level

| Level (`level`) | German badge | Condition (all) |
|---|---|---|
| — (not ready) | — | fewer than `MIN_RATED_DAYS = 14` rated days in the window |
| `unsure` | „noch unsicher" | `E ≥ 4`, `U ≥ 5`, `hE ≥ 2`, `d ≥ 1/10` |
| `noticed` | „auffällig" | `E ≥ 6`, `U ≥ 5`, `hE ≥ 3`, `d ≥ 1/5` |
| `strong` | „deutlich auffällig" | `E ≥ 10`, `U ≥ 10`, `hE ≥ 5`, `d ≥ 3/10` |
| `calm` | „unauffällig" | `E ≥ 8`, `U ≥ 5`, `d ≤ 1/20` (eaten often, no more hard days than without) |

An item gets the highest level whose conditions hold. Sorting: level (strong, noticed, unsure), then `d` descending, then
`E` descending, then name in German order (`insights.german_order_key`). Caps: all groups that qualify (≤ 6), at most 8
ingredients, at most 5 `calm` ingredients (groups are never `calm`: a group is too broad to reassure about).

### 4.4 Groups and ingredients without contradiction
- Both are computed independently from the same days.
- The page shows **„Nach FODMAP-Gruppen"** first: each shown group as a row („Fruktane · nach 8 von 12 Tagen mit Fruktanen
  ein schwerer Tag · ohne: 4 von 29"). Under it, indented, the shown ingredients that carry that group.
- An ingredient with several groups is nested under its **strongest** shown group only (level, then `d`, then
  `FODMAP_KEYS` order), so it appears once. One with no shown group appears in **„Einzelne Zutaten"**.
- A shown group may hold calm ingredients; that is said, not hidden: „Fruktane fallen auf, Weizenbrot (auch Fruktane)
  aber nicht" is the honest reading. The `calm` list is **„Bei dir unauffällig"**, below.
- A group row's own level never changes an ingredient's, and vice versa.

### 4.5 Known limits, and how the UI words them
Shown as a collapsed „Was dieser Vergleich nicht kann" under the section, plus the existing footer:
- **Zusammentreffen, keine Ursache:** „Was oft zusammen auf dem Teller ist, fällt gemeinsam auf. Zwiebel und Knoblauch
  kann ich zum Beispiel schlecht auseinanderhalten, wenn du sie immer zusammen isst."
- **Zeit:** „Ich schaue auf die 24 Stunden vor deinem Bauchgefühl. Manches wirkt schneller oder langsamer."
- **Menge:** „Ich weiß nicht, wie viel du gegessen hast – eine Prise ist für mich dasselbe wie ein Teller."
- **Alles andere:** „Stress, Schlaf, Zyklus oder Medikamente sehe ich nicht. Die können genauso viel ausmachen."
- **Katalog:** „Die FODMAP-Gruppen kenne ich nur für Zutaten aus unserem Katalog."
Every level label is relative („auffällig"), every row shows its counts, and the section's last line is
„Ein Test sagt mehr als jeder Vergleich." with the „Testen" action (phase 2).

### 4.6 Route `pattern-stats`
`POST /functions/v1/pattern-stats`, no body, authenticated. 403 „Bitte stimme zuerst der Datenschutzerklärung zu." without
current health consent (as `shares`). Reads the user's meals and gut-feeling entries of the window, their catalog and
`profiles.timezone`. Never logs ingredient names or counts. Response (phase 1):

```json
{
  "window_days": 90,
  "rated_days": 41,
  "hard_days": 9,
  "ready": true,
  "groups": [
    {"kind": "group", "key": "fructans", "name": "Fruktane", "level": "noticed",
     "exposed": 12, "exposed_hard": 8, "unexposed": 29, "unexposed_hard": 4}
  ],
  "ingredients": [
    {"kind": "ingredient", "key": "zwiebel", "name": "Zwiebel", "level": "strong",
     "exposed": 10, "exposed_hard": 7, "unexposed": 31, "unexposed_hard": 2,
     "groups": ["fructans"], "nested_in": "fructans"}
  ],
  "calm": [
    {"kind": "ingredient", "key": "reis", "name": "Reis", "level": "calm",
     "exposed": 18, "exposed_hard": 2, "unexposed": 23, "unexposed_hard": 7, "groups": [], "nested_in": null}
  ]
}
```
`name` of an ingredient: the spelling of the most recent meal (the existing engine's rule); of a group:
`FODMAP_LABELS_SHORT`. When `ready` is false, the lists are empty and `rated_days` says how far along the user is.

### 4.7 In the app
- `patternStatsProvider` (`AsyncNotifier`), fetched when the Muster page opens and again after entry writes while it is
  watched (`entriesRevisionProvider`, as `insightsProvider`). Not persisted.
- The Muster page (unlocked) gets a new section **„Genauer hingeschaut"** after „Fällt mir auf", subtitle
  „Letzte 90 Tage: wie oft ein schwerer Tag folgte – mit und ohne". Not ready: „Für diesen Vergleich brauche ich 14 Tage
  mit Bauchgefühl – bisher {n}." Offline or failed: „Der Vergleich ist gerade nicht verfügbar." with „Nochmal versuchen".
  The 30-day sections above it are unchanged.
- A row: name, badge, and the counts line „nach {hE} von {E} Tagen mit {Name} ein schwerer Tag · ohne: {hU} von {U}".
  (E ≥ 4, so always „Tagen".) Calm row: „{Name} · an {E} Tagen gegessen, nicht öfter schwere Tage".

## 5. Design: guided test (phase 2)

### 5.1 Data model (core migration, PostgREST + RLS)
`public.tolerance_tests`:

| column | type | notes |
|---|---|---|
| `id` | uuid pk default `gen_random_uuid()` | |
| `user_id` | uuid not null, FK `auth.users` on delete cascade | |
| `subject_kind` | text not null, check in (`group`, `ingredient`) | |
| `subject_key` | text not null, 1–80 chars; a FODMAP key for a group | check: group ⇒ key in the six keys |
| `subject_name` | text not null, 1–80 chars | display name |
| `origin` | text not null, check in (`proposed`, `picked`) | |
| `leave_out_days` | int not null default 5, check 3–7 | |
| `reintro_days` | int not null default 3, check 2–5 | |
| `starts_on` | date not null | first leave-out day, local |
| `status` | text not null default `active`, check in (`active`, `completed`, `stopped`) | |
| `ended_at` | timestamptz null | set with `completed` / `stopped` |
| `created_at` | timestamptz not null default now() | |

- Unique partial index `(user_id) where status = 'active'`: **one active test at a time**, so never two groups at once.
- RLS on; owner-only SELECT, INSERT (`with check auth.uid() = user_id and status = 'active'`), UPDATE (`using`/`with
  check auth.uid() = user_id`); no DELETE for clients (account deletion removes rows; the FK cascades and
  `delete_account.USER_ID_TABLES` lists the table). Default privileges revoked, then column grants: INSERT on the subject
  columns, `origin`, `starts_on`; UPDATE on `status`, `ended_at` only.
- The phases follow from the dates: leave-out `starts_on … starts_on + L − 1`, reintroduction the next `R` days, done
  from the day after.

### 5.2 Evaluation (core, same route)
`pattern-stats` gains `test` (the active test, or the latest completed one ending within 14 days, or null), `tested`
(completed tests of the last 180 days, newest first), `proposal` and `restrictive`.

Per test day (local): `class` (the day's class or `none`) and `exposed` (the subject in the day's exposure window as in
§4.1; on a day without gut-feeling entry, any meal of that local day). Then:
- leave-out day: counted „ohne" if rated and not exposed; „nicht eingehalten" if exposed; „kein Eintrag" if unrated.
- reintroduction day: counted „mit" if rated and exposed; „nicht gegessen" if rated and not exposed; „kein Eintrag".
- **Result** once the phase is done: `without = {good, counted}`, `with = {good, counted}` (good = „Gut"/„Sehr gut").
  `gap = good_without/counted_without − good_with/counted_with`. Outcome:
  - `unclear` if `counted_without < 3` or `counted_with < 2`
  - `worse` if `gap ≥ 2/5`
  - `slightly_worse` if `1/5 ≤ gap < 2/5`
  - `better` if `gap ≤ −1/5`
  - `no_difference` otherwise.
- The server never writes; the app sets `status = completed` the first time it receives `phase: "done"`. A test still
  `active` past its end counts as done everywhere.

```json
"test": {"id": "…", "kind": "ingredient", "key": "zwiebel", "name": "Zwiebel", "origin": "proposed",
         "status": "active", "phase": "leave_out", "starts_on": "2026-12-02",
         "leave_out_days": 5, "reintro_days": 3, "day_index": 2,
         "days": [{"day": "2026-12-02", "phase": "leave_out", "class": "good", "exposed": false}],
         "result": null},
"tested": [{"kind": "ingredient", "key": "zwiebel", "name": "Zwiebel", "outcome": "worse", "ended_on": "2026-12-10"}],
"proposal": {"kind": "ingredient", "key": "zwiebel", "name": "Zwiebel"},
"restrictive": false
```
`result`: `{"without": {"good": 4, "counted": 5}, "with": {"good": 1, "counted": 3}, "outcome": "worse",
"not_kept": 0, "not_eaten": 0}`.

### 5.3 Safety rules (all in core, so the app cannot forget one)
- **Restrictive** (`restrictive: true`) when either holds: `profiles.intolerances` has 3 or more entries; or in the last
  14 local days there are meals on at least 5 days and fewer than 15 distinct ingredient keys across them. While true:
  `proposal` is null and the app offers no „Testen" anywhere; the test page shows the restrictive text (§5.6).
- **Proposal** only when: `ready`; not restrictive; the user's first entry is at least 7 local days ago; no active test;
  the candidate is the top item with level `noticed` or `strong` — ingredients first, groups only if no ingredient
  qualifies — and has no completed test in the last 60 days and no stopped test in the last 14.
- One test at a time (the index). Group tests only ever one group.
- The doctor line on the test intro, the result, and the stop dialog.

### 5.4 Lifecycle in the app
- **Start:** from the proposal (Home sheet or Muster card) or „Testen" on any shown group/ingredient row. The intro page
  explains the two phases and the dates; „Test starten" inserts the row with `starts_on` = tomorrow. A conflict (another
  active test, the unique index) reloads and shows the running one.
- **During:** the Muster card shows „Tag {i} von {L + R}" and the phase; the test page shows one dot per day (gut feeling
  colour as the calendar, a small marker for „nicht eingehalten"/„nicht gegessen", „kein Eintrag" grey).
- **Missed days:** not counted; no extension, no penalty. Too few → `unclear` with „Nochmal testen".
- **Stop:** „Test beenden" → dialog → `status = stopped`, `ended_at = now`. A stopped test shows nothing afterwards
  (no partial result) and blocks a new proposal of that subject for 14 days.
- **Finish:** first `phase: done` → `status = completed`. The result stays on the Muster card for 14 days.

### 5.5 Reminders and the Buddy
- **Local notifications** (existing `LocalNotificationService`, `flutter_local_notifications`; only if permission was
  granted, no new ask): id 3000 on the first reintroduction day at 09:00 („Ab heute darf {Name} wieder auf den Teller –
  ich schau, wie's deinem Bauch damit geht."), id 3001 on the day after the last day at 09:00 („Dein Verträglichkeits-Test
  ist fertig. Magst du reinschauen?"); payload `/patterns/test`; scheduled at start, cancelled on stop and on sign-out
  (`cancelAll` already runs there), rescheduled when the app finds an active test without them (re-install).
- **Home:** three new `BuddyAnnouncement`s offered from outside through `buddyOffersProvider`, so they queue in the hero's
  existing cue queue:
  - `testOffer` (suffix = `<kind>_<key>`, so a declined subject is offered once): ends in a sheet
    („Magst du was ausprobieren?" / „An schweren Tagen war oft {Name} dabei. Wollen wir testen, ob dein Bauch ohne
    besser klarkommt? 5 Tage ohne, dann 3 Tage mit." / „Ansehen" / „Später"). Like the reminders ask, it **never plays
    right after another sheet cue** in the same run (it ends unshown and stays pending), and it is not offered while the
    reminders ask is due.
  - `testReintro` (suffix `<id>_reintro`): a line only, on the first reintroduction day.
  - `testDone` (suffix `<id>_done`): a line only, once the result is there.
- No Home card of its own; the Home insight card is unchanged.

### 5.6 Copy (German, „du", no „Diagnose", no „Auslöser")
- Intro title „Verträglichkeits-Test: {Name}". Body: „So geht's: {L} Tage lässt du {Name} weg, danach isst du es {R} Tage
  wieder ganz normal. Trag jeden Abend dein Bauchgefühl ein – dann vergleiche ich die beiden Phasen." Dates line
  „Ohne: {Datum} – {Datum} · Mit: {Datum} – {Datum}". For a group, a line listing up to five foods of that group the user
  ate in the window („Fruktane stecken bei dir zum Beispiel in Zwiebel, Weizenbrot, Knoblauch.").
- Doctor line (intro, result, stop): „Hast du starke oder anhaltende Beschwerden, sprich bitte mit deiner Ärztin, deinem
  Arzt oder einer Ernährungsfachkraft."
- Phase lines: „Phase 1: ohne {Name}" / „Phase 2: wieder mit {Name}". Not kept: „An {n} Tag(en) war {Name} doch dabei –
  das passiert. Diese Tage zähle ich nicht mit." Not eaten: „An {n} Tag(en) war {Name} nicht dabei – die zähle ich nicht
  mit."
- Result headline: „In den Tagen ohne {Name} ging es dir an {g} von {c} Tagen gut, mit {Name} an {g'} von {c'}."
- Conclusions: `worse` „Mit {Name} ging es dir in diesem Test deutlich schlechter. Das könnte heißen, dass du {Name}
  gerade nicht so gut verträgst." · `slightly_worse` „Mit {Name} ging es dir etwas schlechter. Acht Tage sind kurz – wenn
  du magst, wiederhol den Test später." · `no_difference` „{Name} hat in diesem Test keinen klaren Unterschied gemacht."
  · `better` „Mit {Name} ging es dir in diesem Test nicht schlechter – {Name} scheint gerade kein Problem für dich zu
  sein." · `unclear` „Dafür hab ich zu wenige Tage mit Bauchgefühl. Magst du es nochmal versuchen?"
- Always under the result: „ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund." and the doctor line.
- „getestet" badge on a stats row whose subject is in `tested`: „getestet: deutlich schlechter" / „getestet: etwas
  schlechter" / „getestet: kein klarer Unterschied" / „getestet: kein Problem" / „getestet: unklar"; the latest test wins
  and its badge replaces the „Testen" action for 60 days.
- Restrictive: „Gerade schlage ich keinen Test vor. In deinen Einträgen ist die Auswahl schon recht klein – etwas
  wegzulassen würde sie noch kleiner machen. Wenn du herausfinden willst, was dir guttut, kann dir eine
  Ernährungsfachkraft dabei helfen."
- Stop dialog: „Test beenden?" / „Kein Problem – hör auf deinen Bauch. Das Ergebnis zeige ich dann nicht." / „Beenden" /
  „Weitermachen".

## 6. Design: alternatives ranked by the user's history (phase 3)

### 6.1 What exists (and what the brief assumed)
`ingredient_suggestions` (one row per meal × flagged ingredient, `seen_at`, `dismissed_at`) with
`ingredient_suggestion_replacements` (name + catalog id). The app groups them by detected ingredient
(`SuggestionHelpers.buildGroups`) and shows the replacements in creation order. **There is no per-replacement feedback
today**; the only like/dislike is on whole tip sets (`recommendations.state`). So the per-user ranking needs a new signal.

### 6.2 New feedback
`public.alternative_feedback`: `user_id` (FK cascade), `replacement_ingredient_id` uuid not null (FK `ingredients` on delete
cascade), `verdict` text check in (`liked`, `disliked`), `updated_at` timestamptz default now(); primary key
`(user_id, replacement_ingredient_id)`. Owner-only RLS for SELECT, INSERT, UPDATE, DELETE (delete = „Zurücksetzen");
listed in `delete_account.USER_ID_TABLES`. A verdict is about the food, not the pairing: „Nicht für mich" on Hafermilch
holds wherever Hafermilch is offered (Claude's call: users think in foods; cost: a user who dislikes a pairing but likes
the food must reset it).

In the app: tapping a replacement tile in the suggestion detail opens a small sheet with the name and „Passt für mich",
„Nicht für mich" and, once set, „Zurücksetzen". The tile shows a small check or a dimmed look.

### 6.3 Ordering (deterministic, in the app)
`rankReplacements` in `lib/services/alternatives/alternative_ranking.dart`, applied inside `buildGroups`:

1. tier 0 — `liked`;
2. tier 1 — eaten afterwards: a meal on a later local day than the group's first suggestion lists it (match by base
   name, below);
3. tier 2 — neutral;
4. tier 3 — a sibling of a disliked one (same base name, not itself disliked);
5. tier 4 — `disliked`.

Within a tier: meals eaten afterwards (more first), then the existing order. **Base name:** lower-cased, trimmed, cut at
the first „ (" — „Tofu (fest, natur)" and „Tofu" are siblings (the rule `SuggestionHelpers.ingredientImage` already uses).
Lists that show a summary (Discover's „Stattdessen: …", the suggestion card's row) **leave disliked ones out**; the detail
shows them last under „Nicht für mich", so a rejected item is never first. If every replacement is disliked, the summary
shows none.

### 6.4 Core
`create_suggestions` drops the user's disliked replacements and their siblings from `low_fodmap_names` before the AI call,
so new suggestions stop offering them. Nothing else in core ranks.

## 7. Design: tips context (phase 4)
`tips_context.fetch_tips_context` (still only when `profile.with_context`: opted in + current consent — unchanged) also
reads the 90-day statistics (the route's reads and `compute_pattern_stats`), the tests (`test` and `tested` as in §5.2)
and the disliked alternatives, inside the same savepoint. Three new user-turn sections after the patterns:

- `Vergleich der letzten 90 Tage (Beobachtungen, kein Befund):` one line per shown item
  „- Zwiebel: auffällig (nach 7 von 10 Tagen mit ein schwerer Tag, ohne: 2 von 31)" and „- unauffällig: Reis, Hafer".
- `Verträglichkeits-Tests:` „- läuft: Zwiebel, Phase ohne bis 06.12.2026" / „- abgeschlossen am 10.12.2026: Zwiebel –
  mit Zwiebel deutlich schlechter" / „keine".
- `Alternativen, die nicht passen:` names, or „keine".

Without context each says „nicht verfügbar", like the existing sections. Three fixed rules join the constant system
prompt (the prompt cache stays shared): a finished test outweighs any pattern, never suggest eating a food a test showed
as worse, and never call it a cause; during a running test's leave-out phase never suggest the tested food (or group),
during its reintroduction never suggest leaving it out; never suggest an alternative listed as not fitting.
The eval (`scripts/ai_eval.py`) gets one case with a finished `worse` test; Severin runs it (needs the API key).

## 8. Privacy policy text (German, for the shared final „policy text" task; no version bump here)

Add to **„2. Welche Daten wir verarbeiten"**:
> **Verträglichkeits-Tests:** Wenn du einen Verträglichkeits-Test startest, speichern wir, welche Zutat oder
> FODMAP-Gruppe du testest, wann der Test beginnt, wie lange seine Phasen dauern und ob du ihn abgeschlossen oder beendet
> hast. Das Ergebnis berechnen wir jedes Mal neu aus deinen Einträgen; es wird nicht gesondert gespeichert.
> **Bewertungen von Alternativen:** Wenn du eine Alternative mit „Passt für mich" oder „Nicht für mich" markierst,
> speichern wir diese Bewertung, um dir Alternativen in einer passenden Reihenfolge zu zeigen und dir keine mehr
> vorzuschlagen, die nicht zu dir passen.

Add to **„3. Zwecke und Rechtsgrundlagen"**, under the health-data processing:
> Für die Muster vergleichen wir auf unserem Server deine Einträge der letzten 90 Tage: wie oft nach Mahlzeiten mit einer
> Zutat oder FODMAP-Gruppe ein schwerer Tag folgte und wie oft ohne. Daraus schlägt die App höchstens einen
> Verträglichkeits-Test zur selben Zeit vor. Diese Auswertung ist eine Beobachtung aus deinen eigenen Einträgen, kein
> medizinischer Befund, und sie wird ohne KI berechnet. Rechtsgrundlage ist deine Einwilligung in die Verarbeitung von
> Gesundheitsdaten (Art. 9 Abs. 2 lit. a DSGVO).

Replace in **„4. KI-Funktionen"** the weekly-tips paragraph's list of inputs with:
> … deine Einträge der letzten Wochen, die Muster daraus (welche Zutaten an deinen guten und an deinen schweren Tagen oft
> dabei waren und der Vergleich der letzten 90 Tage), deine Verträglichkeits-Tests mit ihren Ergebnissen, die
> Alternativen, die du als „Nicht für mich" markiert hast, und deine Bewertungen unserer bisherigen Tipps …

Add to **„7. Speicherdauer"**:
> Verträglichkeits-Tests und Bewertungen von Alternativen speichern wir, bis du dein Konto löschst; mit dem Konto werden
> sie sofort gelöscht.

The weekly-tips opt-in sentence in the app („Dafür schicke ich deine Einträge der letzten Wochen, die Muster daraus und
deine Bewertungen meiner Tipps an unseren KI-Dienst.") should read „… die Muster daraus, deine Tests und deine
Bewertungen …" in the same bump (controller's shared task; the plan does not change it).

## 9. Subscription (no gating here)
The subscription track will gate, and this track keeps each behind one widget or provider so it can:
- `/patterns` (whole Muster page, incl. „Genauer hingeschaut" and the test card) and `/patterns/test`;
- the test offer on Home: `toleranceTestOfferDueProvider` (gate it to false) and the two line cues;
- `/recommendations` and Discover's Tipps section; `/ingredient-suggestions` and Discover's Alternativen section,
  including the feedback sheet;
- core: `pattern-stats` stays callable (the subscription track decides whether to gate it server-side).
This track adds no switch, no paywall copy and no check.

## 10. Non-goals
- No ML, embeddings or cross-user learning; no change to the 30-day engine or its shared vectors.
- No multi-group elimination diet, no portions, no custom test lengths in the UI.
- No push notifications; no Home card of its own; no admin view of tests.
- No change to the share view (`share_view`): the dietitian page keeps the 30-day Muster.

## 11. Left to the builder
- Whether `pattern_stats.py` reuses `insights`' private helpers by making them public (behaviour unchanged, vectors
  green) or keeps small copies — not a third engine either way.
- Widget structure of the new Muster section and the test page within the design system.
- Whether the test-day dots reuse `InsightCalendar`'s look.

## 12. Needs from Severin
- Copy sign-off for the result conclusions, the restrictive text and the doctor line (health-claims wording).
- Whether a dietitian should review the test protocol (5 + 3 days, one item) before release.
- Running the AI eval case for phase 4 (API key).
- The shared policy bump (controller merges §8 with the other tracks).

## 13. Manual checks for Severin (device)
- The two test notifications arrive at 09:00 local on iOS and Android, and open the test page.
- The Home offer sheet does not appear on the same visit as „Neue Tipps", a reward or the reminders ask.
- The Muster page with a real-looking account (staging): the Vergleich section reads plainly and nothing sounds like a
  verdict.
