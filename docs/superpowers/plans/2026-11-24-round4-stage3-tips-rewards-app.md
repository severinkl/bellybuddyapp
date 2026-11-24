# Runde 4 Stage 3: Tipps & Belohnungen (App) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first 7 days give something back every day, the day-3 reward is the weekly-tips offer with an immediate first tip, and the Tipps screen shows core's new sets (a letter, „Fokus der Woche" first, „Passendes Rezept: … ›"); the Dart insights engine runs core's shared test vectors.

**Architecture:**
- **Shared vectors:** core's `vectors.json` is copied byte for byte into `test/fixtures/insights/` and every vector runs against `computeInsights` under `TZ=Europe/Vienna`.
- **Tip sets:** `RecommendationItem` gains `focus`, `recipeId`, `recipeTitle` (additive; older sets read as today). The Tipps page shows the letter, the focus item first with its label, and a recipe link for a Tausch-Tipp whose recipe is still in the loaded collection.
- **Rewards state:** pure rules (`lib/services/journey/journey_rules.dart`) over one persisted value per user and device (`JourneyRewards`, SharedPreferences JSON `journey_rewards_<userId>`): the earned day (never lower), the recipe picks, the day-3 answer and the first-tip state. `JourneyRewardsNotifier` advances it from the settled insights, the weekly-tips switch and the ranked collection.
- **Announcements:** three new `BuddyAnnouncement` kinds (`journeyReward`, `patternsUnlocked`, `firstTipFailed`) go through the existing offer queue and flags. The existing `weeklyTipsOffer` becomes the day-3 reward for journey users. `BuddyHero` plays each one into a sheet (`JourneyRewardSheet`, `FirstTipOfferSheet`) or the full-screen `PatternsUnlockedScreen`.
- **First tip:** after „Ja" and a successful opt-in write, `FirstTipNotifier` calls core's `diet-recommendations` once per user and device with the profile and the last 3 days' meals; the saved set arrives through the normal tips load.
- **Journey card:** a reward line under the counters, its own button, opens „Deine Belohnungen" (every earned reward stays reachable).

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3.5 (`Notifier`/`AsyncNotifier`), GoRouter 18, Supabase (`functions.invoke`, PostgREST), `shared_preferences`, `url_launcher`, mocktail, integration_test. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-24-round4-home-recipes-tips-design.md`. This plan covers the app half of **Stage 3** (§6):
- §5.5 rewards (the table, „once per user and device", „never taken away", users past day 7);
- §5.7 „App" (letter, „Fokus der Woche", „Passendes Rezept: … ›", additive schema);
- §4 shared vectors on the Dart side;
- the Decisions log: the KI-Dienst sentence (#4), and the offer sheet keeping both buttons visible on short screens.

Binding alongside it:
- **Backend contract:** core plan `/Users/sevi/projects/bellybuddy-core-tips-wt/docs/superpowers/plans/2026-11-24-round4-stage3-tips-core.md` § „Contract for the app" and the report `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/core-tips-report.md` (items `focus`, `recipe_id`, `recipe_title`; letter in `summary`; ≤ 3 items; focus first; a set is new-layout when any item has `focus: true`).
- **`diet-recommendations`** (core `backend/app/routes/diet_recommendations.py`): request `{"intolerances": [..], "diet": .., "recentMeals": [{"title", "ingredients", "tracked_at"}]}`; the route reads no meals itself (`recentMeals` missing = none) and reads the last 3 days' gut entries from the database; response `{"summary", "recommendations", "fodmapAnalysis", "id", "created_at"}` (`id`/`created_at` only when saved); 429 on an AI rate limit, 500 on an AI error, 200 with `Leider konnte keine Analyse durchgeführt werden.` and `[]` when the model gave nothing usable (saved).
- **Vectors:** `/Users/sevi/projects/bellybuddy-core-tips-wt/backend/tests/fixtures/insights/vectors.json` (28 vectors; sha256 `4b969f96a148df7190fa30f3a5f48a9c50db37e83097db556ef273885e4cae77` at plan time). Template runner: `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/tips/appcopy/test/vectors_runner_test.dart`.
- **Mockups:** `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/round4-home.html` (journey card) and `round4-recipes.src.html` (`SCREENS.tipps`: the Tausch-Tipp with „Passendes Rezept: <b>…</b> ›" and a thumbnail). Where they and the spec differ, the spec wins.

**Base:** stacks on `feat/round4-recipes` (Stage 2) after its final refactor. Names from Stage 2 used below (`rankedRecipesProvider`, `RankedRecipes`, `RecipeFit`, `pickForYou`, `RecipeListTile`, `RecipeImage`, `recipeCollectionProvider`, `context.openRecipe`, `RoutePaths.discoverRecipes`) are as of `34e7bb9`; if the refactor renamed one, use the new name and say so in the task report.

## Global Constraints

From the spec, the contract and `CLAUDE.md`, verbatim where they give values:
- Follow the repo's `CLAUDE.md`:
  - colours, font sizes, spacing and radii only through `AppTheme`/`AppConstants` (add tokens there first);
  - German UI; `AppLogger`, never `print`;
  - Riverpod, GoRouter; `CachedNetworkImage` + `shimmer` for any network image;
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- „Belly Buddy" is never translated.
- **Vocabulary** (§5.9 of the app-structure spec): eintragen, Essen, Bauchgefühl, Tipps (never „Empfehlung"), Alternativen, Tagebuch. `test/utils/vocabulary_test.dart` stays green with no new exemptions.
- **No health claims, no invented statistics.** Rewards and Tipps never say a food helps, harms or causes; patterns are observations; the day-6 preview is the Muster page's existing, clearly fictional sample, labelled as an example.
- **Privacy:**
  - No AI call with user data before the user says yes: the first tip is requested only after „Ja, gern" **and** a successful weekly-tips opt-in write.
  - The request carries exactly `intolerances`, `diet` and `recentMeals` (`title`, `ingredients`, `tracked_at`) of the last 3 days.
  - Nothing is ever logged with meal contents.
- **KI-Dienst sentence** (Decisions log #4) is `WeeklyTipsSwitch.sentence`, unchanged: „Dafür schicke ich deine Einträge der letzten Wochen, die Muster daraus und deine Bewertungen meiner Tipps an unseren KI-Dienst." Every place that switches the tips on shows it.
- **Entry times are wall clock** (`lib/utils/wall_clock.dart`): read with `wallClockFromWire`, write values and bounds with `wallClockToWire`; days via `startOfDay`/`isSameDay` on local `DateTime`s, never `toLocal()`/`toUtc()` on them.
- **Rewards** are per user and device, shown once, never taken away (the earned day never goes down, a pick never changes once stored).
- **Reduced motion:** every new animation respects it; the celebration shows a still Buddy.
- **Layout:** a 375×667 screen at text scale 1.3 does not overflow, and every Buddy sheet keeps both its buttons on screen without scrolling there.
- **Scope:** app only; core is untouched. Deploy order: core #12 first. The release follows this stage.

Execution rules for this repo (carried over from Stage 2):
- **Commits:**
  - Run `dart format .` and `flutter analyze` (0 issues) first.
  - Then `git commit --no-verify` (the hook is broken in worktrees), with a conventional prefix and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - **Never push.**
- **Tests run under the CI zone:** prefix every `flutter test` with `TZ=Europe/Vienna` (CI's unit and widget jobs set it).
- **Test seams:**
  - `test/flutter_test_config.dart` already calls `disableAmbientAnimationsForTests()`.
  - Screens that open links take a `UrlOpener openUrl` (default `launchUrl`); tests pass `RecordingUrlOpener`.
  - Screen tests override `recipeRepositoryProvider` with `FakeRecipeRepository`, `entryRepositoryProvider` with `FakeEntryRepository`, `profileProvider` with `profileProviderSeededWith(...)`, the rewards with `journeyRewardsSeededWith(...)` (Task 4) and the first tip with `FakeFirstTipNotifier` (Task 5).
  - SharedPreferences: `SharedPreferences.setMockInitialValues` per test; a „restart" is a new `ProviderContainer` over the same mock values.
- **Simulators:**
  - Integration tests run **only** on the iPhone Air `CB1F6232-482F-408F-ADF4-89FDA602E6A8`, one file at a time, and the simulator is shut down afterwards.
  - **Never** use `55746DB2…` (Severin's live session) or `7A26EDD4…`.
  - Never run `flutter clean`.
  - Never a bare `git stash`; use a temporary worktree to compare with the base commit.

## Review Focus

1. **Day counting on wall-clock days, DST included.** A day's dot is a local day of the wall-clock `tracked_at`; the reward line's „Heute" uses the same local day. A 23:30 entry on the autumn-DST Sunday counts for that Sunday; a window that slides never lowers the earned day.
   Pinned in Task 1 (the DST and late-evening vectors), Task 3 (`a late-evening entry on the DST Sunday is today`, `never decreases`) and Task 4 (`restart: fewer active days never lower it`).
2. **A reward is never shown twice and never lost after a restart.** The stored earned day, picks and answers come back; a flagged day is not offered again; a cue cut short (app closed before it ended) comes again; a newer day replaces a pending older one, and the older one stays in „Deine Belohnungen".
   Pinned in Task 4 (`restart keeps the earned day and the picks`), Task 8 (`a flagged day is not offered again`, `a newer day replaces a pending older one`, `a cue cut short comes again`) and Task 6 (`the list shows every earned day`).
3. **The day-3 first tip fails (AI error, rate limit, timeout, an empty answer).** The user stays opted in, nothing is retried, one neutral Buddy line says so once, and an empty saved set is never announced as „Neue Tipps".
   Pinned in Task 5 (`500`, `429`, `transport`, `timeout`, `200 without tips: the set stamped seen`, `accept twice: one request`, `after a restart with a request stored: none`) and Task 8 (`firstTipFailed: one line, once`).
4. **Privacy of the first tip.** No request before „Ja", none after „Nein" or a dismissal, none when the opt-in write fails; the body holds only the three keys.
   Pinned in Task 5 (`opt-in fails: no request`, `the body is exactly …`) and Task 8 (`no → no request`, `dismissed → no request`).
5. **Older tip sets without the new fields** render exactly as today: no „Dein Wochenbrief", no „Fokus der Woche", stored order, no recipe link; a hidden recipe gives no link.
   Pinned in Task 2 (`an old set renders as today`, `a recipe no longer in the collection: no link`).
6. **A user who opted in before day 3** gets no offer, no AI call, and a recipe as the day-3 reward.
   Pinned in Task 3 (`weekly on at day 3 → skipped`), Task 8 (`opted in before day 3: journeyReward day 3, no offer`).
7. **Users past day 7 before this release** see no journey, no reward line and no reward announcements; their weekly-tips offer still comes after the unlock with the old sheet.
   Pinned in Task 4 (`journey false: null`), Task 8 (`journey false (past day 7): today's rule`, `journey false → the old sheet`) and Task 9 (`no reward line without the journey`).

