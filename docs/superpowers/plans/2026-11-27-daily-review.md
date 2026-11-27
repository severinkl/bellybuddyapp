# Tagesrückblick und Ergebnis nach dem Essen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An evening review card on Home (the day in the user's own entries, one deterministic alternative, „Probiere ich"), an opt-in evening notice, a „Probiere ich" list in Alternativen, and a quiet after-meal result on the success screen and in the diary — no push per meal.

**Architecture:** Core adds one owner-only table `alternative_choices` and two profile columns. The app computes the review on the device from what it already loads (today's entries, the suggestion groups, the choices) with pure rules; Home shows it as a static card and the Buddy points to it with one queued speech line. The evening notice is a one-shot local notification rescheduled from the same inputs.

**Tech Stack:** Flutter, Riverpod, shared_preferences, flutter_local_notifications + timezone (present), supabase_flutter/PostgREST; core FastAPI/alembic/Postgres. No new package.

**Spec:** `docs/superpowers/specs/2026-11-27-daily-review-design.md` (branch `docs/plan-daily-review`).

## Repos and commands

| | App `bellybuddyapp` | Core `bellybuddy-core` |
|---|---|---|
| Branch | `feat/daily-review` from `feat/share-link` (stage 1); PR targets `feat/share-link` while it is unmerged, else `develop` | `feat/daily-review` from `feat/share-link`; same PR rule |
| Worktree | `~/projects/bellybuddy/.worktrees/daily-review` | `~/projects/bellybuddy-core/.worktrees/daily-review` |
| Tests | `flutter test <path>` | `cd backend && TEST_DATABASE_URL=… uv run pytest <path>` with the `worker` service stopped; local stack via `sg docker -c "docker compose up -d"` (DB 54322, api 18000) |
| Gates | `dart format --set-exit-if-changed . && flutter analyze` (zero issues); `dart run build_runner build` after model changes | `uv run ruff check . && uv run black --check . && uv run mypy --strict app` (in `backend/`) |
| Commits | pre-commit hook fails in worktrees: run the gates by hand, `git commit --no-verify` | as usual |

No simulator or emulator on the dev box: device behaviour goes to the spec's §9 list.

## Global Constraints

- App UI strings German, „du"; exact copy as in the spec §4.3/§4.6/§4.7 and repeated in tasks. Vocabulary test (`test/utils/vocabulary_test.dart`) must stay green: „eintragen", „Tipp", „Klo", never „Empfehlung", „tracken", „erfassen", „Speise", „Serie", „durchschnittlich".
- No praise or blame of the day, no „solltest", no cause („wegen"), never „Diagnose", „Auslöser", „Behandlung"; „könnte" for anything about the body.
- Mascot „Belly Buddy" / „Buddy".
- Colours only `static const Color` in `AppTheme`; font sizes only `AppTheme.fontSize*`; spacing/radii only `AppConstants`; add missing values there first. `CachedNetworkImage` for network images. Riverpod (`AsyncNotifier` for loaded state); GoRouter paths in `lib/router/`; `AppLogger`, never `print()`.
- `tracked_at` is the wall clock in the UTC slot: compare its year/month/day fields with the local day; never `toLocal()`. The device clock (`minuteProvider`, `todayProvider`) is local time.
- Per-user local flags under `<key>_<userId>`; user-owned rows through PostgREST + RLS.
- Core: `mypy --strict`; synthetic test data only; fixtures delete `profiles` as well as `auth.users`; no health data or user text in logs.
- No push per meal. No LLM call. No privacy-policy version bump (controller's shared task).
- Conventional commits; never merge or arm auto-merge; stop at `gh pr create`.

## Review Focus

1. **A meal stored as `2026-11-26T23:30:00Z` on a device in UTC−5 or UTC+9.** It belongs to 26 Nov for the window, the day's meal count and the 14-day count. Tests in DA2.
2. **The day's meals are not analysed yet, or the analysis failed.** The card shows the neutral line, never „nichts gefunden", and switches to the alternative once the refetch brings groups. Tests in DA2 and DA4.
3. **„Probiere ich" or „Passt nicht für mich" while offline.** SnackBar „Das hat nicht geklappt. Versuch es später noch einmal.", the line unchanged, no choice left in state. Tests in DA1 and DA4.
4. **Two accounts on one device.** Closed/said flags and choices of one never affect the other; a sign-out clears the choices. Tests in DA1 and DA3.
5. **Midnight and a changed review time.** At 23:59 → 00:00 the card turns into „Dein Rückblick auf gestern" (not closed, not gone); moving the time from 19:30 to 21:00 at 20:00 hides it until 21:00 and reschedules the notice; switching the reminder off cancels it. Tests in DA3 and DA7.

---

## Core

### Task DC1: `alternative_choices` and the review settings

**Files:**
- Create: `backend/migrations/versions/0017_daily_review.py` (next free number at build time; `down_revision` the head then), `backend/tests/db/test_alternative_choices.py`
- Modify: `backend/app/routes/delete_account.py` (`USER_ID_TABLES`, before `profiles`), `backend/tests/conftest.py` (cleanup table list), `backend/tests/db/test_baseline_inventory.py` (`EXPECTED_TABLES`), `backend/tests/db/test_rls.py` (`OWNED_ROW_SQL`, the forged-insert SQL), `backend/tests/routes/test_delete_account.py`

**Interfaces — Produces (SQL):**

```sql
create table public.alternative_choices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  ingredient_id uuid not null references public.ingredients (id) on delete cascade,
  replacement_ingredient_id uuid not null references public.ingredients (id) on delete cascade,
  choice text not null check (choice in ('try', 'skip')),
  created_at timestamptz not null default now(),
  unique (user_id, ingredient_id, replacement_ingredient_id)
);
-- RLS on; four policies `auth.uid() = user_id` (select, insert with check, update using+check, delete).
-- revoke all from anon, authenticated; grant select, insert, delete, update (choice) to authenticated.
alter table public.profiles
  add column daily_review_time text not null default '19:30' check (daily_review_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  add column daily_review_reminder boolean not null default false;
-- grant insert (both), update (both) on public.profiles to anon, authenticated  (as 0009 does)
```

FK names stay Postgres' defaults (`alternative_choices_ingredient_id_fkey`, `alternative_choices_replacement_ingredient_id_fkey`); the app's embeds name them.

- [ ] **Step 1: Write the failing tests** (`test_alternative_choices.py`, in the style of `test_buddy_state.py`):

```python
async def test_owner_inserts_reads_updates_and_deletes_own_choice()
async def test_choice_must_be_try_or_skip()            # 'maybe' → check violation
async def test_one_row_per_ingredient_and_replacement()  # second insert → unique violation; upsert on conflict updates choice
async def test_other_user_sees_and_changes_nothing()   # bob: select 0 rows, update/delete rowcount 0
async def test_anon_has_no_access()                    # "permission denied"
async def test_user_cannot_change_user_id_or_ingredient()  # update of user_id / ingredient_id denied (column grant)
async def test_rows_go_with_the_account()              # delete auth.users → 0 rows
async def test_profile_review_defaults_and_format()    # new profile: '19:30', false; '7:30' and '24:00' rejected; user can update both
```
`test_rls.py`: add `alternative_choices` to `OWNED_ROW_SQL` (uses `:ingredient` from the catalog fixture) and to the forged-insert SQL, so the existing cross-user tests cover it. `test_delete_account.py`: a seeded choice is gone after deletion.

- [ ] **Step 2: Run** `uv run pytest tests/db/test_alternative_choices.py tests/db/test_rls.py tests/db/test_baseline_inventory.py tests/routes/test_delete_account.py` — expected: FAIL (no table, no columns).
- [ ] **Step 3: Implement** the migration (docstring like 0016's: what, RLS, grants) with a `downgrade` dropping table and columns; add the table to the lists above.
- [ ] **Step 4: Run** the same tests plus `tests/db/test_rls.py::test_profiles_column_privileges` — expected: PASS.
- [ ] **Step 5: Commit** `feat(db): alternative_choices and the daily review settings`.

### Task DC2: Gates and PR (core)

- [ ] **Step 1:** ruff, `black --check`, `mypy --strict app`, full `uv run pytest` (worker stopped). Expected: all green.
- [ ] **Step 2:** After the owner's routine (simplify → code review → fix), push `feat/daily-review` and open the PR (`feat: alternative choices and daily review settings`) to `feat/share-link` (or `develop` once that merged), linking the app PR and the spec. Stop there.

---

## App

### Task DA1: Choices — model, service, provider

**Files:**
- Create: `lib/models/alternative_choice.dart`, `lib/services/alternative_choice_service.dart`, `lib/providers/alternative_choices_provider.dart`
- Modify: `lib/services/ingredient_service.dart` (`fetchReplacements` gets `.order('created_at')`)
- Test: `test/providers/alternative_choices_provider_test.dart`, `test/models/alternative_choice_test.dart`

**Interfaces — Produces:**

```dart
enum AlternativeChoiceKind { tryIt('try'), skip('skip'); const AlternativeChoiceKind(this.db); final String db; }

class AlternativeChoice {
  const AlternativeChoice({required this.id, required this.ingredientId, required this.ingredientName,
    required this.replacementId, required this.replacementName, required this.kind, required this.createdAt});
  final String id, ingredientId, ingredientName, replacementId, replacementName;
  final AlternativeChoiceKind kind;
  final DateTime createdAt;
  factory AlternativeChoice.fromRow(Map<String, dynamic> row);
  // row: {id, ingredient_id, replacement_ingredient_id, choice, created_at,
  //       ingredient: {name}, replacement: {name}}
}

class AlternativeChoiceService {        // wraps SupabaseClient
  Future<List<Map<String, dynamic>>> fetch(String userId);
  // select 'id, ingredient_id, replacement_ingredient_id, choice, created_at,
  //   ingredient:ingredients!alternative_choices_ingredient_id_fkey(name),
  //   replacement:ingredients!alternative_choices_replacement_ingredient_id_fkey(name)'
  // .eq('user_id', userId).order('created_at', ascending: false)
  Future<Map<String, dynamic>> upsert({required String userId, required String ingredientId,
    required String replacementId, required AlternativeChoiceKind kind});
  // upsert(onConflict: 'user_id,ingredient_id,replacement_ingredient_id').select(<same>).single()
  Future<void> delete(String id);
}
final alternativeChoiceServiceProvider = Provider<AlternativeChoiceService>(...);

class AlternativeChoicesNotifier extends AsyncNotifier<List<AlternativeChoice>> {
  // build: watches currentUserIdProvider; signed out → []; else fetch.
  Future<bool> choose({required String ingredientId, required String ingredientName,
    required ReplacementIngredient replacement, required AlternativeChoiceKind kind});
  Future<bool> remove(String choiceId);
}
final alternativeChoicesProvider = AsyncNotifierProvider<AlternativeChoicesNotifier, List<AlternativeChoice>>(...);

/// (ingredientId, replacementId) of every choice, try or skip; empty while loading or failed.
final chosenAlternativesProvider = Provider<Set<(String, String)>>(...);
/// The „Probiere ich" rows, newest first.
final triedAlternativesProvider = Provider<List<AlternativeChoice>>(...);
```

`choose` is optimistic (a provisional row in state at once), replaced by the server row; on error it is removed again, the error logged, `false` returned. `remove` likewise. A result arriving after a user change is dropped (`ref.isCurrentUser`, as in `ingredient_suggestion_provider.dart`).

- [ ] **Step 1: Write the failing tests** (fake service):

```dart
test('fromRow reads names from the two embeds and the kind from choice')
test('signed out: empty list, no fetch')
test('choose tryIt: in state at once; server row replaces it; chosenAlternatives contains (ing, rep)')
test('choose fails: state as before, returns false')
test('remove deletes the row; failure restores it and returns false')
test('a fetch finishing after a switch to user B does not show A\'s choices')
test('triedAlternatives lists only tryIt rows, newest first')
```

- [ ] **Step 2: Run** `flutter test test/providers/alternative_choices_provider_test.dart test/models/alternative_choice_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(alternatives): store „Probiere ich" and „Passt nicht für mich" choices`.

### Task DA2: The review rules and copy (pure)

**Files:**
- Create: `lib/services/daily_review/daily_review_rules.dart`, `lib/services/daily_review/daily_review_copy.dart`
- Modify: `lib/config/constants.dart`
- Test: `test/services/daily_review/daily_review_rules_test.dart`, `test/services/daily_review/daily_review_copy_test.dart`

**Interfaces — Produces:**

```dart
// constants.dart
static const String keyDailyReviewClosedPrefix = 'daily_review_closed_';   // + userId → yyyy-MM-dd
static const String keyDailyReviewSaidPrefix = 'daily_review_said_';       // + userId → yyyy-MM-dd
static const int dailyReviewCarryOverHour = 11;
static const int dailyReviewRecentDays = 14;
static const String dailyReviewDefaultTime = '19:30';
static const int dailyReviewEarliestMinutes = 16 * 60, dailyReviewLatestMinutes = 23 * 60 + 30;

// daily_review_rules.dart
class ReviewDay { const ReviewDay(this.day, {required this.yesterday}); final DateTime day; final bool yesterday; }

/// The day whose review is open at [now] (local), or null: today from [reviewMinutes] on;
/// otherwise yesterday until dailyReviewCarryOverHour; a closed day is never open.
ReviewDay? openReviewDay({required DateTime now, required int reviewMinutes, required DateTime? closedDay});

/// 'HH:MM' → minutes, clamped to [dailyReviewEarliestMinutes, dailyReviewLatestMinutes]; unparsable → 19:30.
int reviewMinutesOf(String? time);

/// Whether [trackedAt] (wall clock in the UTC slot) falls on local [day]: compares y/m/d fields only.
bool onWallClockDay(DateTime trackedAt, DateTime day);

class AlternativePick { const AlternativePick({required this.group, required this.replacement, required this.recentMeals});
  final IngredientSuggestionGroup group; final ReplacementIngredient replacement; final int recentMeals; }

AlternativePick? pickAlternative({required List<IngredientSuggestionGroup> groups,
  required Set<String> dayMealIds, required Set<(String, String)> chosen, required DateTime day});

class DailyReviewLine { const DailyReviewLine(this.text, {this.route}); final String text; final String? route; }

class DailyReview {
  final ReviewDay day; final int meals; final GutFeelingRatingLevel? lastGut;
  final AlternativePick? alternative; final bool alternativeLocked; final List<DailyReviewLine> extras;
}

/// Null without a meal on that day. lastGut: the level of the day's latest gut-feeling entry by trackedAt.
/// alternativeLocked keeps the pick (the card hides its names).
DailyReview? buildDailyReview({required ReviewDay day, required List<MealEntry> meals,
  required List<GutFeelingEntry> gutFeelings, required List<IngredientSuggestionGroup> groups,
  required Set<(String, String)> chosen, bool alternativeLocked = false, List<DailyReviewLine> extras = const []});
```

The pick follows the spec §4.2 exactly (candidates with a meal id in `dayMealIds` and a replacement; order by meals in the 14 wall-clock days ending with `day`, then latest meal, then name ignoring case; the first group with an unchosen replacement, its first unchosen replacement in `group.replacements` order).

`DailyReviewCopy` holds every string of spec §4.3 plus the cue line and notification bodies:
`title(ReviewDay)`, `meals(int, {required bool yesterday})`, `gut(GutFeelingRatingLevel)` („Dein Bauchgefühl zuletzt: {label}."), `gutHard` („Ich bin für dich da. 💛"), `gutAsk` („Magst du noch dein Bauchgefühl eintragen?"), `gutAskButton` („Bauchgefühl eintragen"), `alternative(String ingredient, String replacement, {required bool yesterday})`, `recent(String ingredient, int n)` („{Zutat} war in {n} deiner Mahlzeiten der letzten zwei Wochen."), `tryIt` („Probiere ich"), `skip` („Passt nicht für mich"), `saved` („Gemerkt! Du findest es unter Entdecken › Alternativen."), `savedOpen` („Ansehen"), `none({required bool yesterday})`, `locked` („Für morgen hätte ich eine Alternative für dich."), `upsell` („Mehr erfahren"), `failed` („Das hat nicht geklappt. Versuch es später noch einmal."), `close` („Schließen"), `cueLine` („Magst du kurz auf deinen Tag schauen? Er wartet gleich unter mir. 🌙"), `notificationBody(String? buddyName)`.

- [ ] **Step 1: Write the failing tests:**

```dart
// openReviewDay
test('19:29 → null; 19:30 → today; 23:59 → today')
test('00:00 next day → yesterday; 10:59 → yesterday; 11:00 → null')
test('review time 09:00 is clamped to 16:00')                 // via reviewMinutesOf
test('a closed today → null at 20:00; a closed yesterday → null at 08:00, today still opens at 19:30')
// onWallClockDay / buildDailyReview
test('a meal at 2026-11-26T23:30:00Z is on 26 Nov; one at 2026-11-27T00:10:00Z is not')
test('no meal that day → null; 1 meal → meals 1')
test('lastGut is the level of the latest entry of the day; none → null')
// pickAlternative
test('only groups with a meal of the day are candidates')
test('more meals in the last 14 days wins; a meal 15 days back does not count')
test('tie → latest meal; tie → name ignoring case')
test('a chosen (try or skip) replacement is skipped; the next replacement of the same group is picked')
test('all replacements of the top group chosen → the next group')
test('groups without replacements are never picked; nothing left → null')
// copy
test('meals: „Heute hast du 1 Mahlzeit eingetragen." / „Gestern hast du 3 Mahlzeiten eingetragen."')
test('alternative: „Statt Zwiebel könntest du morgen Frühlingszwiebel (grün) probieren." / „… heute …"')
test('none: today „Für morgen hab ich keine Alternative für dich. Genieß deinen Abend!", yesterday „Für heute hab ich keine Alternative für dich."')
test('notificationBody: null → „🌙 Dein Tagesrückblick ist da."; „Bobo" → „🌙 Bobo hat auf deinen Tag geschaut. Dein Tagesrückblick ist da."')
test('no string contains solltest, wegen, Diagnose, Auslöser, zu viel')
```

- [ ] **Step 2: Run** `flutter test test/services/daily_review` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, `flutter test test/utils/vocabulary_test.dart` and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(review): rules and copy of the daily review`.

### Task DA3: Profile fields and the review providers

**Files:**
- Modify: `lib/models/user_profile.dart` (two fields; `anyNotificationOn`, `withNotifications`), `test/helpers/fixtures.dart`
- Create: `lib/providers/daily_review_provider.dart`
- Test: `test/models/user_profile_test.dart` (or the existing migration test file), `test/providers/daily_review_provider_test.dart`

**Interfaces — Produces:**

```dart
// user_profile.dart
@JsonKey(name: 'daily_review_time') @Default('19:30') String dailyReviewTime,
@JsonKey(name: 'daily_review_reminder') @Default(false) bool dailyReviewReminder,
// anyNotificationOn: … || dailyReviewReminder
// withNotifications(on): dailyReviewReminder: on ? dailyReviewReminder : false

// daily_review_provider.dart
/// Seams (spec §4.8): the subscription track and Insights v2 replace these bodies.
final dailyReviewAlternativeLockedProvider = Provider<bool>((ref) => false);
final dailyReviewUpsellRouteProvider = Provider<String?>((ref) => null);
final dailyReviewExtrasProvider = Provider<List<DailyReviewLine>>((ref) => const []);

/// The signed-in user's closed review day (prefs), with close(day).
class DailyReviewClosedNotifier extends AsyncNotifier<DateTime?> { Future<void> close(DateTime day); }
final dailyReviewClosedProvider = AsyncNotifierProvider<DailyReviewClosedNotifier, DateTime?>(...);

/// The review open now (minuteProvider, profile time, closed day), or null.
final openReviewDayProvider = Provider<ReviewDay?>(...);

/// The open review built from that day's entries (today: entriesProvider when its day is today;
/// yesterday: diaryEntriesProvider(day)), ingredientSuggestionProvider's groups (empty while
/// loading/failed), chosenAlternativesProvider and the seams. Null while not open, signed out,
/// during the Buddy onboarding (buddyOnboardingRequiredProvider), or without a meal that day.
final dailyReviewProvider = Provider<DailyReview?>(...);

/// Whether the Buddy's line was said for [day] (prefs), and recording it.
Future<bool> dailyReviewSaidOn(String userId, DateTime day);
Future<void> recordDailyReviewSaid(String userId, DateTime day);
```

- [ ] **Step 1: Write the failing tests** (ProviderContainer, `SharedPreferences.setMockInitialValues`, a fixed `buddyClockProvider`, fake repositories as in existing provider tests):

```dart
test('profile JSON without the new keys → 19:30 and false; with them → read')
test('withNotifications(true) keeps dailyReviewReminder false; withNotifications(false) clears true')
test('at 19:30 with one meal today → review for today; with no meal → null')
test('at 08:00 with a meal yesterday → yesterday review from the diary day')
test('the minute ticks from 19:29 to 19:30 → review appears without other changes')
test('23:59 → 00:00: today\'s review becomes yesterday\'s')
test('close(today) → null for the rest of today; user B on the same device still sees theirs')
test('profile time changed to 21:00 at 20:00 → null until 21:00')
test('groups still loading → review with alternative null; groups arrive → alternative set')
test('dailyReviewAlternativeLockedProvider overridden true → alternativeLocked true, pick kept')
test('during the Buddy onboarding → null')
```

- [ ] **Step 2: Run** `dart run build_runner build`, then `flutter test test/providers/daily_review_provider_test.dart test/models` — expected: new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, `flutter test test/screens/settings test/repositories/notification_repository_test.dart` (existing profile users) and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(review): review window and providers`.

### Task DA4: The Home card

**Files:**
- Create: `lib/screens/dashboard/widgets/daily_review_card.dart`
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (the card under `BuddyHero`, before the insight card, in a `Consumer`, with `AppConstants.gap16` only when shown)
- Test: `test/screens/dashboard/widgets/daily_review_card_test.dart`, `test/screens/dashboard/dashboard_screen_test.dart` (placement)

**Interfaces — Consumes:** `dailyReviewProvider`, `dailyReviewClosedProvider.notifier.close`, `alternativeChoicesProvider.notifier.choose`, `dailyReviewUpsellRouteProvider`, `ingredientSuggestionProvider.notifier.fetchSuggestions`, `DailyReviewCopy`.
**Produces:** `DailyReviewCard` with keys `cardKey`, `closeKey`, `tryKey`, `skipKey`, `savedOpenKey`, `gutAskKey`, `upsellKey`.

Behaviour: texts and order per spec §4.3. On first build while shown, once per Home visit, `fetchSuggestions()`. „Probiere ich" → `choose(kind: tryIt)`: true → the saved line with „Ansehen" (pushes `RoutePaths.ingredientSuggestions`) for the rest of this card's life; false → SnackBar `DailyReviewCopy.failed`. „Passt nicht für mich" → `choose(kind: skip)`: the provider's next pick shows by itself; false → SnackBar. „Bauchgefühl eintragen" opens the gut-feeling tracker the way Home's ring does. „×" → `close(review.day.day)`. Locked: `locked` line, no names, no try/skip; „Mehr erfahren" only with a non-null upsell route.

- [ ] **Step 1: Write the failing tests** (provider overrides with built `DailyReview` values):

```dart
testWidgets('today with a pick: title, meals line, gut line, alternative, recent caption, both buttons')
testWidgets('Schlecht as last gut feeling: „Ich bin für dich da. 💛" follows the level line')
testWidgets('no gut feeling today: „Bauchgefühl eintragen" opens the tracker; yesterday: no ask')
testWidgets('no pick: the neutral line, no buttons')
testWidgets('Probiere ich: choose(tryIt) once; then „Gemerkt! …" and „Ansehen" opens Alternativen')
testWidgets('Probiere ich fails: SnackBar „Das hat nicht geklappt. Versuch es später noch einmal.", buttons stay')
testWidgets('Passt nicht für mich: choose(skip); the next pick from the provider shows')
testWidgets('locked: „Für morgen hätte ich eine Alternative für dich.", ingredient not shown; „Mehr erfahren" only with a route')
testWidgets('× closes for that day')
testWidgets('extras lines render between the day and the alternative')
testWidgets('the card asks fetchSuggestions once per Home visit')
testWidgets('Home: the card sits between the Buddy and the insight card; absent when dailyReviewProvider is null')
```

- [ ] **Step 2: Run** `flutter test test/screens/dashboard` — expected: new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/screens/dashboard` and both gates — expected: PASS, existing tests unchanged.
- [ ] **Step 5: Commit** `feat(review): the daily review card on Home`.

### Task DA5: The Buddy's line

**Files:**
- Modify: `lib/screens/dashboard/widgets/buddy_hero.dart`
- Test: `test/screens/dashboard/widgets/buddy_hero_test.dart`

**Interfaces — Consumes:** `dailyReviewProvider`, `dailyReviewSaidOn`, `recordDailyReviewSaid`, `DailyReviewCopy.cueLine`.

Behaviour, next to the reminders-ask counterparts (`_queueRemindersAsk`, `_remindersAskQueued`, `_sheetCuePlayed`):
- A cue `_Cue.dailyReview(null)` declared after `remindersAsk` (and before any rating cue the rating track adds; any guided-test cue of Insights v2 goes before it).
- Queued when Home becomes visible and when `dailyReviewProvider` turns non-null (listened with `fireImmediately`), if not queued yet this visit and not said for that review day.
- At play: re-check (still a review, still not said); skipped without being said when `_sheetCuePlayed`; else `_say(cueLine)`, `_holdStage()`, and `recordDailyReviewSaid`.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('review open: the Buddy says the line once; a second Home visit the same evening: silent')
testWidgets('the reminders ask and a day\'s reward are due: they play first; the line is skipped this visit and said on the next')
testWidgets('„Neue Tipps" (no sheet) is due: it plays first, then the line')
testWidgets('the review closes while the line waits: nothing said, nothing recorded')
testWidgets('the next evening: said again')
```

- [ ] **Step 2: Run** `flutter test test/screens/dashboard/widgets/buddy_hero_test.dart` — expected: new tests FAIL.
- [ ] **Step 3: Implement.** Only the cue, its queueing and its play branch; if more than that is needed, stop and report it as a concern.
- [ ] **Step 4: Run** `flutter test test/screens/dashboard` and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(review): the Buddy points to the daily review`.

### Task DA6: „Probiere ich" in Alternativen

**Files:**
- Create: `lib/screens/ingredient_suggestions/widgets/tried_alternatives_section.dart`
- Modify: `lib/screens/ingredient_suggestions/ingredient_suggestions_screen.dart` (the section above the search field)
- Test: `test/screens/ingredient_suggestions/tried_alternatives_section_test.dart`

**Interfaces — Consumes:** `triedAlternativesProvider`, `alternativeChoicesProvider.notifier.remove`.

Section title „Probiere ich"; one row per item „{replacementName} statt {ingredientName}", newest first; trailing `IconButton(Icons.close)` with tooltip „Nicht mehr merken" → `remove(id)`; false → SnackBar `DailyReviewCopy.failed`. Absent without items.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('two tried items: „Frühlingszwiebel (grün) statt Zwiebel" first (newest), then the older')
testWidgets('skip choices are not listed; none tried: no section')
testWidgets('„Nicht mehr merken" removes the row; failure: SnackBar, row stays')
```

- [ ] **Step 2: Run** `flutter test test/screens/ingredient_suggestions` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(alternatives): „Probiere ich" list in Alternativen`.

### Task DA7: Settings and the evening notice

**Files:**
- Modify: `lib/services/local_notification_service.dart`, `lib/repositories/notification_repository.dart` (scheduler interface), `lib/screens/settings/widgets/settings_notifications_screen.dart`, `lib/app.dart` (watch the sync next to `notificationSyncProvider`)
- Create: `lib/providers/daily_review_reminder_provider.dart`
- Test: `test/providers/daily_review_reminder_provider_test.dart`, `test/screens/settings/settings_notifications_test.dart`, `test/services/local_notification_service_test.dart` (if present; else the repository test)

**Interfaces — Produces:**

```dart
// LocalNotificationService (and the repository's scheduler seam)
static const _dailyReviewId = 3000;           // channel 'daily_review', name 'Tagesrückblick',
                                              // description 'Sagt dir Bescheid, wenn dein Tagesrückblick da ist'
static Future<void> scheduleDailyReview({required int hour, required int minute,
  required String timezone, String? buddyName});   // one-shot today at hour:minute (no matchDateTimeComponents),
                                                   // payload RoutePaths.dashboard; replaces a pending one
static Future<void> cancelDailyReview();

// daily_review_reminder_provider.dart
/// Pure: whether today's notice should be pending.
bool dailyReviewNoticeDue({required bool reminderOn, required int todayMeals,
  required DateTime now, required int reviewMinutes, required DateTime? closedDay});
/// Schedules or cancels from profile, today's meals (entriesProvider for today), minute-free inputs
/// (it is evaluated on changes, not every minute), the closed day and the Buddy's name; errors logged.
final dailyReviewReminderSyncProvider = Provider<void>(...);
```

Settings section per spec §4.6: „Tagesrückblick" (`Icons.nightlight_outlined`), row „Ab" + time → `showTimePicker` (24 h), stored as `HH:MM` after `reviewMinutesOf` clamping, saved immediately; caption „Ab dieser Uhrzeit zeigt dir Home deinen Rückblick auf den Tag."; switch „Erinnerung am Abend" inside `_Greyed(enabled: allowed)`, caption „Ich sag dir Bescheid, wenn er da ist – nur an Tagen mit eingetragener Mahlzeit."

- [ ] **Step 1: Write the failing tests:**

```dart
test('due: on, 1 meal, 18:00, review 19:30, not closed → true; off / 0 meals / 19:30 / closed → false')
test('sync: first meal of the day saved at 12:00 with the reminder on → scheduleDailyReview(19, 30) once')
test('sync: switch off → cancelDailyReview; time changed to 21:00 → scheduled at 21:00')
test('sync: card closed before the time → cancelled')
testWidgets('settings: section shows „Ab 19:30"; picking 21:15 stores "21:15"; picking 09:00 stores "16:00"')
testWidgets('settings: the switch is greyed while notifications are not allowed; the time row is not')
testWidgets('settings: turning the master switch on leaves „Erinnerung am Abend" off')
```

- [ ] **Step 2: Run** the three test paths — expected: FAIL.
- [ ] **Step 3: Implement.** Android channel created in `initialize` like the other two.
- [ ] **Step 4: Run** the tests, `flutter test test/screens/settings test/repositories` and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(review): review time and the evening notice`.

### Task DA8: After a meal — the quiet result (B2)

**Files:**
- Modify: `lib/repositories/meal_media_repository.dart` (`triggerSuggestionRefresh` → `Future<int> refreshSuggestions()` returning `created`), `lib/providers/meal_tracker_provider.dart` (`savedMealId`; background refresh then `fetchSuggestions()`), `lib/screens/trackers/meal/meal_tracker_screen.dart` (the line on the success screen), `lib/screens/diary/widgets/detail_sheets/meal_detail.dart` (the line under „Zutaten"; becomes a `ConsumerWidget`)
- Create: `lib/widgets/common/flagged_ingredients_line.dart`, and in `ingredient_suggestion_provider.dart` a `mealSuggestionGroupsProvider`
- Test: `test/providers/meal_tracker_provider_test.dart`, `test/widgets/common/flagged_ingredients_line_test.dart`, `test/screens/trackers/meal/meal_tracker_screen_test.dart`, `test/screens/diary/meal_detail_test.dart`

**Interfaces — Produces:**

```dart
Future<int> refreshSuggestions();   // invoke('refresh-ingredient-suggestions') → (data['created'] as num?)?.toInt() ?? 0
// MealTrackerState: final String? savedMealId;  (create mode only, like savedImageUrl)
/// The suggestion groups that contain [mealId], by ingredient name; empty while loading or failed.
final mealSuggestionGroupsProvider = Provider.family<List<IngredientSuggestionGroup>, String>(...);
class FlaggedIngredientsLine extends StatelessWidget {
  const FlaggedIngredientsLine({super.key, required this.names, required this.onOpen});
  static String text(List<String> names);
  // 1: „Zwiebel könnte deinem Bauch zu schaffen machen."
  // 2: „Zwiebel und Knoblauch könnten deinem Bauch zu schaffen machen."
  // ≥3: „Zwiebel, Knoblauch und 2 weitere könnten deinem Bauch zu schaffen machen."
  // link „Alternativen ansehen ›"
}
```

`save()` starts `refreshSuggestions()` unawaited and, when it completes, `fetchSuggestions()` (errors logged; never blocks the success screen). The success screen shows the line above „Trinken eintragen" once `mealSuggestionGroupsProvider(savedMealId)` is non-empty; the diary meal detail shows it whenever non-empty. The link pushes `RoutePaths.ingredientSuggestions`.

- [ ] **Step 1: Write the failing tests:**

```dart
test('save: refreshSuggestions is called once, then fetchSuggestions once it completes')
test('refreshSuggestions throws: logged, the success state is set, no fetch')
test('create mode stores savedMealId; edit mode does not')
test('text: 1, 2 and 4 names give the three sentences')
testWidgets('success screen: groups for the meal arrive while it is up → the line and the link appear')
testWidgets('success screen: no groups → no line, no placeholder')
testWidgets('diary meal detail: groups for the meal → the line under „Zutaten"; tap opens Alternativen')
```

- [ ] **Step 2: Run** the four test paths — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, `flutter test test/screens/trackers test/screens/diary` and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(meal): show flagged ingredients after a meal, without a push`.

### Task DA9: Gates and PR (app)

- [ ] **Step 1:** `dart format --set-exit-if-changed .`, `flutter analyze`, full `flutter test`. Expected: all green, including `test/utils/vocabulary_test.dart`.
- [ ] **Step 2:** After the owner's routine (simplify → code review → fix), push `feat/daily-review` and open the PR (`feat: daily review and the after-meal result`) to `feat/share-link` (or `develop` once that merged), linking the core PR and the spec; list the spec's §9 manual checks and the policy paragraph (§5) for the shared policy task. Stop there.
