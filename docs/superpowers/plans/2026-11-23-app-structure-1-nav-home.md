# App-Struktur Stage 1: Navigation & Home — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2-tab shell and the crowded dashboard with a 5-slot bar (Home · Tagebuch · (+) · Entdecken · Ich), one "Eintragen" sheet for all four entry types, a calm Home (Streak chip, Buddy in a display-only care ring, one next-action button, a locked insight card), an Entdecken hub over the existing content screens, an Ich tab, one app-wide vocabulary and a rewritten, replayable tutorial.

**Architecture:**
- **Shell:** the `StatefulShellRoute` grows from 2 to 4 branches (`/dashboard`, `/diary`, `/discover`, `/me`). The centre plus is not a branch; it opens a modal sheet that pushes the existing tracker routes.
- **Home:** keeps `BuddyHero`/`CareRing` from PR #83. The need bubbles turn into a read-only display, and one tap target opens the Tagebuch. A new `InsightCard` is fed by a small `insightProgressProvider`: active days and gut-feeling count over 30 days. Stage 2 replaces its unlocked state with real insights.
- **Entdecken:** a new screen that previews the existing recommendation, suggestion and recipe providers and links into the existing screens.

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3 (Notifier/AsyncNotifier), GoRouter 18, mocktail, integration_test.

**Spec:** `docs/superpowers/specs/2026-11-23-app-structure-redesign-design.md` (approved 2026-11-23). This plan implements its **Stage 1**: §5.1, §5.2, §5.3 (insight card locked only, no tips row), §5.4, §5.6 as a hub, §5.8, §5.9 and §5.10. Not in scope: Stage 2 (§5.5 insights and Muster page) and Stage 3 (RSS, weekly tips opt-in, Entdecken badge, core job).

## Global Constraints

From the spec, verbatim:
- Follow the repo's `CLAUDE.md`:
  - Colours, font sizes, spacing and radii go only through `AppTheme`/`AppConstants`.
  - German UI.
  - Riverpod AsyncNotifier, GoRouter, `AppLogger`.
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- The mascot is "Belly Buddy". Never "Bauch-Buddy".
- Reduced motion is respected. Text scale 1.3 and a 375×667 phone must not overflow.
- PostgREST caps responses at 1000 rows (`PGRST_DB_MAX_ROWS`), so multi-day queries paginate.
- Notification taps route to `/meal-tracker`, `/gut-feeling-tracker`, `/recommendations`, `/ingredient-suggestions` and `/dashboard`. These routes stay valid (`/dashboard` = Home tab).
- Gate order is unchanged: upgrade gate → auth → health consent → Buddy onboarding gate, including the new `/loading` hold from PR #83.
- Process per stage: build via plan → `/simplify` → `/code-review` → fix findings → PR to the stage's base. Integration tests run on a second simulator. Severin tests each stage locally. One release at the end.
- No invented statistics, no efficacy claims, and nothing that reads like a diagnosis.
- No guilt and no punishing pet.
- No tile, row or link may lead to an empty, paused or placeholder screen.

Execution rules for this repo:
- **Commits:** run `dart format .` and `flutter analyze` (0 issues) first, then commit with `git commit --no-verify`. The pre-commit hook is broken in git worktrees. Use conventional prefixes and end the message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Test seams:** widget tests that pump the Buddy or the care ring need `AnimatedBuddy.tickerEnabled = false` and `CareRing.pulseEnabled = false`. Copy `test/screens/dashboard/flutter_test_config.dart` into every new test directory that pumps them (`test/screens/discover/`, `test/screens/me/`, `test/widgets/log_sheet/`).
- **Simulators:** integration tests run only on the second simulator, iPhone 17 `7A26EDD4-1542-45F9-A6CE-83D13D4C5219`. Boot it with `xcrun simctl boot`, run one file at a time, then `xcrun simctl shutdown` it. **Never** run them on `55746DB2…`: that is Severin's live session.
- Never run `flutter clean`.

## Review Focus

1. **Plus from the Tagebuch on a past day.** The entry lands on that day at 12:00. It does not land on today or at the current clock time. Pinned in Task 1 (`buildTrackedAt`, sheet extra) and Task 2 (nav from the diary).
2. **Deep links and gate in the new shell.**
   - `/dashboard`, `/diary`, `/discover` and `/me` all wait on `/loading` while the gate is pending, then continue to the held tab.
   - `/recommendations` and the tracker paths still open from a cold start.
   - Pinned in Task 2.
3. **Ring tap vs. Buddy poke.**
   - Tapping the Buddy inside the ring makes him talk and does not navigate.
   - Tapping a counter or the ring opens the Tagebuch on **today**, even when the Tagebuch was showing another day.
   - Pinned in Task 4.
4. **Small phone and large text.**
   - At 375×667 and text scale 1.3, Home shows chip, ring, button and insight card, and the 5-slot bar shows all labels, with no overflow.
   - Pinned in Task 2 (nav) and Task 4 (Home).