## Decisions (spec gaps ruled in this plan)

- **Where the day-7 celebration plays:** on Home, as the announcement `patternsUnlocked`: the Buddy celebrates, then the full-screen `PatternsUnlockedScreen`, whose „Muster ansehen" replaces it with the Muster page. It also catches an unlock from a back-dated entry or another device. The success page stays as Stage 1 left it: `LogMoment` says no line on the entry that unlocks.
- **Newest-only announcements:** when several days are earned at once (back-dated entries, the app unopened), the Buddy announces only the newest of days 1–6. The day-3 offer and the day-7 celebration are their own kinds and are never skipped. Every earned reward stays reachable in „Deine Belohnungen".
- **The reward line** sits below the counters as its own button (it opens „Deine Belohnungen"); the rest of the card still opens Muster. A button inside the card's `MergeSemantics` would be swallowed.
- **Line wording:** „Heute: <reward>" once today's dot is filled; „Heute wartet: <next reward>" before today's first entry; „Bald: Deine ersten Muster" while day 7 also needs Bauchgefühl entries.
- **Day 3 copy:** not „Dein erster Tipp ist fertig". No tip exists before „Ja" (no AI call before consent). The line is „Ich hab genug für deinen ersten Tipp! Soll ich ihn dir machen? ✨".
- **Already opted in before day 3:** day 3 gives a recipe. Their Monday tips come anyway, and a first tip would be an AI call they didn't ask for.
- **A dismissed first-tip sheet** counts as „Nein" for the offer: it doesn't come again, and the list's day 3 becomes the recipe. Only an explicit „Nein, danke" opens the recipe sheet right away.
- **First tip:**
  - once per user and device; the state is stored before the call;
  - no retry (cost, rate limits);
  - client timeout 60 s;
  - success = an `id` and at least one item;
  - every failure (429, 500, transport, timeout, 200 without items, no `id`) is one `failed` state and one Buddy line, „Dein erster Tipp hat gerade nicht geklappt. Die wöchentlichen Tipps bleiben eingeschaltet.";
  - an empty saved set is stamped seen, so „Neue Tipps sind da!" never contradicts that line.
- **First-tip body:** the profile's `intolerances` and `diet`, plus the meals of the last 3 days (`tracked_at ≥ now − 3 days`, wall clock). The route reads no meals itself, and core reads the same 3 days' gut entries.
- **Day 2:** a fixed article by link, „Low FODMAP kurz und knackig" (`https://www.myfodmap.at/low-fodmap-kurz-und-knackig`). It is in today's feed, and opening it by link keeps it once it drops out of the feed's newest 20.
- **Day 4:** six sayings in the app; a user's saying is `sayings[sum of the user id's code units % 6]`: stable without storage, and different users differ.
- **Recipe picks (days 1, 3, 5):**
  - made by `JourneyRewardsNotifier` once the day is earned **and** the fit is checked (rules and profile known), then stored and never changed;
  - a later pick excludes earlier ones;
  - while unchecked, the reward shows „Rezepte, die zu dir passen, findest du unter Entdecken." and stores nothing.
  - Day 1 = the first „Für dich" recipe (`pickForYou` order).
  - Day 3 (recipe variant) = the next one.
  - Day 5 = the best-ranked passing recipe with a line matching a calm-day ingredient (`Insights.calmDayIngredients`), naming up to 3 matched lines. Without a match it is the next „Für dich" recipe under the title „Noch ein Rezept für dich", so the copy never claims a match.
- **Day 6:** no „Morgen" promise. The line is „Noch ein Tag, dann schau ich nach deinen ersten Mustern.", or with the Bauchgefühl entries still missing. The preview is the Muster page's blurred sample, extracted as `PatternsPreview`.
- **Tausch-Tipp:**
  - no Alternativen link (§5.7's „App" names only the recipe; the card's existing „→ Alternative: …" line names it);
  - the link shows only on a `substitute` item whose `recipe_id` is in the loaded collection (hidden since → gone; loading or failed → no link);
  - the title is `recipe_title`, else the collection's.
- **Letter:** a set is new-layout when any item has `focus: true`. The summary then shows under „Dein Wochenbrief" in regular weight, and only the first focus item gets „Fokus der Woche".
- **The offer waits for the journey decision:** `weeklyTipsOfferDueProvider` is false while `journeyProvider` is null. Journey users follow day 3; others keep the app-structure Stage-3 rule (after unlock, #86) and its old sheet.
- **Compact Buddy sheet:** below 700 dp of screen height, `BuddyAskSheet`'s Buddy is 140 dp instead of 220 dp, for every Buddy sheet.
- **Vectors:**
  - skipped (with a reason) unless the local offsets are Vienna's (+1 h in January, +2 h in July), like `wall_clock_test`;
  - CI's unit job already runs `test/services/` under `TZ=Europe/Vienna`, so no workflow change;
  - the rules table is checked in any zone;
  - no hash pin in the app (see the note for core).

## Note for core's CI (vectors diff)

The app's copy is `test/fixtures/insights/vectors.json` in `severinkl/bellybuddyapp`. It is byte-identical to core's `backend/tests/fixtures/insights/vectors.json`: copied with `cp`, never reformatted.

A core CI step can compare the two:
1. Read the app's copy on `develop` with a read-only token: `gh api repos/severinkl/bellybuddyapp/contents/test/fixtures/insights/vectors.json?ref=develop --jq .content | base64 -d`.
2. Fail when its `sha256sum` differs from core's file.

The app side pins nothing. A change of the rules or the vectors lands in both repos together (core first), as the file's `_comment` says.

---

## File Structure

| File | Responsibility |
|---|---|
| `test/fixtures/insights/vectors.json` (copy), `test/services/insights/insight_vectors_test.dart` (create) | shared vectors against `computeInsights` |
| `lib/models/recommendation_item.dart`, `lib/models/recommendation.dart` (modify) | `focus`, `recipeId`, `recipeTitle`; `isLetter`, `itemsFocusFirst` |
| `lib/widgets/common/bb_card.dart` (modify) | `borderColor` |
| `lib/screens/recommendations/widgets/recommendation_card.dart`, `recommendation_summary_card.dart`, `recommendations_screen.dart` (modify); `tip_recipe_link.dart` (create) | letter, focus label, recipe link |
| `lib/models/journey_rewards.dart` (create) | `JourneyRewards`, `RecipePick`, `TipOffer`, `FirstTipState` |
| `lib/services/journey/journey_rules.dart`, `journey_copy.dart` (create) | pure rules, the line, titles, copy, sayings |
| `lib/providers/journey_rewards_provider.dart` (create) | persisted state + derived providers |
| `lib/models/first_tip.dart`, `lib/providers/first_tip_provider.dart` (create); `lib/services/recommendation_service.dart`, `lib/repositories/recommendation_repository.dart`, `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart` (modify) | the first-tip request |
| `lib/widgets/buddy/buddy_ask_sheet.dart` (modify) | compact Buddy |
| `lib/screens/dashboard/widgets/first_tip_offer_sheet.dart`, `journey_reward_sheet.dart`, `journey_rewards_sheet.dart`, `journey_reward_actions.dart` (create) | the reward surfaces and their actions |
| `lib/screens/patterns/widgets/patterns_preview.dart` (create), `patterns_locked.dart` (modify) | the blurred sample, shared |
| `lib/screens/patterns/patterns_unlocked_screen.dart` (create); `lib/router/route_names.dart`, `app_router.dart`, `lib/screens/screens.dart` (modify) | the day-7 celebration |
| `lib/providers/buddy_provider.dart`, `buddy_offers_provider.dart`, `lib/screens/dashboard/widgets/buddy_hero.dart` (modify) | kinds, when they're due, how they play |
| `lib/screens/dashboard/widgets/journey_reward_line.dart` (create), `insight_card.dart`, `lib/screens/dashboard/dashboard_screen.dart` (modify) | the card's reward line |
| `lib/config/constants.dart` (modify) | keys, sizes, durations |
| `test/helpers/fakes.dart`, `fixtures.dart`, `riverpod_helpers.dart`, `integration_test/helpers/test_app.dart` (modify) | fakes, seeds |

`AppConstants` additions (each added in the task that first needs it):
- `keyJourneyRewardsPrefix = 'journey_rewards_'`
- `firstTipMealsWindow = Duration(days: 3)`
- `firstTipTimeout = Duration(seconds: 60)`
- `buddyAskSheetCompactBelow = 700.0`
- `buddyAskSheetCompactHeight = 140.0`
- `tipRecipeThumbSize = 40.0`

No new colours: the focus uses `AppTheme.primary`/`primarySoft`.

---

### Task 1: Core's shared insights vectors in the Dart tests

**Files:**
- Create: `test/fixtures/insights/vectors.json` (copy), `test/services/insights/insight_vectors_test.dart`

**Interfaces:**
- Consumes: `computeInsights(InsightSource, DateTime)`, `InsightRules`, `InsightSource(meals:, gutFeelings:, activityTimes:)`, `InsightMeal`, `GutFeelingEntry`, `wallClockFromWire`.
- Produces: nothing for later tasks.

**Mapping** (from the template runner, unchanged):
- `meals[].tracked_at`, `gut_feelings[].tracked_at` and `activity[]` → `wallClockFromWire`.
- `activity` → `InsightSource.activityTimes`.
- `now` → `DateTime.parse`.
- Omitted mood fields → null.
- The result goes through `toJson(Insights)` and is compared as `jsonDecode(jsonEncode(toJson(got)))` against `expected` (deep equality), `reason: description`.

- [ ] **Step 1:** `cp /Users/sevi/projects/bellybuddy-core-tips-wt/backend/tests/fixtures/insights/vectors.json test/fixtures/insights/vectors.json`, then `shasum -a 256` both files. Expected: equal hashes. Note the hash for the commit message; if core's file changed since the plan, take the current one.
- [ ] **Step 2: Write the tests** (read the file with `File('test/fixtures/insights/vectors.json')`):
  - **`the file holds core's format`** (any zone): `timezone == 'Europe/Vienna'`, `vectors.length >= 28`, ids unique.
  - **`the rules table matches InsightRules`** (any zone): every key of `rules` against its `InsightRules` constant, the shares as `[numerator, denominator]`, `meals_before_hours == InsightRules.mealsBefore.inHours`.
  - **One `test(v['id'])` per vector** with `skip: _vienna ? false : 'only under TZ=Europe/Vienna'`, where `_vienna = DateTime(2026, 1, 15).timeZoneOffset == const Duration(hours: 1) && DateTime(2026, 7, 15).timeZoneOffset == const Duration(hours: 2)`.
