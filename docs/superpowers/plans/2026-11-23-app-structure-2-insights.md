# App-Struktur Stage 2: Insights & Muster — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Home's locked insight card into real, honest insights from the user's last 30 days: good and hard days, „Fällt mir auf", and a Muster page behind the card.

**Architecture:**
- **Data:** one paginated fetch per entry table loads a 30-day `InsightSource`. Meals reach 24 h further back.
- **Computation:** a pure, exhaustively unit-tested `computeInsights(source, now)` turns it into an `Insights` value: unlock, calendar, columns, „Fällt mir auf", Home pick.
- **State:** `insightsProvider` replaces Stage 1's `insightProgressProvider`. It recomputes after every entry write (`entriesRevisionProvider`) and at local midnight. It applies only the newest result and hides stale numbers after a user change.
- **UI:** `InsightCard` renders the Home pick and opens `/patterns`, a pushed `PatternsScreen`.

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3 (`AsyncNotifier`), GoRouter 18, mocktail, integration_test.

**Spec:** `docs/superpowers/specs/2026-11-23-app-structure-redesign-design.md` (approved 2026-11-23). This plan implements **Stage 2**: §5.5 in full, plus the card states of §5.3 item 4. Mockup: „Runde 3 · 4 · Muster" at https://claude.ai/artifact/1TXEAjPsD821CgJrKXLG4q. The local copy is `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/buddy-mockups.html`. Where the mockup and the spec differ, the spec wins: the mockup's „schwach" becomes the spec's „noch unsicher", and the spec's counts are shown everywhere.

## Global Constraints

From the spec, verbatim:
- Follow the repo's `CLAUDE.md`:
  - colours, font sizes, spacing and radii only through `AppTheme`/`AppConstants`;
  - German UI;
  - Riverpod AsyncNotifier, GoRouter, `AppLogger`;
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- The mascot is "Belly Buddy". Never "Bauch-Buddy".
- Reduced motion is respected. Text scale 1.3 and a 375×667 phone must not overflow.
- PostgREST caps responses at 1000 rows (`PGRST_DB_MAX_ROWS`), so multi-day queries paginate.
- No invented statistics, no efficacy claims, and nothing that reads like a diagnosis. Every insight is an observation from the user's own entries, with counts, and carries "kein medizinischer Befund".
- No guilt and no punishing pet. Bad gut days never make the Buddy sick or sad at the user.
- No tile, row or link may lead to an empty, paused or placeholder screen.
- Thresholds are Severin's decisions; change them only with him:
  - hard = existing level `schlecht` (average > 3.5); good = `spiGut`/`gut` (average ≤ 2.5); medium = `durchschnittlich`;
  - unlock at ≥ 7 distinct active days **and** ≥ 3 gut-feeling entries in the window;
  - "Fällt mir auf" needs H ≥ 3, and an item needs hard ≥ 3, hard/H ≥ 0.5 and hard/H − (G > 0 ? good/G : 0) ≥ 0.25, top 5. Up to 3 "noch unsicher" items with hard == 2 that pass the rate rules;
  - columns need ≥ 3 days of their class; an item is "oft dabei" when it is present on ≥ 2 of those days **and** on ≥ half of them, max 5.

Execution rules for this repo:
- **Commits:** `dart format .` and `flutter analyze` (0 issues) first, then `git commit --no-verify` (the hook is broken in worktrees). Use a conventional prefix and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Test seams:** the root `test/flutter_test_config.dart` already holds the Buddy and care-ring animations still; don't add per-directory copies.
- **Simulators:** integration tests run only on iPhone 17 `7A26EDD4-1542-45F9-A6CE-83D13D4C5219`, one file at a time, shut down afterwards. Never use `55746DB2…`. Never run `flutter clean`.

## Review Focus