5. **Tutorial replay from Ich.**
   - The replay starts whether or not the Home branch has been built yet.
   - It starts exactly once.
   - Pinned in Task 8.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/utils/date_format_utils.dart` (modify) | `buildTrackedAt` uses the past-day 12:00 rule; adds `kMonthShortNames` and `formatLogTargetDay` |
| `lib/router/tracker_routes.dart` (create) | `CareNeed` → tracker path, `openTracker` |
| `lib/widgets/log_sheet/log_sheet.dart` (create) | the "Eintragen" sheet |
| `lib/router/route_names.dart`, `lib/router/app_router.dart` (modify) | `/discover` and `/me` branches; 4-branch shell without swipe |
| `lib/router/tab_navigation.dart` (create) | `openDiaryOn` |
| `lib/widgets/common/bb_bottom_nav.dart` (modify) | 5-slot bar; the plus opens the sheet |
| `lib/widgets/common/swipeable_pages.dart` (delete) | – |
| `lib/providers/buddy_onboarding_gate_provider.dart` (modify) | gate covers all 4 tab roots |
| `lib/screens/discover/discover_screen.dart` (create) | Entdecken hub (Task 6) |
| `lib/screens/me/me_screen.dart` (create) | Ich tab (Task 7) |
| `lib/services/buddy/daily_care.dart`, `lib/services/buddy/buddy_copy.dart` (modify) | vocabulary for needs and actions |
| `lib/screens/dashboard/widgets/care_ring.dart` (modify) | display-only counters; one `onTap` |
| `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart` (modify) | table filter; `fetchInsightProgress` |
| `lib/models/insight_progress.dart` (create) | `InsightProgress` value type |
| `lib/providers/insight_progress_provider.dart` (create) | loads and refreshes the progress |
| `lib/screens/dashboard/widgets/insight_card.dart` (create) | locked / "kommt bald" card |
| `lib/screens/dashboard/widgets/streak_sheet.dart` (modify) | `openStreakSheetAndSaveGoal` helper |
| `lib/screens/dashboard/dashboard_screen.dart`, `widgets/buddy_hero.dart` (modify) | Home H2 |
| `lib/screens/dashboard/widgets/today_list.dart`, `widgets/feature_card.dart`, `lib/widgets/common/tracker_card.dart` (delete when unused) | – |
| `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart` (delete) | pause dialog removed |
| `lib/screens/recipes/recipes_screen.dart`, `widgets/recipes_tab_toggle.dart` (modify / delete) | no Inspiration |
| `lib/providers/tutorial_provider.dart` (modify) | replay request |
| `lib/screens/dashboard/widgets/tutorial/*` (modify) | 7 new steps and keys |

---

### Task 1: The "Eintragen" sheet and the past-day time rule

**Files:**
- Modify: `lib/utils/date_format_utils.dart` (`buildTrackedAt`, at line ~107; add `kMonthShortNames`, `formatLogTargetDay`)
- Create: `lib/router/tracker_routes.dart`, `lib/widgets/log_sheet/log_sheet.dart`
- Modify: `lib/screens/diary/diary_screen.dart` (`_DiaryBody` empty state, ~line 204–256)
- Test: `test/utils/date_format_utils_test.dart`, `test/widgets/log_sheet/log_sheet_test.dart` (+ `flutter_test_config.dart`), `test/screens/diary/diary_screen_test.dart` (create if it doesn't exist)

**Interfaces:**
- Produces:
  - `DateTime buildTrackedAt(DateTime? initialDate, {DateTime? now})`
  - `const List<String> kMonthShortNames` (`['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez']`)
  - `String formatLogTargetDay(DateTime day)` → `'Mi, 18. Nov'`
  - `String trackerPathFor(CareNeed need)`
  - `void openTracker(BuildContext context, CareNeed need, {DateTime? at})`. It pushes `trackerPathFor(need)` with `extra: at`.
  - `Future<void> showLogSheet(BuildContext context, {required DateTime day, required DateTime now, CareNeed? suggested})`
  - `LogSheet.optionKey(CareNeed need)` → `ValueKey('log_sheet_${need.name}')`

- [ ] **Step 1: Failing tests for `buildTrackedAt` and `formatLogTargetDay`**

```dart
test('null initialDate → now', () {
  final now = DateTime(2026, 11, 23, 9, 41);
  expect(buildTrackedAt(null, now: now), now);
});
test('today keeps the current clock time', () {
  final now = DateTime(2026, 11, 23, 9, 41);
  expect(buildTrackedAt(DateTime(2026, 11, 23), now: now), DateTime(2026, 11, 23, 9, 41));
});
test('a past day defaults to 12:00', () {
  final now = DateTime(2026, 11, 23, 9, 41);
  expect(buildTrackedAt(DateTime(2026, 11, 18, 22, 5), now: now), DateTime(2026, 11, 18, 12));
});
test('formatLogTargetDay', () {
  expect(formatLogTargetDay(DateTime(2026, 11, 18)), 'Mi, 18. Nov');
  expect(formatLogTargetDay(DateTime(2026, 3, 2)), 'Mo, 2. Mär');
});
```
Update the existing `buildTrackedAt` group (line ~218) where it asserted the clock time for a past date.

- [ ] **Step 2:** Run `flutter test test/utils/date_format_utils_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** the rule. `now` defaults to `DateTime.now()`. If `initialDate` is on the same day as `now`, return that day at `now`'s hour and minute; otherwise return that day at 12:00. Build `formatLogTargetDay` from `kWeekdayShortNames` and `kMonthShortNames`. The meal, gut-feeling and toilet trackers already call `buildTrackedAt(initialDate)`. The drink tracker takes a full `initialTrackedAt`, so the sheet passes `buildTrackedAt(day, now: now)` for every type; the function is idempotent.

- [ ] **Step 4: Failing widget tests for the sheet**

`LogSheet` test cases:
- **`shows four options headed by the day`:** day = now (23.11.2026 12:40):
  - `find.text('Eintragen')` findsOneWidget;
  - `find.text('Heute · 12:40')` findsOneWidget;
  - options `Essen`, `Trinken`, `Bauchgefühl`, `Klo`, each found via `LogSheet.optionKey`.
- **`a past day reads Für …`:** day = 18.11.2026 → `find.text('Für Mi, 18. Nov')` findsOneWidget.
- **`suggested option is highlighted`:** `suggested: CareNeed.drink` → the drink option widget has `Semantics(selected: true)`, and the others don't.
- **`tapping an option pushes its tracker with the day at 12:00`:** use a test `GoRouter` with stub routes. Tap `Trinken` on day 18.11. The pushed location is `/drink-tracker` with `extra == DateTime(2026,11,18,12)`, and the sheet is closed.
- **`from today pushes extra null`:** day = now → `extra == null`.

- [ ] **Step 5: Implement** `showLogSheet`:
  - Use `showModalBottomSheet` with the existing `BbDragHandle`.
  - Title `'Eintragen'`. The subtitle is `'Heute · ${formatTime(now)}'` when `isSameDay(day, now)`, otherwise `'Für ${formatLogTargetDay(day)}'`.
  - Show 2×2 large buttons with the `CareNeed.emoji` and `CareNeed.label`. The suggested one gets the primary-colour border and fill used by the goal picker's selected style.
  - On tap: pop the sheet, then call `openTracker(context, need, at: isSameDay(day, now) ? null : buildTrackedAt(day, now: now))`.
  - New sizes go into `AppConstants` (for example `logSheetOptionHeight`).

- [ ] **Step 6: Diary empty state.** Test `empty day shows the Buddy line and no tracker cards`:
  - `find.text('Tipp unten aufs Plus, dann tragen wir was ein!')` findsOneWidget;
  - `find.byType(TrackerCard)` findsNothing;
  - the title is `'Noch keine Einträge für heute.'` / `'Keine Einträge an diesem Tag.'`.

  Implement the empty state:
  - a happy `MascotImage` (existing widget) of the size used in the diary cards;
  - the title;
  - the Buddy line in the same style as the old "Bereit zum Tracken?" text.

  Delete `TrackerCard` if it has no other users (grep first).

- [ ] **Step 7:** Run `flutter test test/utils test/widgets/log_sheet test/screens/diary`. Expected: PASS. Then run `dart format .` and `flutter analyze`.

- [ ] **Step 8: Commit** `feat(nav): one Eintragen sheet for all four entries; past days log at 12:00`

---

### Task 2: Four-tab shell with the plus in the middle

**Files:**
- Modify:
  - `lib/router/route_names.dart`
  - `lib/router/app_router.dart` (shell at line ~128–161)
  - `lib/widgets/common/bb_bottom_nav.dart`
  - `lib/providers/buddy_onboarding_gate_provider.dart:101`
- Create:
  - `lib/router/tab_navigation.dart`
  - `lib/screens/discover/discover_screen.dart`: a placeholder Scaffold with title `'Entdecken'`, filled in Task 6
  - `lib/screens/me/me_screen.dart`: a placeholder with title `'Ich'`, filled in Task 7
- Delete: `lib/widgets/common/swipeable_pages.dart`
- Test:
  - `test/router/buddy_onboarding_gate_test.dart`
  - `test/router/navigation_shell_test.dart` (create)
  - `test/widgets/common/bb_bottom_nav_test.dart` (create)

**Interfaces:**
- Consumes: `showLogSheet` (Task 1); `nextCareAction`, `DailyCare.fromEntries` (`lib/services/buddy/daily_care.dart`); `entriesProvider`; `diaryDateProvider`.
- Produces:
  - `RoutePaths.discover = '/discover'`, `RoutePaths.me = '/me'`, `RouteNames.discover = 'discover'`, `RouteNames.me = 'me'`
  - `buddyOnboardingGatedPaths = {dashboard, diary, discover, me}`
  - `BbBottomNav.navDiscoverKey = Key('bottom_nav_discover')`, `BbBottomNav.navMeKey = Key('bottom_nav_me')`; `navHomeKey`, `navDiaryKey` and `centerButtonKey` are kept
  - `void openDiaryOn(BuildContext context, WidgetRef ref, DateTime day)`. It sets `diaryDateProvider` to `startOfDay(day)` and then calls `context.go(RoutePaths.diary)`.
  - Branch indices: 0 Home, 1 Tagebuch, 2 Entdecken, 3 Ich.

- [ ] **Step 1: Failing tests**

`navigation_shell_test.dart`:
- **`bar shows five slots in order`:** labels `Home`, `Tagebuch`, `Eintragen`, `Entdecken`, `Ich`, appearing left to right (compare `tester.getCenter(...).dx`).
- **`tabs switch branches`:** tap `navDiscoverKey` → `DiscoverScreen` is shown; tap `navMeKey` → `MeScreen`.
- **`no swipe between tabs`:** a horizontal fling on Home stays on Home.
- **`plus on Home opens the sheet for now with the suggested need`:** with entries in which breakfast was logged at 09:00 and now is 12:40, tap `centerButtonKey` → the sheet shows `'Heute · 12:40'` and Essen is selected (lunch slot).
- **`plus on the Tagebuch logs for the shown day`:** set `diaryDateProvider` to 18.11.2026, select the Tagebuch, tap plus → `'Für Mi, 18. Nov'`, and no option is selected.
- **`tapping Tagebuch resets to today`:** existing behaviour, kept.
- **`5-slot bar fits 375×667 at text scale 1.3`:** `tester.view.physicalSize`/`devicePixelRatio` set to 375×667, `textScaleFactorTestValue = 1.3`, then `expect(tester.takeException(), isNull)`.

`buddy_onboarding_gate_test.dart` (extend):
- **`discover and me are held on /loading while pending`:** `/discover` → `/loading?…held=/discover` → `/discover` once resolved.
- **`/me` → `/buddy-onboarding` when required.**
- **`/recommendations is never gated`:** stays `null`.

- [ ] **Step 2:** Run these tests. Expected: FAIL.

- [ ] **Step 3: Implement the shell.**
  - Shell builder: `Scaffold(backgroundColor: AppTheme.background, body: navigationShell, bottomNavigationBar: BbBottomNav(...))`, with no `SwipeablePages`.
  - Add two `StatefulShellBranch`es for `/discover` and `/me`.
  - Extend the gated set.

- [ ] **Step 4: Implement the bar.**
  - The `Row` gets 5 children: `_NavItem` Home, `_NavItem` Tagebuch (keeps `TutorialKeys.tagebuch`), `_CenterButton` with label `'Eintragen'` (replacing "Essen tracken"), `_NavItem` Entdecken (`Icons.explore_outlined` / `Icons.explore`), and `_NavItem` Ich (`Icons.person_outline` / `Icons.person`).
  - The wave background is always `AppTheme.background`.
  - The plus:
    - `day = currentIndex == 1 ? ref.read(diaryDateProvider) : now`;
    - `suggested = isSameDay(day, now) ? nextCareAction(DailyCare.fromEntries(ref.read(entriesProvider), now), now).need : null`;
    - then `showLogSheet(...)`.
    - `now` comes from `ref.read(buddyClockProvider)()` (defined in `buddy_hero.dart`; move it to `lib/providers/buddy_provider.dart` next to `buddyTodayProvider` if importing the widget file into the nav is awkward).
  - Label widths: tighten `_NavItem` font and spacing via new `AppConstants` values only if the 375-px test overflows.

- [ ] **Step 5:** Run `flutter test test/router test/widgets/common`. Expected: PASS.

- [ ] **Step 6: Commit** `feat(nav): Home · Tagebuch · Eintragen · Entdecken · Ich`

---

### Task 3: Care ring as a display, and the vocabulary of needs

**Files:**
- Modify:
  - `lib/services/buddy/daily_care.dart` (`CareNeed`, `CareAction` doc)
  - `lib/services/buddy/buddy_copy.dart:143` (`careButton`)
  - `lib/screens/dashboard/widgets/care_ring.dart`
- Test: `test/services/buddy/buddy_copy_test.dart`, `test/screens/dashboard/widgets/care_ring_test.dart`

**Interfaces:**
- Produces:
  - `CareNeed.logLabel` becomes a getter: `'$label eintragen'`, giving `Essen eintragen`, `Trinken eintragen`, `Bauchgefühl eintragen` and `Klo eintragen`. The `logLabel` constructor field is removed.
  - `BuddyCopy.careButton(CareAction.feed) == '🍽 Essen eintragen'`. The drink and gut-feeling actions read `'💧 Trinken eintragen'` and `'🙂 Bauchgefühl eintragen'`. Breakfast, lunch, snack and dinner are unchanged.
  - `CareRing({required DailyCare care, required double diameter, required Widget buddy, required VoidCallback onTap, CareNeed? highlight})`. `onNeed` is removed. `CareRing.needKey` is kept for finding the counters.
  - `CareRing.tapKey = Key('care_ring_tap')`.

- [ ] **Step 1: Failing tests**
  - `careButton(CareAction.feed) == '🍽 Essen eintragen'`, `careButton(CareAction.drink) == '💧 Trinken eintragen'`.
  - **`counters are not buttons`:** for each need, `tester.getSemantics(find.byKey(CareRing.needKey(need)))` has no tap action, and its label contains `need.label`.
  - **`tapping a counter calls onTap once`.**
  - **`tapping the Buddy does not call onTap`:** the `buddy` slot is a `GestureDetector` test double whose tap is recorded; `onTap` count stays 0.

- [ ] **Step 2:** Run them. Expected: FAIL.

- [ ] **Step 3: Implement.**
  - `_NeedBubble` loses `onTap` and becomes `Semantics(container: true, label: '<label>: <value>')`.
  - The whole ring `Stack` is wrapped in `Semantics(button: true, label: 'Heute im Tagebuch ansehen', child: GestureDetector(key: CareRing.tapKey, behavior: HitTestBehavior.opaque, onTap: onTap, …))`. The Buddy's own `GestureDetector` inside wins the gesture arena.
  - Remove `_tutorialKeys` (bauchgefuehl/klo). Their `TutorialKeys` entries are deleted in Task 8.
  - Update every `CareNeed.logLabel` and `'Füttern'` user. `buddy_hero.dart` passes `onTap` in Task 4; until then pass `onTap: () {}`, so the tree compiles.

- [ ] **Step 4:** Run `flutter test test/services/buddy test/screens/dashboard/widgets/care_ring_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit** `refactor(home): the care ring shows, the button acts; „Essen eintragen" instead of „Füttern"`

---

### Task 4: Home H2: chip, ring → Tagebuch, one button, locked insight card

**Files:**
- Modify:
  - `lib/services/entry_query_service.dart:114` (`fetchTrackedAtSince` gains `Iterable<String>? tables`)
  - `lib/repositories/entry_repository.dart`
  - `lib/screens/dashboard/widgets/buddy_hero.dart`
  - `lib/screens/dashboard/widgets/streak_sheet.dart`
  - `lib/screens/dashboard/dashboard_screen.dart`
- Create:
  - `lib/models/insight_progress.dart`
  - `lib/providers/insight_progress_provider.dart`
  - `lib/screens/dashboard/widgets/insight_card.dart`
- Delete: `lib/screens/dashboard/widgets/today_list.dart` and its test
- Test:
  - `test/repositories/entry_repository_test.dart` (extend)
  - `test/providers/insight_progress_provider_test.dart`
  - `test/screens/dashboard/widgets/insight_card_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `CareRing(onTap:)` (Task 3), `openDiaryOn` (Task 2), `openTracker` (Task 1).
- Produces:
  - `class InsightProgress { const InsightProgress({required this.activeDays, required this.gutFeelingEntries}); static const daysNeeded = 7; static const gutFeelingsNeeded = 3; bool get unlocked; int get daysLeft; int get gutFeelingsLeft; }`
  - `Future<InsightProgress> EntryRepository.fetchInsightProgress({required String userId, required DateTime now})`. The window starts at `addDays(startOfDay(now), -29)`. `activeDays` is the number of distinct local days across all four tables. `gutFeelingEntries` is the row count in `gut_feeling_entries`, paginated through `fetchTrackedAtSince(tables: ['gut_feeling_entries'])`.
  - `insightProgressProvider`: `AsyncNotifierProvider<InsightProgressNotifier, InsightProgress>`. It watches `currentUserIdProvider`, refetches on each new `buddyEventsProvider` event, and offers `Future<void> refresh()`. Stage 2 replaces it.
  - `InsightCard({required AsyncValue<InsightProgress> progress})`, with `InsightCard.cardKey = Key('insight_card')`.
  - `Future<void> openStreakSheetAndSaveGoal(BuildContext context, WidgetRef ref, {required BuddyStatus status, required DateTime today})`. Extracted from `_BuddyHeroState._openStreakSheet` and `_saveGoal`; the hero keeps its `_goalCelebrating`/`_chipSheetOpen` guards.

- [ ] **Step 1: Failing data tests**
  - **`fetchInsightProgress counts distinct days and gut entries in 30 days`:** fake query service rows: 3 entries on day −1, 1 on day −5, 2 gut entries on day −1, 1 on day −40 (outside the window) → `InsightProgress(activeDays: 2, gutFeelingEntries: 2)`.
  - **`daysLeft/gutFeelingsLeft/unlocked`:** `(2,1)` → `daysLeft 5`, `gutFeelingsLeft 2`, `unlocked false`; `(7,3)` → `unlocked true`.
  - **`provider refetches after a log event`:** emit a `BuddyLogEvent` → the repository is called twice.

- [ ] **Step 2: Failing UI tests**

`InsightCard`:
- **`locked shows the days left and both bars`:**
  - `find.text('Was ich über deinen Bauch lerne')`;
  - `find.text('Noch 5 Tage, dann zeig ich dir erste Muster.')`;
  - `find.text('Tage mit Einträgen')` + `find.text('2 von 7')`;
  - `find.text('Bauchgefühl-Einträge')` + `find.text('1 von 3')`.
- **`singular`:** `(6,3)` → `'Noch 1 Tag, dann zeig ich dir erste Muster.'`
- **`days done, gut feelings missing`:** `(9,1)` → `'Noch 2 Bauchgefühl-Einträge, dann zeig ich dir erste Muster.'`; `(9,2)` → `'Noch 1 Bauchgefühl-Eintrag, dann zeig ich dir erste Muster.'`
- **`unlocked (Stage 1 interim)`:** `'Genug Einträge! Deine ersten Muster kommen bald.'`, the bars are absent, and the card has no tap action.
- **`error/loading hides the card`:** `find.byKey(InsightCard.cardKey)` findsNothing.

`BuddyHero` / Dashboard:
- **`Home shows chip, ring, one button and the insight card, nothing else`:**
  - findsNothing for `'Für dich erstellt'`, `'Heute'` (list title), `Icons.settings`, `Icons.feedback_outlined`, `StreakWeekRow`;
  - findsOneWidget for `BuddyHero.actionKey`, `InsightCard.cardKey`, `StreakChip`.
- **`ring tap opens the Tagebuch on today`:** set `diaryDateProvider` to an older day, tap `CareRing.tapKey` → the location is `/diary` and `diaryDateProvider == startOfDay(now)`.
- **`tapping the Buddy pokes, no navigation`:** tap `find.byType(AnimatedBuddy)` → the location stays `/dashboard`, and the bubble shows a mood line.
- **`next-action button opens the suggested tracker`:** before 05:00 with nothing logged, the drink suggestion → `/drink-tracker`.
- **`fits 375×667 at text scale 1.3`:** pump Home in the shell, `expect(tester.takeException(), isNull)`, and the bottom of `InsightCard` lies within the scroll content (scroll if needed; no overflow error).

- [ ] **Step 3:** Run them. Expected: FAIL.

- [ ] **Step 4: Implement.**
  - **`BuddyHero`:**
    - Remove the `StreakWeekRow`; the week row lives in the streak sheet only.
    - Pass `CareRing(onTap: () => openDiaryOn(context, ref, _now()))`.
    - The action button calls `openTracker(context, action.need ?? CareNeed.food)` and gets `KeyedSubtree(key: TutorialKeys.nextAction)` (key added in Task 8; until then use a local `GlobalKey`).
    - `_open` is replaced by `openTracker`.
  - **Dashboard:**
    - Remove `_DashboardHeader`, `_ForYouSection` and `TodayList`.
    - Stop fetching ingredient suggestions on Home.
    - The column is `BuddyHero(key: TutorialKeys.buddy)`, `AppConstants.gap16`, then `InsightCard(progress: ref.watch(insightProgressProvider))`.
    - `_loadData` also awaits `insightProgressProvider.notifier.refresh()`.
    - Keep the tutorial, opt-in and soft-nudge flow as it is.
  - **`InsightCard`:** styled like the mockup H2 card, using a `BbCard`, the uppercase label style of `StepFieldLabel`, and two progress bars with the theme's primary colour. Text and spacing come from `AppTheme`/`AppConstants` only.
  - Delete `today_list.dart` and its test.

- [ ] **Step 5:** Run `flutter test test/repositories test/providers test/screens/dashboard`. Expected: PASS.

- [ ] **Step 6: Commit** `feat(home): Buddy, ring, one button and what I'm learning about your gut`

---

### Task 5: Streak sheet from anywhere

**Files:** `lib/screens/dashboard/widgets/streak_sheet.dart`, `test/screens/dashboard/widgets/streak_sheet_test.dart`.

**Interfaces:** Produces `openStreakSheetAndSaveGoal` (signature in Task 4). Task 4 creates the helper while extracting it from the hero. This task covers its own tests and the week row inside the sheet.

- [ ] **Step 1: Failing tests**
  - **`helper saves the chosen goal`:** open, select 30, tap `'Ziel festlegen'` → `BuddyNotifier.setStreakGoal(30)` is called once.
  - **`helper with no change saves nothing`:** dismiss → no call.
  - **`sheet contains the week row`:** `find.byType(StreakWeekRow)` findsOneWidget.

- [ ] **Step 2:** Run. Expected: FAIL for the two helper tests if Task 4 left them uncovered; the week-row test documents existing behaviour.

- [ ] **Step 3: Implement** whatever the tests need. If a save fails, log it via `AppLogger` (same message as the hero's) and show the SnackBar `'Das Ziel konnte nicht gespeichert werden.'`.

- [ ] **Step 4:** Run `flutter test test/screens/dashboard/widgets/streak_sheet_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit** `refactor(streak): one way to open „Dein Streak" and save the goal`

---

### Task 6: Entdecken hub over the existing screens

**Files:**
- Create: `lib/screens/discover/discover_screen.dart` (replaces the placeholder); `lib/screens/discover/widgets/discover_section.dart`
- Modify:
  - `lib/screens/recommendations/recommendations_screen.dart` (remove the notice call at ~line 62–69; rename UI titles at 236 and 380 to `'Tipps'`)
  - `lib/providers/recommendation_provider.dart` (remove `recommendationsNoticeSeenProvider`)
  - `lib/screens/ingredient_suggestions/ingredient_suggestions_screen.dart:74` (`'Alternativen'`)
  - `lib/screens/recipes/recipes_screen.dart`: drop the toggle and `_InspirationTab`, showing `MyRecipesTab` directly
  - `lib/config/constants.dart` (`blogUrl`)
- Delete:
  - `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart` and its tests
  - `lib/screens/recipes/widgets/recipes_tab_toggle.dart`, if unused
  - `lib/screens/dashboard/widgets/feature_card.dart` and its test, if unused
- Test: `test/screens/discover/discover_screen_test.dart` (+ `flutter_test_config.dart`), recommendations, suggestions and recipes screen tests.

**Interfaces:**
- Consumes: `recommendationProvider` (newest-first `List<Recommendation>`), `unseenRecommendationCountProvider`, `ingredientSuggestionProvider` (+ `.notifier.newCount`), `userRecipesProvider` (+ `.notifier.fetch()`), `showAddRecipeChooserSheet`, `RecipeCard`.
- Produces:
  - `DiscoverScreen`
  - Keys: `DiscoverScreen.tipsKey = Key('discover_tips')`, `alternativesKey`, `recipesKey`, `knowledgeKey`
  - `AppConstants.blogUrl = 'https://www.myfodmap.at/blog'`

- [ ] **Step 1: Failing tests**
  - **`four sections in order`:** section titles `'Tipps'`, `'Alternativen'`, `'Meine Rezepte'`, `'Wissen'`, top to bottom.
  - **`Tipps card shows the newest set`:**
    - newest recommendation created 16.11.2026, 3 items, unseen count 1;
    - expect `'Neu'`, `'Woche 47'`, `'3 Tipps'` and its summary text;
    - tap → `/recommendations`.
  - **`no tips`:** `'Noch keine Tipps.'`, and the card is not tappable.
  - **`Alternativen previews the newest 3`:** given 5 groups → 3 ingredient names shown; `'Alle ›'` → `/ingredient-suggestions`; with `newCount` 2 → `'2 neu'`.
  - **`Meine Rezepte`:** recipes → up to 6 `RecipeCard`s; `'Alle ›'` → `/recipes`; `'+'` opens the chooser.
  - **`no recipes`:** `'Noch keine Rezepte.'` + `'Erstes Rezept erstellen'` (opens the chooser).
  - **`Wissen opens the blog`:** tap `knowledgeKey` → `launchUrl` is called with `AppConstants.blogUrl`. Use the url_launcher platform mock already used in the settings tests, if present; otherwise inject a launcher callback.
  - **Recommendations screen:** `no pause dialog` → after pumping, `find.text('Danke, dass du dabei bist! 💛')` findsNothing; the title shows `'Tipps'`.
  - **Recipes screen:** `no Inspiration` → `find.text('Inspiration')` findsNothing.
  - **Suggestions screen title:** `'Alternativen'`.

- [ ] **Step 2:** Run. Expected: FAIL.

- [ ] **Step 3: Implement.**
  - `DiscoverScreen` is a `CustomScrollView` with pull-to-refresh. `initState` fetches recommendations, suggestions and recipes.
  - The Tipps card body (2-line summary) comes from `Recommendation.summary`. The ISO week is computed from `createdAt.toLocal()`; add `int isoWeekOf(DateTime)` to `date_format_utils.dart` with a test.
  - Wissen card: title `'Wissen rund um die Verdauung'`, subtitle `'Artikel aus dem myfodmap-Blog'`, `LaunchMode.externalApplication`. Stage 3 replaces it with the in-app list.
  - Delete the dead code listed above, after grepping for users.

- [ ] **Step 4:** Run `flutter test test/screens/discover test/screens/recommendations test/screens/ingredient_suggestions test/screens/recipes`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(discover): Tipps, Alternativen, Meine Rezepte and Wissen in one tab; no pause dialog`

---

### Task 7: The Ich tab

**Files:**
- Create: `lib/screens/me/me_screen.dart` (replaces the placeholder), `lib/screens/me/widgets/rename_buddy_dialog.dart`
- Modify:
  - `lib/screens/settings/settings_screen.dart` (remove the "Feedback geben" tile, lines ~55–62)
  - `lib/providers/tutorial_provider.dart` (replay request; see Task 8 for how it is consumed)
- Test: `test/screens/me/me_screen_test.dart` (+ `flutter_test_config.dart`), `test/screens/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `buddyProvider` (`BuddyStatus.state.name`, `.streak`, `.state.streakGoal`), `BuddyNotifier.setName(String)`, `AppConstants.isValidBuddyName`, `AppConstants.buddyNameMaxLength`, `openStreakSheetAndSaveGoal` (Task 4), `currentVersionProvider` (`lib/providers/upgrade_gate_provider.dart`), `AppConstants.feedbackFormUrl`.
- Produces:
  - `MeScreen`
  - Keys: `MeScreen.renameKey = Key('me_rename')`, `streakKey`, `settingsKey`, `tutorialKey`, `feedbackKey`
  - `Future<String?> showRenameBuddyDialog(BuildContext context, {required String current})`
  - `TutorialNotifier.requestReplay()`

- [ ] **Step 1: Failing tests**
  - **`header shows the Buddy and his name`:** `find.byType(AnimatedBuddy)` findsOneWidget; the name text (e.g. `'Bruno'`); `StreakChip` present.
  - **`rows`:**
    - `'Streak & Ziel'` with subtitle `'🔥 3 Tage · Ziel: 14 Tage'`, or `'🔥 3 Tage · Noch kein Ziel'` without a goal;
    - `'Einstellungen'` (`'Profil, Benachrichtigungen, Konto'`);
    - `'Tutorial wiederholen'` (`'Die Tour durch Home nochmal ansehen'`);
    - `'Feedback geben'` (`'Teile uns deine Ideen und Wünsche mit'`);
    - the footer shows `'Version 1.2.3'` from the overridden `currentVersionProvider`.
  - **`rename saves a valid name`:** tap `renameKey` → dialog `'Buddy umbenennen'` → enter `'  Pepe '` → tap `'Speichern'` → `setName('Pepe')` is called once, and the header shows `Pepe`.
  - **`rename rejects empty and too long`:** `'   '` and a 21-character name → the error text `'Bitte gib einen Namen mit 1 bis 20 Zeichen ein.'` is shown, `'Speichern'` is disabled, and no `setName` call happens.
  - **`rename to the same name saves nothing`:** no `setName` call.
  - **`rename failure`:** `setName` throws → SnackBar `'Umbenennen hat nicht geklappt. Versuch es später nochmal.'`; the header keeps the old name.
  - **`Einstellungen pushes /settings`.**
  - **`Streak & Ziel opens „Dein Streak"`.**
  - **`Feedback opens the form`:** `launchUrl` with `AppConstants.feedbackFormUrl`.
  - **Settings:** `find.text('Feedback geben')` findsNothing.

- [ ] **Step 2:** Run. Expected: FAIL.

- [ ] **Step 3: Implement.**
  - The header uses its own `BuddyController` (mood happy, disposed with the state) in `AnimatedBuddy` at a new `AppConstants.meBuddySize`. Next to it are the name and a `TextButton('Umbenennen')`.
  - The rows are the existing settings list-tile style. Reuse the widget from `settings_screen.dart` if it is in `widgets/`; otherwise move it there.
  - The dialog trims its input and validates with `AppConstants.isValidBuddyName`, using a `maxLength` counter. It returns the new name or `null`.
  - **Tutorial wiederholen:** calls `ref.read(tutorialProvider.notifier).requestReplay()`, then `context.go(RoutePaths.dashboard)`.

- [ ] **Step 4:** Run `flutter test test/screens/me test/screens/settings`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(me): Ich tab with the Buddy, streak, settings, tutorial and feedback`

---

### Task 8: Tutorial for the new layout, replayable

**Files:**
- Modify:
  - `lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart`
  - `dashboard_tutorial_steps.dart`
  - `lib/providers/tutorial_provider.dart`
  - `lib/screens/dashboard/dashboard_screen.dart`
  - `buddy_hero.dart`, `insight_card.dart`, `bb_bottom_nav.dart` (key placement)
- Test:
  - `test/screens/dashboard/tutorial_overlay_test.dart`
  - `test/providers/tutorial_provider_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Produces:
  - `TutorialKeys` = { `buddy`, `nextAction`, `plus`, `insight`, `tagebuch`, `entdecken`, `ich` }. Removed: `bauchgefuehl`, `klo`, `essenTracken`, `fuerDich`, `alternativen`, `wissen`, `rezepte`, `feedback`, `settings`.
  - `dashboardTutorialSteps` has 7 steps in that order.
  - `TutorialNotifier`: `void requestReplay()`, `bool consumeReplay()`, backed by an in-memory flag (a `Notifier<bool>` named `tutorialReplayProvider`).

Step copy: bold parts are in `**`, built with the existing `_t`/`_b` helpers.
1. buddy: `Das ist dein **Buddy**! Jeder Eintrag hält euren 🔥 **Streak** am Leben. Der **Ring** zeigt, was er heute schon bekommen hat – tipp drauf für dein Tagebuch.`
2. nextAction: `Dieser Knopf schlägt dir den **nächsten Eintrag** vor – passend zur Tageszeit.`
3. plus: `Hier trägst du **alles** ein: Essen, Trinken, Bauchgefühl und Klo.`
4. insight: `Sobald genug Einträge da sind, zeig ich dir hier, **was mir an deinem Bauch auffällt**.`
5. tagebuch: `Im **Tagebuch** siehst du alle deine Einträge, Tag für Tag.`
6. entdecken: `Unter **Entdecken** findest du Tipps, Alternativen, deine Rezepte und Wissen rund um die Verdauung.`
7. ich: `Unter **Ich** kannst du mich umbenennen, dein Streak-Ziel ändern und alles einstellen.`

- [ ] **Step 1: Failing tests**
  - **`tour has 7 steps over the new keys`:** `dashboardTutorialSteps.length == 7`, keys in the order above; no step text contains `Serie`, `Speisen`, `tracken` or `1 x pro Tag`.
  - **`overlay advances through 7 steps`:** existing overlay test, with the count updated.
  - **`replay from Ich starts the tour on Home once`:** with the profile tutorial already seen, call `requestReplay()` before Home was ever built, then go to `/dashboard` → `'Überspringen'` is shown. After finishing, going back to Home again does not show it.
  - **`replay while Home is already built`:** Home built → switch to Ich → request → go to Home → the tour shows.
  - **`consumeReplay is true once`:** first call true, second false.

- [ ] **Step 2:** Run. Expected: FAIL.

- [ ] **Step 3: Implement.**
  - Key placement:
    - `TutorialKeys.plus` on the centre button.
    - `entdecken`/`ich` on their nav items.
    - `nextAction` on the hero button.
    - `insight` on `InsightCard`.
    - `buddy` stays on `BuddyHero`.
  - The dashboard checks `consumeReplay()` in its post-load microtask (next to `_maybeShowTutorial`), and also via `ref.listen(tutorialReplayProvider, …)` while built. A replay shows the overlay even when `tutorialSeenAt != null`, and still calls `markSeen()` at the end.

- [ ] **Step 4:** Run `flutter test test/screens/dashboard test/providers/tutorial_provider_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(tutorial): a 7-step tour of the new Home and tabs, replayable from Ich`

---

### Task 9: One vocabulary across the app (§5.9)

**Files:** the files listed below, plus their tests. Grep `test/` and `integration_test/` for every old string, and update the assertions.

**Exact replacements:**

| File | Old | New |
|---|---|---|
| `lib/screens/trackers/{gut_feeling,toilet,drink}/*_tracker_screen.dart` | button `'speichern'` / `'weiter'` | `'Speichern'` / `'Weiter'` |
| `lib/widgets/buddy/streak_chip.dart` | semantics "Serie" | "Streak" |
| `lib/services/reminder_copy.dart` | `Logbuch`, `Essens-Tagebuch` | `Tagebuch` |
| `lib/screens/settings/widgets/delete_account_dialog.dart` | `Ernährungstagebuch` | `Tagebuch` |
| `lib/utils/diary_helpers.dart` | card title `Toilettengang` | `Klo` |
| `lib/screens/trackers/toilet/toilet_tracker_screen.dart` | `Toilettengang gespeichert!` | `Klo-Eintrag gespeichert!` |
| `lib/screens/trackers/meal/meal_tracker_screen.dart` | `Getränk tracken`, `Getränk hinzufügen` | `Trinken eintragen` |
| `lib/screens/recipes/recipe_detail_screen.dart` | `Mahlzeit jetzt tracken` | `Jetzt als Essen eintragen` |
| `lib/screens/ingredient_suggestions/widgets/suggestion_card.dart`, `suggestion_detail_modal.dart` | `Speisen` | `Mahlzeiten` (fix the grammar of the surrounding phrase) |
| `lib/screens/buddy/buddy_onboarding_screen.dart:658` | `Mahlzeit eintragen` | `Essen eintragen` |
| `lib/screens/not_found_screen.dart` | `Zurück zum Dashboard` | `Zurück zu Home` |
| `lib/screens/settings/widgets/settings_notifications_screen.dart` | `Empfehlungen & Tipps` | `Tipps` |
| `lib/screens/recommendations/widgets/recommendation_feedback_view.dart` | `War diese Empfehlung hilfreich?`, `Empfehlung ausblenden` and every other user-facing "Empfehlung" | `War dieser Tipp hilfreich?`, `Tipp ausblenden`, "Tipp/Tipps" |

**Not changed:**
- The health-consent text (`health_consent_content.dart`, including "Toiletten-Einträge"). Per spec §5.9, legal texts change only where they name app sections, and this names a data type.
- Playful tracker titles (`Am Klo 💩 gewesen?`, `Wie geht es dir?`).
- The Buddy's bubble lines that say "füttern".

- [ ] **Step 1: Failing test** `test/utils/vocabulary_test.dart`. It scans `lib/**/*.dart` string literals, excluding `health_consent_content.dart`, `buddy_copy.dart` bubble pools and comments, and asserts that none contains:
  - `Essen tracken`, `Bauch-Buddy`, `Belly Freund`, `Logbuch`, `Essens-Tagebuch`, `Ernährungstagebuch`, `Zutaten-Vorschläge`, `Toilettengang`, `Stuhlgang`, `Getränk tracken`, `Getränk hinzufügen`, `jetzt tracken`, `Serie`;
  - a button label exactly `'speichern'` or `'weiter'`.

  Implement it with `Directory('lib').listSync(recursive: true)` and a regex over quoted strings.

- [ ] **Step 2:** Run it. Expected: FAIL, listing the offenders.

- [ ] **Step 3:** Apply the table above and update every affected test assertion.

- [ ] **Step 4:** Run `flutter test`. Expected: PASS for the whole suite.

- [ ] **Step 5: Commit** `fix(copy): one vocabulary: eintragen, Essen, Trinken, Bauchgefühl, Klo, Tagebuch, Tipps, Alternativen`

---

### Task 10: Integration tests for the new structure, and the stage check

**Files:**
- `integration_test/helpers/test_app.dart`
- `integration_test/meal_tracking_flow_test.dart`, `drink_tracking_flow_test.dart`, `diary_flow_test.dart`
- `integration_test/recipes_flow_test.dart` (navigation part only; its save-as-recipe case already fails on base)
- `integration_test/tutorial_flow_test.dart`, `auth_flow_test.dart`, `registration_flow_test.dart`

**Updated flows:**
- **Meal:** the centre button now opens the sheet. Tap `centerButtonKey`, then `LogSheet.optionKey(CareNeed.food)`.
- **Drink:** `centerButtonKey` → `LogSheet.optionKey(CareNeed.drink)`. The meal tracker's drink button is now labelled `'Trinken eintragen'`.
- **Diary:** a past-day plus entry lands on that day. Add the case: diary on yesterday → plus → Klo → save → the entry appears on yesterday's page.
- **Recipes:** reach recipes via `BbBottomNav.navDiscoverKey` → `DiscoverScreen.recipesKey` → `'Alle ›'`, instead of `FeatureCard`.
- **Tutorial:** 7 advances instead of 11; then the notification modal appears.
- **Auth/registration:** update any dashboard expectations (no `'Für dich erstellt'`; the Home check is now `BuddyHero.actionKey`).

- [ ] **Step 1:** Update the files above.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze` (0 issues) and `flutter test`. Expected: all pass.
- [ ] **Step 3: Integration tests on the second simulator**, one file at a time:
  ```bash
  xcrun simctl boot 7A26EDD4-1542-45F9-A6CE-83D13D4C5219 || true
  for f in tutorial_flow_test diary_flow_test drink_tracking_flow_test meal_tracking_flow_test registration_flow_test auth_flow_test recipes_flow_test; do
    flutter test integration_test/$f.dart -d 7A26EDD4-1542-45F9-A6CE-83D13D4C5219 --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown 7A26EDD4-1542-45F9-A6CE-83D13D4C5219
  ```
  Expected: every file `EXIT 0`, except `recipes_flow_test`'s pre-existing "save-as-recipe from the meal tracker success screen" case. Its navigation part must pass.