- [ ] **Step 3:** Run `TZ=Europe/Vienna flutter test test/services/insights/insight_vectors_test.dart`. Expected: PASS, nothing skipped. A failing vector is a real divergence between the engines: stop and report it. Never edit `vectors.json` in the app.
- [ ] **Step 4:** Run `TZ=UTC flutter test test/services/insights/insight_vectors_test.dart`. Expected: the 2 format tests pass and the vectors are skipped with the reason.
- [ ] **Step 5: Commit** `test(insights): core's shared vectors run against the Dart engine` (body: the source path and the sha256).

---

### Task 2: Tip sets with a letter, a focus and a recipe link

**Files:**
- Modify:
  - `lib/models/recommendation_item.dart`, `lib/models/recommendation.dart`
  - `lib/widgets/common/bb_card.dart`
  - `lib/screens/recommendations/recommendations_screen.dart`
  - `lib/screens/recommendations/widgets/recommendation_card.dart`, `recommendation_summary_card.dart`
  - `lib/config/constants.dart`
  - `test/helpers/fixtures.dart`
- Create: `lib/screens/recommendations/widgets/tip_recipe_link.dart`
- Test:
  - `test/models/recommendation_item_test.dart`, `test/models/recommendation_test.dart`
  - `test/screens/recommendations/recommendations_screen_test.dart`
  - `test/screens/recommendations/widgets/tip_recipe_link_test.dart` (create)

**Interfaces:**
- Consumes: `recipeCollectionProvider` (its `settledValue`), `RecipeImage`, `context.openRecipe(id)` (Stage 2).
- Produces:
  ```dart
  class RecommendationItem {
    const RecommendationItem({required this.type, required this.ingredient, required this.reason,
      this.alternative, this.focus = false, this.recipeId, this.recipeTitle});
    final bool focus;            // json['focus'] == true (anything else, missing included: false)
    final String? recipeId;      // `recipe_id`, trimmed; blank → null
    final String? recipeTitle;   // `recipe_title`, trimmed; blank → null
    bool get hasRecipeLink => isSubstitute && recipeId != null;
    // toJson adds `focus: true`, `recipe_id`, `recipe_title` only when set (old shape otherwise)
  }
  extension RecommendationLetter on Recommendation {
    bool get isLetter;                               // any item has focus
    List<RecommendationItem> get itemsFocusFirst;    // the first focus item, then the others in stored order
  }
  class TipRecipeLink extends ConsumerWidget {
    const TipRecipeLink({super.key, required this.recipeId, this.title});
    static Key keyFor(String recipeId);              // ValueKey('tip_recipe_link_$recipeId')
  }
  ```
  - `BbCard` gains `Color? borderColor` (default `AppTheme.border`).
  - `RecommendationCard` gains `bool focus = false` and `static const focusLabelKey`.
  - `testRecommendationItem({String type = 'substitute', String ingredient = 'Zwiebel', String reason = 'Grund', String? alternative = 'Schnittlauch', bool focus = false, String? recipeId, String? recipeTitle})` goes into `fixtures.dart`.

**Rules:**
- **Letter layout** (`isLetter`):
  - the summary card shows a label „Dein Wochenbrief" (`StepFieldLabel.style`) above the summary, in regular weight (`fontSizeBodyLG`, `lineHeightBody`);
  - the items come in `itemsFocusFirst` order;
  - the first item gets `focus: true`: a pill „Fokus der Woche" (`Icons.star_rounded`, `AppTheme.primarySoft` fill) above its header row, and a border in `AppTheme.primary` (`borderWidthLg`).
- **Old layout:** everything as today (bold summary, no label, stored order, no pill).
- **Recipe link:** under the reason and the alternative of an item with `hasRecipeLink`.
  - `TipRecipeLink` reads `recipeCollectionProvider.settledValue`. It renders nothing unless the list holds `recipeId`.
  - Otherwise one row: a `tipRecipeThumbSize` square `RecipeImage` (radius `radiusSm`), „Passendes Rezept: " plus the title in w600, then `Icons.chevron_right`. The title is `title`, else the collection recipe's.
  - Semantics: one button labelled „Passendes Rezept: <title>". A tap calls `context.openRecipe(recipeId)`.
- While editing `recommendation_card.dart`, replace its numeric literals with the tokens of the same value (`spacing12`, `spacingMd`, `iconSizeSm`, `iconSizeClose`, `spacingSm`, `spacing10`, `spacingXs`, `spacing6`).

- [ ] **Step 1: Failing tests.**
  - **Model:**
    - `new fields read`: `{'type': 'substitute', 'ingredient': 'Zwiebel', 'reason': 'r', 'alternative': 'Frühlingszwiebelgrün', 'focus': true, 'recipe_id': 'r-1', 'recipe_title': 'Hirse-Bowl'}` → `focus`, `recipeId == 'r-1'`, `recipeTitle == 'Hirse-Bowl'`, `hasRecipeLink`.
    - `an old item`: the four old keys only → `focus` false, `recipeId` null, `hasRecipeLink` false.
    - `focus "true" (a string) is false`; `blank recipe_id is null`; `a try item with recipe_id has no link`.
    - `toJson`: an old item gives exactly the old keys; a new one round-trips.
  - **`Recommendation`:**
    - `isLetter` true with one focus item, false without;
    - `itemsFocusFirst` of `[try A, substitute B (focus)]` → `[B, A]`; of an old set → stored order.
  - **Screen** (`recommendations_screen_test`, fake collection holding `testRecipe(id: 'r-1', title: 'Hirse-Bowl')`, the router with stub `/collection/:id`):
    - `a new set: the letter, then the focus item first`: a set `[try Haferflocken, substitute Zwiebel (focus, recipe r-1)]`.
      - „Dein Wochenbrief" and the summary are shown;
      - the first card is Zwiebel with „Fokus der Woche";
      - „Fokus der Woche" `findsOneWidget`;
      - Haferflocken follows.
    - `an old set renders as today`:
      - no „Dein Wochenbrief", no „Fokus der Woche", no link;
      - items in stored order;
      - the summary text in `FontWeight.w600`.
    - `the recipe link opens the recipe`: „Passendes Rezept: " + „Hirse-Bowl" → tap → location `/collection/r-1`.
    - `a recipe no longer in the collection: no link` (collection without r-1); `the collection loading or failed: no link`.
    - `recipe_title missing: the collection's title`.
    - `fits 375×667 at 1.3`: a letter, 3 items, one link; no vertical overflow (`collectFlutterErrors` + `verticalOverflows`).
  - **`TipRecipeLink` semantics:** one button node with label „Passendes Rezept: Hirse-Bowl".
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/models/recommendation_item_test.dart test/models/recommendation_test.dart test/screens/recommendations`. Expected: FAIL (undefined members).
- [ ] **Step 3: Implement** per the interfaces and rules (`AppConstants.tipRecipeThumbSize = 40.0`).
- [ ] **Step 4:** Run the same tests, then `flutter analyze`. Expected: PASS, 0 issues.
- [ ] **Step 5: Commit** `feat(tips): the weekly letter, „Fokus der Woche" first and the matching recipe on a Tausch-Tipp`

---

### Task 3: Journey rewards: the value, the rules and the copy

**Files:**
- Create:
  - `lib/models/journey_rewards.dart`
  - `lib/services/journey/journey_rules.dart`, `lib/services/journey/journey_copy.dart`
- Test: `test/models/journey_rewards_test.dart`, `test/services/journey/journey_rules_test.dart`