1. **Late-evening meal, hard morning.** The window must reach into the previous day, and on day 1 of the 30-day window before it. A meal at 21:00 on day N−1 counts for a hard entry at 07:00 on day N, including when day N is the window's first day. Pinned in Task 2 (`fetches meals 24 h before the window`) and Task 3 (`window reaches into the previous day`).
2. **Same ingredient spelled differently.** "Zwiebel", " zwiebel " and "ZWIEBEL" are one ingredient. The shown name is the trimmed spelling from the most recent meal. Pinned in Task 3.
3. **Delete, then come back.** After deleting the 3rd gut-feeling entry in the Tagebuch, Home's card goes back to locked without a pull-to-refresh. After a sign-out and sign-in as another user, the card never shows the previous user's numbers. Pinned in Task 4.
4. **Midnight on Home.** With the app open across local midnight, the 30-day window moves on. Day 31 drops out, and the calendar's last cell is the new today. Pinned in Task 4 (`recomputes at local midnight`).
5. **Large text on a small phone.** At 375×667 and text scale 1.3, the unlocked Muster page (calendar, both columns, five "Fällt mir auf" rows with a "noch unsicher" badge) and every card state have no overflow. Pinned in Tasks 5 and 7.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/insight_source.dart` (create) | `InsightSource`, `InsightMeal`: the raw 30-day input |
| `lib/models/insights.dart` (create) | `Insights` value: progress, calendar, columns, noticed, home pick |
| `lib/models/insight_progress.dart` (keep) | unchanged; it is now part of `Insights` |
| `lib/utils/gut_feeling_rating.dart` (modify) | `gutFeelingLevelFor(double avg)`, extracted |
| `lib/services/entry_query_service.dart` (modify) | generic paginated select; `fetchInsightSource` |
| `lib/repositories/entry_repository.dart` (modify) | `fetchInsightSource`; drop `fetchInsightProgress` |
| `lib/services/insights/insights_engine.dart` (create) | pure `computeInsights` |
| `lib/services/insights/insight_copy.dart` (create) | German strings for card and page |
| `lib/providers/insights_provider.dart` (create) | loading, revision, midnight, ordering |
| `lib/providers/insight_progress_provider.dart` (delete) | – |
| `lib/screens/dashboard/widgets/insight_card.dart` (modify) | 4 states, tap → `/patterns` |
| `lib/router/route_names.dart`, `lib/router/app_router.dart` (modify) | `/patterns` |
| `lib/screens/patterns/patterns_screen.dart` + `widgets/*` (create) | Muster page |

---

### Task 1: Gut-feeling level from an average

**Files:**
- Modify: `lib/utils/gut_feeling_rating.dart`
- Test: `test/utils/gut_feeling_rating_test.dart`

**Interfaces:**
- Produces `GutFeelingRatingLevel gutFeelingLevelFor(double avg)`. Boundaries: avg ≤ 1.5 → `spiGut`, ≤ 2.5 → `gut`, ≤ 3.5 → `durchschnittlich`, otherwise `schlecht`.
- `calculateGutFeelingRating` uses it, with unchanged behaviour.

- [ ] **Step 1: Failing test.** `gutFeelingLevelFor boundaries`:
  - `1.5 → spiGut`
  - `1.51 → gut`
  - `2.5 → gut`
  - `2.51 → durchschnittlich`
  - `3.5 → durchschnittlich`
  - `3.51 → schlecht`

  Existing `calculateGutFeelingRating` tests stay green.
- [ ] **Step 2:** `flutter test test/utils/gut_feeling_rating_test.dart` → FAIL (undefined).
- [ ] **Step 3:** Extract the function and use it inside `calculateGutFeelingRating`.
- [ ] **Step 4:** PASS. **Step 5: Commit** `refactor(gut-feeling): the rating level for any average`

---

### Task 2: One 30-day insight source, each table queried once

**Files:**
- Create: `lib/models/insight_source.dart`
- Modify: `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart`, `test/helpers/fakes.dart` (`FakeEntryRepository`)
- Test: `test/services/entry_query_service_test.dart`, `test/repositories/entry_repository_test.dart`

**Interfaces:**
- **Value types:**
  - `class InsightMeal { const InsightMeal({required this.trackedAt, required this.ingredients}); final DateTime trackedAt; final List<String> ingredients; }`
  - `class InsightSource { const InsightSource({required this.meals, required this.gutFeelings, required this.activityInstants}); final List<InsightMeal> meals; final List<GutFeelingEntry> gutFeelings; final List<DateTime> activityInstants; }`
  - `activityInstants` holds `tracked_at` from **all four** tables inside the window. The meals and gut entries are already in it.
- **Query service:** `Future<InsightSource> EntryQueryService.fetchInsightSource({required String userId, required DateTime since, required DateTime mealsSince})`.
  - One paginated select per table, through a generic private `_fetchPaged(table, columns, userId, sinceIso)`. `_fetchTrackedAtTable` becomes a call to it.
  - meal_entries: `'tracked_at, ingredients'` since `mealsSince`.
  - gut_feeling_entries: `'*'` since `since`.
  - toilet_entries, drink_entries: `'tracked_at'` since `since`.
  - The four selects run in parallel (`Future.wait`).
  - Meal instants earlier than `since` are **not** added to `activityInstants`.
- **Repository:** `Future<InsightSource> EntryRepository.fetchInsightSource({required String userId, required DateTime now})`.
  - `since = addDays(startOfDay(now), -(InsightProgress.windowDays - 1))`
  - `mealsSince = since.subtract(const Duration(hours: 24))`
  - `fetchInsightProgress` is removed, with its tests and its fake.
- **Fake:** `FakeEntryRepository.insightSource` (settable), `insightSourceError` (throws when set), and `insightSourceCalls` (count).

- [ ] **Step 1: Failing tests.**
  - `fetchInsightSource selects each table once with its columns`:
    - mock the client, as the existing `fetchTrackedAtSince` tests do;
    - expect `from('meal_entries').select('tracked_at, ingredients')` once, `gut_feeling_entries` with `'*'`, and the two others with `'tracked_at'`;
    - expect `eq('user_id', uid)` and `gte('tracked_at', …)` on each.
  - `fetches meals 24 h before the window`: the meals `gte` value equals `mealsSince.toUtc().toIso8601String()`, and the others use `since`.
  - `paginates every table`: a table returning 1000 then 3 rows yields 1003 rows (same pattern as `paginates a table until a short page is returned`).
  - `meal instants before since are not activity`: a meal at `since − 2 h` is in `meals` but not in `activityInstants`.
  - Repository `fetchInsightSource window`: `now = 23.11.2026 09:41` → `since = 25.10.2026 00:00` local, `mealsSince = 24.10.2026 00:00` local.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. `GutFeelingEntry.fromJson` parses the gut rows. Meal rows map to `InsightMeal` (`ingredients` null → `[]`).
- [ ] **Step 4:** `flutter test test/services test/repositories` → PASS.
- [ ] **Step 5: Commit** `feat(insights): one 30-day source of meals, gut feelings and active days`

---

### Task 3: `computeInsights`, the pure engine

**Files:**
- Create: `lib/models/insights.dart`, `lib/services/insights/insights_engine.dart`
- Test: `test/services/insights/insights_engine_test.dart`

**Interfaces (produced):**
```dart
enum DayClass { good, medium, hard, none }
class InsightDay { final DateTime day; final DayClass dayClass; }          // local midnight
class IngredientCount { final String name; final int count; final int of; } // "an count von of … Tagen"
class DayColumn { final int days; final bool shown; final List<IngredientCount> often; } // shown == days >= 3
class Noticed { final String name; final int hard; final int hardDays; final int good; final int goodDays; final bool uncertain; }
sealed class InsightPick {}  // NoticedPick(Noticed) | GoodDaysPick(DayColumn) | NothingYetPick()
class Insights {
  final InsightProgress progress;      // activeDays, gutFeelingEntries (existing type)
  bool get unlocked => progress.unlocked;
  final List<InsightDay> calendar;     // 30 entries, oldest first, last = today
  final int gutFeelingDays;            // days with ≥1 gut entry (page header)
  final DayColumn goodDays, hardDays;
  final List<Noticed> noticed;         // shown items first (≤5), then uncertain (≤3); empty when hardDays.days < 3
  final InsightPick pick;
}
Insights computeInsights(InsightSource source, DateTime now);
```
Give the value types `==`/`hashCode`, either hand-written or by a const record comparison. They are not Freezed, so no codegen is needed.

**Algorithm.** The spec fixes these rules; implement them exactly.
1. **Window.** `start = addDays(startOfDay(now), -29)`. Ignore entries with `trackedAt` after `now`. Use local time for everything (`toLocal()`).
2. **Progress.** `activeDays` = distinct `startOfDay` of the `activityInstants` in `[start, now]`. `gutFeelingEntries` = number of gut entries in `[start, now]`.
3. **Per entry.** `level = gutFeelingLevelFor(gutFeelingAverage(…all fields of the entry…))`.
4. **Per day.** The day's class comes from the mean of its entries' averages, through `gutFeelingLevelFor`:
   - `spiGut`/`gut` → good
   - `durchschnittlich` → medium
   - `schlecht` → hard
   - no gut entry → none

   The calendar lists all 30 days.
5. **Anchors.**
   - For a hard day, the anchor is the **earliest entry that day whose own level is `schlecht`**. One always exists when the day's mean is > 3.5.
   - For a good day, it is the earliest entry whose own level is `spiGut`/`gut`.
   - The day's window is `[anchor − 24 h, anchor)`.
6. **Ingredient keys.**
   - `key = name.trim().toLowerCase()`. Skip empty keys.
   - An ingredient is "there" on a day when any meal with `trackedAt` inside that day's window lists its key. One meal counts at most once per day.
   - The **display name** is the trimmed spelling from the most recent meal in the source that has the key.
7. **Counts.** For each key: `hard` = hard days it was there, `good` = good days it was there. `H` = number of hard days, `G` = number of good days.
8. **Fällt mir auf, only when `H >= 3`.**
   - `rate = hard/H`, `gap = rate − (G > 0 ? good/G : 0)`.
   - **Shown items:** `hard >= 3 && rate >= 0.5 && gap >= 0.25`. Sort by `hard` desc, then `gap` desc, then display name asc. Take the top 5.
   - **Uncertain items:** `hard == 2 && rate >= 0.5 && gap >= 0.25`, same sort, top 3, `uncertain: true`.
9. **Columns.**
   - Each column is shown only when its class has `days >= 3`.
   - An item is "oft dabei" when `count >= 2 && count * 2 >= days`. Sort by count desc, then name asc. Max 5. `IngredientCount(name, count, of: days)`.
10. **Pick, only meaningful when unlocked.**
    - First shown (non-uncertain) Noticed → `NoticedPick`.
    - Otherwise, when `goodDays.shown && goodDays.often.isNotEmpty` → `GoodDaysPick`.
    - Otherwise → `NothingYetPick`.

- [ ] **Step 1: Failing tests.** Build sources with a helper `meal(DateTime at, List<String> ing)` and a gut entry with all four symptoms at `v`, i.e. `gut(DateTime at, int v)`, so the average is `v`. Use `now = 23.11.2026 20:00`.
  - `calendar has 30 days, oldest first, today last`: `calendar.first.day == 25.10.2026`, `calendar.last.day == 23.11.2026`.
  - `progress counts distinct active days and gut entries`: 3 entries on one day plus 1 on another → `activeDays 2`. Entries outside the window or after `now` are not counted.
  - `day class from the mean of the day's entries`: entries 2 and 3 → mean 2.5 → good. Entries 3 and 4 → 3.5 → medium. Entries 4 and 4 → hard. A day without entries → none.
  - `hard anchor is the first schlecht entry, not the first entry`: hard day with a 3 at 08:00 and a 5 at 12:00. A meal at 10:00 is inside the 12:00 window. A meal at 11:59 the day before is inside; one at 12:00 the day before is not (the window is `[anchor−24h, anchor)`).
  - `window reaches into the previous day`: a hard entry at 07:00 on the window's first day, with an onion meal at 21:00 the day before the window → onion counts for that hard day.
  - `ingredient matching ignores case and spaces`: meals with "Zwiebel", " zwiebel ", "ZWIEBEL" on three hard days → one item, `hard == 3`. The display name is the most recent spelling, trimmed.
  - `one meal counts once per day`: two onion meals in one window → `hard` rises by 1.
  - **`Fällt mir auf thresholds`** (H = 5, G = 6):

    | Ingredient | hard | good | Expected |
    |---|---|---|---|
    | Zwiebel | 4 | 1 | shown (rate 0.8, gap 0.633) |
    | Knoblauch | 3 | 1 | shown (0.6, 0.433) |
    | Kaffee | 3 | 3 | **not** shown (gap 0.1) |
    | Brot | 3 | 2 | shown (0.6, 0.267) |
    | Milch | 2 | 0 | uncertain (0.4) → **not**, rate < 0.5 |

    Order: Zwiebel, Knoblauch, Brot.
  - `uncertain needs hard == 2 and the rates`: H = 4, G = 2, Apfel hard 2, good 0 → uncertain (0.5, 0.5). Birne hard 2, good 1 → not (gap 0.0).
  - `no section below 3 hard days`: H = 2 → `noticed` is empty, even with strong items.
  - `G == 0 uses gap = rate`: H = 3, G = 0, Reis hard 3 → shown.
  - `top 5 and top 3`: 7 qualifying shown items → 5; 4 qualifying uncertain → 3; sorted as specified.
  - **`columns`:**
    - 2 good days → `goodDays.shown == false`.
    - 4 good days: Reis on 3 → `IngredientCount('Reis', 3, of: 4)`; Hafer on 2 → included (2*2 >= 4); Karotte on 1 → excluded.
    - 5 good days: an item on 2 → excluded (4 < 5).
    - Max 5, sorted by count desc then name.
  - **`pick`:**
    - With shown Noticed → `NoticedPick` with the top item.
    - Without one, but with a shown good column with items → `GoodDaysPick`.
    - Otherwise → `NothingYetPick`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement exactly as the algorithm says. No I/O, no clock, no Flutter imports beyond `foundation` (if needed for `listEquals`).
- [ ] **Step 4:** `flutter test test/services/insights` → PASS.
- [ ] **Step 5: Commit** `feat(insights): good and hard days and „Fällt mir auf" from the last 30 days`

---

### Task 4: `insightsProvider` replaces the progress provider

**Files:**
- Create: `lib/providers/insights_provider.dart`
- Delete: `lib/providers/insight_progress_provider.dart` and its test
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (refresh call and card wiring)
- Test: `test/providers/insights_provider_test.dart`

**Interfaces:**
- **Provider:** `insightsProvider`, an `AsyncNotifierProvider<InsightsNotifier, Insights>` with no automatic retry (same as Stage 1's `_noRetry`).
- **`build()`:**
  - watches `currentUserIdProvider`;
  - signed out → an empty `Insights` (progress 0/0, 30 `none` days, `NothingYetPick`);
  - signed in → fetches through `fetchInsightSource(userId:, now: clock())`, then `computeInsights`.
- **Revision:** `ref.listen(entriesRevisionProvider, …)` → `refresh()`.
- **Midnight:** a one-shot `Timer` to the next local midnight, using `buddyClockProvider` for "now", calls `refresh()` and re-arms. It is cancelled in `ref.onDispose`.
- **`Future<void> refresh()`:**
  - It never throws.
  - While the first load runs it joins it (as Stage 1 did).
  - It increments a private `_seq` before fetching and applies the result **only if `_seq` is unchanged**, so an older fetch never overwrites a newer one.
  - It applies only when `ref.mounted` and the user id is unchanged.
- **Stale values.** Hide the card when `insights.isReloading`: Riverpod 3 sets this when `build` reruns because the user changed. Stage 1's re-login bug came from it.

- [ ] **Step 1: Failing tests** (fake repository, fake clock through a `buddyClockProvider` override, mocktail-free):
  - `loads and computes`: the source with 7 active days and 3 gut entries → `unlocked`.
  - `recomputes after any entry write`: bump `entriesRevisionProvider` → `insightSourceCalls == 2`. Deleting the 3rd gut entry (the fake returns 2) → `unlocked == false`.
  - `recomputes at local midnight`:
    - clock at 23:59:30 under `fakeAsync`; advance 31 s → a second fetch with `now` on the next day;
    - the new value's `calendar.last.day` is the new day;
    - the timer is re-armed (advance 24 h → a third fetch).
  - `a newer refresh wins`: the first refresh's fetch completes **after** the second's (use `Completer`s) → state holds the second result.
  - `a user change never shows the previous user's insights`: user A loaded → switch `currentUserIdProvider` to B with a pending fetch → `state.isReloading` is true. Home's card (Task 5) shows nothing until B's value arrives.
  - `a failed refresh keeps the last value; a failed first load is an error`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, then delete the old provider.
  - `DashboardScreen._loadData` calls `ref.read(insightsProvider.notifier).refresh()`.
  - The card `Consumer` passes `ref.watch(insightsProvider)`.
  - `grep -r insightProgressProvider lib test` is empty.
- [ ] **Step 4:** `flutter test test/providers test/screens/dashboard` → PASS.
- [ ] **Step 5: Commit** `feat(insights): recompute after every entry write and at midnight; never stale across users`

---

### Task 5: Home's insight card — four states, tap opens Muster

**Files:**
- Create: `lib/services/insights/insight_copy.dart`
- Modify: `lib/screens/dashboard/widgets/insight_card.dart`, `lib/router/route_names.dart`, `lib/router/app_router.dart` (add a stub `/patterns` route building a placeholder `PatternsScreen`, which Task 6 fills)
- Test: `test/services/insights/insight_copy_test.dart`, `test/screens/dashboard/widgets/insight_card_test.dart`

**Interfaces:**
- **Routes:**
  - `RoutePaths.patterns = '/patterns'`, `RouteNames.patterns = 'patterns'`. This is a top-level pushed route, like `/recommendations`, and it is not gated.
  - `InsightCard({required AsyncValue<Insights> insights})`. `InsightCard.cardKey` is kept.
  - The tutorial key is still passed from the dashboard (`TutorialKeys.insight`).
- **Copy, exact** (`InsightCopy` static functions):
  - `lockedLine(progress)`: unchanged from Stage 1. Examples: „Noch 5 Tage, dann zeig ich dir erste Muster." / „Noch 1 Tag, …" / „Noch 2 Bauchgefühl-Einträge, …" / „Noch 1 Bauchgefühl-Eintrag, …".
  - `noticedHeadline(n)`: „Zwiebel war an 4 von 5 schweren Tagen dabei."
  - `noticedGood(n)`: „an guten Tagen: 1 von 6". With `goodDays == 0`: „an guten Tagen: noch keine".
  - `noticedRow(n)`: „Zwiebel · an 4 von 5 schweren Tagen dabei · an guten Tagen: 1 von 6". This is the page row; with goodDays == 0 the last part is „an guten Tagen: noch keine".
  - `goodDaysLine(col)`: „An guten Tagen gab's oft Haferflocken, Reis und Karotte." Joined with ", " and " und " before the last; one item gives „An guten Tagen gab's oft Reis."
  - `goodDaysSub(col)`: „6 gute Tage in den letzten 30".
  - `nothingYet`: „Noch fällt mir nichts Eindeutiges auf – trag weiter ein, dann sehe ich mehr."
  - `noFinding = 'kein Befund'`.
  - **Card headers** (uppercase, `StepFieldLabel.style`): locked/nothing → „Was ich über deinen Bauch lerne"; NoticedPick → „Fällt mir auf"; GoodDaysPick → „Deine guten Tage". The trailing link text is „Muster ›".

- [ ] **Step 1: Failing tests.**
  - Copy tests cover every function above, with the exact strings and the singular/plural cases.
  - **Card tests:**
    - `locked shows progress and opens Muster`: the Stage 1 assertions stay. Tapping the card pushes `/patterns` (stub-route router from `test/helpers/app_host.dart`).
    - `noticed pick`:
      - the header „FÄLLT MIR AUF" (semantics „Fällt mir auf");
      - the headline and the good line;
      - `find.text('kein Befund')`;
      - tap → `/patterns`.
    - `good-days pick`: the summary line + „6 gute Tage in den letzten 30" + „kein Befund".
    - `nothing yet`: the nothing-yet line + „kein Befund".
    - `hidden while loading, after an error without a value, and while reloading for another user`: `find.byKey(InsightCard.cardKey)` finds nothing.
    - `fits 375×667 at text scale 1.3` for each of the 4 states: `tester.takeException()` is null.
    - `semantics`: the card is a button labelled „Muster ansehen", plus its visible text.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Keep Stage 1's `BbCard` styling and the locked bars.
  - Wrap the card in `InkWell`/`GestureDetector` → `context.push(RoutePaths.patterns)`.
  - Add any new sizes only to `AppConstants`.
- [ ] **Step 4:** `flutter test test/services/insights test/screens/dashboard` → PASS.
- [ ] **Step 5: Commit** `feat(home): the insight card shows what I noticed and opens Muster`

---

### Task 6: Muster page — locked state and the route

**Files:**
- Create: `lib/screens/patterns/patterns_screen.dart`, `lib/screens/patterns/widgets/patterns_locked.dart`
- Test: `test/screens/patterns/patterns_screen_test.dart`

**Interfaces:**
- **Screen:** `PatternsScreen`, a `ConsumerWidget`. It watches `insightsProvider` and has pull-to-refresh, which calls `refresh()`.
- **Header:** a back pill or app bar titled „Muster".
- **States:**
  - loading → a centred `CircularProgressIndicator`;
  - error without a value → „Muster konnten nicht geladen werden." + `TextButton('Nochmal versuchen')` → `refresh()`;
  - locked → `PatternsLocked`;
  - unlocked → `PatternsUnlocked` (Task 7). Until Task 7 lands, a minimal placeholder is acceptable; Task 7 replaces it.

**Locked content** (mockup „Gesperrt"):
- The Buddy line in a speech-bubble style card: title „Ich sammle noch!" and the body `InsightCopy.lockedLine(progress)`.
- Section label „Bis zu den ersten Mustern" with the two progress rows. Reuse Stage 1's `_ProgressRow`: move it to `lib/widgets/common/` or export it from the card file.
- **Hint:**
  - when `gutFeelingsLeft > 0`: „Trag abends kurz dein Bauchgefühl ein, das hilft mir am meisten.";
  - otherwise: „Trag weiter ein – jeder Tag mit Einträgen zählt."
- **Preview:**
  - label „Das siehst du dann · Beispiel", then a blurred (`ImageFiltered` blur) sample of the unlocked layout with clearly fictional example values;
  - the whole preview is `ExcludeSemantics` under one `Semantics(label: 'Vorschau mit Beispielwerten')`;
  - under reduced motion, show it without animation (it isn't animated anyway).
- **Footer:** „ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund."

- [ ] **Step 1: Failing tests.**
  - `/patterns opens from a cold start and is not gated`. Add the router redirect case to `test/router/buddy_onboarding_gate_test.dart`: `/patterns` with a pending gate → `null`, like `/recommendations`.
  - `locked shows the Buddy line, both bars, the right hint and the preview`, for progress (2,1) and for (7,1).
  - `preview is marked as Beispiel and excluded from semantics`.
  - `error shows retry, which refreshes`.
  - `fits 375×667 at text scale 1.3`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement (tokens only).
- [ ] **Step 4:** `flutter test test/screens/patterns test/router` → PASS.
- [ ] **Step 5: Commit** `feat(patterns): the Muster page shows the way to the first patterns`

---

### Task 7: Muster page — unlocked: calendar, good and hard days, „Fällt mir auf"

**Files:**
- Create: `lib/screens/patterns/widgets/patterns_unlocked.dart`, `insight_calendar.dart`, `day_columns.dart`, `noticed_list.dart`
- Modify: `lib/config/app_theme.dart` / `lib/config/constants.dart` for new tokens, if needed
- Test: `test/screens/patterns/patterns_unlocked_test.dart`

**Content, top to bottom** (mockup „Frei"):
1. **Calendar.**
   - Header „Letzte 30 Tage · {gutFeelingDays} Tage mit Bauchgefühl" (singular „1 Tag mit Bauchgefühl").
   - A 7-column grid aligned to weekdays (Mo–So header from `kWeekdayShortNames`), with leading blanks before the first day.
   - Each cell shows the day number **and** a class icon:
     - good `Icons.sentiment_satisfied_alt`
     - medium `Icons.sentiment_neutral`
     - hard `Icons.sentiment_dissatisfied`
     - none: an empty outlined cell
   - Colours come from the existing `AppTheme.gutFeelingGood/Neutral/Bad`.
   - Cell semantics: `'{d}. {Mon}: gut|mittel|schwer|kein Eintrag'`, e.g. „18. Nov: schwer".
   - The legend „gut · mittel · schwer · kein Eintrag" uses the same icons.
2. **„Deine guten und schweren Tage".** Two cards (stacked, or side by side if they fit at 375 px):
   - title „{n} gute Tage" / „{n} schwere Tage" (singular „1 guter Tag" / „1 schwerer Tag");
   - when `shown`: label „oft dabei:" and rows „Reis · an 3 von 4 guten Tagen" / „Zwiebel · an 4 von 5 schweren Tagen". With no items, „Noch nichts, das oft dabei war.";
   - when not shown: „Noch zu wenige gute Tage" / „Noch zu wenige schwere Tage".
3. **„Fällt mir auf"**, only when `hardDays.days >= 3`:
   - shown rows use `InsightCopy.noticedRow`;
   - uncertain rows show the same text plus a badge „noch unsicher";
   - if both lists are empty: `InsightCopy.nothingYet`.
4. **Footer.**
   - „ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund."
   - plus „Schwerer Tag = Bauchgefühl „Schlecht"; guter Tag = „Gut" oder „Sehr gut"."

- [ ] **Step 1: Failing tests** (built from a fixed `Insights` value, not through the engine):
  - `calendar has 30 day cells aligned to weekdays`: the first cell's semantics are „25. Okt: …"; 25.10.2026 is a Sunday, so 6 leading blanks.
  - `classes are not colour-only`: the hard cell contains the dissatisfied icon, and its semantics contain „schwer".
  - `header counts gut-feeling days`: „Letzte 30 Tage · 21 Tage mit Bauchgefühl" and the singular case.
  - `columns`: the shown good column lists „Reis · an 3 von 4 guten Tagen"; the hidden hard column says „Noch zu wenige schwere Tage".
  - `Fällt mir auf rows and uncertain badge`: the Zwiebel row text equals `noticedRow`, and an uncertain row has „noch unsicher".
  - `no Fällt-mir-auf section below 3 hard days`: `find.text('Fällt mir auf')` finds nothing.
  - `footer lines present`.
  - `fits 375×667 at text scale 1.3` with the maximum content (5 + 3 rows, both columns with 5 items, long German names such as „Vollkornweizenbrot").
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and wire it into `PatternsScreen`.
- [ ] **Step 4:** `flutter test test/screens/patterns` → PASS.
- [ ] **Step 5: Commit** `feat(patterns): calendar, good and hard days and what I noticed`

---

### Task 8: Integration flow and the stage check

**Files:**
- `integration_test/helpers/test_app.dart` (the fake repository returns an `InsightSource`)
- `integration_test/insights_flow_test.dart` (create)

**Flow:**
- **Locked:** Home shows the locked card → tap → the Muster page shows „Ich sammle noch!" → back.
- **Unlocked:**
  - seed the fake source with a computed unlocked case: Zwiebel on 4 of 5 hard days, 6 good days;
  - Home's card reads „FÄLLT MIR AUF" + „Zwiebel war an 4 von 5 schweren Tagen dabei.";
  - tap → the page shows the calendar header, both columns and the Zwiebel row;
  - pull to refresh → no error.

- [ ] **Step 1:** Write the test.
- [ ] **Step 2:** `dart format .`, `flutter analyze` (0), `flutter test` → all pass.
- [ ] **Step 3: On the second simulator only:**
  ```bash
  xcrun simctl boot 7A26EDD4-1542-45F9-A6CE-83D13D4C5219 || true
  for f in insights_flow_test tutorial_flow_test diary_flow_test; do
    flutter test integration_test/$f.dart -d 7A26EDD4-1542-45F9-A6CE-83D13D4C5219 --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown 7A26EDD4-1542-45F9-A6CE-83D13D4C5219
  ```
  Expected: EXIT 0 for all three. The tutorial still targets the card through `TutorialKeys.insight`.
- [ ] **Step 4: Commit** `test(integration): Home's insight card into the Muster page`

---

## Self-Review notes

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §5.5 data | 2 |
| Classification and unlock | 1, 3 |
| Fällt mir auf | 3 (algorithm), 5/7 (copy) |
| Columns | 3, 7 |
| Home pick | 3, 5 |
| Muster locked | 6 |
| Muster unlocked | 7 |
| Recompute after writes and at midnight | 4 |
| Card tappable → `/patterns` | 5 |
| Tutorial step 4 | unchanged key, verified in 8 |

**Deferred Stage 1 items folded in:**
- one select per table (Task 2);
- writes and midnight trigger a recompute (Task 4);
- stale numbers across users (Task 4/5);
- out-of-order refresh (Task 4).

**Interfaces across tasks:**
- `gutFeelingLevelFor` (T1 → T3);
- `InsightSource`/`fetchInsightSource` (T2 → T3/T4/T8);
- `Insights`, `InsightPick`, `Noticed`, `DayColumn`, `IngredientCount`, `DayClass` (T3 → T4–T7);
- `insightsProvider` (T4 → T5–T7);
- `InsightCopy` (T5 → T6/T7);
- `RoutePaths.patterns` (T5 → T6/T8).

**Spec vs. mockup:** the spec wins. „noch unsicher" replaces „schwach", every row shows counts, and the H < 3 section is hidden rather than shown empty. The locked preview is labelled „Beispiel" so that the sample values are never mistaken for the user's own data.
