# Buddy Alltag (Part 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Buddy the heart of the everyday app: persisted Buddy state, a streak derived from entries with streak savers, a care-driven mood, a dashboard hero, animated Buddy reactions on all four tracker success screens, and Buddy-voiced reminders.

**Architecture:** New `buddy_state` table (bellybuddy-core Alembic migration, PostgREST + RLS). App: Freezed `BuddyState` → `BuddyService` → `BuddyRepository` (Supabase impl + SharedPreferences impl for dev) → `BuddyNotifier` (`AsyncNotifier`) which runs a pure `evaluateStreak` over activity days fetched from the four entry tables (`tracked_at`). Trackers emit a `BuddyLogEvent`; success screens render an animated reaction; the dashboard hero derives mood from today's entries.

**Tech Stack:** Flutter/Riverpod 3/GoRouter/Freezed/mocktail (app); Python/Alembic/pytest/Postgres (core).

**Spec:** `docs/superpowers/specs/2026-11-22-animated-buddy-design.md` (§6). Depends on Plan 1 (`docs/superpowers/plans/2026-11-22-buddy-1-rig.md`) — import everything from `package:belly_buddy/widgets/buddy/buddy.dart`.

## Global Constraints

- App worktree `/Users/sevi/projects/bellybuddy/.worktrees/animated-buddy`, branch `feat/animated-buddy`. Core work happens in a separate worktree of `/Users/sevi/projects/bellybuddy-core` on branch `feat/buddy-state` off `develop` (Task 1 creates it).
- CLAUDE.md design-token rules (colors in `AppTheme`, `AppTheme.fontSize*`, `AppConstants` spacing/radii), `AppLogger`, `dart format`, `flutter analyze` zero issues, `dart run build_runner build --delete-conflicting-outputs` after Freezed changes.
- UI files import `package:material_ui/material_ui.dart`.
- Services take a `SupabaseClient`; providers are declared at the bottom of their own file (pattern: `profile_service.dart`, `profile_repository.dart`, `profile_provider.dart`).
- Tests: hand-written fakes in `test/helpers/fakes.dart`, mocktail mocks in `test/helpers/mocks.dart`, Supabase builders in `test/helpers/supabase_mocks.dart`, `tester.pumpWithProviders` in `test/helpers/riverpod_helpers.dart`. Place tests under CI-run dirs: `test/models/ test/utils/ test/services/ test/repositories/ test/providers/ test/screens/ test/widgets/`.
- German copy, "du", warm and a little cheeky, never medical advice. The Buddy never gets sick, never guilt-trips.
- A day = local device calendar day of `tracked_at.toLocal()`.
- Commit prefixes conventional (`feat(buddy):`, `feat(db):`, `test:` …).

## Review Focus

1. **New user with zero entries / no `buddy_state` row**: dashboard must render (Buddy `sleepy` or `hungry`, streak chip "0 Tage"), no crash, no saver consumption. Test in Task 6 and Task 9.
2. **Signed-out / user switch**: `buddyProvider` must not leak the previous user's state (it must rebuild on `currentUserIdProvider` change) and must not throw while signed out. Test in Task 6.
3. **Backend without the table yet / network error** on `buddy_state` fetch: dashboard still renders the Buddy with streak hidden; error logged via `AppLogger`, no red screen. Test in Task 6.
4. **Midnight and DST**: an entry at 23:59 local and one at 00:01 the next day count as two days; the spring-forward day still counts as one day. Test in Task 5.
5. **Backfilled day after a saver was spent**: refund exactly once, saver stock never exceeds 2. Test in Task 5.

---

### Task 1: Core — `buddy_state` table (bellybuddy-core)