- [ ] **Step 4: Commit** `test(integration): flows through the new tabs and the Eintragen sheet`

---

## Self-Review notes
- **Spec coverage:**

  | Spec section | Task(s) |
  |---|---|
  | §5.1 | 2 |
  | §5.2 | 1, 2 |
  | §5.3 | 3, 4 (tips row deferred to Stage 3) |
  | §5.4 | 1 (empty state), 9 (vocabulary) |
  | §5.6 hub | 6 (opt-in, RSS and badge deferred to Stage 3) |
  | §5.8 | 5, 7 |
  | §5.9 | 3, 9 |
  | §5.10 | 8 |

  §5.5 is Stage 2; Task 4 gives only the locked card plus the interim "kommt bald" state, which is not tappable. §5.7 is Stage 3.
- **Interfaces used across tasks:**
  - `openTracker`/`trackerPathFor` (T1 → T4)
  - `showLogSheet` (T1 → T2)
  - `openDiaryOn` (T2 → T4)
  - `CareRing.onTap` (T3 → T4)
  - `openStreakSheetAndSaveGoal` (T4 → T5, T7)
  - `requestReplay`/`consumeReplay` (T7/T8)
  - `TutorialKeys.*` (T8; T4 uses a local key until then)
- **Release note:** `buddyClockProvider` currently lives in `buddy_hero.dart`. Task 2 may move it to `buddy_provider.dart`; if so, all imports must be updated in the same commit.