**Interfaces:**
- Consumes: `Insights` (`progress`, `unlocked`, `journey`, `calmDayIngredients`), `InsightRules.daysNeeded`, `RankedRecipes` (`fits`, `checked`), `RecipeFit` (`recipe`, `checked`, `passtZuMir`), `RecipeIngredient.matchKeys`, `pickForYou`, `isSameDay`, `joinGerman`.
- Produces:
  ```dart
  enum TipOffer { offered, accepted, declined, skipped }
  enum FirstTipState { requested, done, failed }

  class RecipePick {
    const RecipePick({required this.id, required this.title, this.matched = const []});
    final String id, title;
    final List<String> matched;              // day 5: matched line names, recipe order, ≤ 3
    Map<String, Object?> toJson();           // {"id", "title", "matched"}
    static RecipePick? fromJson(Object? json); // null on another shape
  }

  class JourneyRewards {
    const JourneyRewards({this.earnedDay = 0, this.patternsFreed = false,
      this.picks = const {}, this.tipOffer, this.firstTip});
    final int earnedDay;                     // 0–7, never lower
    final bool patternsFreed;                // insights were unlocked once
    final Map<int, RecipePick> picks;        // keys 1, 3, 5
    final TipOffer? tipOffer;                // null: day 3 not decided
    final FirstTipState? firstTip;
    JourneyRewards copyWith({int? earnedDay, bool? patternsFreed, Map<int, RecipePick>? picks,
      TipOffer? tipOffer, FirstTipState? firstTip});
    Map<String, Object?> toJson();
      // {"earned": 4, "freed": false, "picks": {"1": {...}}, "tipOffer": "offered", "firstTip": null}
    static JourneyRewards? fromJson(Object? json);
      // null unless a map with an int `earned`; a bad pick is skipped; an unknown enum name reads null
    // value equality (==, hashCode)
  }

  // journey_rules.dart
  JourneyRewards advanceRewards(JourneyRewards r, {required Insights insights, required bool? weeklyTips});
  JourneyRewards fillPicks(JourneyRewards r, {required RankedRecipes ranked, required Set<String> calmKeys});
  RecipePick? pickJourneyRecipe(List<RecipeFit> ranked,
      {Set<String> exclude = const {}, Set<String> goodKeys = const {}});
  int? announcementDay(JourneyRewards r);
  bool tipOfferDue(JourneyRewards r, {required bool? weeklyTips});
  bool rewardEarned(int day, JourneyRewards r);         // 1–6: day ≤ earnedDay; 7: patternsFreed
  String rewardTitle(int day, JourneyRewards r, {required bool? weeklyTips});
  String sayingFor(String userId);
  class JourneyRewardLine {
    const JourneyRewardLine(this.text, {required this.day, required this.earned});
    final String text; final int day; final bool earned;   // value equality
  }
  JourneyRewardLine rewardLine(JourneyRewards r,
      {required Insights insights, required DateTime now, required bool? weeklyTips});
  ```
- `JourneyCopy` (`abstract final class`, exact strings):
  ```dart
  // Titles (the line and the list)
  day1 = 'Dein erstes Rezept'; day2 = 'Ein Wissen-Häppchen';
  day3Tip = 'Dein erster Tipp'; day3Recipe = 'Ein Rezept für dich'; day4 = 'Ein Spruch von mir';
  day5 = 'Ein Rezept mit deinen Zutaten'; day5Generic = 'Noch ein Rezept für dich';
  day6 = 'Eine Vorschau auf deine Muster'; day7 = 'Deine ersten Muster';
  String today(String t) => 'Heute: $t'; String waiting(String t) => 'Heute wartet: $t';
  String soon(String t) => 'Bald: $t'; String dayLabel(int d) => 'Tag $d';
  rewardsTitle = 'Deine Belohnungen'; openRewards = 'Belohnungen ansehen';
  // The Buddy's lines in a day's sheet
  day1Line = 'Willkommen an Tag 1! Hier ist dein erstes Rezept für dich.';
  day2Line = 'Tag 2! Hier ist ein Wissen-Häppchen für dich.';
  day2Body = 'FODMAPs sind bestimmte Kohlenhydrate in Lebensmitteln. Was dahintersteckt, erklärt dieser Artikel kurz und knackig.';
  articleTitle = 'Low FODMAP kurz und knackig'; articleSource = 'myfodmap.at';
  articleUrl = 'https://www.myfodmap.at/low-fodmap-kurz-und-knackig';
  articleFailure = 'Der Artikel konnte nicht geöffnet werden.';
  day3Line = 'Tag 3! Hier ist ein Rezept für dich.';
  day3AfterNoLine = 'Alles klar! Dann hier ein Rezept für dich.';
  day5Line = 'Tag 5! Hier ist ein Rezept mit Zutaten, die du schon gegessen hast.';
  String day5Because(List<String> names) =>
      'Mit ${joinGerman(names)}: Die hast du an Tagen ohne schlechtes Bauchgefühl gegessen.';
  day5GenericLine = 'Tag 5! Hier ist noch ein Rezept, das zu dir passt.';
  String day6Line(int gutFeelingsLeft) => gutFeelingsLeft > 0
      ? 'Noch ein Tag und $gutFeelingsLeft× Bauchgefühl, dann schau ich nach deinen ersten Mustern.'
      : 'Noch ein Tag, dann schau ich nach deinen ersten Mustern.';
  day6Body = 'So sieht die Muster-Seite dann aus, hier mit ausgedachten Werten:';
  example = 'Beispiel';
  noRecipe = 'Rezepte, die zu dir passen, findest du unter Entdecken.';
  firstTipStarted = 'Ich mach dir jetzt deinen ersten Tipp. Das dauert einen Moment ✨';
  firstTipFailed = 'Dein erster Tipp hat gerade nicht geklappt. Die wöchentlichen Tipps bleiben eingeschaltet.';
  // Buttons
  openRecipe = 'Rezept ansehen'; toRecipes = 'Zu den Rezepten'; readArticle = 'Artikel lesen';
  thanks = 'Danke!'; okay = 'Okay'; later = 'Später'; toTips = 'Zu deinen Tipps'; toPatterns = 'Muster ansehen';
  // Day 4
  sayings = [
    'Jeder Eintrag hilft mir, dich besser kennenzulernen.',
    'Schön, dass du dranbleibst!',
    'Kleine Schritte zählen. Du machst gerade jeden Tag einen.',
    'Dein Bauch und ich, wir lernen uns gerade kennen.',
    'Du machst das super. Ich bin gern dabei.',
    'Vier Tage geschafft! Ich freu mich auf die nächsten mit dir.',
  ];
  ```

**Rules:**
- **`advanceRewards`:**
  - `earnedDay = max(r.earnedDay, min(insights.progress.activeDays, InsightRules.daysNeeded))`;
  - `patternsFreed = r.patternsFreed || insights.unlocked`;
  - when `r.tipOffer == null && earnedDay >= 3 && weeklyTips != null`: `tipOffer = weeklyTips ? skipped : offered`;
  - otherwise everything is kept. The result `==` `r` when nothing changed.