**Files (repo `/Users/sevi/projects/bellybuddy-core`):**
- Create worktree: `git -C /Users/sevi/projects/bellybuddy-core worktree add -b feat/buddy-state ../bellybuddy-core-buddy-wt develop`
- Create: `backend/migrations/versions/0008_buddy_state.py`
- Modify: `backend/tests/db/test_rls.py` (`OWNED_ROW_SQL`, `FORGED_INSERT_SQL`), `backend/tests/db/test_baseline_inventory.py` (`EXPECTED_TABLES`), `backend/app/routes/delete_account.py` (`USER_ID_TABLES`), `backend/tests/routes/test_delete_account.py` (`ROW_COUNTS`, `seed_everything`), `backend/tests/routes/conftest.py` (`USER_TABLES`), `backend/app/routes/admin_generate_test_personas.py` (`PERSONA_TABLES`), `migrate/tests/test_restore.py` (`_restore_set()` exclusion + the exact "added after baseline" report line)
- Test: `backend/tests/db/test_buddy_state.py`

**Schema (Claude's call: own `id` PK so the generic RLS tests that use `returning id` / `where id = :id` apply unchanged; `user_id` unique):**
```sql
create table public.buddy_state (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null default 'Buddy' check (char_length(btrim(name)) between 1 and 20),
  streak_goal integer check (streak_goal in (7, 14, 30, 50, 100)),
  savers integer not null default 0 check (savers between 0 and 2),
  saved_days date[] not null default '{}',
  last_milestone integer not null default 0 check (last_milestone >= 0),
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```
Plus: `enable row level security`; `revoke all … from anon, authenticated`; `grant select, insert, update … to authenticated` (no delete, no anon — account deletion runs as the api role); policies `"Users can view their own buddy state"` (select), `"Users can create their own buddy state"` (insert, `with check (auth.uid() = user_id)`), `"Users can update their own buddy state"` (update, `using` + `with check` `auth.uid() = user_id`), all `to authenticated`; trigger `update_buddy_state_updated_at before update … execute function public.update_updated_at_column()`. Downgrade: `drop table public.buddy_state`. Module docstring in the style of 0007 (why each grant).

- [ ] **Step 1:** Create the worktree. Check the local stack: `docker compose ps` in the worktree (start with `docker compose up -d --build --wait db auth storage migrate` per README; stop `worker`). If Docker is unavailable, note it and rely on CI for the DB tests (still write them).
- [ ] **Step 2: Write failing tests** `test_buddy_state.py` (use `session`, `make_user`, `as_user`, `as_anon` fixtures): owner can insert/select/update own row; other user sees 0 rows and cannot update; anon cannot select; insert with `savers = 3` or `name = ''` or `streak_goal = 8` raises (inside `session.begin_nested()`); `updated_at` changes on update; deleting the `auth.users` row cascades. Add `buddy_state` to the generic RLS fixture dicts and inventory.
- [ ] **Step 3: Run** `cd backend && TEST_DATABASE_URL=... uv run pytest tests/db -q` → new tests FAIL.
- [ ] **Step 4: Implement** the migration; add `buddy_state` to every table list named in Files; update `migrate/tests/test_restore.py` so a table created after the baseline export (`buddy_state`) is excluded from `_restore_set()` and the expected report lines include it (sorted).
- [ ] **Step 5: Run** backend tests (`uv run pytest`) and migrate tests (`uv run --project backend pytest migrate/tests`) → PASS; `pre-commit run --all-files` (black/ruff/flake8/mypy) → clean.
- [ ] **Step 6: Commit** `feat(db): buddy_state table for the animated Buddy`

### Task 2: App model + service + repositories

**Files:**
- Create: `lib/models/buddy_state.dart`, `lib/services/buddy_service.dart`, `lib/repositories/buddy_repository.dart`
- Modify: `lib/repositories/repositories.dart` (export), `test/helpers/fakes.dart` (`FakeBuddyRepository`), `test/helpers/mocks.dart` (`MockBuddyService`)
- Test: `test/models/buddy_state_test.dart`, `test/services/buddy_service_test.dart`, `test/repositories/buddy_repository_test.dart`

**Interfaces:**
- Produces:
  ```dart
  @freezed abstract class BuddyState with _$BuddyState {
    const factory BuddyState({
      String? id,
      @JsonKey(name: 'user_id') String? userId,
      @Default('Buddy') String name,
      @JsonKey(name: 'streak_goal') int? streakGoal,
      @Default(0) int savers,
      @JsonKey(name: 'saved_days') @DateOnlyListConverter() @Default(<DateTime>[]) List<DateTime> savedDays,
      @JsonKey(name: 'last_milestone') @Default(0) int lastMilestone,
      @JsonKey(name: 'onboarding_completed_at') DateTime? onboardingCompletedAt,
    }) = _BuddyState;
    factory BuddyState.fromJson(Map<String, dynamic> json) => _$BuddyStateFromJson(json);
  }
  class DateOnlyListConverter implements JsonConverter<List<DateTime>, List<dynamic>> // 'yyyy-MM-dd' <-> local-midnight DateTime
  class BuddyService { BuddyService(SupabaseClient); Future<Map<String, dynamic>?> fetchByUserId(String userId); Future<void> upsert(Map<String, dynamic> data); } // table 'buddy_state', upsert onConflict 'user_id'
  final buddyServiceProvider = Provider<BuddyService>(...);
  abstract class BuddyRepository { Future<BuddyState?> fetch(String userId); Future<void> save(String userId, BuddyState state); }
  class SupabaseBuddyRepository implements BuddyRepository // strips id/updated_at, sets user_id, onboarding_completed_at as UTC ISO
  class LocalBuddyRepository implements BuddyRepository // SharedPreferences key 'buddy_state_<userId>', JSON
  final buddyRepositoryProvider = Provider<BuddyRepository>(...); // LocalBuddyRepository when const bool.fromEnvironment('BUDDY_LOCAL_STATE') else Supabase
  ```
- Add `static const String keyBuddyStatePrefix = 'buddy_state_';` to `AppConstants`.

- [ ] **Step 1: Failing tests:** JSON round-trip incl. `saved_days: ['2026-11-20']` ↔ `DateTime(2026,11,20)`; defaults (`name 'Buddy'`, `savers 0`); `SupabaseBuddyRepository.save` calls `upsert` with `user_id` set and no `id` key (mocktail `MockBuddyService`, `verify(...)`); `fetch` returns null on null map; `LocalBuddyRepository` save→fetch round-trip with `SharedPreferences.setMockInitialValues({})`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement**, run build_runner. **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(buddy): BuddyState model, service and repositories`

### Task 3: Activity days from the entry tables

**Files:**
- Modify: `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart`, `test/helpers/fakes.dart` (`FakeEntryRepository.seedActivityDays`)
- Test: `test/services/entry_query_service_test.dart` (add group), `test/repositories/entry_repository_test.dart` (add group)

**Interfaces:**
- Produces: `Future<List<DateTime>> EntryQueryService.fetchTrackedAtSince({required String userId, required DateTime since})` — for each table in `entryTableFor.values`: `.select('tracked_at').eq('user_id', userId).gte('tracked_at', since.toUtc().toIso8601String())`, run in parallel, flattened, parsed `DateTime.parse(...)`.
- Produces: `Future<Set<DateTime>> EntryRepository.fetchActivityDays({required String userId, required DateTime since})` → set of `DateTime(y, m, d)` from each `tracked_at.toLocal()`.

- [ ] **Step 1: Failing tests:** service queries all four tables with `select('tracked_at')` and the `gte` filter (mocks via `supabase_mocks.dart`); repository maps `2026-11-21T23:30:00Z` to the correct local date for the test's TZ (set `TZ`-independent by constructing UTC instants from local `DateTime(2026,11,21,23,59).toUtc()`), dedupes same-day entries.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): fetch activity days across entry tables`

### Task 4: Mood logic, reaction mapping, Buddy copy

**Files:**
- Create: `lib/services/buddy/buddy_mood_logic.dart`, `lib/services/buddy/buddy_copy.dart`
- Test: `test/services/buddy/buddy_mood_logic_test.dart`, `test/services/buddy/buddy_copy_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum EntryKind { meal, drink, toilet, gutFeeling }
  enum LogSentiment { good, neutral, bad }
  class TodayCare { const TodayCare({this.count = 0, this.kinds = const {}, this.lastLogAt}); final int count; final Set<EntryKind> kinds; final DateTime? lastLogAt;
    factory TodayCare.fromEntries(EntriesState s, DateTime now); } // only entries whose tracked_at.toLocal() is today
  BuddyMood deriveBuddyMood(TodayCare care, DateTime now);
  LogSentiment sentimentForGutFeeling(GutFeelingEntry e); // calculateGutFeelingRating: spiGut/gut → good, durchschnittlich → neutral, schlecht → bad
  LogSentiment sentimentForToilet(ToiletEntry e); // stoolType 3 → good, 1 or 5 → bad, else neutral
  class BuddyReaction { const BuddyReaction(this.action, this.line, {this.moodAfter}); final BuddyAction action; final String line; final BuddyMood? moodAfter; }
  BuddyReaction reactionFor(EntryKind kind, LogSentiment sentiment, {required String name, required Random rnd});
  String moodLine(BuddyMood mood, {required String name, required int streak, required Random rnd});
  ```
- `deriveBuddyMood` table (first match wins; `h = now.hour`):
  1. `care.count == 0 && h < 10` → `sleepy`
  2. `care.kinds.length >= 3` → `energetic`
  3. `care.lastLogAt != null && now.difference(care.lastLogAt!) < 5h` → `happy`
  4. `h >= 10 && h < 22` → `hungry`
  5. otherwise → `sleepy` (late night)
- `reactionFor`: meal → `eat`; drink → `drink`; toilet good/neutral → `relief`, bad → `hug` (`moodAfter: empathetic`); gutFeeling good → `celebrate`, neutral → `nodYes`, bad → `hug` (`moodAfter: empathetic`). Line pools in `buddy_copy.dart` (≥3 variants each), e.g. meal: „Mmmh, lecker!", „Danke fürs Füttern!", „Nom nom nom!"; drink: „Ahh, erfrischend!", „Prost! 💧"; relief: „Puh, Erleichterung!"; gut bad: „Oh nein … ich drück dich. Danke, dass du's eingetragen hast."; gut good: „Juhu, guter Bauchtag!".
- `moodLine` pools per mood using `{name}`/`{streak}` (e.g. hungry: „Ich hab Hunger … fütterst du mich?", sleepy morning: „Guten Morgen … *gähn*", energetic: „Wir sind heute ein Top-Team!").

- [ ] **Step 1: Failing tests:** each row of the mood table (5 cases incl. 09:59 vs 10:00 boundary, 4h59 vs 5h01 since last log); entries from yesterday don't count in `TodayCare.fromEntries`; sentiment mapping for every `GutFeelingRatingLevel` and stool types 1–5; `reactionFor` covers every kind×sentiment and returns a non-empty German line; every `BuddyMood` has a `moodLine` without leftover `{` placeholders.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): care-based mood, reactions and Buddy copy`

### Task 5: Streak engine (pure)

**Files:**
- Create: `lib/services/buddy/streak_engine.dart`
- Test: `test/services/buddy/streak_engine_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class StreakEvaluation {
    final int streak; final bool todayCounted;
    final List<DateTime> consumedDays, refundedDays;
    final BuddyState next; // savers / savedDays / lastMilestone / streakGoal updated
    final int saversEarned; final bool goalReached; final bool streakBroken;
    bool get changed; // next != input state
  }
  StreakEvaluation evaluateStreak({required Set<DateTime> activityDays, required BuddyState state, required DateTime today, required DateTime windowStart, bool initialize = false});
  ```
- Algorithm (all dates local midnight; `today` normalised):
  1. **Refund:** every date in `state.savedDays` that is in `activityDays` is removed from `savedDays`; `savers = min(2, savers + refunds)`.
  2. `counted(d) = activityDays ∪ savedDays (after refund)`.
  3. **Fillable gap:** let `y = today - 1`. If `!counted(y)`: let the gap be the maximal run of uncounted days ending at `y`, scanning back no further than `windowStart`; it is fillable iff a counted day exists immediately before the gap and `gapLength ≤ savers`. If fillable: add gap days to `savedDays`, `savers -= gapLength`, `consumedDays = gap`. If not fillable and the run of counted days immediately before the gap has length ≥ 2: `streakBroken = true`.
  4. **Streak:** anchor = `today` if `counted(today)` else `y`; `streak` = number of consecutive counted days walking back from anchor (0 if anchor uncounted). `todayCounted = counted(today)`.
  5. **Milestones:** `m = (streak ~/ 7) * 7`. If `initialize`: `lastMilestone = m`, no rewards. Else if `m > lastMilestone`: `saversEarned = (m - lastMilestone) ~/ 7`, `savers = min(2, savers + saversEarned)`, `lastMilestone = m`. Else if `streak < lastMilestone`: `lastMilestone = m` (reset after a break).
  6. **Goal:** if `streakGoal != null && streak >= streakGoal` → `goalReached = true`, `next.streakGoal = null`.
  7. Saved days count toward `streak` (Claude's call; documented in the PR).
- The caller (Task 6) passes `windowStart = today - 120 days`; if `streak` reaches the window (anchor - streak + 1 ≤ windowStart) it refetches with a doubled window (max 3650 days) and re-evaluates.

- [ ] **Step 1: Failing tests** (table-driven, `today = DateTime(2026,11,22)`): empty days → streak 0, nothing consumed; today only → 1; 10 consecutive incl. today → 10, `saversEarned 1` (from lastMilestone 0 → 7), `lastMilestone 7`; yesterday missing, 5 days before, savers 1 → consumed [21.11.], streak 7 incl. saved day → also milestone 7 → savers back to 1; gap of 2 with 1 saver → not filled, `streakBroken` true, streak = today only; refund: savedDays [21.11.] and activity now contains 21.11. → refunded, savers +1 capped at 2; savers already 2 + refund → stays 2; `initialize: true` with 40-day streak → `lastMilestone 35`, `saversEarned 0`; goal 7 reached → `goalReached`, `next.streakGoal == null`; today not yet logged but yesterday counted → streak counts through yesterday, `todayCounted false`; old gap (ends 3 days ago) is never filled even with savers; **midnight**: activity built from `DateTime(2026,11,21,23,59)` and `DateTime(2026,11,22,0,1)` normalised by Task 3's mapping counts as 2 days; **DST**: a 2026-03-29 (Europe DST switch) run of 3 days around it counts 3 (use `DateTime(y,m,d)` arithmetic via day increments, never `Duration(hours: 24)`).
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): streak engine with savers, refunds and milestones`

### Task 6: `buddyProvider` and `buddyEventsProvider`

**Files:**
- Create: `lib/providers/buddy_provider.dart`, `lib/providers/buddy_events_provider.dart`
- Test: `test/providers/buddy_provider_test.dart`, `test/providers/buddy_events_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 3, 5; `currentUserIdProvider`; `AppLogger`.
- Produces:
  ```dart
  enum BuddyAnnouncement { saverUsed, streakBroken, saverEarned, goalReached }
  class BuddyStatus { const BuddyStatus({required this.state, required this.hasRow, required this.streak, required this.todayCounted, this.announcements = const []}); final BuddyState state; final bool hasRow; final int streak; final bool todayCounted; final List<BuddyAnnouncement> announcements; }
  class BuddyNotifier extends AsyncNotifier<BuddyStatus?> { // null when signed out
    Future<void> refresh();                 // re-fetch days + evaluate + persist if changed (only when hasRow)
    Future<void> setName(String name);      // trims, 1–20 chars, creates the row if missing
    Future<void> setStreakGoal(int? goal);
    Future<void> completeOnboarding({bool grantGiftSaver = true}); // idempotent: sets onboardingCompletedAt once, +1 saver (cap 2) once; first-time row creation uses evaluateStreak(initialize: true)
    void clearAnnouncements();
  }
  final buddyProvider = AsyncNotifierProvider<BuddyNotifier, BuddyStatus?>(BuddyNotifier.new);
  class BuddyLogEvent { const BuddyLogEvent(this.kind, this.sentiment, {required this.at}); final EntryKind kind; final LogSentiment sentiment; final DateTime at; }
  class BuddyEventsNotifier extends Notifier<BuddyLogEvent?> { void emit(BuddyLogEvent e); BuddyLogEvent? consume(); } // consume returns & clears; emit also triggers ref.read(buddyProvider.notifier).refresh() (unawaited, errors logged)
  final buddyEventsProvider = NotifierProvider<BuddyEventsNotifier, BuddyLogEvent?>(BuddyEventsNotifier.new);
  ```
- `build()` watches `currentUserIdProvider`; signed out → `null`; fetch errors → `AppLogger.error(...)` and rethrow (AsyncError — UI degrades, see Task 9). Announcements: `saverUsed` when `consumedDays` non-empty, `streakBroken`, `saverEarned` when `saversEarned > 0`, `goalReached`; each shown at most once per local day (SharedPreferences key `buddy_announced_<kind>_<yyyy-MM-dd>`; add key prefix constant to `AppConstants`).

- [ ] **Step 1: Failing tests** (`createContainer` with `FakeBuddyRepository`, `FakeEntryRepository.seedActivityDays`, `currentUserIdProvider.overrideWithValue('u1')`): no row → `hasRow false`, `streak` computed, nothing saved; existing row with consumable gap → saved once with `savedDays` + announcement `saverUsed`; second `refresh()` same day → no duplicate announcement; `completeOnboarding()` twice → savers +1 only once; `setName('  Bauchi  ')` stores `'Bauchi'`; `setName('')` throws `ArgumentError`; user id switch `u1 → u2` → state rebuilt from u2's repo; signed out (`null` id) → `null`; repository throws → `AsyncError`; events: `emit` then `consume()` returns event and state becomes null; `emit` calls `refresh` (verify fake repo fetch count increments).
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): buddyProvider and Buddy log events`

### Task 7: Animated reactions on all tracker success screens

**Claude's call (deviation from spec §6.3, documented in the PR):** all four trackers keep their success screen and show the animated Buddy reaction there (the user chose this for meals; trackers are also opened from the diary, where a dashboard-only reaction would never be seen). The dashboard hero then reflects the new mood/streak.

**Files:**
- Modify: `lib/widgets/common/bb_success_overlay.dart` (add `Widget? illustration` — replaces the `MascotImage` when set; treated like a mascot for auto-dismiss; mascot bounce skipped for the illustration; respect `MediaQuery.disableAnimationsOf` for its own fade/slide), `lib/widgets/common/tracker_screen_scaffold.dart` (pass-through `successIllustration`)
- Create: `lib/widgets/buddy/buddy_reaction_view.dart`
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart`, `lib/screens/trackers/drink/drink_tracker_screen.dart`, `lib/screens/trackers/toilet/toilet_tracker_screen.dart`, `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart`
- Test: `test/widgets/common/bb_success_overlay_test.dart` (extend), `test/widgets/buddy/buddy_reaction_view_test.dart`, extend each tracker's screen test

**Interfaces:**
- Consumes: Task 4 `reactionFor`, Task 6 `buddyEventsProvider`, `buddyProvider` (name), Plan 1 `BuddyController`/`BuddyStage`.
- Produces: `class BuddyReactionView extends ConsumerStatefulWidget { const BuddyReactionView({super.key, required EntryKind kind, required LogSentiment sentiment, Uint8List? foodImageBytes, double size = AppConstants.buddyReactionSize}); }` — creates/disposes its own `BuddyController`, decodes `foodImageBytes` with `ui.instantiateImageCodec` (failure → apple fallback, logged), plays `reaction.action` on first frame, `say(reaction.line)`, then sets `moodAfter` if any. Add `AppConstants.buddyReactionSize = 220`.
- Trackers, on successful save: `ref.read(buddyEventsProvider.notifier).emit(BuddyLogEvent(kind, sentiment, at: DateTime.now()))` and show `successIllustration: BuddyReactionView(...)`. Meal passes `state.imageBytes`; the meal screen's existing `successActions` („Getränk hinzufügen") and `successBottomCallout` („Als Rezept speichern") stay exactly as they are. Edit-mode saves (meal edit) emit nothing and keep current behavior.

- [ ] **Step 1: Failing tests:** overlay with `illustration` renders it and no `MascotImage`; `BuddyReactionView(kind: meal)` → controller action `eat`, bubble text in the meal pool; `toilet` + `bad` → `hug`; each tracker test: after a successful save, `buddyEventsProvider` holds the right kind/sentiment and a `BuddyReactionView` is shown; meal success still shows „Getränk hinzufügen" and „Als Rezept speichern" (update `meal_tracker_drink_handoff_test.dart` expectations only where the mascot finder changed).
- [ ] **Step 2–4:** FAIL → implement → PASS (`flutter test test/screens/trackers test/widgets`).
- [ ] **Step 5: Commit** `feat(buddy): animated Buddy reactions on tracker success screens`

### Task 8: Streak chip + streak goal sheet

**Files:**
- Create: `lib/widgets/buddy/streak_chip.dart`, `lib/screens/buddy/streak_goal_picker.dart`
- Test: `test/widgets/buddy/streak_chip_test.dart`, `test/screens/buddy/streak_goal_picker_test.dart`

**Interfaces:**
- Produces:
  - `class StreakChip extends StatefulWidget { const StreakChip({super.key, required int streak, required int savers, required bool todayCounted}); }` — „🔥 {n} Tage" (1 → „1 Tag"), „🛡 {savers}" when > 0; `todayCounted == false && streak > 0` → muted style + tooltip/semantics „Heute noch offen"; when `streak` increases between builds → pop animation (scale 1→1.25→1, skipped under reduced motion).
  - `const List<int> kStreakGoalOptions = [7, 14, 30, 50, 100];` and labels map: 7 „Guter Start", 14 „Stark", 30 „Legendär", 50 „Unaufhaltsam", 100 „Bauch-Legende".
  - `List<int> streakGoalChoices(int currentStreak)` → first 3 options `> currentStreak` (fewer if not available).
  - `class StreakGoalPicker extends StatelessWidget { const StreakGoalPicker({super.key, required int currentStreak, required ValueChanged<int> onSelected}); }` (vertical list of 3 cards: "{n} Tage" + label).
  - `Future<int?> showStreakGoalSheet(BuildContext context, {required int currentStreak, required String title});` — modal bottom sheet with Buddy (`BuddyStage`, `inLove`) + title + picker; returns chosen goal or null.

