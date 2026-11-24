# Runde 4 Stage 1: Home & Motivation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Home's four bubbles show how long ago each need was logged (meters that drain with time), saving charges that need's circle on the success page, the streak gets a drawn flame that glows until the day's first entry, the first 7 days become a journey with a feedback line after the day's first Bauchgefühl, and Entdecken shows an example tip while weekly tips are off.

**Architecture:**
- **Meters:** a pure model in `lib/services/buddy/care_meters.dart`: `CareLog` (when each need was last logged) and `CareMeters.at(log, now)` (linear drain over awake hours 07–22, never below 15 %). Home's entries load also fetches the latest meal, drink and Bauchgefühl before the loaded day (one row per table), so `careLogProvider` spans midnight. The hero derives meters, mood and next action from it every minute. `CareRing` keeps its layout, but each bubble is a `NeedMeter`, and the four-quarter ring goes.
- **Success page:** before saving, a tracker captures a `LogMoment`: the need's level before and after, the streak day it lights, and (Bauchgefühl) the journey line. `LogSuccessHero` replaces `BuddyReactionView` as the success illustration. It holds a `ChargingMeter` (1.2 s), an ignite row „Tag n" and the Buddy.
- **Flame:** `StreakFlame` (CustomPainter) has tiers by streak, glows as an ember until today counts, and bursts on ignite. It is used in `StreakChip`, `StreakMoment` and `StreakWeekRow`. The Buddy reloads after an entry is deleted or moved, so the flame follows.
- **Journey:** the insights engine adds `Insights.journey` (the latest 7 days with entries, each with or without Bauchgefühl). `journeyProvider` decides once per user and device whether Home shows it. While locked, `InsightCard` shows `JourneyDots` for journey users, with an empty reward slot for Stage 3.
- **Tipps preview:** `ExampleTipCard` sits above the opt-in. The switch gets the Monday subline and the new KI-Dienst sentence.

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3.5 (`Notifier`/`AsyncNotifier`), GoRouter 18, Supabase (PostgREST), SharedPreferences, mocktail, integration_test. No new dependencies, no Freezed model changes.

**Spec:** `docs/superpowers/specs/2026-11-24-round4-home-recipes-tips-design.md` (approved 2026-11-24). This plan implements **Stage 1** (§6):
- §5.1 Ring 2.0;
- §5.2 success page with the charging circle;
- §5.3 streak flame;
- §5.4 Tipps preview, plus the KI-Dienst sentence of the Decisions log (builder-check item 4);
- from §5.5, the journey card and the feedback line.

The §5.5 rewards table is Stage 3; the card gets an empty slot for it.

Mockup source: `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/round4-home.html` (published as https://claude.ai/artifact/C4i1ZNb6vj6PBm43Vzm9u9). The chosen variants are Ring A, saving B, flame b, journey A + feedback C and Tipps preview A. Its token table is used as is. Where the mockup and the spec differ, the spec wins.

## Global Constraints

From the spec and `CLAUDE.md`, verbatim where they give values:
- Follow the repo's `CLAUDE.md`:
  - colours, font sizes, spacing and radii only through `AppTheme`/`AppConstants` (add tokens there first);
  - German UI;
  - Riverpod, GoRouter, `AppLogger` (never `print`);
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- „Belly Buddy" is never translated (never „Bauch-Buddy").
- Vocabulary (§5.9 of the app-structure spec): eintragen, Essen/Trinken/Bauchgefühl/Klo, Tipps (never „Empfehlung" in the UI), Alternativen, Streak, Tagebuch. `test/utils/vocabulary_test.dart` stays green, with no new exemptions. New UI copy goes outside the exempt `buddy_copy.dart`, except for Buddy line pools that already live there.
- **Reduced motion:** every animation (meter drain and charge, flame, ignite burst, journey dots) respects it, and the reduced-motion versions are instant.
- **Layout:** a 375×667 screen at text scale 1.3 does not overflow.
- **Anti-goals:**
  - **Guilt or punishment.** Meters never drop to empty, the Buddy never scolds, and a dim flame is neutral: no warning colour, no text.
  - **Health claims, invented statistics or anything that reads like a diagnosis.** The feedback line „promises nothing".
- Meter rules (§5.1), as tunable constants in `AppConstants`:
  - Essen drains over about **5 h**, Trinken over about **3 h**, Bauchgefühl over about **24 h**;
  - linear from the last entry's `tracked_at`;
  - pauses overnight (**22:00–07:00** local);
  - floor of **15 %**;
  - a future-dated entry counts from its time;
  - entries from yesterday count too.
- Klo has no meter. It shows „vor X Std" („heute noch nicht" before the first entry).
- No new Home tap targets (§2 non-goals). The journey is the existing insight card, and it still opens Muster.
- No AI calls in this stage. The weekly-tips sentence is exactly: „Dafür schicke ich deine Einträge der letzten Wochen, die Muster daraus und deine Bewertungen meiner Tipps an unseren KI-Dienst."
- App only. Core is untouched in Stage 1. The release follows Stage 3.

Execution rules for this repo:
- **Commits:** run `dart format .` and `flutter analyze` (0 issues) first. Then `git commit --no-verify` (the hook is broken in worktrees), with a conventional prefix and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. **Never push.**
- **Codegen:** none needed. `Insights`, `EntriesState`, `CareLog` and `LatestEntries` are plain Dart. If a generated file is stale anyway, run `dart run build_runner build --delete-conflicting-outputs`.
- **Test seams:**
  - The root `test/flutter_test_config.dart` calls `disableAmbientAnimationsForTests()`. That holds the Buddies, the ring's glow and (from Task 6) the flame's wobble, breathing and sparks still.
  - Hero tests keep `tickBuddiesInTests()` and pump fixed durations (never `pumpAndSettle` there).
  - One-shot animations (meter tween, charge, ignite burst, dot bump) settle.
