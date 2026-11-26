# Round 5b — Severin's click-through feedback — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Apply addendum 5b: streak badge at the flame (chip row goes), a taller recognisable flame, the notification re-ask, no „Beispiel".

**Architecture:** Home layout in `lib/screens/dashboard/` (buddy_hero, care_ring, home_flame) and `lib/widgets/buddy/` (streak_chip,
streak_flame); the re-ask rides the existing Home cue queue in buddy_hero (BuddyCopy lines, `homeCoveredProvider` gating) and the
notification helpers in `lib/providers/notification_provider.dart`.

**Tech Stack:** Flutter 3.50, Riverpod 3.5, GoRouter, shared_preferences, flutter_local_notifications/permission APIs already wrapped by
`notificationRepositoryProvider`.

**Spec:** `docs/superpowers/specs/2026-11-25-round5-polish-recipes-design.md` — „Addendum 5b" (binding), plus the round-5 sections it amends.

## Global Constraints
- CLAUDE.md: German UI copy; colors only via `AppTheme`; font sizes via `AppTheme.fontSize*`; spacing/radii via `AppConstants`; `AppLogger`, no print.
- Name is „Belly Buddy"; no invented statistics, no health claims; the Buddy never judges.
- Tap targets ≥ 48 dp; reduced motion respected; text never drawn below the user's text scale.
- `dart format .`, `flutter analyze` 0 issues, full `flutter test` under TZ=Europe/Vienna (and once TZ=UTC at the end) green.
- Integration only on iPhone Air CB1F6232-482F-408F-ADF4-89FDA602E6A8 (one file at a time, `--dart-define-from-file=env.json`, shut down after). NEVER 55746DB2 (Severin's live preview runs from THIS worktree — don't kill its flutter process) or 7A26EDD4. Never `flutter clean`.
- Commits: conventional prefixes, `git commit --no-verify`, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No push.

## Review Focus
1. Large text (375×667 @1.3 and @2.0): the badge never overlaps the need bubbles, never clips; the Home lines still fit their budget.
2. Streak 0 / 1 / 100+: badge text width (3 digits) and „1 Tag" vs „Tage" in semantics.
3. Notifications permanently denied on iOS/Android → „Einschalten" opens system settings, never a dead button.
4. Re-ask never during the tour, over a sheet, or twice in a day; never after the 4th time; never when reminders are on.
5. The taller flame never paints over the need bubbles or the speech bubble, and the tour's step-1 spotlight still fits the Buddy.

---

### Task 1: Home — streak badge, taller flame, no „Beispiel"

**Files:** Modify `lib/screens/dashboard/widgets/buddy_hero.dart`, `care_ring.dart`, `home_flame.dart`, `lib/widgets/buddy/streak_chip.dart`
(or a new `streak_badge.dart` beside it), `lib/widgets/buddy/streak_flame.dart` (only if the painter needs a parameter),
`lib/services/insights/insight_copy.dart`, the tour steps if one points at the chip; tests next to each.

- [ ] Tests first:
  - Home has no chip row above the ring; a badge with the count sits at the flame's lower right, opens „Dein Streak" on tap, has a ≥ 48 dp
    target and semantics „Streak: n Tage, Dein Streak öffnen" („1 Tag" for one); shows at 0.
  - The ring/bubble move up by the freed row (pin the ring's top against the previous layout minus the row height).
  - Flame geometry: its tips rise above the Buddy's head top by a clear margin (≥ 15 % of his height), it is offset to one side, opacity
    higher / blur lower than before (pin the new constants), and it stays clear of every need bubble's rect at 402×874 and 375×667 @1.3.
  - The label reads „Das siehst du dann" (no „Beispiel") — Muster preview and the day-6 sheet.
  - The tour step that pointed at the chip (if any) points at the badge.
- [ ] Implement; render Home (ember/brennt/lodert × talking/silent) at 402×874 and 375×667 @1.3 into
  `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/round5b-visual/` and LOOK: the
  flame must read as fire at a glance (tips clearly above his head), the Buddy still the hero, not him burning.
- [ ] Verify (format, analyze, full test), integration: home_motivation_flow, tutorial_flow, journey_rewards_flow. Commit(s).

### Task 2: Notifications — the Buddy asks again; Ich row

**Files:** Modify `lib/providers/notification_provider.dart` (a re-ask schedule), `lib/screens/dashboard/widgets/buddy_hero.dart` (the cue),
BuddyCopy, `lib/screens/me/me_screen.dart` (the row), `lib/config/constants.dart` (prefs keys); tests.

- [ ] Tests first:
  - „off" = OS permission not granted OR no notification flag on in the profile.
  - Schedule: eligible after the 2nd active day, after the 7th, then every 30 days after the last ask; at most 4 asks in total (count + last
    date in prefs); at most one a day; never while reminders are on.
  - The cue plays through the existing queue only while Home is free (not during the tour, not over a sheet); after the welcome/onboarding cues.
  - The cue shows a short line + explanation and two actions: „Einschalten" (→ `enableReminders`; when the OS reports permanently denied →
    opens the system app settings) and „Später" (counts as an ask).
  - Ich: while off, a row „Erinnerungen sind aus · Einschalten" (same action); hidden while on.
  - The onboarding step and the one-time dashboard dialog are unchanged.
- [ ] Implement; German copy in BuddyCopy (warm, short, no pressure, fits the 3-line budget).
- [ ] Verify (format, analyze, full test both TZ), integration: home_motivation_flow, tutorial_flow. Commit(s).