- [ ] **Step 1: Failing tests:** chip texts for 0/1/5 and savers 0/2; muted semantics „Heute noch offen"; `streakGoalChoices(0) == [7,14,30]`, `(10) == [14,30,50]`, `(120) == []`; picker tap calls `onSelected(14)`; sheet returns the tapped value.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): streak chip and streak goal picker`

### Task 9: Dashboard hero

**Files:**
- Create: `lib/screens/dashboard/widgets/buddy_hero.dart`
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (insert hero as first sliver content, above the existing header row; header icons stay top-right; add `TutorialKeys.buddy` and one tutorial step „Das ist dein Buddy …" as the first step in `dashboard_tutorial_steps.dart`), `lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart`
- Test: `test/screens/dashboard/widgets/buddy_hero_test.dart`, update `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 4, 6, 8; `entriesProvider`; Plan 1 widgets.
- Produces: `class BuddyHero extends ConsumerStatefulWidget { const BuddyHero({super.key}); }` — owns one `BuddyController`; height `AppConstants.buddyHeroHeight = 300`; layout: `StreakChip` row (left) · `BuddyStage` (bubble above) · `BbButton` „🍎 Füttern" → `context.push(RoutePaths.mealTracker)`.
  - Mood: `deriveBuddyMood(TodayCare.fromEntries(entries, now), now)`, recomputed on `entriesProvider` change and every minute (`Timer.periodic(1 min)`); on first build and on mood change → `say(moodLine(...))`.
  - Events: on build/resume, `consume()` any `BuddyLogEvent` younger than 2 min → after 600 ms `say` a follow-up („Danke! 🔥 {streak} Tage" when `todayCounted` just became true, else the mood line).
  - Announcements (from `buddyProvider`): `saverUsed` → `play(hug)` + „Puh! Dein Streak-Saver hat uns gestern gerettet 🛡"; `streakBroken` → „Neuer Anlauf — ich bin dabei!"; `saverEarned` → `play(celebrate)` + „Du hast einen Streak-Saver verdient! 🛡"; `goalReached` → `play(celebrate)`, mood `inLove`, then `showStreakGoalSheet(title: 'Wir haben's geschafft! Neues Ziel?')` → `setStreakGoal`. Then `clearAnnouncements()`.
  - Degradation: `buddyProvider` loading/error/null → Buddy still shown with mood from entries, `StreakChip` hidden, name 'Buddy'.
- Dashboard: `_loadData()` also awaits `ref.read(buddyProvider.notifier).refresh()` (errors swallowed+logged so refresh-indicator never fails); remove nothing else in this task.

- [ ] **Step 1: Failing tests:** hero renders `AnimatedBuddy` + „Füttern"; with no entries at 14:00 → controller mood `hungry` (inject clock via a `buddyClockProvider = Provider<DateTime Function()>((_) => DateTime.now)` defined in `buddy_hero.dart`, overridden in tests); with a meal logged 1 h ago → `happy`; `buddyProvider` error → no `StreakChip`, Buddy present; announcement `saverUsed` → bubble shows the saver line and `clearAnnouncements` called; tapping „Füttern" pushes `/meal-tracker` (GoRouter test harness as in `meal_tracker_drink_handoff_test.dart`); dashboard test still finds all existing tutorial keys plus `TutorialKeys.buddy`.
- [ ] **Step 2–4:** FAIL → implement → PASS (`flutter test test/screens/dashboard`).
- [ ] **Step 5: Commit** `feat(buddy): Buddy hero on the dashboard`

### Task 10: Buddy-voiced reminders (copy only)

**Files:**
- Modify: `lib/services/reminder_copy.dart`, `lib/services/local_notification_service.dart`, `lib/repositories/notification_repository.dart`, `lib/providers/notification_provider.dart`
- Test: `test/services/reminder_copy_test.dart` (extend), `test/repositories/notification_repository_test.dart` (extend), `test/providers/notification_provider_test.dart` (extend or create)

**Interfaces:**
- Produces: `ReminderCopy.pickMealBody(int hour, Random rnd, {String? buddyName})` and `pickMoodBody(..., {String? buddyName})` — when `buddyName` is non-null, pick from new Buddy pools (≥4 per slot) with `{name}` substituted, e.g. „🍽️ {name} hat Hunger! Was gab's zu Mittag?", „🥄 {name} wartet aufs Frühstück!", „🌙 {name} will wissen, wie dein Bauch sich heute anfühlt."; no streak numbers. `NotificationScheduler`/`LocalNotificationService.scheduleMealReminders/scheduleMoodReminders` gain `{String? buddyName}`; `NotificationRepository.syncNotifications(UserProfile profile, {String? buddyName})`; `notificationSyncProvider` also watches `buddyProvider.select((s) => s.value?.state.name)` and passes the name only when `hasRow`.

- [ ] **Step 1: Failing tests:** Buddy pools contain the name and no `{`; without name → old pools unchanged; repository forwards `buddyName` to the scheduler (`MockNotificationScheduler` verify); renaming the Buddy re-triggers `syncNotifications` (`FakeNotificationRepository.syncCount` increments).
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): Buddy-voiced reminder copy`