- **Simulators:** integration tests run **only** on the iPhone Air `CB1F6232-482F-408F-ADF4-89FDA602E6A8`, one file at a time, and the simulator is shut down afterwards. **Never** use `55746DB2…` (Severin's live session) or `7A26EDD4…`. Never run `flutter clean`.
- **Clock in tests:** pin `buddyClockProvider`/`buddyTodayProvider`. Dates below use 23.11.2026 unless a test says otherwise. Meter values are `1 − 0.85 · awake / drain` (clamped to 0.15…1), so tests compare with `closeTo(x, 0.005)`.

## Review Focus

1. **Midnight, the night pause and DST.**
   - A drink at 21:00 reads the same at 23:59, at 00:01 after the new day has loaded, and at 06:59, then drains from 07:00.
   - The new day's load brings the latest entries before it, so no meter drops at midnight.
   - Across 29.3.2026 and 25.10.2026, the awake time is the clock time between 07 and 22.

   Pinned in:
   - Task 1: `awakeBetween across the DST switches`, `the night pause holds a level`;
   - Task 2: `loadEntries brings the latest entries before the day`;
   - Task 4: `open across midnight: the meters carry over`, `resumed the next morning: yesterday's meal still counts`.
2. **A future-dated entry (later today).**
   - Its meter stays full until its time, then drains.
   - Klo reads „um 20:00".
   - The success page charges to full.

   Pinned in Task 1 (`a future entry keeps the meter full`, `careAgo of a later time today`) and Task 7 (`an entry for later today charges to full`).
3. **Reduced motion everywhere.**
   - Meters take a new level at once, and the glow holds still.
   - The charging circle shows the new level at once.
   - The flame neither wobbles, breathes nor bursts: it is lit at once.
   - A filling journey dot doesn't bump.
   - No frame stays scheduled.

   Pinned in Task 3 (`NeedMeter`), Task 4 (ring), Task 6 (flame), Task 7 (charge) and Task 9 (dots).
4. **375×667 at text scale 1.3.** These screens must not overflow:
   - Home with Klo's two-line label and the journey card;
   - the meal success page with circle, ignite row, actions and callout;
   - the Bauchgefühl success page with the feedback line;
   - Entdecken's example card;
   - the Tagebuch totals line.

   Pinned in Tasks 4, 5, 7, 9, 10 and 11.
5. **Today's first entry deleted again.** The Buddy reloads after a delete or a moved entry, so:
   - the chip's flame glows as an ember again at once, with no burst and no reverse animation;
   - the count goes back;
   - the need's meter falls back to the previous entry's level;
   - the journey shows one dot less if the day has no other entry.

   Pinned in Task 6 (`a delete or a move reloads a loaded Buddy`, `lit → ember: no burst`) and Task 2 (`careLogProvider follows a reload without the deleted entry`).
6. **Users already past day 7.**
   - Whether a user gets the journey is decided once per user and device, at first sight of their insights.
   - 7 or more days with entries, or already unlocked → no journey: Stage 2's card with both bars.
   - A new user keeps the journey until unlock, even at day 8 with fewer than 3 Bauchgefühl entries.

   Pinned in Task 8 (`journeyProvider` group).

## Decisions (spec gaps ruled in this plan)

- **Where yesterday comes from:** `EntriesNotifier.loadEntries` also fetches the `tracked_at` of the latest meal, drink and Bauchgefühl before the loaded day (`limit 1` per table), in the same load. It doesn't use the 30-day insights source. That source keeps drinks only as unlabelled instants, holds a previous user's value while reloading, and fails on its own. A Bauchgefühl from two days back can still be above the floor (24 awake hours), so "yesterday's list" alone would not do either. Klo needs only today („heute noch nicht" before the first entry), so it is not fetched.
- **Drain curve:** linear from 1.0 at the entry to the 15 % floor reached exactly at the drain time, counting only awake time (07:00–22:00 local, per calendar day, DST-safe). A future-dated entry gives 1.0 until its time.
- **Next action and mood:**
  - The lowest of Essen, Trinken and Bauchgefühl wins; ties go Essen → Trinken → Bauchgefühl, and Klo never drives it.
  - Below `careMeterLow` (35 %) he asks for that need. For Essen, the button names the meal of the time of day: the existing `mealSlotAt`, which gives none at night, so it falls back to „🍽 Essen eintragen".
  - With no meter below 35 % it is `CareAction.feed`.
  - Mood:
    1. sleepy: nothing logged today before 10:00;
    2. energetic: every meter at 70 % or more;
    3. happy: the lowest at 35 % or more;
    4. hungry: by day (10–22);
    5. otherwise sleepy.
- **The four-quarter ring goes** (mockup A: „Der große Ring fällt weg"): its quarters showed daily quotas. The glow stays lime (`careGlow`), matching the lime next-action button.
- **Klo's bubble:** a plain circle in `careLooSoft` with a `careLoo` ring, then two lines: „Klo" and „vor 3 Std" / „heute noch nicht". Meter size follows the ring (`diameter × 0.27`, 48–72), so both rows fit at 375×667 @1.3.
- **Counts in the Tagebuch:** a one-line total above the day's entries, e.g. „2× Essen · 1,5 l getrunken · 1× Bauchgefühl · 1× Klo".
- **Success page:**
  - Klo has no circle (it has no meter); its page shows the Buddy and, if it lights the streak, the ignite row.
  - „Today's first entry" means all of these hold: the Buddy status says today isn't counted, Home's log shows no entry today, and the entry is dated today.
  - „Tag n" shows `streak + 1`.
- **Flame:**
  - Tiers: 0–2 small, 3–6 medium, 7–29 large, 30+ large with a blue core and sparks.
  - Streak 0 with today uncounted is a static grey ember („aus"). An ember never says anything (spec).
  - The week row's day marks are still flames.
  - Ich's subtitle („🔥 3 Tage · Ziel …"), the tour text and the Buddy's „Danke! 🔥" line are text, not the chip or „Dein Streak": they keep the emoji.
  - The chip burst plays when the chip is next visible, so returning Home from the success page shows it (mockup B).
- **Journey card:**
  - Filled dots are lime with a check, and days with a Bauchgefühl get a green pip under the dot (mockup: „Grüne Pünktchen markieren Tage mit Bauchgefühl"). This is how the spec's „dots for days with a Bauchgefühl entry are green" is drawn.
  - The dots are the latest 7 days with entries, and the Buddy stands on the last filled dot (dot 1 before any entry).
  - The title lines are the mockup's (Task 9).
  - The counters are „n von 7 Tagen" and „Bauchgefühl n von 3".
- **Who sees the journey** (§5.5 „Users who already passed day 7 … see no journey"):
  - The decision is persisted per user and device the first time the user's insights load: locked with fewer than 7 days with entries → journey, otherwise none.
  - A user switching device mid-journey after day 7 sees the Stage 2 card there. That is accepted.
  - Stage 3 reuses this flag for the rewards and the offer logic.
- **Feedback line:**
  - It comes only after today's first Bauchgefühl, while locked, and only when that entry is good or neutral. After a bad one he keeps his empathetic line; the calm success page shouldn't turn into a progress cheer.
  - When days are still missing: „Notiert! Noch N Tage, dann schau ich nach ersten Mustern." When only Bauchgefühl entries are missing: „Notiert! Noch N× Bauchgefühl, dann schau ich nach ersten Mustern."
  - There is no line when this entry unlocks the patterns (Stage 3 celebrates that).
- **Example tip:**
  - It shows whenever the opt-in card shows (weekly tips known to be off), directly above it.
  - The subline „Jeden Montag 2–3 Tipps" lives in `WeeklyTipsSwitch`, so Settings shows it too.
  - The new KI-Dienst sentence replaces the old one everywhere it is shown: the switch (Entdecken and Settings) and the offer sheet.
- **Tour step 1** described the old ring. It now says the bubbles fill and drain.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/config/app_theme.dart`, `lib/config/constants.dart` (modify) | care colours and tints, flame colours; meter, flame, charge, journey and dash constants |
| `lib/services/buddy/care_meters.dart` (create) | `awakeBetween`, `meterLevel`, `careAgo`, `CareLog`, `CareMeters`, `CareCopy` |
| `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart` (modify) | `LatestEntries`, `fetchLatestBefore` |
| `lib/providers/entries_provider.dart` (modify) | `EntriesState.latestBefore`; Buddy reload after a delete or move |
| `lib/providers/care_log_provider.dart` (create) / `daily_care_provider.dart` (delete) | `careLogProvider` |
| `lib/widgets/buddy/need_meter.dart` (create) | `NeedMeter`, `careColorsOf` |
| `lib/screens/dashboard/widgets/care_ring.dart` (rewrite) | bubbles as meters, no quarters |
| `lib/services/buddy/daily_care.dart`, `buddy_mood_logic.dart`, `buddy_copy.dart` (modify) | `nextCareAction`/`deriveBuddyMood` on `CareLog`; `DailyCare` goes; copy |
| `lib/screens/dashboard/widgets/buddy_hero.dart`, `lib/widgets/common/bb_bottom_nav.dart`, `…/tutorial/dashboard_tutorial_steps.dart` (modify) | meters wired in |
| `lib/utils/diary_helpers.dart`, `lib/screens/diary/diary_screen.dart` (modify) | day totals |
| `lib/widgets/buddy/streak_flame.dart` (create) | `StreakFlame`, `FlamePainter` |
| `lib/widgets/buddy/streak_chip.dart`, `streak_week_row.dart`, `lib/screens/buddy/widgets/streak_moment.dart`, `lib/screens/dashboard/widgets/streak_sheet.dart` (modify) | flame instead of 🔥 |
| `lib/services/buddy/log_moment.dart`, `lib/providers/log_moment.dart`, `lib/widgets/buddy/log_success_hero.dart` (create) | `LogMoment`, `captureLogMoment`, `ChargingMeter`, `LogSuccessHero` |
| `lib/screens/trackers/{meal,drink,gut_feeling,toilet}/*_tracker_screen.dart`, `lib/widgets/buddy/buddy_reaction_view.dart` (modify) | success hero, line override |
| `lib/models/insights.dart`, `lib/services/insights/insights_engine.dart` (modify) | `JourneyDay`, `Insights.journey` |
| `lib/providers/journey_provider.dart` (create) | `journeyProvider` |
| `lib/screens/dashboard/widgets/journey_dots.dart` (create), `insight_card.dart`, `dashboard_screen.dart`, `lib/services/insights/insight_copy.dart` (modify) | the journey card |
| `lib/screens/discover/widgets/example_tip_card.dart` (create), `discover_tips_section.dart`, `lib/widgets/common/weekly_tips_switch.dart` (modify) | Tipps preview |
| `test/helpers/ambient_animations.dart`, `test/helpers/fakes.dart`, `integration_test/helpers/test_app.dart` (modify) | seams and fakes |

---

### Task 1: Care colours and the meter model

**Files:**
- Modify: `lib/config/app_theme.dart`, `lib/config/constants.dart`
- Create: `lib/services/buddy/care_meters.dart`
- Test: `test/config/app_theme_contrast_test.dart`, `test/services/buddy/care_meters_test.dart` (create)

**Interfaces:**
- Produces:
  - `AppTheme`. The four care colours are replaced; `careGlow` stays. All colours come from the mockup's token table:
    ```dart
    careFood = Color(0xFFD27A12);    careFoodSoft = Color(0xFFFCEBD5);
    careWater = Color(0xFF3A8FCC);   careWaterSoft = Color(0xFFE2F0FA);
    careGut = Color(0xFF3A9A48);     careGutSoft = gutFeelingGoodSoft;
    careLoo = Color(0xFF9C7350);     careLooSoft = Color(0xFFF1E7DE);
    streakFlame = Color(0xFFFF7A2E); streakFlameCore = buddySparkle; streakFlameHot = buddyWater;
    streakEmber = Color(0xFFF4B996); streakEmberCore = Color(0xFFF8DDA6); streakEmberOff = Color(0xFFDDD5CC);
    ```
  - `AppConstants`:
    - drains: `careFoodDrain = Duration(hours: 5)`, `careDrinkDrain = Duration(hours: 3)`, `careGutFeelingDrain = Duration(hours: 24)`;
    - night pause: `careNightFromHour = 22`, `careNightUntilHour = 7`;
    - levels: `careMeterFloor = 0.15`, `careMeterLow = 0.35`, `careMeterHigh = 0.7`.

    A doc comment marks them tunable and says the floor keeps a meter from ever looking empty.
  - `care_meters.dart`:
    ```dart
    const meteredNeeds = [CareNeed.food, CareNeed.drink, CareNeed.gutFeeling];
    Duration? drainOf(CareNeed need);                  // null for Klo
    Duration awakeBetween(DateTime from, DateTime to);
    double meterLevel(DateTime? last, DateTime now, Duration drain);
    String careAgo(DateTime last, DateTime now);
    class CareLog {                                    // == / hashCode by value
      const CareLog({this.lastMealAt, this.lastDrinkAt, this.lastGutFeelingAt, this.lastToiletAt, this.lastGutFeelingLevel});
      final DateTime? lastMealAt, lastDrinkAt, lastGutFeelingAt, lastToiletAt;   // local
      final GutFeelingRatingLevel? lastGutFeelingLevel;  // the loaded day's latest Bauchgefühl
      DateTime? lastAt(CareNeed need);
      bool loggedOn(CareNeed need, DateTime day);         // lastAt(need) falls on day's date
      bool anyOn(DateTime day);
    }
    class CareMeters {                                 // == / hashCode by value
      const CareMeters({required this.food, required this.drink, required this.gutFeeling});
      factory CareMeters.at(CareLog log, DateTime now);
      final double food, drink, gutFeeling;
      double? level(CareNeed need);                     // null for Klo
      CareNeed get lowest;                              // ties: food, drink, gutFeeling
    }
    abstract final class CareCopy {
      static const notToday = 'heute noch nicht';
      static const notYet = 'noch nicht eingetragen';
      static String looLine(CareLog log, DateTime now); // careAgo if Klo was logged today, else notToday
      static String spoken(CareNeed need, CareLog log, DateTime now); // a bubble's semantics value
    }
    ```

**Rules:**
- **`awakeBetween`:**
  - It is zero when `to` is not after `from`.
  - Otherwise, for each local calendar day from `from`'s to `to`'s (stepping with `addDays`), it adds the overlap of `[from, to)` with that day's awake window `[DateTime(y, m, d, careNightUntilHour), DateTime(y, m, d, careNightFromHour))`.
  - Inputs may be UTC: convert with `toLocal()` first.
  - Building the window with the `DateTime` constructor keeps DST switches (which fall at night) out of the sum.
- **`meterLevel`:**
  - `last == null` → `careMeterFloor`.
  - Otherwise `(1 − (1 − floor) · awake / drain).clamp(floor, 1.0)`, with `awake = awakeBetween(last, now)` (zero for a future `last`), computed in microseconds.
- **`careAgo`:**
  - `last` after `now` → `'um HH:mm'` (zero-padded, built by hand, no locale data);
  - under 10 min → `'gerade eben'`;
  - under 60 min → `'vor N Min'`;
  - same calendar day → `'vor N Std'` (whole hours, rounded down);
  - the calendar day before → `'gestern'`;
  - else `'vor N Tagen'` (calendar days).
- **`CareCopy.spoken`:**
  - Klo: `'zuletzt ${careAgo}'` when logged today, else `notToday`.
  - A metered need: `notYet` without a last entry, else `'zuletzt ${careAgo}'`.

- [ ] **Step 1: Failing tests.**
  - **Contrast** (`app_theme_contrast_test.dart`): `each care colour has at least 3:1 on the page`. `careFood`, `careWater`, `careGut`, `careLoo` against `AppTheme.background` ≥ 3.0.
  - **`awakeBetween`:**
    - 10:00 → 13:30 same day → `Duration(hours: 3, minutes: 30)`;
    - 21:00 → 08:00 next day → 2 h;
    - 23:00 → 06:59 next day → `Duration.zero`;
    - 21:00 on the 21st → 08:00 on the 23rd → 17 h;
    - `to` before `from` → zero;
    - **`across the DST switches`:**
      - `DateTime(2026, 3, 28, 21)` → `DateTime(2026, 3, 29, 8)` → 2 h;
      - `DateTime(2026, 10, 24, 21)` → `DateTime(2026, 10, 25, 8)` → 2 h.
    - **A UTC instant equals its local twin:** `awakeBetween(t.toUtc(), u) == awakeBetween(t, u)`.
  - **`meterLevel`** (drink, 3 h):
    - `null` → 0.15;
    - logged at `now` → 1.0;
    - 1.5 h awake → 0.575;
    - exactly 3 h → 0.15;
    - 10 h → 0.15;
    - **`a future entry keeps the meter full`:** 18:00 at 14:00 → 1.0;
    - **`the night pause holds a level`:** drink at 21:00 gives 0.717 at 23:59 and at 06:59 next day, then 0.575 at 07:30.
    - Food 5 h: 1 h → 0.83, 4.75 h → 0.1925.
    - Bauchgefühl 24 h: 6 h → 0.7875.
  - **`careAgo`** at 14:00:
    - 13:55 → `'gerade eben'`;
    - 13:35 → `'vor 25 Min'`;
    - 10:59 → `'vor 3 Std'`;
    - previous day 20:00 → `'gestern'`;
    - three days before → `'vor 3 Tagen'`;
    - **`careAgo of a later time today`:** 18:00 → `'um 18:00'`.
    - At 00:30, the previous day's 23:50 → `'vor 40 Min'`.
  - **`CareLog`:**
    - `lastAt` per need;
    - `loggedOn(toilet, now)` true for 08:00 today and false for 23:00 yesterday;
    - `anyOn` counts Klo;
    - value equality.
  - **`CareMeters.at`:**
    - meal 13:00, drink 12:30, Bauchgefühl 08:00 at 14:00 → food 0.83, drink 0.575, gutFeeling 0.7875;
    - `level(CareNeed.toilet)` is null;
    - `lowest`: the drink; with nothing logged → `CareNeed.food` (ties).
  - **`CareCopy`:**
    - `looLine` → `'vor 3 Std'` for Klo at 11:00, `'heute noch nicht'` for Klo yesterday;
    - `spoken(drink)` → `'zuletzt vor 1 Std'`, and `notYet` without a drink.
- [ ] **Step 2:** Run `flutter test test/config test/services/buddy/care_meters_test.dart`. Expected: FAIL (undefined).
- [ ] **Step 3: Implement** per the interfaces and rules. Update the colour comment block in `AppTheme` (one colour and one soft tint per need; the flame's lit, ember and off colours).
- [ ] **Step 4:** Run the tests again. Expected: PASS. Run `flutter test test/screens/dashboard/widgets/care_ring_test.dart`; the old ring only changes colour and still passes.
- [ ] **Step 5: Commit** `feat(home): need-meter model and colours (drain, night pause, floor)`

---

### Task 2: Home knows the latest entries before today

**Files:**
- Modify:
  - `lib/services/entry_query_service.dart`
  - `lib/repositories/entry_repository.dart`
  - `lib/providers/entries_provider.dart`
  - `lib/services/buddy/care_meters.dart` (`CareLog.fromEntries`)
  - `test/helpers/fakes.dart`
- Create: `lib/providers/care_log_provider.dart`
- Test:
  - `test/services/entry_query_service_test.dart`
  - `test/providers/entries_provider_test.dart`
  - `test/services/buddy/care_meters_test.dart`
  - `test/providers/care_log_provider_test.dart` (create)

**Interfaces:**
- Consumes: `CareLog` (Task 1).
- Produces:
  - In `entry_query_service.dart`: `class LatestEntries { const LatestEntries({this.meal, this.drink, this.gutFeeling}); final DateTime? meal, drink, gutFeeling; }`, with value equality.
  - `Future<LatestEntries> EntryQueryService.fetchLatestBefore({required String userId, required DateTime before})`.
    - For `meal_entries`, `drink_entries` and `gut_feeling_entries`, in parallel: `select('tracked_at').eq('user_id', userId).lt('tracked_at', before.toIso8601String()).order('tracked_at', ascending: false).limit(1)`.
    - The first row's `tracked_at` is parsed, or null when there is none.
    - Errors are logged and rethrown.
    - `before.toIso8601String()` is the same format `fetchEntriesForDateRange` uses for its start, so the two windows meet without a gap.
  - `Future<LatestEntries> EntryRepository.fetchLatestBefore({required String userId, required DateTime before})`, a pass-through.
  - `EntriesState.latestBefore`: `LatestEntries`, default `const LatestEntries()`; `copyWith({LatestEntries? latestBefore})`.
  - `EntriesNotifier.loadEntries(date)`:
    - It runs `fetchForDate` and `fetchLatestBefore(before: startOfDay(date))` together.
    - A failing latest-before query is logged and gives `const LatestEntries()`; the day still loads.
    - Only the latest load publishes, and it publishes both.
    - `fetchForDate`'s error path is unchanged.
  - `factory CareLog.fromEntries(EntriesState s, DateTime day)`:
    - each `lastXAt` is the latest of the state's entries of that kind and `s.latestBefore` (all `toLocal()`);
    - Klo comes from `s.toiletEntries` only;
    - `lastGutFeelingLevel` is the level of `day`'s latest Bauchgefühl (as `DailyCare` did).
  - `final careLogProvider = Provider<CareLog>`: `CareLog.fromEntries(entries, entries.day ?? ref.read(buddyClockProvider)())`.
  - `FakeEntryRepository`: `LatestEntries latestBefore = const LatestEntries()`, and `final List<DateTime> latestBeforeRequests`.

- [ ] **Step 1: Failing tests.**
  - **Query** (follow the `fetchTrackedAtSince` tests' mocking):
    - `fetchLatestBefore selects tracked_at before the moment, newest first, one row`: it verifies `lt('tracked_at', '2026-11-23T00:00:00.000')`, `order('tracked_at', ascending: false)` and `limit(1)` on each of the three tables, and that `toilet_entries` is never queried;
    - `maps each table's row, null without one`;
    - `rethrows`.
  - **Notifier** (`entries_provider_test.dart`; `setUp` stubs `fetchLatestBefore` with `const LatestEntries()` for every existing test):
    - `loadEntries brings the latest entries before the day`: `before == DateTime(2026, 11, 23)` for `loadEntries(DateTime(2026, 11, 23, 14))`, and `state.latestBefore.drink == DateTime(2026, 11, 22, 21)`;
    - `a failing latest-before query still loads the day`: the meals are set, `latestBefore == const LatestEntries()`, `error == null`;
    - `a superseded load publishes neither`.
  - **`CareLog.fromEntries`:**
    - a meal today 08:00 plus latest-before meal yesterday 19:00 → `lastMealAt` 08:00;
    - only latest-before → yesterday 19:00;
    - UTC `tracked_at` is converted to local;
    - Klo only from today's list;
    - `lastGutFeelingLevel` null when the only Bauchgefühl is yesterday's.
  - **Provider** (`care_log_provider_test.dart`, modelled on `daily_care_provider_test.dart`):
    - `follows the entries`;
    - `before the first load, today by the Buddy's clock`;
    - `careLogProvider follows a reload without the deleted entry`: push a state without today's drink but with latest-before drink yesterday 21:00 → `lastDrinkAt` is yesterday 21:00.
- [ ] **Step 2:** Run `flutter test test/services/entry_query_service_test.dart test/providers/entries_provider_test.dart test/services/buddy test/providers/care_log_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `loadEntries` starts both futures, then awaits the day's first and the latest-before second. Not `(a, b).wait`: that would wrap `fetchForDate`'s error in a `ParallelWaitError`, and the existing `repo error sets state.error and rethrows` expects the original error.
  - The latest-before future catches its own error, so a failure never fails the day.
  - `dailyCareProvider` stays until Task 4.
- [ ] **Step 4:** Run the tests again, then `flutter test test/providers test/screens/dashboard`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(home): Home's load knows the latest meal, drink and Bauchgefühl before today`

---

### Task 3: `NeedMeter`

**Files:**
- Create: `lib/widgets/buddy/need_meter.dart`
- Modify: `lib/config/constants.dart`
- Test: `test/widgets/buddy/need_meter_test.dart` (create)

**Interfaces:**
- Consumes: the care colours (Task 1).
- Produces:
  - `({Color color, Color soft}) careColorsOf(CareNeed need)`: food → `careFood`/`careFoodSoft`, drink → `careWater`/…, gutFeeling → `careGut`/…, toilet → `careLoo`/`careLooSoft`.
  - `NeedMeter({super.key, required CareNeed need, required double? level, required double size, required Widget child})`, a `StatelessWidget`.
    - It paints a `size` circle with `NeedMeterPainter` and centres `child` in a `size × 0.5` box through `FittedBox(fit: BoxFit.scaleDown)`.
    - It adds no semantics (the bubble or page speaks).
  - `NeedMeterPainter` (public for tests) has fields `need` and `level`, plus `@visibleForTesting` getters `Color get fill` and `double get sweep`. It paints:
    - **metered (`level` non-null):**
      - the fill `Color.lerp(AppTheme.background, soft, level)`;
      - a track ring `AppTheme.muted`;
      - an arc in `color` from 12 o'clock clockwise, `sweep = 2π · level`, round caps;
      - stroke `size × careMeterStrokeShare`.
    - **Klo (`level == null`):** the fill `careLooSoft` and a `careLoo` ring of `AppConstants.borderWidthLg`, with no arc.
  - `AppConstants.careMeterStrokeShare = 0.085`.

- [ ] **Step 1: Failing tests.**
  - `fill deepens with the level`: water at 0.5 → `fill == Color.lerp(background, careWaterSoft, 0.5)`, `sweep == closeTo(pi, 1e-9)`.
  - `each need draws in its own colour`: `careColorsOf` for all four.
  - `Klo: a plain circle, no arc`: `sweep == 0`, `fill == careLooSoft`.
  - `the child is centred and scaled down to half the size`: a 200 px wide `Text` child inside a 60 px meter → its rendered width ≤ 30.
  - `no semantics of its own`: inside `ensureSemantics`, the meter adds no node.
- [ ] **Step 2:** Run `flutter test test/widgets/buddy/need_meter_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(home): a need's meter as a filling circle`

---

### Task 4: Home's ring becomes need meters

**Files:**
- Modify:
  - `lib/screens/dashboard/widgets/care_ring.dart` (rewrite)
  - `lib/screens/dashboard/widgets/buddy_hero.dart`
  - `lib/services/buddy/daily_care.dart`
  - `lib/services/buddy/buddy_mood_logic.dart`
  - `lib/services/buddy/buddy_copy.dart`
  - `lib/widgets/common/bb_bottom_nav.dart`
  - `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart`
  - `lib/config/constants.dart`
- Delete: `lib/providers/daily_care_provider.dart`, `test/providers/daily_care_provider_test.dart`
- Test:
  - `test/screens/dashboard/widgets/care_ring_test.dart` (rewrite)
  - `test/services/buddy/daily_care_test.dart`
  - `test/services/buddy/buddy_mood_logic_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart`
  - `test/router/navigation_shell_test.dart`

**Interfaces:**
- Consumes: `CareLog`, `CareMeters`, `CareCopy` (Task 1); `careLogProvider`, `LatestEntries` (Task 2); `NeedMeter` (Task 3).
- Produces:
  - `CareRing({super.key, required CareLog log, required DateTime now, required double diameter, required Widget buddy, required ValueChanged<CareNeed> onNeed, CareNeed? highlight})`.
    - `needKey` and `diameterFor` are unchanged.
    - New: `static double meterSizeFor(double diameter) => (diameter * AppConstants.careMeterFactor).clamp(careMeterMinSize, careMeterMaxSize)`.
    - Constants: `careMeterFactor = 0.27`, `careMeterMinSize = 48.0`, `careMeterMaxSize = 72.0`.
    - Removed: `careRingStroke`, `careRingGapDegrees`, `_RingPainter`, `_ProgressTween`.
  - **A bubble** (same corners, same tap area including the glow padding, still a `Semantics(button, label: need.logLabel, value: CareCopy.spoken(...))`) is a `Column`:
    - the meter in its glow;
    - `need.label` (`fontSizeCaptionLG`, w600, one line, scaled down);
    - for Klo, a second line `CareCopy.looLine` (`fontSizeCaption`, `mutedForeground`).

    Each metered level sits in a `TweenAnimationBuilder<double>` (`animMedium`, `Duration.zero` with reduced motion), so a rebuild with the same level never animates. The meter's child is the emoji at `AppTheme.fontSizeHeading`, which `NeedMeter` scales down on small rings. The Bauchgefühl emoji is `lastGutFeelingLevel?.face ?? need.emoji`. The glow is the existing pulsing `careGlow`, now a circle around the meter.
  - `CareAction nextCareAction(CareLog log, DateTime now)`. `DailyCare`, `glassesForMl` and `DailyCare.*Goal` are gone; `CareNeed`, `CareAction`, `DayParts` and `mealSlotAt` stay.
  - `BuddyMood deriveBuddyMood(CareLog log, DateTime now)`.
  - `CareNeed careNeedOf(EntryKind kind)` in `buddy_mood_logic.dart`. It replaces the hero's private `_needOf`.
  - `BuddyHero`:
    - `_care` is a `CareLog` from `ref.listenManual(careLogProvider, …)`; meters come from `CareMeters.at(_care, _careAt)`.
    - `_updateCare` rebuilds when the log, the meters or the action changed.
    - `_justDrank` reads `_care.lastDrinkAt`.
    - The ring gets `log: _care, now: _careAt`.
  - `BbBottomNav._openLogSheet` suggests `nextCareAction(ref.read(careLogProvider), now).need`. The doc says "its meters" instead of "its counts".
  - Copy (`BuddyCopy`):
    - `care[CareAction.drink] = ['Hast du Durst? 💧', 'Schluck für Schluck: Was hast du getrunken?']`;
    - `careAfterLog[CareAction.drink] = ['Danke fürs Trinken! 💧', 'Ahh, das tat gut! 💧']`;
    - `care[CareAction.feed] = ["Mir geht's richtig gut, danke dir! 💚", 'Du hast toll für uns gesorgt!', 'Rundum zufrieden – danke dir!']`.
  - Tour step 1 (marked): `Das ist dein **Buddy**! Jeder Eintrag hält euren 🔥 **Streak** am Leben. Seine **Blasen** füllen sich, wenn du einträgst, und leeren sich langsam – tipp auf eine, um einzutragen.`

**Rules** (the order is load-bearing):
- **`nextCareAction`:**
  1. `m = CareMeters.at(log, now)`.
  2. If `m.level(m.lowest)! >= careMeterLow` → `feed`.
  3. Else, by the lowest need:
     - food → `mealSlotAt(now) ?? CareAction.feed`;
     - drink → `drink`;
     - gutFeeling → `gutFeeling`.
- **`deriveBuddyMood`:**
  1. `!log.anyOn(now) && hour < 10` → sleepy;
  2. lowest ≥ `careMeterHigh` → energetic;
  3. lowest ≥ `careMeterLow` → happy;
  4. 10 ≤ hour < 22 → hungry;
  5. else sleepy.

- [ ] **Step 1: Failing tests.**
  - **`nextCareAction`** (rewrite the group; the `mealSlotAt` group stays):
    - `nothing logged: the meal of the time of day`: 08:00 → breakfast, 13:00 → lunch, 16:00 → snack, 19:00 → dinner;
    - `nothing logged at night: Essen eintragen`: 02:00 → feed;
    - `the lowest meter wins, Klo never does`: meal 12:00, drink 10:00, Bauchgefühl 08:00 at 13:00 → drink, also with Klo at 12:59;
    - `Bauchgefühl when it is lowest`: meal 12:00, drink 12:00, Bauchgefühl yesterday 08:00 → gutFeeling (0.29 vs 0.72 vs 0.83);
    - `Essen lowest: the meal of the time of day`: meal 08:00, drink 12:30, Bauchgefühl 09:00 at 12:45 → lunch;
    - `ties go Essen, Trinken, Bauchgefühl`: meal 13:00, nothing else, at 14:00 → drink;
    - `nothing under 35 %: feed`: meal 12:00, drink 12:00, Bauchgefühl 08:00 at 13:00 → feed;
    - `a drink for later today is no thirst`: drink 18:00 at 13:00 → not drink.
  - **`deriveBuddyMood`** (rewrite the group):
    - nothing today: 09:59 → sleepy, 10:00 → hungry;
    - meal 13:30, drink 13:30, Bauchgefühl 08:00 at 14:00 → energetic;
    - meal 13:00, drink 12:00, Bauchgefühl 08:00 → happy;
    - drink 10:00 instead → hungry;
    - the same at 22:30 → sleepy;
    - only Klo at 07:00, at 08:00 → sleepy;
    - `yesterday's late drink still counts`: drink yesterday 21:30, meal 07:00, Bauchgefühl 07:15 at 07:30 → energetic.
  - **Ring** (`care_ring_test.dart`; the helper `meter(tester, need)` reads the `NeedMeter.level` inside `CareRing.needKey(need)`):
    - `each metered need shows its level, Klo its last time`: meal 13:00, drink 12:30, Bauchgefühl 08:00, Klo 11:00 at 14:00 → 0.83 / 0.575 / 0.7875, plus the texts `Klo` and `vor 3 Std`;
    - `Klo before today's first entry: heute noch nicht` (Klo yesterday 22:00);
    - `Bauchgefühl shows today's latest level`: the existing face test, on `CareLog(lastGutFeelingAt: …, lastGutFeelingLevel: level)`;
    - `bubbles are buttons that say when it was last`: values `zuletzt vor 1 Std` (meal 13:00), `noch nicht eingetragen` (no drink) and `heute noch nicht` (Klo);
    - `a rebuild with the same levels does not animate; a change does` (as before);
    - `reduced motion: a new level shows at once`: after one `pump()` the level is the new one, and `hasScheduledFrame` is false;
    - `the four-quarter ring is gone`: every `CustomPaint` under `CareRing` lies inside a `NeedMeter`;
    - the glow, tap, corner and no-overflow tests stay;
    - `small phone at text scale 1.3` uses Klo `heute noch nicht`.
  - **Hero** (replacements; the rest stays):
    - `lunch logged → he asks for a drink, Trinken glows`: instead of `🍽 1/3`, `meter(food) == closeTo(0.83, 0.005)`.
    - `every load reaches the ring at once`: the loads carry a meal at 13:00, then 13:30 → food 0.83, then 0.915.
    - `a meal logged 1 h ago → happy` becomes `meal 1 h ago, drink 2 h ago, Bauchgefühl this morning → happy`.
    - The two `right after a drink …` tests log the drink for `now − 4 h` (event and entry `trackedAt`). The drink meter stays at the floor, `💧 Trinken eintragen` shows, and he thanks with the new `careAfterLog` lines.
    - `resumed the next morning: yesterday's meal still counts`: `entries.next = EntriesState(latestBefore: LatestEntries(meal: DateTime(2026, 11, 22, 19)))` → at 08:00, food 0.32.
    - `open across midnight: the meters carry over`: food 0.49 at 23:59, the same after the 00:00:30 load that brings the meal as latest-before, then 0.405 at 07:30.
    - New: `the meters drain with the minute tick`: drink 13:00 → 0.717 at 14:00, 0.433 after the clock moves to 15:00 and a minute tick.
  - **Dashboard:** the tour test expects the new step 1.
  - **Shell:** `plus on Home opens the sheet for now with the suggested need`. With breakfast at 09:00 and nothing else, at 12:40 the drink is lowest → `_expectSelected(tester, CareNeed.drink)`; update the comment.
- [ ] **Step 2:** Run `flutter test test/services/buddy test/screens/dashboard test/router test/widgets/common/bb_bottom_nav_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Run `grep -rn "DailyCare\|dailyCareProvider\|glassesForMl\|careRingStroke" lib test integration_test` → empty.
- [ ] **Step 4:** Run the same tests plus `flutter test test/utils/vocabulary_test.dart test/widgets/log_sheet`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(home): the four needs as meters that drain with time`

---

### Task 5: The day's totals in the Tagebuch

**Files:**
- Modify: `lib/utils/diary_helpers.dart`, `lib/screens/diary/diary_screen.dart`
- Test: `test/utils/diary_helpers_test.dart`, `test/screens/diary/diary_screen_test.dart`

**Interfaces:**
- Produces:
  - `static String? DiaryHelpers.dayTotals(List<DiaryEntry> entries)`.
    - Parts, in order, each left out at 0: `'$n× Essen'`, `'<amount> getrunken'`, `'$n× Bauchgefühl'`, `'$n× Klo'`, joined with `' · '`.
    - The amount: below 1000 ml → `'$ml ml'`; otherwise litres rounded to one decimal (`(ml / 100).round() / 10`), with a comma and `,0` dropped (`'1,5 l'`, `'2 l'`).
    - null for no entries.
  - `DiaryScreen.totalsKey = Key('diary_day_totals')`: the first item of the day's list, above the cards, in `AppTheme.captionMutedStyle`, wrapping.

- [ ] **Step 1: Failing tests.**
  - `dayTotals`:
    - 2 meals, drinks 250 + 1250 ml, 1 Bauchgefühl → `'2× Essen · 1,5 l getrunken · 1× Bauchgefühl'`;
    - 750 ml → `'750 ml getrunken'`; 2000 → `'2 l getrunken'`; 1250 → `'1,3 l getrunken'`;
    - only one Klo → `'1× Klo'`;
    - empty → null.
  - Screen:
    - `the day's totals stand above its entries`: the `totalsKey` top < the first `DiaryEntryCard` top;
    - `an empty day shows no totals`;
    - `fits 375×667 at text scale 1.3` with all four parts.
- [ ] **Step 2:** Run `flutter test test/utils/diary_helpers_test.dart test/screens/diary`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(diary): the day's totals above its entries`

---

### Task 6: The streak flame

**Files:**
- Create: `lib/widgets/buddy/streak_flame.dart`
- Modify:
  - `lib/widgets/buddy/streak_chip.dart`
  - `lib/widgets/buddy/streak_week_row.dart`
  - `lib/screens/buddy/widgets/streak_moment.dart`
  - `lib/screens/dashboard/widgets/streak_sheet.dart`
  - `lib/providers/entries_provider.dart`
  - `lib/config/app_theme.dart` (remove `fontSizeStreakFlame`)
  - `lib/config/constants.dart`
  - `test/helpers/ambient_animations.dart`
  - `integration_test/helpers/test_app.dart`
- Test:
  - `test/widgets/buddy/streak_flame_test.dart` (create)
  - `test/widgets/buddy/streak_chip_test.dart`
  - `test/widgets/buddy/streak_week_row_test.dart`
  - `test/screens/dashboard/widgets/streak_sheet_test.dart`
  - `test/providers/entries_provider_test.dart`

**Interfaces:**
- Consumes: the flame colours (Task 1).
- Produces:
  ```dart
  enum FlameTier { small, medium, large, blazing }  // scales 0.62, 0.8, 1.0, 1.06
  enum FlameLook { off, ember, lit }
  class StreakFlame extends StatefulWidget {
    const StreakFlame({super.key, required this.streak, required this.lit, required this.height,
        this.igniteOnMount = false, this.still = false});
    const StreakFlame.mark({super.key, required this.height}); // a still, lit, large flame (week row)
    static FlameTier tierOf(int streak);   // 0–2 small, 3–6 medium, 7–29 large, 30+ blazing
    @visibleForTesting static bool ambientEnabled = true;
  }
  class FlamePainter extends CustomPainter { // public for tests
    final FlameLook look; final FlameTier tier;
    final double burst;   // 0..1 progress of the ignite burst, 0 when none
    final double wobble;  // −1..1, 0 when still
    final double breath;  // 0..1, the ember's breathing, 1 when still
  }
  ```
  - **Look:** `lit` → lit; `!lit && streak > 0` → ember; `!lit && streak == 0` → off.
  - **Size:** height `height`, width `height × 100 / 120`.
  - **Drawing** (in a 100×120 box scaled to the size; every shape has a `buddyOutline` stroke):
    - The body is scaled by the tier about (50, 114); an ember is scaled × 0.8 more.
    - Fills:
      - lit: outer `streakFlame`, inner `streakFlameCore`, blazing core `streakFlameHot`;
      - ember: `streakEmber`, `streakEmberCore`, no hot core;
      - off: outer `streakEmberOff` only.
    - Shapes (port the mockup's SVG; widths are stroke widths):
      ```
      outer  M50 6C58 26 82 40 82 72C82 98 66 114 50 114C34 114 18 100 18 76C18 60 26 50 32 42C33 54 38 60 44 62C40 44 44 24 50 6Z   (4.5)
      shine  M25.5 88C23 78 24 67 29 59   white, 3.6, round, 85 % opacity (lit only)
      inner  M50 50C56 62 68 72 68 88C68 102 60 108 50 108C40 108 32 101 32 89C32 79 38 73 42 65C43 70 45 72 47 72C46 64 47 57 50 50Z   (3)
      core   M50 84C54 90 57 94 57 99C57 104 54 106.5 50 106.5C46 106.5 43 104 43 99C43 94 46 90 50 84Z   (2.6, blazing only)
      sparks circles (28,36,r3.4) (72,30,r3) (56,14,r2.6), rising and fading (blazing, ambient)
      burst  8 circles r4 from (50,66) to (0,−40) (28,−30) (40,−4) (30,24) (−30,24) (−40,−4) (−28,−30) (12,−46) offsets, fading; body pops 0.8 → 1.24 → 1
      ```
  - **Motion:**
    - **Ambient** (only while `ambientEnabled && !still && !disableAnimations`): the lit flame wobbles (skew ≤ 3°, period `streakFlameWobble`), the ember breathes (opacity 0.7–1.0 over `streakFlameBreath`), and a blazing flame's sparks rise.
    - **Ignite** (`streakFlameIgnite`, one shot):
      - It plays when `lit` turns true, or on the first build with `igniteOnMount`.
      - If `TickerMode` is off then, it waits and plays once visible.
      - With reduced motion it never plays, and the flame is lit at once.
      - `lit` turning false switches to the ember at once, with no animation.
  - Constants:
    - heights: `streakFlameChipHeight = 22.0`, `streakFlameMomentHeight = 72.0`, `streakFlameMarkHeight = 20.0`, `streakFlameIgniteHeight = 32.0`;
    - durations: `streakFlameIgnite = Duration(milliseconds: 750)`, `streakFlameWobble = Duration(milliseconds: 1700)`, `streakFlameBreath = Duration(milliseconds: 2800)`.
  - **`StreakChip`:**
    - It becomes `Row(StreakFlame(streak, lit: todayCounted, height: streakFlameChipHeight), SizedBox(width: spacingXs), Text(days))`.
    - The label text loses `🔥 `.
    - Semantics, muted colours, the tooltip and the pop on a rising streak are unchanged.
  - **`StreakMoment`:**
    - New parameter `bool lit = true`.
    - `StreakFlame(streak: streak, lit: lit, height: AppConstants.streakFlameMomentHeight)` replaces the `🔥` text.
    - `StreakSheet` passes `lit: status.todayCounted`.
    - The onboarding keeps the default: its streak moment comes right after the first meal.
  - **`StreakWeekRow`:** an active day shows `StreakFlame.mark(height: streakFlameMarkHeight)` instead of `🔥`.
  - **`EntriesNotifier._write(write, {bool refreshesBuddy = false})`:**
    - `_update`, `_delete` and `deleteByType` pass true.
    - After the revision bump: `if (ref.exists(buddyProvider)) unawaited(ref.read(buddyProvider.notifier).reload())`.
    - Inserts don't, because a tracker's log event already refreshes the Buddy.
  - `disableAmbientAnimationsForTests()` also sets `StreakFlame.ambientEnabled = false`.
  - `buildTestApp` calls `disableAmbientAnimationsForTests()` (import `../../test/helpers/ambient_animations.dart`) instead of its two lines.

- [ ] **Step 1: Failing tests.**
  - **Flame:**
    - `tiers by streak`: 0, 2 → small; 3, 6 → medium; 7, 29 → large; 30 → blazing;
    - `looks: lit, ember, off`: the painter `look` for (5, true), (5, false), (0, false);
    - `the blazing flame has its hot core and sparks`: `tier == blazing`;
    - `size keeps the 100:120 shape`: height 24 → width 20;
    - `ember → lit plays one burst`: after the rebuild, `burst > 0` within 300 ms, then `0` after 800 ms, and `hasRunningAnimations` is false;
    - `lit → ember: no burst` (today's first entry deleted again): `look == ember` and `burst == 0` right after one `pump()`;
    - `igniteOnMount bursts once on the first build`;
    - `an ignite while hidden plays once visible`: under `TickerMode(enabled: false)` flip `lit`, so no burst; enable it, and the burst runs;
    - `reduced motion: lit at once, no burst, no wobble`: `burst == 0`, `wobble == 0`, `hasScheduledFrame` false;
    - `ambient off in tests; on, it wobbles`: with `ambientEnabled = true` (reset in `tearDown`), `hasRunningAnimations` is true.
  - **Chip:**
    - `the flame replaces the emoji`: no `🔥` text, one `StreakFlame` whose `lit == todayCounted`, the text `4 Tage`;
    - `semantics unchanged`: `Streak: 4 Tage, Heute noch offen`.
  - **Week row:** `active days show a still flame mark`: 2 active days → 2 `StreakFlame`, no `🔥`.
  - **Sheet:** `„Dein Streak" shows the flame as an ember until today counts`: `todayCounted: false` → `look == ember`; no new text.
  - **Entries:**
    - `a delete or a move reloads a loaded Buddy`: override `buddyProvider` with a `FakeBuddyNotifier` subclass counting `reload`, read it once, then `deleteByType('meal', 'm1')` → 1, and `updateDrinkById(...)` → 2;
    - `an insert does not` → 0;
    - `no Buddy loaded: nothing reloads`: never read → no Buddy built.
- [ ] **Step 2:** Run `flutter test test/widgets/buddy test/screens/dashboard/widgets/streak_sheet_test.dart test/providers/entries_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Run `grep -rn "fontSizeStreakFlame" lib test` → empty.
- [ ] **Step 4:** Run the tests above plus `flutter test test/screens/dashboard test/screens/me test/screens/buddy`. Expected: PASS (`pumpAndSettle` still settles, since the seam holds the flame still).
- [ ] **Step 5: Commit** `feat(streak): a drawn flame that grows with the streak and glows until today's first entry`

---

### Task 7: The success page charges the need and lights the flame

**Files:**
- Create:
  - `lib/services/buddy/log_moment.dart`
  - `lib/providers/log_moment.dart`
  - `lib/widgets/buddy/log_success_hero.dart`
- Modify:
  - `lib/screens/trackers/meal/meal_tracker_screen.dart`
  - `lib/screens/trackers/drink/drink_tracker_screen.dart`
  - `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart`
  - `lib/screens/trackers/toilet/toilet_tracker_screen.dart`
  - `lib/config/app_theme.dart`, `lib/config/constants.dart`
- Test:
  - `test/services/buddy/log_moment_test.dart` (create)
  - `test/widgets/buddy/log_success_hero_test.dart` (create)
  - `test/screens/trackers/{drink,toilet,gut_feeling,meal}/…_test.dart`

**Interfaces:**
- Consumes: `CareLog`, `meterLevel`, `drainOf` (Task 1); `careLogProvider` (Task 2); `NeedMeter`, `careColorsOf` (Task 3); `careNeedOf` (Task 4); `StreakFlame` (Task 6); `BuddyStatus`.
- Produces:
  ```dart
  class LogMoment {
    const LogMoment({required this.need, this.from, this.to, this.ignitesDay});
    final CareNeed need;
    final double? from, to;   // the need's level before / with the entry, at the moment of saving; null for Klo
    final int? ignitesDay;    // the streak the entry makes when it is today's first; null otherwise
  }
  LogMoment logMomentFor({required CareNeed need, required DateTime trackedAt, required CareLog care,
      required DateTime now, BuddyStatus? buddy});
  LogMoment captureLogMoment(WidgetRef ref, {required EntryKind kind, required DateTime trackedAt});
  class ChargingMeter extends StatelessWidget {
    const ChargingMeter({super.key, required this.need, required this.from, required this.to, required this.size});
  }
  class LogSuccessHero extends StatelessWidget {
    const LogSuccessHero({super.key, required this.moment, required this.kind, required this.sentiment, this.foodImageBytes});
    static const igniteKey = Key('log_success_ignite');
  }
  ```
  - **`logMomentFor`:**
    - `from = meterLevel(care.lastAt(need), now, drain)`;
    - `to = meterLevel(latest of care.lastAt(need) and trackedAt, now, drain)`;
    - both are null for Klo.
    - `ignitesDay = buddy.streak + 1` when all of these hold: `buddy != null`, `!buddy.todayCounted`, `isSameDay(trackedAt, now)`, `!care.anyOn(now)`.
  - **`captureLogMoment`:** reads `careLogProvider`, `buddyClockProvider` and `buddyProvider.value`, with `need = careNeedOf(kind)`. Each tracker calls it right before its write and keeps the result in a `LogMoment? _moment` field:
    - toilet and Bauchgefühl in `_save`;
    - drink in `_save` before `save()`;
    - meal in `_save` before `notifier.save()`, create mode only.
  - **`ChargingMeter`:**
    - It is a `TweenAnimationBuilder<double>(tween: Tween(begin: from, end: to), duration: AppConstants.careChargeDuration, curve: Curves.easeOutCubic)` over a `NeedMeter`.
    - With reduced motion the tween is `Tween(begin: to, end: to)` with `Duration.zero`.
    - The child is the need's emoji at `AppTheme.fontSizeChargeIcon`, inside `ExcludeSemantics`.
  - **`LogSuccessHero`:** a `LayoutBuilder` → `Column(mainAxisSize: min)` with:
    - `ChargingMeter(size: min(careChargeSize, maxHeight × careChargeHeightShare))` (not for Klo);
    - `gap8`;
    - when `ignitesDay != null`, `Row(key: igniteKey, mainAxisSize: min)` holding `StreakFlame(streak: n, lit: true, height: streakFlameIgniteHeight, igniteOnMount: true)`, then `spacingSm`, then `Text('Tag $n')` (`fontSizeTitleLG`, w700, `primaryForeground`), followed by `gap8`;
    - `Flexible(BuddyReactionView(kind, sentiment, foodImageBytes))`.
  - Each tracker passes `_moment == null ? null : LogSuccessHero(moment: _moment, …)` where it passed `BuddyReactionView` before. Drink and meal build their success illustration on every build, so never force-unwrap. The Bauchgefühl tracker passes it as `BbSuccessOverlay.illustration`. „Tippen zum Fortfahren" and the meal page's actions and callout are unchanged.
  - Constants: `careChargeSize = 120.0`, `careChargeDuration = Duration(milliseconds: 1200)`, `careChargeHeightShare = 0.3`; `AppTheme.fontSizeChargeIcon = 44`.

- [ ] **Step 1: Failing tests.**
  - **`logMomentFor`** at 14:00:
    - drink last at 13:00 → `from` 0.717, `to` 1.0;
    - `a back-dated entry older than the last changes nothing`: drink for 11:00 → `from == to == 0.717`;
    - `an entry for later today charges to full`: drink for 18:00 → `to` 1.0;
    - Klo → both null;
    - ignite cases:
      - status (streak 4, not counted) and an entry today → `ignitesDay` 5;
      - counted → null;
      - the entry dated yesterday → null;
      - `care.anyOn(now)` → null;
      - no status → null;
      - streak 0 → 1.
  - **`LogSuccessHero`:**
    - `the circle charges from the old level to the new in about 1.2 s`: `from` 0.4, `to` 1.0 → 0.4 at once, strictly between at 600 ms, 1.0 at 1300 ms;
    - `reduced motion: the new level at once`: 1.0 after one `pump()`, and `hasScheduledFrame` false;
    - `Klo: no circle`;
    - `today's first entry: the flame ignites next to „Tag 5"`: `igniteKey` found, `Tag 5`, `StreakFlame.lit`;
    - `otherwise no flame`;
    - `fits a short slot`: inside a `SizedBox(height: 260)` with the ignite row → `takeException()` null.
  - **Trackers:**
    - `the drink success page charges Trinken to full`: `ChargingMeter` with `need == CareNeed.drink` and `to == 1.0`;
    - `the Klo success page has no circle`;
    - `the Bauchgefühl page charges Bauchgefühl`;
    - `the meal page fits 375×667 at text scale 1.3 with its circle, actions and callout`;
    - existing `BuddyReactionView` finds stay green: it is a descendant now.
- [ ] **Step 2:** Run `flutter test test/services/buddy/log_moment_test.dart test/widgets/buddy/log_success_hero_test.dart test/screens/trackers`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again plus `flutter test test/widgets/common test/widgets/buddy`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(log): the success page charges the need's circle and lights the day's flame`

---

### Task 8: Journey data and who sees it

**Files:**
- Modify: `lib/models/insights.dart`, `lib/services/insights/insights_engine.dart`, `lib/config/constants.dart`
- Create: `lib/providers/journey_provider.dart`
- Test:
  - `test/models/insights_test.dart`
  - `test/services/insights/insights_engine_test.dart`
  - `test/providers/journey_provider_test.dart` (create)

**Interfaces:**
- Produces:
  - `class JourneyDay { const JourneyDay(this.day, {required this.gutFeeling}); final DateTime day; final bool gutFeeling; }`, with value equality and `toString`.
  - `Insights({…, this.journey = const []})`, `final List<JourneyDay> journey`.
    - It holds the latest `InsightRules.daysNeeded` local days with any entry in the window, oldest first, each marking a Bauchgefühl entry that day.
    - It joins `==`, `hashCode` and `toString`. The default keeps existing fixtures compiling.
    - `computeInsights` fills it from the same active-day set as `progress.activeDays`, so `journey.length == min(activeDays, 7)`.
  - `AppConstants.keyInsightJourneyPrefix = 'insight_journey_'`.
  - `final journeyProvider = NotifierProvider<JourneyNotifier, bool?>`:
    - **`build()`:**
      - It watches `currentUserIdProvider`; signed out → null.
      - It starts `SharedPreferences.getInstance()` at once.
      - It listens to `insightsProvider` with `fireImmediately`. On the first `AsyncData` (only that class, never a loading or error state with a value), it decides.
    - **Deciding:**
      - A stored `bool` under `<prefix><userId>` wins.
      - Otherwise the value is `!insights.unlocked && insights.progress.activeDays < InsightRules.daysNeeded`, and it is stored.
      - The state stays as decided for this build; the decision never changes for the user and device.
    - Prefs that can't be read or written are logged, and the computed value is used, unstored.
    - A result for a user who is no longer current is dropped.
    - null means undecided.

- [ ] **Step 1: Failing tests.**
  - **Engine:**
    - `journey: the latest 7 days with entries, oldest first, each marking a Bauchgefühl`: activity on days −9, −5, −3, −1 and 0, with Bauchgefühl on −3 and 0 → five `JourneyDay`s, `gutFeeling` `[f, f, t, f, t]`;
    - with 9 active days → only the latest 7;
    - `journey.length` matches `progress.activeDays` up to 7.
  - **Model:** `journey` takes part in equality.
  - **`journeyProvider`** (fake insights via `insightsProvider.overrideWith`, `SharedPreferences.setMockInitialValues({})`):
    - `a new user (2 days, locked) gets the journey, stored`: `true`, and prefs `insight_journey_<uid> == true`;
    - `a user past day 7 (9 days, 1 Bauchgefühl) gets none`: `false`;
    - `an unlocked user gets none`;
    - `decided once`: stored `true` stays `true` at 9 days, stored `false` stays `false` at 2 days;
    - `undecided while the insights load`: null under `AsyncLoading`;
    - `per user`: user B is decided under its own key;
    - `signed out: null`.
- [ ] **Step 2:** Run `flutter test test/models/insights_test.dart test/services/insights test/providers/journey_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again plus `flutter test test/providers test/screens/patterns`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(insights): the first-patterns journey's days, decided once per user who sees it`

---

### Task 9: The journey card on Home

**Files:**
- Create: `lib/screens/dashboard/widgets/journey_dots.dart`
- Modify:
  - `lib/screens/dashboard/widgets/insight_card.dart`
  - `lib/screens/dashboard/dashboard_screen.dart`
  - `lib/services/insights/insight_copy.dart`
  - `lib/config/constants.dart`
- Test:
  - `test/screens/dashboard/widgets/journey_dots_test.dart` (create)
  - `test/screens/dashboard/widgets/insight_card_test.dart`
  - `test/services/insights/insight_copy_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `JourneyDay`, `Insights.journey`, `journeyProvider` (Task 8); `careGut` (Task 1).
- Produces:
  - `JourneyDots({super.key, required List<JourneyDay> days})`, a `StatefulWidget`. It shows 7 slots spaced evenly over a `muted` track line (`journeyTrackHeight`).
    - **Filled slots** (`days[i]`): `journeyDotSize` circles in `primary` with a `buddyOutline` border and a check, plus a `careGut` pip (`journeyPipSize`) under days with a Bauchgefühl.
    - **Empty slots:** `background` with a `border` outline.
    - **The Buddy:** a still Buddy (`CustomPaint(painter: BuddyPainter(controller))` over a never-ticked `BuddyController(mood: BuddyMood.happy)` owned and disposed by the state, height `journeyBuddyHeight`) stands on the last filled dot, or on dot 1 with none.
    - **Bump:** when `days.length` grows while mounted, the new dot bumps (scale 1 → 1.14 → 1 over `journeyDotBump`). There is no bump with reduced motion or on the first build.
    - The whole row is `ExcludeSemantics`: the counters speak.
    - `static Key dotKey(int i)`, `static const buddyKey`, `static const pipKey`.
  - `InsightCard({super.key, required AsyncValue<Insights> insights, bool? journey, Widget? journeyReward})`:
    - locked and `journey == true` → `_Journey`:
      - the existing header (lock, title, „MUSTER ›");
      - `InsightCopy.journeyLine(progress)`;
      - `JourneyDots(days: insights.journey)`;
      - `journeyReward` (when non-null, under the dots: Stage 3's slot);
      - the counters row `Wrap(spacing, runSpacing)` with `journeyDays` and `journeyGutFeelings` (`fontSizeCaptionLG`, the numbers w600).
    - locked and `journey == false` → the Stage 2 `_Locked` (both bars), unchanged.
    - locked and `journey == null` → hidden (`SizedBox.shrink()`, like loading).
    - Unlocked: unchanged.
  - `DashboardScreen` passes `journey: ref.watch(journeyProvider)` inside the existing `Consumer`.
  - `InsightCopy`:
    - `static String journeyLine(InsightProgress p)`, locked only, by `min(activeDays, 7)`:
      - 0 → `'Mit deinem ersten Eintrag fang ich an zu lernen.'`
      - 1 → `'Tag 1! Ich lerne gerade, was du so isst.'`
      - 2 → `'Ich sammle, was du isst und wie’s deinem Bauch danach geht.'`
      - 3 → `'Ich lerne gerade, was dir guttut.'`
      - 4 → `'Mehr als die Hälfte. Jeder Tag macht das Bild klarer.'`
      - 5 → `'Jetzt hab ich schon ein paar Tage zum Vergleichen.'`
      - 6 → `'Noch ein Tag, dann schau ich nach ersten Mustern.'`, or with Bauchgefühl entries missing `'Noch ein Tag und ${g}× Bauchgefühl, dann schau ich nach ersten Mustern.'`
      - 7 → `'Noch ${g}× Bauchgefühl, dann schau ich nach ersten Mustern.'`
      - (`g` = `gutFeelingsLeft`)
    - `static String journeyDays(InsightProgress p)` → `'${min(activeDays, 7)} von 7 Tagen'`.
    - `static String journeyGutFeelings(InsightProgress p)` → `'Bauchgefühl ${min(n, 3)} von 3'`, plus `' ✓'` once met.
  - Constants: `journeyDotSize = 22.0`, `journeyPipSize = 7.0`, `journeyBuddyHeight = 34.0`, `journeyTrackHeight = 3.0`, `journeyDotBump = Duration(milliseconds: 900)`.

- [ ] **Step 1: Failing tests.**
  - **Copy:** each `journeyLine` case:
    - (0, 0) → day 0 line;
    - (2, 1) → day 2 line;
    - (6, 3) → `Noch ein Tag, dann …`;
    - (6, 1) → `Noch ein Tag und 2× Bauchgefühl, …`;
    - (9, 1) → `Noch 2× Bauchgefühl, …`.

    Then `journeyDays` (9 → `7 von 7 Tagen`) and `journeyGutFeelings` (1 → `Bauchgefühl 1 von 3`, 4 → `Bauchgefühl 3 von 3 ✓`).
  - **Dots:**
    - `fills one dot per day with entries, a green pip for Bauchgefühl days`: 3 days `[t, f, t]` → 3 filled, 2 pips;
    - `the Buddy stands on the last filled dot`: `buddyKey` centre x ≈ `dotKey(2)` centre x; with no days ≈ `dotKey(0)`;
    - `a dot that fills while shown bumps`: rebuild with 4 days → `hasRunningAnimations` true, then settles;
    - `reduced motion: no bump`: `hasScheduledFrame` false;
    - `no semantics of its own`.
  - **Card:**
    - `a journey user's locked card: line, dots, counters, opens Muster`: `journey: true`, progress (2, 1) with 2 journey days → the day 2 line, `JourneyDots`, `2 von 7 Tagen`, `Bauchgefühl 1 von 3`, no `InsightProgressBars`; a tap → `/patterns`;
    - `without the journey: Stage 2's bars` (`journey: false`): the existing locked tests;
    - `undecided: hidden` (`journey: null`, locked);
    - `unlocked ignores the journey`;
    - `a reward shows under the dots when given`: `journeyReward: Text('R')` lies between `JourneyDots` and the counters;
    - `fits 375×667 at text scale 1.3` with 7 days.
  - **Dashboard:**
    - the insight-card tests that assert `Noch N Tage, dann zeig ich dir erste Muster.` now assert the journey counter (`InsightCopy.journeyDays(...)`): their users are new, so they get the journey (prefs mocked in `setUp`).
    - `deleting the 3rd gut-feeling entry locks the card again` expects `Bauchgefühl 2 von 3`.
    - Add `a user past day 7 sees Stage 2's card`: prefs hold `insight_journey_<testUserId>: false` → `Tage mit Einträgen` is shown.
- [ ] **Step 2:** Run `flutter test test/services/insights test/screens/dashboard`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again plus `flutter test test/router test/utils/vocabulary_test.dart`. Expected: PASS (the shell's `Home fits 375×667 at text scale 1.3` included).
- [ ] **Step 5: Commit** `feat(home): the first 7 days as a journey on the insight card`

---

### Task 10: The feedback line after the day's first Bauchgefühl

**Files:**
- Modify:
  - `lib/services/buddy/log_moment.dart`
  - `lib/providers/log_moment.dart`
  - `lib/services/insights/insight_copy.dart`
  - `lib/widgets/buddy/buddy_reaction_view.dart`
  - `lib/widgets/buddy/log_success_hero.dart`
  - `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart`
- Test:
  - `test/services/buddy/log_moment_test.dart`
  - `test/services/insights/insight_copy_test.dart`
  - `test/widgets/buddy/buddy_reaction_view_test.dart`
  - `test/screens/trackers/gut_feeling/gut_feeling_tracker_test.dart`

**Interfaces:**
- Consumes: `LogMoment`, `logMomentFor`, `captureLogMoment` (Task 7); `InsightProgress`, `insightsProvider`.
- Produces:
  - `LogMoment.buddyLine` (`String?`).
  - `logMomentFor` gains `Insights? insights` and `LogSentiment sentiment = LogSentiment.good`.
    - `buddyLine` is set when all of these hold:
      - `need == gutFeeling`;
      - `sentiment != bad`;
      - `insights != null && !insights.unlocked`;
      - `isSameDay(trackedAt, now)`;
      - `!care.loggedOn(gutFeeling, now)`.
    - Its value is `InsightCopy.journeyFeedback(after)`, where `after = InsightProgress(activeDays: activeDays + (care.anyOn(now) ? 0 : 1), gutFeelingEntries: gutFeelingEntries + 1)`.
  - `captureLogMoment(ref, {kind, trackedAt, LogSentiment sentiment = LogSentiment.good})` passes the insights' `AsyncData` value only.
  - `static String? InsightCopy.journeyFeedback(InsightProgress after)`:
    - with days left → `'Notiert! Noch $n ${n == 1 ? 'Tag' : 'Tage'}, dann schau ich nach ersten Mustern.'`;
    - else with Bauchgefühl entries left → `'Notiert! Noch ${g}× Bauchgefühl, dann schau ich nach ersten Mustern.'`;
    - unlocked → null.
  - `BuddyReactionView({…, String? line})`: it says `line ?? reaction.line`. The action and mood stay the reaction's.
  - `LogSuccessHero` passes `line: moment.buddyLine`.
  - The Bauchgefühl tracker captures with the entry's sentiment.

- [ ] **Step 1: Failing tests.**
  - **Copy:**
    - (3 days, 2 Bauchgefühl) after → `Notiert! Noch 4 Tage, …`;
    - (6, 2) → `Noch 1 Tag`;
    - (7, 2) → `Notiert! Noch 1× Bauchgefühl, …`;
    - (7, 3) → null.
  - **`logMomentFor`:**
    - `today's first good Bauchgefühl while locked says how far it is`: progress (2, 1), nothing today → after (3, 2) → `Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.`;
    - `on a day that already counts, the days stay` (care has a meal today) → `Noch 5 Tage`;
    - `a second Bauchgefühl today: no line`;
    - `a bad one: no line`;
    - `unlocked: no line`;
    - `the entry that unlocks: no line` (6 days, 2 Bauchgefühl, nothing today);
    - `no insights: no line`;
    - `a back-dated Bauchgefühl: no line`.
  - **Reaction view:** `says the given line instead, keeps the reaction's action`.
  - **Tracker:**
    - `the day's first Bauchgefühl, locked: the Buddy says how far it is`: override `insightsProvider` with locked (2, 1) and `careLogProvider` with an empty log; good sliders → the bubble text equals the line;
    - `fits 375×667 at text scale 1.3 with the line and the ignite row`.
- [ ] **Step 2:** Run `flutter test test/services test/widgets/buddy test/screens/trackers/gut_feeling`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again plus `flutter test test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(log): after the day's first Bauchgefühl the Buddy says how far the first patterns are`

---

### Task 11: The Tipps preview and the new KI-Dienst sentence

**Files:**
- Create: `lib/screens/discover/widgets/example_tip_card.dart`
- Modify:
  - `lib/screens/discover/widgets/discover_tips_section.dart`
  - `lib/widgets/common/weekly_tips_switch.dart`
  - `lib/config/constants.dart`
- Test:
  - `test/screens/discover/widgets/discover_tips_section_test.dart`
  - `test/widgets/common/weekly_tips_switch_test.dart`
  - `test/screens/dashboard/widgets/weekly_tips_offer_sheet_test.dart`
  - `test/screens/discover/discover_screen_test.dart`

**Interfaces:**
- Produces:
  - `ExampleTipCard({super.key})`, with `static const cardKey = Key('discover_example_tip')` and the copy constants:
    - `label = 'Beispiel'`;
    - `lead = 'So sieht ein Tipp aus'`;
    - `title = 'Zwiebel mal tauschen?'`;
    - `body = 'Diese Woche war in 3 Mahlzeiten Zwiebel. Magst du mal das Grüne von Frühlingszwiebeln probieren? Danach siehst du an deinem Bauchgefühl, wie es dir damit geht.'`;
    - `footer = 'Ausgedachtes Beispiel, nicht aus deinen Einträgen.'`.

    Layout: on `AppTheme.background`, with a **dashed** `AppTheme.border` outline (`borderWidthLg`, `dashLength`/`dashGap`, radius `radiusLg`, a private `CustomPainter` over the rounded rect's path metrics):
    - a row with the pill (uppercase `label`, `fontSizeCaption`, w700, `mutedForeground` on `secondary`, radius `radiusSm`) and `lead` (`captionMutedStyle`);
    - `title` (`fontSizeSubtitleLG`, w700);
    - `body` (`fontSizeBodyLG`, `lineHeightBody`);
    - `footer` (`captionMutedStyle`).

    Its semantics read `'Beispiel-Tipp: $title. $body $footer'` as one node.
  - `DiscoverTipsSection`: wherever the opt-in card shows (weekly tips `false`), it is preceded by `ExampleTipCard` + `gap12`.
  - `WeeklyTipsSwitch`:
    - `static const subline = 'Jeden Montag 2–3 Tipps'` as the `SwitchListTile` subtitle;
    - `sentence = 'Dafür schicke ich deine Einträge der letzten Wochen, die Muster daraus und deine Bewertungen meiner Tipps an unseren KI-Dienst.'`.
  - Constants: `dashLength = 6.0`, `dashGap = 4.0`.

- [ ] **Step 1: Failing tests.**
  - **Section** (extend the state matrix): `ExampleTipCard.cardKey` is found exactly when the opt-in is, and its bottom lies above the opt-in's top.
  - **Card:**
    - `labelled as an example`: `BEISPIEL`, `So sieht ein Tipp aus`, the footer;
    - `a dashed outline`: a `CustomPaint` with the dash painter is a descendant;
    - `speaks as one example`: the semantics label starts with `Beispiel-Tipp: Zwiebel mal tauschen?`;
    - `fits 375×667 at text scale 1.3` above the switch.
  - **Switch:**
    - `shows the title, the Monday subline and the sentence`;
    - the old sentence is gone (`find.textContaining('Mahlzeiten und dein Bauchgefühl der letzten Woche')` finds nothing).
  - **Offer sheet:** the expected body uses the new sentence.
  - **Entdecken:**
    - `weekly tips off: the example above the switch`;
    - `on: no example`.
- [ ] **Step 2:** Run `flutter test test/screens/discover test/widgets/common test/screens/dashboard/widgets/weekly_tips_offer_sheet_test.dart test/screens/settings`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run again plus `flutter test test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(tips): an example tip above the opt-in; the switch says what it sends now`

---

### Task 12: Integration flows and the stage check

**Files:**
- Modify: `test/helpers/fakes.dart` (`FakeEntryRepository({…, this.countInsertsAsActivity = false})`: when true, `insertEntry` adds the row's local `tracked_at` day to the activity days, so the Buddy's refresh after a log sees today)
- Create: `integration_test/home_motivation_flow_test.dart`

`FakeEntryRepository.fetchForDate` returns its seeded result, never inserted rows. So the flows check the success pages and the Buddy, not Home's meters after a log; the widget tests of Tasks 2 and 4 cover those.

**Flows** (`setUp`: `setNotificationModalShown`, and remove `insight_journey_$testUserId` from the real prefs, which persist on the simulator between files):
1. **Meter and charge:**
   - today empty, with Home's clock real;
   - tap `CareRing.needKey(CareNeed.drink)`, then log a drink with the drink tracking flow's steps;
   - the success page shows a `ChargingMeter` for Trinken, whose level is 1.0 after `pump(1300 ms)`, and „Tippen zum Fortfahren";
   - a tap → back on Home.
2. **Flame:**
   - `FakeEntryRepository(countInsertsAsActivity: true)..seedActivityDays({the 3 days before today})` → the chip reads `3 Tage`, and its `FlamePainter.look == ember`;
   - log Klo through its bubble → the success page shows `Tag 4`;
   - continue → the chip reads `4 Tage`, and its look is lit.
3. **Journey and feedback:**
   - `insightSource` with 2 days with entries, none today, and 1 Bauchgefühl → the card shows `2 von 7 Tagen` and `Bauchgefühl 1 von 3`;
   - log a good Bauchgefühl → the success page's bubble says `Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.`
4. **Tipps preview:**
   - Entdecken with weekly tips off → `ExampleTipCard` above the switch;
   - turn it on → the example is gone, and `DiscoverTipsSection.emptyWhileOn` shows.

- [ ] **Step 1:** Write the flows and the fake's flag.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze` (0 issues) and the full `flutter test`. Expected: all pass.
- [ ] **Step 3: Only on the iPhone Air**, one file at a time:
  ```bash
  SIM=CB1F6232-482F-408F-ADF4-89FDA602E6A8
  xcrun simctl boot $SIM || true
  for f in home_motivation_flow_test insights_flow_test discover_flow_test tutorial_flow_test diary_flow_test drink_tracking_flow_test meal_tracking_flow_test recipes_flow_test auth_flow_test registration_flow_test; do
    flutter test integration_test/$f.dart -d $SIM --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown $SIM
  ```
  Expected: every file `EXIT 0`. If a case fails, run the same file on the base commit before calling it pre-existing. Use a temporary worktree for that, never a bare `git stash`.
- [ ] **Step 4: Commit** `test(integration): meters, the flame, the journey line and the Tipps preview`

---

## Self-Review notes

**Spec coverage:**

| Spec | Task(s) |
|---|---|
| §5.1 meters for Essen 5 h, Trinken 3 h, Bauchgefühl 24 h; linear, night pause, 15 % floor, future entries, yesterday counts | 1, 2, 4 |
| §5.1 Klo „vor X Std" / „heute noch nicht" | 1, 4 |
| §5.1 tokens `careWater/Food/Gut/Loo` + tints (≥3:1), glow on the suggested need | 1, 3, 4 |
| §5.1 next action and mood from the meters, meal logic for Essen, gentle lines („Hast du Durst? 💧") | 4 |
| §5.1 counts in the Tagebuch | 5 |
| §5.2 success page: the need's circle charges old → new in ~1.2 s, the Buddy's line, „Tippen zum Fortfahren", reduced motion | 7 |
| §5.2 the day's first entry ignites the flame next to „Tag n" | 6, 7 |
| §5.3 drawn flame in the chip and „Dein Streak", tiers, glimmt → ignite, neutral, `streakFlame`/`streakEmber` | 1, 6 |
| §5.4 „Beispiel" card (dashed, made-up footer), subline, KI-Dienst sentence (Decisions log item 4) | 11 |
| §5.5 journey: active-day dots, Bauchgefühl days green, the Buddy on the current dot, both counters, reward slot (empty), opens Muster | 8, 9 |
| §5.5 feedback line after the day's first Bauchgefühl while locked | 10 |
| §5.5 users already past day 7 see no journey | 8, 9 |
| §3 reduced motion, 375×667 @1.3, vocabulary | every UI task |

The §5.5 rewards table, the day-3 offer and the day-7 celebration are Stage 3 by §6.

**Interfaces across tasks:**
- `CareLog`, `CareMeters`, `meterLevel`, `drainOf`, `careAgo`, `CareCopy`: T1 → T2, T4, T7, T10.
- `LatestEntries`, `EntriesState.latestBefore`, `careLogProvider`: T2 → T4, T7, T10.
- `NeedMeter`, `careColorsOf`: T3 → T4, T7.
- `nextCareAction(CareLog, …)`, `deriveBuddyMood(CareLog, …)`, `careNeedOf`: T4 → T7.
- `StreakFlame`, `FlamePainter`, `FlameLook`: T6 → T7, T12.
- `LogMoment`, `logMomentFor`, `captureLogMoment`, `LogSuccessHero`, `ChargingMeter`: T7 → T10, T12.
- `JourneyDay`, `Insights.journey`, `journeyProvider`: T8 → T9.
- `InsightCopy.journeyLine/journeyDays/journeyGutFeelings`: T9 → T12. `journeyFeedback`: T10 → T12.
- `ExampleTipCard`, `WeeklyTipsSwitch.subline/sentence`: T11 → T12.

**Known, accepted:**
- The day query's boundary format (`startOfDay(date).toIso8601String()`, no offset) is pre-existing. The latest-before query uses the same format on purpose, so the windows abut, and the convention is not changed here.
- When a tracker opens before Home has loaded the day (cold start from a reminder), the circle charges from what Home knows, possibly the floor.
- For Severin, from the Decisions log: check whether the privacy policy's text on requested recommendations covers patterns and ratings.