- **`fillPicks`:**
  - nothing unless `ranked.checked`;
  - for each day of `[1, 3, 5]` with `day <= r.earnedDay` and no pick, in that order;
  - day 3 once `tipOffer` is decided and not `accepted` (a withdrawn offer, still `offered`, gets its recipe too);
  - `exclude` = the ids picked so far (including this call's); `goodKeys` = `calmKeys` for day 5, else empty;
  - a null pick is left out; existing picks are never replaced.
- **`pickJourneyRecipe`:**
  - `order = pickForYou(ranked, count: ranked.length)` without `exclude`d ids;
  - `passing(f) = !f.checked || f.passtZuMir`;
  - with `goodKeys`: the first passing recipe with a line whose `matchKeys` intersects `goodKeys` → its matching line names (in recipe order, distinct without case, at most 3);
  - otherwise (or no match): the first of `order` with `matched` empty;
  - empty → null.
- **`announcementDay`:** `earnedDay` when it is 1–6, except 3 unless `tipOffer == skipped`; otherwise null.
- **`tipOfferDue`:** `r.earnedDay >= 3 && r.tipOffer == TipOffer.offered && weeklyTips == false`.
- **`rewardTitle`:**
  - **day 3:**
    - `accepted` → `day3Tip`;
    - `declined`/`skipped` → `day3Recipe`;
    - `offered`/null → `weeklyTips == true ? day3Recipe : day3Tip`;
  - **day 5:** `picks[5]?.matched.isEmpty == true ? day5Generic : day5`;
  - **others:** their constant.
- **`rewardLine`** (`n = r.earnedDay`, `filled = insights.journey.isNotEmpty && isSameDay(insights.journey.last.day, now)`):
  - `filled && 1 <= n <= 6` → `today(rewardTitle(n))`, day n, earned;
  - else `next = filled ? 7 : min(n + 1, 7)`:
    - `next == 7` → `(!filled && insights.progress.gutFeelingsLeft == 0) ? waiting(day7) : soon(day7)`, day 7, not earned;
    - else `waiting(rewardTitle(next))`, day `next`, not earned.
- **`sayingFor`:** `sayings[userId.codeUnits.fold(0, (a, b) => a + b) % sayings.length]`.

- [ ] **Step 1: Failing tests** (`lockedInsights(activeDays:, gutFeelings:, journey:)`, `testRecipe`/`testLine`, `RecipeFit`s from `rankRecipes(..., rules: testIntoleranceRules(), intolerances: ['Fruktose'], signals: const RankingSignals())`):
  - **`JourneyRewards`:**
    - JSON round-trip with all fields;
    - `fromJson('nope')`, `fromJson({'earned': 'x'})` → null;
    - `{'earned': 2, 'tipOffer': 'later'}` → `tipOffer` null;
    - a pick `{'id': 1}` is skipped.
  - **`advanceRewards`:**
    - `earned follows the active days, capped at 7` (2 → 2, 9 → 7);
    - `never decreases` (stored 4, insights 2 → 4);
    - `patterns freed once unlocked, kept after` (unlocked → true; locked again → still true);
    - `day 3 waits for the weekly tips` (null → `tipOffer` null; false → offered);
    - `weekly on at day 3 → skipped`;
    - `decided once` (offered + weekly true → offered);
    - `nothing new → equal`.
  - **Picks:**
    - `day 1 = the first Für-dich recipe` (A passing, B kritisch → A);
    - `day 3 skips day 1's pick`;
    - `day 3 not picked while undecided or accepted`; `day 3 picked for offered, declined and skipped`;
    - `day 5 = the best passing recipe with a calm-day ingredient`: calm `{'reis', 'karotte'}`; X passing without a match, Y passing with lines Karotte, Reis, Zwiebel → Y, `matched == ['Karotte', 'Reis']`;
    - `day 5 without a match: the next recipe, matched empty, title Noch ein Rezept für dich`;
    - `unchecked ranking: no pick`; `empty collection: no pick`;
    - `stored picks stay when the ranking changes`.
  - **`announcementDay`:**
    - 0 and 7 → null; 1, 2, 4, 5, 6 → themselves;
    - 3 with null/offered/accepted/declined → null; 3 with skipped → 3.
  - **`tipOfferDue`:**
    - (3, offered, false) → true;
    - weekly null or true → false; declined → false; earned 2 → false.
  - **`rewardLine`** (now 14:00 unless said):
    - `no entry yet` → „Heute wartet: Dein erstes Rezept";
    - `day 2 filled today` → „Heute: Ein Wissen-Häppchen", earned;
    - `day 2 yesterday, none today` → „Heute wartet: Dein erster Tipp" (weekly false), and „Heute wartet: Ein Rezept für dich" with weekly true;
    - `a late-evening entry on the DST Sunday is today`: now `DateTime(2026, 10, 25, 23, 45)`, journey last day `DateTime(2026, 10, 25)`, earned 2 → „Heute: Ein Wissen-Häppchen";
    - `day 6 filled` → „Heute: Eine Vorschau auf deine Muster";
    - `day 6 yesterday, Bauchgefühl complete` → „Heute wartet: Deine ersten Muster";
    - `… one Bauchgefühl missing` → „Bald: Deine ersten Muster";
    - `day 7 locked` → „Bald: Deine ersten Muster".
  - **`sayingFor`:** the same id twice → equal; `'u1'` and `'u2'` → different; always one of `sayings`.
  - **`rewardEarned`:** day 7 only with `patternsFreed`.
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/models/journey_rewards_test.dart test/services/journey`. Expected: FAIL.
- [ ] **Step 3: Implement** per the interfaces and rules.
- [ ] **Step 4:** Run again, plus `flutter test test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(journey): the rewards of the first 7 days as rules (earned day, picks, the line)`

---

### Task 4: The rewards per user and device

**Files:**
- Create: `lib/providers/journey_rewards_provider.dart`
- Modify:
  - `lib/config/constants.dart` (`keyJourneyRewardsPrefix`)
  - `test/helpers/riverpod_helpers.dart`
- Test: `test/providers/journey_rewards_provider_test.dart`

**Interfaces:**
- Consumes: Task 3; `currentUserIdProvider`, `journeyProvider`, `insightsProvider` (`settledValue`), `weeklyTipsEnabledProvider`, `rankedRecipesProvider`, `buddyClockProvider`.
- Produces:
  ```dart
  class JourneyRewardsNotifier extends Notifier<JourneyRewards?> {
    // null while signed out, while journeyProvider != true, and until the stored value is read
    Future<void> answerTipOffer({required bool accepted}); // offered → accepted / declined; else unchanged
    Future<void> setFirstTip(FirstTipState state);
  }
  final journeyRewardsProvider = NotifierProvider<JourneyRewardsNotifier, JourneyRewards?>(JourneyRewardsNotifier.new);
  final journeyRewardLineProvider = Provider<JourneyRewardLine?>;  // null unless rewards and settled, locked insights
  final journeyRewardAnnouncementProvider = Provider<int?>;        // announcementDay(rewards)
  final patternsUnlockedDueProvider = Provider<bool>;              // rewards?.patternsFreed ?? false
  final firstTipFailedProvider = Provider<bool>;                   // rewards?.firstTip == FirstTipState.failed
  Override journeyRewardsSeededWith(JourneyRewards? rewards);      // riverpod_helpers.dart
  ```

**Behaviour:**
- **`build`:**
  - watches the user id and `journeyProvider`; returns null unless signed in and the journey is `true`;
  - reads `${keyJourneyRewardsPrefix}$userId` (a JSON string) asynchronously, like `JourneyNotifier` (prefs that can't be read, or unreadable JSON, start from `const JourneyRewards()` and are logged);
  - then applies `fillPicks(advanceRewards(…))` and sets the state.
- **Listens** (no rebuild): `insightsProvider` (settled values only), `weeklyTipsEnabledProvider` and `rankedRecipesProvider` (`AsyncData` only). Each recomputes `fillPicks(advanceRewards(current, insights, weeklyTips), ranked, insights.calmDayIngredients)`.
- **One path for every change:** the listeners, `answerTipOffer` and `setFirstTip` all go through one `_apply(JourneyRewards Function(JourneyRewards) change)`, which then runs `fillPicks` with the latest `rankedRecipesProvider` data and the settled insights' `calmDayIngredients` (so „Nein" picks day 3's recipe before its sheet opens).
- **Stored only when changed:** writes run one after another (a `Future` chain) so an older write never lands last. A failed write is logged, and the in-memory value still applies.
- **User changes:** every await is followed by `ref.isCurrentUser(userId)`; another user's result lands nowhere.
- **Line:** `journeyRewardLineProvider` passes `buddyClockProvider()` as `now`.

- [ ] **Step 1: Failing tests** (`SharedPreferences.setMockInitialValues`, `FakeEntryRepository..insightSource = insightSourceFor(...)`, `FakeRecipeRepository` with two fitting recipes, `profileProviderSeededWith(testUserProfile(intolerances: ['Fruktose']))`, the clock pinned, `SwitchableUserId`):
  - `journey false (a user past day 7) or undecided: null`.
  - `a journey user: earned day 2 from 2 active days, stored as JSON under journey_rewards_<userId>`.
  - `restart keeps the earned day and the picks`: container 1 earns day 3 with picks; container 2 over the same prefs with `insightSourceFor(activeDays: 1, …)` → `earnedDay == 3`, picks equal (fewer active days never lower it).
  - `picks once the ranking is checked`: rules failing → no picks; rules back + refresh → the day-1 pick stored.
  - `day 3: weekly off → offered; on → skipped`.
  - `answerTipOffer`: offered → accepted / declined, stored; skipped stays skipped.
  - `setFirstTip(failed)` stored, and `firstTipFailedProvider` true.
  - `unreadable stored JSON starts afresh`.
  - `another user reads their own key`.
  - **Derived:**
    - `journeyRewardLineProvider` null while unlocked, „Heute: Ein Wissen-Häppchen" for day 2 filled today;
    - `journeyRewardAnnouncementProvider` 2;
    - `patternsUnlockedDueProvider` true after unlock.
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/providers/journey_rewards_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** per the interfaces and behaviour; add `journeyRewardsSeededWith` (a notifier whose `build` returns the value and whose methods update it in memory).
- [ ] **Step 4:** Run again, then `TZ=Europe/Vienna flutter test test/providers`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(journey): the rewards kept per user and device, never lower`

---

### Task 5: The first tip, once, after yes

**Files:**
- Create: `lib/models/first_tip.dart`, `lib/providers/first_tip_provider.dart`
- Modify:
  - `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart`
  - `lib/services/recommendation_service.dart`, `lib/repositories/recommendation_repository.dart`
  - `lib/config/constants.dart` (`firstTipMealsWindow`, `firstTipTimeout`)
  - `test/helpers/fakes.dart`
- Test:
  - `test/services/recommendation_service_test.dart`, `test/services/entry_query_service_test.dart`
  - `test/providers/first_tip_provider_test.dart` (create)

**Interfaces:**
- Consumes: `journeyRewardsProvider` (Task 4), `profileProvider` (`setWeeklyTips`, `value.intolerances/diet`), `recommendationProvider.notifier.fetchRecommendations()`, `RecommendationRepository.markSeen`, `buddyClockProvider`, `wallClockToWire`.
- Produces:
  ```dart
  class FirstTipResult { const FirstTipResult({this.id, required this.tips});
    final String? id; final int tips; bool get ok => id != null && tips > 0; }
  class FirstTipException implements Exception { const FirstTipException([this.status]); final int? status; }

  // EntryQueryService / EntryRepository: `since` added (null: as today)
  Future<List<MealEntry>> fetchRecentMeals({required String userId, int? limit, DateTime? since});
      // since → .gte('tracked_at', wallClockToWire(since))

  // RecommendationService (RecommendationRepository delegates, no retry)
  static const firstTipFunction = 'diet-recommendations';
  Future<FirstTipResult> requestFirstTip({required List<String> intolerances, required String? diet,
      required List<MealEntry> meals});
      // body exactly {'intolerances': [...], 'diet': diet, 'recentMeals': [{'title', 'ingredients',
      //   'tracked_at': wallClockToWire(m.trackedAt)}]};
      // FunctionException → FirstTipException(e.status); anything else (transport, not a map) →
      // FirstTipException(); result: id = data['id'] as String?, tips = (data['recommendations'] as List?)?.length ?? 0

  class FirstTipNotifier extends Notifier<bool> {   // true while a request runs
    Future<bool> accept();
  }
  final firstTipProvider = NotifierProvider<FirstTipNotifier, bool>(FirstTipNotifier.new);
  ```
- Fakes (`fakes.dart`):
  - `FakeRecommendationRepository`:
    - `Recommendation? firstTipSet` (on a request: inserted first into `sets`, then returned as `FirstTipResult(id: set.id, tips: set.recommendations.length)`);
    - `Object? firstTipError`, `Completer<void>? firstTipGate`;
    - `firstTipRequests` (records intolerances, diet, meals).
  - `FakeEntryRepository.fetchRecentMeals` filters its `recentMeals` by `since` and records `recentMealsSince`.
  - `FakeFirstTipNotifier extends FirstTipNotifier`: records `accepts`, returns `acceptResult` (default true).

**`accept()`:**
1. Read the user id, `journeyRewardsProvider` and the profile. Any of them missing → log, return false.
2. `rewards.firstTip != null` → return true: never a second request on this device.
3. `await profileNotifier.setWeeklyTips(true)`. It throws → log, return false, change nothing.
4. `answerTipOffer(accepted: true)`, then `setFirstTip(requested)`. Both are stored before the call.
5. Set the state true and start `_request` unawaited; return true.

**`_request`** (one attempt, never retried):
- the meals since `buddyClock() − firstTipMealsWindow`, then `requestFirstTip(…).timeout(AppConstants.firstTipTimeout)` (the timeout lives here, so the fake exercises it);
- after each await, `ref.isCurrentUser(userId)`, else drop it (logged);
- `ok` → `setFirstTip(done)`, then `fetchRecommendations()` unawaited;
- not `ok` → `setFirstTip(failed)`; with an `id` → `markSeen(userId, [id])` (a failure only logged);
- any exception → `setFirstTip(failed)`;
- finally the state is false. Logs carry the status only, never meals.

- [ ] **Step 1: Failing tests.**
  - **Service** (Supabase function mock as in `recipe_service_test`'s adapt tests):
    - `the body is exactly intolerances, diet and recentMeals`: a meal at `DateTime(2026, 11, 23, 23, 30)` → `'tracked_at': '2026-11-23T23:30:00.000Z'`; no other keys;
    - `answer with id and 2 items → ok`; `200 fallback without items → tips 0, not ok`; `no id → not ok`;
    - `429 → FirstTipException(429)`; `500 → FirstTipException(500)`; `a non-map answer → FirstTipException(null)`.
  - **Query:** `fetchRecentMeals since filters tracked_at ≥ the wall clock`: verify `gte('tracked_at', wallClockToWire(since))`; without `since` → no `gte`.
  - **Notifier** (journey rewards seeded with `tipOffer: offered`, profile seeded with weekly off, clock pinned):
    - `opt-in first, then one request with the profile and the last 3 days' meals`:
      - `weeklyTipsWrites == [true]` before the request;
      - `recentMealsSince == now − 3 days`;
      - a meal of 4 days ago not sent;
      - `tipOffer == accepted`; `firstTip` requested, then done;
      - the recommendations refetched.
    - `opt-in fails: false, no request, firstTip unchanged` (`weeklyTipsError` set).
    - `accept twice: one request` (second call while gated and after done).
    - `after a restart with a request stored: none` (seed `firstTip: requested` → true, 0 requests).
    - `500` / `429` / `transport` / `timeout` (gate never completes, `fakeAsync` past 60 s):
      - `failed`;
      - `profile.weeklyTipsEnabled` stays true;
      - exactly one request.
    - `200 without tips: failed, the set stamped seen` (`marked == [[id]]`).
    - `the user changed meanwhile: nothing stored for the new user`.
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/services/recommendation_service_test.dart test/services/entry_query_service_test.dart test/providers/first_tip_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** per the interfaces and the steps above.
- [ ] **Step 4:** Run again, then the whole `test/providers test/services test/repositories`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(tips): the first tip on day 3, requested once after yes and the opt-in`

---

### Task 6: The reward sheets and their actions

**Files:**
- Modify:
  - `lib/widgets/buddy/buddy_ask_sheet.dart`
  - `lib/screens/patterns/widgets/patterns_locked.dart`
  - `lib/config/constants.dart`
- Create:
  - `lib/screens/patterns/widgets/patterns_preview.dart`
  - `lib/screens/dashboard/widgets/first_tip_offer_sheet.dart`, `journey_reward_sheet.dart`, `journey_rewards_sheet.dart`, `journey_reward_actions.dart`
- Test:
  - `test/widgets/buddy/buddy_ask_sheet_test.dart`, `test/screens/patterns/patterns_screen_test.dart`
  - `test/screens/dashboard/widgets/first_tip_offer_sheet_test.dart`, `journey_reward_sheet_test.dart`, `journey_rewards_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 3–4; `RecipeListTile`, `recipeFitProvider(id)`, `context.openRecipe`, `RoutePaths.discoverRecipes`, `RoutePaths.recommendations`, `RoutePaths.patterns`, `openExternalUrl`, `UrlOpener`, `insightsProvider`, `currentUserIdProvider`, `WeeklyTipsSwitch.sentence`, `showBuddySheet`.
- Produces:
  ```dart
  // buddy_ask_sheet.dart: the Buddy is AppConstants.buddyAskSheetCompactHeight tall when
  // MediaQuery.sizeOf(context).height < AppConstants.buddyAskSheetCompactBelow, else streakSheetBuddyHeight.

  class PatternsPreview extends StatelessWidget { const PatternsPreview({super.key}); } // the blurred sample, its semantics

  enum FirstTipAnswer { yes, no }
  Future<FirstTipAnswer?> showFirstTipOfferSheet(BuildContext context); // null: dismissed
  class FirstTipOfferSheet extends StatelessWidget {
    static const yesKey = Key('first_tip_yes'), noKey = Key('first_tip_no');
    static const line = 'Ich hab genug für deinen ersten Tipp! Soll ich ihn dir machen? ✨';
    static const body = 'Dann schalte ich die wöchentlichen Tipps ein: jeden Montag 2–3 Tipps. '
        '${WeeklyTipsSwitch.sentence} Ausschalten kannst du sie jederzeit unter Entdecken '
        'oder in den Einstellungen.';
    static const yes = 'Ja, gern', no = 'Nein, danke';
  }

  Future<bool> showJourneyRewardSheet(BuildContext context, {required int day, bool afterNo = false});
      // true: the primary button; false: „Später" or dismissed
  class JourneyRewardSheet extends ConsumerWidget {
    const JourneyRewardSheet({super.key, required this.day, this.afterNo = false});
    static const primaryKey = Key('journey_reward_primary'), laterKey = Key('journey_reward_later');
  }

  Future<void> showJourneyRewardsSheet(BuildContext context, {UrlOpener openUrl = launchUrl});
  class JourneyRewardsSheet extends ConsumerWidget {
    const JourneyRewardsSheet({super.key, this.openUrl = launchUrl});
    static Key rowKey(int day) => ValueKey('journey_reward_row_$day');
  }

  Future<void> openJourneyReward(BuildContext context, WidgetRef ref, int day, {UrlOpener openUrl = launchUrl});
  ```

**A day's sheet** (`BuddyAskSheet`: line in the bubble, content, primary `BbButton`, then a muted `TextButton` „Später"):

| day | Buddy line | content | primary |
|---|---|---|---|
| 1 | `day1Line` (no pick: `noRecipe`) | `RecipeListTile` of the pick (`recipeFitProvider(pick.id)`); none without a pick | `openRecipe` (no pick: `toRecipes`) |
| 2 | `day2Line` | `day2Body`, then `articleTitle` (w600) · `articleSource` | `readArticle` |
| 3 | `afterNo ? day3AfterNoLine : day3Line` | like day 1 | like day 1 |
| 4 | `sayingFor(userId)` | — | `thanks` only, no „Später" (pops false: nothing to open) |
| 5 | matched: `day5Line`; generic: `day5GenericLine`; no pick: `noRecipe` | the tile, and with `matched` the caption `day5Because(matched)` | like day 1 |
| 6 | `day6Line(insights.progress.gutFeelingsLeft)` | `day6Body`, a „Beispiel" label, `PatternsPreview` | `okay` only, no „Später" (pops false) |

A pick whose recipe is no longer in the collection shows `RecipeListTile` only if `recipeFitProvider` finds it; otherwise the card names `pick.title` and the button stays `openRecipe` (the detail then says „Rezept nicht gefunden").

**„Deine Belohnungen"** (`showBuddySheet`; a drag handle, the title `rewardsTitle`, then rows for days 1–7):
- An earned row (`rewardEarned`) shows a leading `dayLabel(day)` circle, `rewardTitle`, a detail line and a chevron when it has an action. A tap pops the sheet, then calls `openJourneyReward`.
- Detail lines:
  - 1/3/5: the pick's title, or `noRecipe`;
  - 2: `articleTitle · articleSource`;
  - 3 (accepted): `toTips`;
  - 4: the saying (no chevron, no tap);
  - 6: `example`;
  - 7: `toPatterns`.
- A row not earned yet: muted, `Icons.lock_outline`, no tap. Semantics: „Tag n: <title>, kommt noch".

**`openJourneyReward`:**
- 1, 5: pick → `openRecipe(pick.id)`, else `go(discoverRecipes)`;
- 2: `openExternalUrl(articleUrl, mode: LaunchMode.inAppBrowserView, failureMessage: articleFailure, open: openUrl)`;
- 3: `accepted` → `push(recommendations)`, else like 1;
- 4: nothing;
- 6, 7: `push(patterns)`.
- Navigations are not awaited.

- [ ] **Step 1: Failing tests.**
  - **`BuddyAskSheet`:**
    - `a short screen gets the compact Buddy` (375×667) → `BuddyStage` height `buddyAskSheetCompactHeight`;
    - `390×844 keeps streakSheetBuddyHeight` (update the existing height expectations to run at a tall size).
  - **`PatternsLocked`** still shows the sample through `PatternsPreview` (the existing patterns tests stay green).
  - **`FirstTipOfferSheet`:**
    - `shows the line, the KI-Dienst sentence and both buttons`;
    - `yes / no / dismissed → yes / no / null`;
    - `both buttons on screen at 375×667, text scale 1.3`: no vertical overflow, `getRect(yesKey).bottom` and `getRect(noKey).bottom` ≤ 667, without scrolling.
  - **`JourneyRewardSheet`** (rewards seeded, `FakeRecipeRepository`, profile seeded, user `'u1'`):
    - `day 1 with a pick: line, the recipe tile, „Rezept ansehen" → true`;
    - `day 1 without a pick: noRecipe and „Zu den Rezepten"`;
    - `day 2: the article title and source`;
    - `day 3 after no: day3AfterNoLine`;
    - `day 4: the user's saying, „Danke!" → false`;
    - `day 5 matched: „Mit Karotte und Reis: Die hast du an Tagen ohne schlechtes Bauchgefühl gegessen."`;
    - `day 5 generic: day5GenericLine, no caption`;
    - `day 6 with one Bauchgefühl missing: „Noch ein Tag und 1× Bauchgefühl, …", „Beispiel", the preview`;
    - `each day's buttons on screen at 375×667 @1.3` (a loop over days 1–6; no vertical overflow, every button's bottom ≤ 667 without scrolling).
  - **„Deine Belohnungen"** (router with stub routes for `/collection/:id`, `/recommendations`, `/patterns`, `/discover/recipes`):
    - `the list shows every earned day`: earned 4 with picks 1 and 3, `tipOffer: declined` → rows 1–4 earned (3 shows its recipe), 5–7 locked;
    - `row 1 opens the recipe`; `row 2 opens the article in the in-app browser` (`RecordingUrlOpener`, mode `inAppBrowserView`);
    - `row 3 accepted opens the Tipps`; `row 4 has no tap`; `row 6 opens Muster`;
    - `fits 375×667 @1.3` (scrollable, no overflow).
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/widgets/buddy/buddy_ask_sheet_test.dart test/screens/patterns test/screens/dashboard/widgets`. Expected: FAIL.
- [ ] **Step 3: Implement** per the interfaces, the table and the rules (constants `buddyAskSheetCompactBelow = 700.0`, `buddyAskSheetCompactHeight = 140.0`). Keep `weekly_tips_offer_sheet_test`'s Buddy-height expectation valid by pumping it at a tall size.
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(journey): a sheet per day's reward, „Deine Belohnungen" and the first-tip offer`

---

### Task 7: The day-7 celebration page

**Files:**
- Create: `lib/screens/patterns/patterns_unlocked_screen.dart`
- Modify: `lib/router/route_names.dart`, `lib/router/app_router.dart`, `lib/screens/screens.dart`
- Test: `test/screens/patterns/patterns_unlocked_screen_test.dart` (the real router's registration is exercised by Task 10's day-7 flow)

**Interfaces:**
- Consumes: `BbSuccessOverlay` (`message`, `subMessage`, `illustration`, `actions`, `onDismissed`), `BuddyStage`/`BuddyController`, `BbButton`, `RoutePaths.patterns`.
- Produces:
  ```dart
  // RouteNames.patternsUnlocked = 'patterns-unlocked'; RoutePaths.patternsUnlocked = '/patterns-unlocked' (top level, no bar)
  class PatternsUnlockedScreen extends StatefulWidget {
    static const openKey = Key('patterns_unlocked_open');
    static const title = 'Muster frei!';
    static const line = '7 Tage und 3× Bauchgefühl: Ich hab mir deine Einträge angeschaut. '
        'Deine Muster-Seite ist jetzt frei.';
  }
  ```

**Rules:**
- The page is a `BbSuccessOverlay`:
  - `message: title`, `subMessage: line`;
  - the Buddy as `illustration` (a `BuddyStage` in `BuddyMood.inLove`; it plays `BuddyAction.celebrate` once unless `MediaQuery.disableAnimationsOf(context)`);
  - `actions: [BbButton(tapKey: openKey, label: JourneyCopy.toPatterns)]`.
- The button calls `context.pushReplacement(RoutePaths.patterns)`. `onDismissed` (a tap elsewhere) pops.

- [ ] **Step 1: Failing tests:**
  - `shows the title, the line and „Muster ansehen"`;
  - `„Muster ansehen" replaces it with Muster`: the router stack `/dashboard` → push `/patterns-unlocked` → tap → location `/patterns`; back → `/dashboard`;
  - `a tap elsewhere goes back`;
  - `reduced motion: the Buddy doesn't celebrate` (`controller.currentAction` null);
  - `fits 375×667 @1.3` (`collectFlutterErrors`, no vertical overflow).
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/screens/patterns/patterns_unlocked_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(journey): „Muster frei!", the full-screen celebration of day 7`

---

### Task 8: The Buddy announces the rewards

**Files:**
- Modify:
  - `lib/providers/buddy_provider.dart`, `lib/providers/buddy_offers_provider.dart`
  - `lib/screens/dashboard/widgets/buddy_hero.dart`
- Test:
  - `test/providers/buddy_offers_provider_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart`, `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 4–7; `journeyProvider`, `firstTipProvider`, `WeeklyTipsSwitch.failure`, `showWeeklyTipsOfferSheet` (non-journey users).
- Produces:
  ```dart
  enum BuddyAnnouncement { saverUsed, streakBroken, saverEarned, goalReached, tipsArrived,
    weeklyTipsOffer, journeyReward, patternsUnlocked, firstTipFailed }

  // buddy_offers_provider.dart
  const journeyRewardSuffix = 'day';          // flag suffix 'day$n'
  const onceSuffix = 'once';                  // patternsUnlocked, firstTipFailed (weeklyTipsOfferSuffix stays 'once')
  final weeklyTipsOfferDueProvider = Provider<bool>;
    // journeyProvider: true → rewards != null && tipOfferDue(rewards, weeklyTips);
    //   false → settled insights unlocked && weeklyTips == false (app-structure Stage 3, as today); null → false
  final buddyOffersProvider = Provider<Map<BuddyAnnouncement, String>>;
    // in this order: tipsArrived: set.id; journeyReward: 'day$n' (journeyRewardAnnouncementProvider);
    // weeklyTipsOffer: 'once'; patternsUnlocked: 'once' (patternsUnlockedDueProvider && journey == true);
    // firstTipFailed: 'once' (firstTipFailedProvider)
  // offerStillAppliesProvider: journeyReward, patternsUnlocked, firstTipFailed → true
  ```

**Hero cues** (`_Cue` gains `journeyReward(endsInSheet: true)`, `patternsUnlocked(endsInSheet: true)`, `firstTipFailed`; `_cueFor` maps them):
- **`journeyReward`:**
  - `play(celebrate)`;
  - after `buddyActionDuration(celebrate)`: `_showJourneyReward()`;
  - it reads `journeyRewardAnnouncementProvider` (null → `_nextCue`);
  - `showJourneyRewardSheet(context, day: day)`; true → `openJourneyReward(context, ref, day)`; then `_nextCue()`.
  - It defers like the offer (`_deferredSheet` while hidden or while „Dein Streak" is open).
- **`weeklyTipsOffer`:**
  - wave, then `_offerWeeklyTips()`;
  - `journeyProvider` not true → as today (`WeeklyTipsOfferSheet`, „Zu den Tipps" → `go(discover)`);
  - for a journey user, `showFirstTipOfferSheet`:
    - **yes:** `firstTipProvider.notifier.accept()`. True → `_say(JourneyCopy.firstTipStarted)`, `_holdStage()` (the stage moves on after the line). False → a SnackBar `WeeklyTipsSwitch.failure`, then `_nextCue()`.
    - **no:** `answerTipOffer(accepted: false)`, then `showJourneyRewardSheet(context, day: 3, afterNo: true)` (true → `openJourneyReward(…, 3)`), then `_nextCue()`.
    - **dismissed:** `answerTipOffer(accepted: false)`, then `_nextCue()`.
- **`patternsUnlocked`:**
  - `play(celebrate)`;
  - after its duration: `context.push(RoutePaths.patternsUnlocked)` unawaited, then `_nextCue()` (later cues wait until Home is visible again);
  - deferred while hidden or while „Dein Streak" is open.
- **`firstTipFailed`:** `_say(JourneyCopy.firstTipFailed)`, `_holdStage()`.

- [ ] **Step 1: Failing tests.**
  - **Offers** (the `loaded` helper gains `recipeRepositoryProvider` → `FakeRecipeRepository()`, a seeded profile, and `journeyProvider` decided: `await pumpEventQueue()` after the loads; existing tests keep their expectations):
    - `journey undecided: no weekly-tips offer`;
    - `journey false (past day 7): today's rule` (unlocked + off → due; locked → not);
    - `journey true, day 3, weekly off → weeklyTipsOffer once`;
    - `the day-3 offer comes while the insights are still locked`;
    - `opted in before day 3: journeyReward day 3, no offer`;
    - `day 2 → journeyReward: 'day2'`;
    - `a newer day replaces a pending older one` (day 4 pending, insights move to 5 → the Buddy's pending key ends `_day5`, one entry);
    - `a flagged day is not offered again`: `buddy_announced_<u>_journeyReward_day2` set → `offerAnnouncement` queues nothing;
    - `unlocked journey user → patternsUnlocked 'once'; with the flag set → not queued`;
    - `firstTip failed → firstTipFailed 'once'`;
    - `offerStillApplies: the new kinds always apply`.
  - **Hero** (`pumpHero` overrides `journeyProvider` with a fixed value (default false), `journeyRewardsProvider` via `journeyRewardsSeededWith`, `firstTipProvider` with `FakeFirstTipNotifier`, `recipeRepositoryProvider` with `FakeRecipeRepository`; stub routes for `/collection/:id`, `/recommendations`, `/patterns`, `/patterns-unlocked`, `/discover/recipes`):
    - `journeyReward day 1 → celebrate, the sheet, „Rezept ansehen" opens the recipe; marked shown`;
    - `journeyReward while „Dein Streak" is open waits until it closed`;
    - `a cue cut short comes again`: dispose the hero while the sheet is open → the announcement is still pending (not marked);
    - `journey user, weeklyTipsOffer → the first-tip sheet`:
      - `yes → accept called once, the Buddy says firstTipStarted`;
      - `yes with a failing opt-in → the SnackBar, nothing said`;
      - `no → declined, the day-3 recipe sheet with day3AfterNoLine, no accept`;
      - `dismissed → declined, no second sheet, no accept`;
    - `journey false → the old sheet` (the existing weeklyTipsOffer tests, unchanged);
    - `patternsUnlocked → celebrate, then /patterns-unlocked`;
    - `patternsUnlocked waits while the hero is hidden`;
    - `firstTipFailed → the line, once`.
  - **Dashboard:** `a journey user on day 1 hears the reward` (the real offers path, `baseOverrides`).
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/providers/buddy_offers_provider_test.dart test/screens/dashboard`. Expected: FAIL.
- [ ] **Step 3: Implement** the kinds, the offers and the cues; update `BuddyAnnouncement`'s and `buddyOffersProvider`'s docs.
- [ ] **Step 4:** Run again, then `TZ=Europe/Vienna flutter test test/providers test/screens`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(journey): the Buddy announces each day's reward, the first-tip offer on day 3 and „Muster frei!"`

---

### Task 9: The reward line on the journey card

**Files:**
- Create: `lib/screens/dashboard/widgets/journey_reward_line.dart`
- Modify: `lib/screens/dashboard/widgets/insight_card.dart`, `lib/screens/dashboard/dashboard_screen.dart`
- Test:
  - `test/screens/dashboard/widgets/insight_card_test.dart`
  - `test/screens/dashboard/widgets/journey_reward_line_test.dart` (create)
  - `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `journeyRewardLineProvider` (Task 4), `showJourneyRewardsSheet` (Task 6).
- Produces:
  ```dart
  class JourneyRewardLineView extends ConsumerWidget {
    const JourneyRewardLineView({super.key});
    static const lineKey = Key('journey_reward_line');
  } // nothing while the line provider is null
  ```
  `InsightCard.journeyReward` keeps its type; its doc now says „below the counters, its own button".

**Rules:**
- **The line:**
  - `Icons.card_giftcard_outlined` (`iconSizeXs`, `AppTheme.primary`), then the text (`fontSizeCaptionLG`, w600, `AppTheme.foreground`), then `Icons.chevron_right`;
  - a tap opens „Deine Belohnungen";
  - semantics: one button, label = the line's text, hint `JourneyCopy.openRewards`.
- **The card** (journey layout only):
  - `BbCard` holds a `Column`: first the existing `MergeSemantics(Semantics(button, „Muster ansehen", InkWell(…)))` with the header, line, dots and counters;
  - then, when `journeyReward != null`, the reward line, padded `spacingMd` left, right and bottom and outside the merged button.
  - The other layouts are unchanged.
- **Dashboard:** `InsightCard(…, journeyReward: const JourneyRewardLineView())`.

- [ ] **Step 1: Failing tests.**
  - **Card:**
    - replace `a reward shows under the dots when given` with `a reward shows below the counters, outside the card's button`:
      - `reward.top >= counters.bottom`;
      - the card's semantics label doesn't contain „R";
      - the reward has its own semantics node;
    - `tapping the reward doesn't open Muster; the card still does`;
    - `fits 375×667 at 1.3 with 7 days and a line`.
  - **Line** (rewards and insights seeded):
    - `„Heute: Ein Wissen-Häppchen" → tap → „Deine Belohnungen"`;
    - `no reward line without the journey` (journey false → nothing);
    - `nothing while unlocked`;
    - `semantics: one button with the text and the hint`.
  - **Dashboard:** `a journey user's card shows the line`.
- [ ] **Step 2:** Run `TZ=Europe/Vienna flutter test test/screens/dashboard`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(journey): the card says today's reward and opens „Deine Belohnungen"`

---

### Task 10: Integration flows and the stage check

**Files:**
- Modify: `integration_test/helpers/test_app.dart` (pass-through of `recommendationRepo` exists; add `journeyRewardsPrefs` cleanup helper `clearJourneyPrefs(String userId)` that removes `insight_journey_`, `journey_rewards_` and `buddy_announced_<userId>_*` keys)
- Create: `integration_test/journey_rewards_flow_test.dart`

**Flows:**
- `setUp`:
  - `setNotificationModalShown()`, `clearJourneyPrefs(testUserId)`;
  - profile `intolerances: ['Fruktose']`, `diet: 'vegetarisch'`;
  - the collection „Reis-Bowl" (fits) and „Hirse-Bowl" (fits), as in `recipe_collection_flow_test`.
1. **Day 1:**
   - `insightSourceFor(activeDays: 1, gutFeelings: 0, now: DateTime.now())`;
   - Home: the Buddy's sheet „Willkommen an Tag 1! …" with „Reis-Bowl" → „Rezept ansehen" → the recipe detail;
   - back: the card's line „Heute wartet: Ein Wissen-Häppchen" → tap → „Deine Belohnungen": Tag 1 „Reis-Bowl", Tag 2 locked.
2. **Day 3, yes:**
   - 3 active days, 1 Bauchgefühl, weekly off;
   - `recommendationRepo.firstTipSet` = an unseen set with a focus `substitute` Zwiebel → Frühlingszwiebelgrün, `recipe_id` of „Hirse-Bowl", and a `try` item;
   - the sheet „Ich hab genug für deinen ersten Tipp! …" → „Ja, gern":
     - the profile's weekly-tips write is `true`;
     - the Buddy says `firstTipStarted`;
     - the row „✨ Neue Tipps" appears;
   - open it: „Dein Wochenbrief", „Fokus der Woche" on Zwiebel, „Passendes Rezept: Hirse-Bowl" → the recipe detail.
3. **Day 3, no, then a restart:**
   - „Nein, danke" → „Alles klar! Dann hier ein Rezept für dich." → „Später";
   - pump a fresh `buildTestApp` over the same prefs: no offer sheet, and the line „Heute wartet: Ein Spruch von mir";
   - `firstTipRequests` is empty.
4. **Day 7:**
   - 7 active days, 3 Bauchgefühl (unlocked), with `insight_journey_<id>` stored true;
   - „Muster frei!" → „Muster ansehen" → the Muster page, unlocked.

- [ ] **Step 1:** Write the flows and the helper.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze` (0 issues) and the full `TZ=Europe/Vienna flutter test`. Expected: all pass, the vectors not skipped.
- [ ] **Step 3: Only on the iPhone Air**, one file at a time:
  ```bash
  SIM=CB1F6232-482F-408F-ADF4-89FDA602E6A8
  xcrun simctl boot $SIM || true
  for f in journey_rewards_flow_test home_motivation_flow_test recipe_collection_flow_test recipes_flow_test discover_flow_test insights_flow_test meal_tracking_flow_test tutorial_flow_test diary_flow_test drink_tracking_flow_test auth_flow_test registration_flow_test; do
    flutter test integration_test/$f.dart -d $SIM --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown $SIM
  ```
  Expected: every file `EXIT 0`. If a case fails, run the same file on the base commit in a temporary worktree before calling it pre-existing.
- [ ] **Step 4: Commit** `test(integration): the journey's rewards, the first tip and „Muster frei!"`

---

## Self-Review notes

**Spec coverage:**

| Spec / contract | Task(s) |
|---|---|
| §5.5 one reward per active day, unlocked when its dot fills; a one-time announcement through the queue; reachable from the card | 3, 4, 8, 9 |
| §5.5 per user and device, never taken away | 3 (max, stable picks), 4 (prefs), 8 (flags) |
| Day 1: top-ranked recipe for the profile, opening the recipe | 3, 6, 8 |
| Day 2: Wissen-Häppchen with a fixed article | 3, 6 |
| Day 3: the offer moves here; yes = opt-in + immediate first tip via `diet-recommendations` (only after yes); no = a recipe, not repeated; the switch stays in Entdecken/Settings | 4, 5, 6, 8 |
| Day 4: a saying from a fixed list, no claims | 3, 6 |
| Day 5: a recipe with the user's calm-day ingredients | 3, 6 |
| Day 6: preview, blurred, clearly fake | 6 |
| Day 7: full-screen celebration only once the rule is met, else the card says what's missing | 3 (line), 7, 8; the existing `journeyLine` |
| Users past day 7: no journey, the offer after the unlock as today | 4, 8, 9 |
| §5.7 app: letter, focus first with „Fokus der Woche", „Passendes Rezept: … ›" opening the detail, older sets as today | 2 |
| Contract: hidden recipe → no link; `focus` missing = false; new layout when any focus | 2 |
| §4 shared vectors, Dart side; the note for core's diff step | 1, Note |
| Decisions #4 KI-Dienst sentence; both buttons visible at 375×667 @1.3 (compact Buddy) | 6 |
| §3 privacy, reduced motion, layout, vocabulary | 5, 6, 7, 8, 9, Global |

**Interfaces across tasks:**
- `JourneyRewards`, `RecipePick`, `TipOffer`, `FirstTipState`, `advanceRewards`, `fillPicks`, `pickJourneyRecipe`, `announcementDay`, `tipOfferDue`, `rewardEarned`, `rewardTitle`, `rewardLine`, `JourneyRewardLine`, `sayingFor`, `JourneyCopy`: T3 → T4–T9.
- `journeyRewardsProvider` (`answerTipOffer`, `setFirstTip`), `journeyRewardLineProvider`, `journeyRewardAnnouncementProvider`, `patternsUnlockedDueProvider`, `firstTipFailedProvider`, `journeyRewardsSeededWith`: T4 → T5, T6, T8, T9.
- `FirstTipResult`, `FirstTipException`, `requestFirstTip`, `fetchRecentMeals(since:)`, `firstTipProvider.accept`, `FakeFirstTipNotifier`, `FakeRecommendationRepository.firstTipSet/firstTipRequests`: T5 → T8, T10.
- `FirstTipAnswer`, `showFirstTipOfferSheet`, `showJourneyRewardSheet`, `showJourneyRewardsSheet`, `openJourneyReward`, `PatternsPreview`: T6 → T8, T9.
- `RoutePaths.patternsUnlocked`, `PatternsUnlockedScreen`: T7 → T8, T10.
- `BuddyAnnouncement.journeyReward/patternsUnlocked/firstTipFailed`: T8.
- `RecommendationItem.focus/recipeId/recipeTitle/hasRecipeLink`, `isLetter`, `itemsFocusFirst`, `TipRecipeLink`, `BbCard.borderColor`: T2 → T10.

**Known, accepted:**
- **Two devices:** each may ask the day-3 question and request one first tip (per device, as the spec's flags are); the server keeps both sets.
- **A timeout that the server finishes anyway:** the line says it didn't work, and the set arrives later as „Neue Tipps".
- **Skipped days aren't announced:** only the newest earned day plays; the rest wait in „Deine Belohnungen".
- **Picks need a checked fit:** a user whose intolerance table can't load sees the „unter Entdecken" fallback until it can.
- **For Severin:**
  - the privacy-policy question (Decisions log #4, core report „Unresolved" 1) is unchanged by this stage;
  - the day-3 line deviates from the spec's quote on purpose (see Decisions).
