# Slot-aware reminder pools — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Segment local meal and mood reminder bodies into morning/midday/evening pools so each reminder's copy matches its scheduled hour.

**Architecture:** A new pure-Dart module `lib/services/reminder_copy.dart` owns a `TimeSlot` enum, an hour-to-slot helper, and `ReminderCopy` with two pickers (`pickMealBody`, `pickMoodBody`). `LocalNotificationService` drops its private message constant and the inline mood literal and delegates body selection to the new pickers, passing the reminder's scheduled `hour` and its existing `_random`.

**Tech Stack:** Dart, Flutter, `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-04-18-slot-aware-reminder-pools-design.md`

**Branch:** `feat/slot-aware-reminder-pools` (already checked out, branched from `develop`)

## File structure

- **Create:** `lib/services/reminder_copy.dart` — `TimeSlot` enum, `timeSlotForHour(int)`, `ReminderCopy` class with `mealPools`, `moodPools`, `pickMealBody`, `pickMoodBody`. Public `const` maps (not private) so tests can assert pool membership without leaking internals via `@visibleForTesting`; the maps are immutable, so exposure is harmless. This is a minor deviation from the spec's `_mealPools`/`_moodPools` sketch, motivated by test ergonomics.
- **Create:** `test/services/reminder_copy_test.dart` — boundary table test for `timeSlotForHour`, per-slot picker tests, midday-mood fallback, pool-integrity sanity.
- **Modify:** `lib/services/local_notification_service.dart` — remove `_mealReminderMessages` (lines 34–39), import `reminder_copy.dart`, replace the meal body pick (lines 144–145) and the inline mood body literal (line 208) with picker calls.

---

## Task 1: `TimeSlot` enum + `timeSlotForHour` helper

**Files:**
- Create: `test/services/reminder_copy_test.dart`
- Create: `lib/services/reminder_copy.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/reminder_copy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/reminder_copy.dart';

void main() {
  group('timeSlotForHour', () {
    test('maps boundary hours correctly (night wraps into evening)', () {
      expect(timeSlotForHour(0), TimeSlot.evening);
      expect(timeSlotForHour(4), TimeSlot.evening);
      expect(timeSlotForHour(5), TimeSlot.morning);
      expect(timeSlotForHour(10), TimeSlot.morning);
      expect(timeSlotForHour(11), TimeSlot.midday);
      expect(timeSlotForHour(16), TimeSlot.midday);
      expect(timeSlotForHour(17), TimeSlot.evening);
      expect(timeSlotForHour(22), TimeSlot.evening);
      expect(timeSlotForHour(23), TimeSlot.evening);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:belly_buddy/services/reminder_copy.dart'`.

- [ ] **Step 3: Create the enum + helper**

Create `lib/services/reminder_copy.dart`:

```dart
enum TimeSlot { morning, midday, evening }

/// Maps a 24-hour clock hour to a [TimeSlot]. Hours 23 and 0–4 wrap into
/// [TimeSlot.evening] — we don't ship a separate "night" pool because the
/// volume doesn't justify it, and evening copy reads fine at 23:30.
TimeSlot timeSlotForHour(int hour) {
  if (hour >= 5 && hour <= 10) return TimeSlot.morning;
  if (hour >= 11 && hour <= 16) return TimeSlot.midday;
  return TimeSlot.evening;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/services/reminder_copy.dart test/services/reminder_copy_test.dart
git commit -m "$(cat <<'EOF'
feat(reminders): add TimeSlot enum and timeSlotForHour helper

Foundation for slot-aware reminder copy. Maps 24h clock hours to
morning/midday/evening buckets; night hours wrap into evening.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Meal pools + `pickMealBody`

**Files:**
- Modify: `test/services/reminder_copy_test.dart`
- Modify: `lib/services/reminder_copy.dart`

- [ ] **Step 1: Add the failing picker tests**

Append inside `main()` in `test/services/reminder_copy_test.dart` (after the `timeSlotForHour` group), and add `import 'dart:math';` at the top:

```dart
  group('ReminderCopy.pickMealBody', () {
    test('morning hour returns a line from the morning meal pool', () {
      final body = ReminderCopy.pickMealBody(7, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.morning]!, contains(body));
    });

    test('midday hour returns a line from the midday meal pool', () {
      final body = ReminderCopy.pickMealBody(13, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.midday]!, contains(body));
    });

    test('evening hour returns a line from the evening meal pool', () {
      final body = ReminderCopy.pickMealBody(20, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.evening]!, contains(body));
    });

    test('night hour (23) draws from the evening meal pool', () {
      final body = ReminderCopy.pickMealBody(23, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.evening]!, contains(body));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: FAIL — `The getter 'ReminderCopy' isn't defined`.

- [ ] **Step 3: Add `ReminderCopy` with meal pools and `pickMealBody`**

Append to `lib/services/reminder_copy.dart` (and add `import 'dart:math';` at the top):

```dart
class ReminderCopy {
  static const mealPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      "Frühstück schon drin? Trag's ein.",
      'Was hat dein Bauch zum Frühstück bekommen?',
      'Morgenmuffel-Frühstück: Kaffee zählt nicht als Mahlzeit.',
      'Erster Bissen des Tages — notiert?',
      "Frühstück oder Luft? Sag's.",
    ],
    TimeSlot.midday: [
      'Mittagspause — was lag auf dem Teller?',
      'Was hat dein Bauch zu Mittag bekommen?',
      'Snack oder richtige Mahlzeit? Beides eintragen.',
      "Mittag im Logbuch? Sonst vergisst du's.",
      'Zwischendurch gefuttert? Kurz notieren.',
      'Zeit zum Eintragen! Was hast du gegessen?',
      'Erinnerung: Halte dein Essens-Tagebuch aktuell.',
    ],
    TimeSlot.evening: [
      'Abendessen notieren — bevor der Tag vorbei ist.',
      "Was hat's heute Abend gegeben?",
      "Abendbrot, Pizza oder Resteverwertung? Trag's ein.",
      'Letzte Mahlzeit des Tages im Kasten?',
      'Was hat dein Bauch heute Abend abbekommen?',
      'Vergiss nicht, deine Mahlzeiten zu tracken!',
      'Was hast du heute gegessen? Trag es ein!',
    ],
  };

  static String pickMealBody(int hour, Random random) {
    final pool = mealPools[timeSlotForHour(hour)]!;
    return pool[random.nextInt(pool.length)];
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: PASS (5 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/services/reminder_copy.dart test/services/reminder_copy_test.dart
git commit -m "$(cat <<'EOF'
feat(reminders): add meal pools and pickMealBody

Three time-of-day pools (morning 5, midday 7, evening 7) selected by
the scheduled hour. Existing four-line pool expanded and retagged per
slot; no line appears in more than one bucket.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Mood pools + `pickMoodBody` with midday fallback

**Files:**
- Modify: `test/services/reminder_copy_test.dart`
- Modify: `lib/services/reminder_copy.dart`

- [ ] **Step 1: Add the failing tests**

Append another group inside `main()` in `test/services/reminder_copy_test.dart`:

```dart
  group('ReminderCopy.pickMoodBody', () {
    test('morning hour returns a line from the morning mood pool', () {
      final body = ReminderCopy.pickMoodBody(7, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.morning]!, contains(body));
    });

    test('evening hour returns a line from the evening mood pool', () {
      final body = ReminderCopy.pickMoodBody(20, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.evening]!, contains(body));
    });

    test('midday hour falls back to the evening mood pool', () {
      // There is no dedicated midday mood pool; a user who schedules a
      // mood reminder between 11–16 should still get an evening line
      // rather than crash on a null pool lookup.
      final body = ReminderCopy.pickMoodBody(13, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.evening]!, contains(body));
    });

    test('night hour (23) draws from the evening mood pool', () {
      final body = ReminderCopy.pickMoodBody(23, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.evening]!, contains(body));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: FAIL — `The getter 'moodPools' isn't defined for the class 'ReminderCopy'`.

- [ ] **Step 3: Add mood pools and `pickMoodBody`**

Append inside the `ReminderCopy` class in `lib/services/reminder_copy.dart` (after `pickMealBody`):

```dart
  static const moodPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      'Morgenmuffel oder Bauch-Muffel?',
      "Brummt's, zwickt's, oder ist alles chill?",
      'Wie hat dein Bauch geschlafen?',
      "Grummelt's schon? Sag's.",
      'Bauch-Report zur Morgenlage.',
    ],
    TimeSlot.evening: [
      "Tagesende: wie geht's dem Bauch?",
      'Abend-Check — was hat dein Bauch heute mitgemacht?',
      'Blähungs-Bilanz des Tages?',
      'Bauch-Fazit fürs Logbuch.',
      'Zwickt, brummt, oder tiptop? Eintragen!',
      'Wie war dein Bauchgefühl heute?',
    ],
  };

  static String pickMoodBody(int hour, Random random) {
    final slot = timeSlotForHour(hour);
    final pool = moodPools[slot] ?? moodPools[TimeSlot.evening]!;
    return pool[random.nextInt(pool.length)];
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: PASS (9 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/services/reminder_copy.dart test/services/reminder_copy_test.dart
git commit -m "$(cat <<'EOF'
feat(reminders): add mood pools and pickMoodBody with midday fallback

Morning (5) and evening (6) mood pools. Midday-scheduled mood reminders
fall back to the evening pool — no dedicated midday mood copy for now.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Pool-integrity sanity test

**Files:**
- Modify: `test/services/reminder_copy_test.dart`

- [ ] **Step 1: Add the integrity test**

Append another group inside `main()` in `test/services/reminder_copy_test.dart`:

```dart
  group('pool integrity', () {
    test('every meal pool is non-empty', () {
      for (final entry in ReminderCopy.mealPools.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'meal pool for ${entry.key} is empty',
        );
      }
    });

    test('every mood pool is non-empty', () {
      for (final entry in ReminderCopy.moodPools.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'mood pool for ${entry.key} is empty',
        );
      }
    });

    test('no meal line appears in more than one slot', () {
      final all = ReminderCopy.mealPools.values.expand((p) => p).toList();
      expect(all.toSet().length, all.length);
    });

    test('no mood line appears in more than one slot', () {
      final all = ReminderCopy.moodPools.values.expand((p) => p).toList();
      expect(all.toSet().length, all.length);
    });
  });
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: PASS (13 tests total). The data is already correct by design; these tests guard future edits.

- [ ] **Step 3: Commit**

```bash
git add test/services/reminder_copy_test.dart
git commit -m "$(cat <<'EOF'
test(reminders): enforce non-empty pools and no cross-bucket duplicates

Guard rails so future copy edits can't silently drop a pool to zero
lines or leak the same line into two slots.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Wire into `LocalNotificationService`

**Files:**
- Modify: `lib/services/local_notification_service.dart`

The existing scheduling loops already parse the scheduled hour — we reuse that variable and call the new pickers. No new state; `_random` stays where it is.

- [ ] **Step 1: Add the import**

Edit `lib/services/local_notification_service.dart`. Add this import below the existing `../utils/logger.dart` import at line 8:

```dart
import 'reminder_copy.dart';
```

- [ ] **Step 2: Delete the obsolete `_mealReminderMessages` constant**

Remove lines 34–39 of `lib/services/local_notification_service.dart`:

```dart
  static const _mealReminderMessages = [
    'Zeit zum Eintragen! Was hast du gegessen?',
    'Vergiss nicht, deine Mahlzeiten zu tracken!',
    'Was hast du heute gegessen? Trag es ein!',
    'Erinnerung: Halte dein Essens-Tagebuch aktuell.',
  ];
```

(The lines themselves have migrated into `ReminderCopy.mealPools` under `TimeSlot.midday` and `TimeSlot.evening` — this constant is now dead.)

- [ ] **Step 3: Replace the meal body pick**

In `scheduleMealReminders`, change lines 144–145 from:

```dart
      final body =
          _mealReminderMessages[_random.nextInt(_mealReminderMessages.length)];
```

to:

```dart
      final body = ReminderCopy.pickMealBody(hour, _random);
```

- [ ] **Step 4: Replace the inline mood body literal**

In `scheduleMoodReminders`, insert a `body` local after the `scheduledDate` calculation (around line 199) and use it in the `zonedSchedule` call.

Change this block (current lines ~199–209):

```dart
      final scheduledDate = _nextInstanceOfTime(hour, minute, location);
      _log.debug(
        'scheduling mood reminder $i: ${moodReminderTimes[i]} → $scheduledDate '
        '(now=${tz.TZDateTime.now(location)})',
      );
      try {
        await _plugin.zonedSchedule(
          id: _moodReminderIdBase + i,
          title: 'Belly Buddy',
          body: 'Wie war dein Bauchgefühl heute?',
          scheduledDate: scheduledDate,
```

to:

```dart
      final scheduledDate = _nextInstanceOfTime(hour, minute, location);
      final body = ReminderCopy.pickMoodBody(hour, _random);
      _log.debug(
        'scheduling mood reminder $i: ${moodReminderTimes[i]} → $scheduledDate '
        '(now=${tz.TZDateTime.now(location)})',
      );
      try {
        await _plugin.zonedSchedule(
          id: _moodReminderIdBase + i,
          title: 'Belly Buddy',
          body: body,
          scheduledDate: scheduledDate,
```

- [ ] **Step 5: Run analyzer and the full test suite**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test test/services/reminder_copy_test.dart`
Expected: PASS (13 tests).

Run: `flutter test`
Expected: PASS (no regressions in any existing suite — no existing tests touch `LocalNotificationService`).

- [ ] **Step 6: Format**

Run: `dart format lib/services/local_notification_service.dart lib/services/reminder_copy.dart test/services/reminder_copy_test.dart`
Expected: no files changed (or minor whitespace).

- [ ] **Step 7: Commit**

```bash
git add lib/services/local_notification_service.dart
git commit -m "$(cat <<'EOF'
refactor(reminders): delegate body selection to slot-aware ReminderCopy

Meal and mood reminder bodies now come from ReminderCopy.pickMealBody /
pickMoodBody, passing the scheduled hour so a 07:30 fire and a 21:30
fire draw from different pools. Removes the flat _mealReminderMessages
constant and the inline mood body literal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Push and open PR against `develop`

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/slot-aware-reminder-pools
```

- [ ] **Step 2: Open the PR against `develop`**

```bash
gh pr create --base develop --title "feat: slot-aware reminder pools" --body "$(cat <<'EOF'
## Summary
- Segment local meal and mood reminder copy into morning/midday/evening pools; each fire now uses copy matching its scheduled hour
- 30 variants total (meal 5/7/7, mood 5/–/6); existing 5 lines retagged into specific slots; night hours wrap into evening; midday-scheduled mood reminders fall back to evening
- New `lib/services/reminder_copy.dart` with `TimeSlot`, `timeSlotForHour`, `ReminderCopy.pickMealBody`, `ReminderCopy.pickMoodBody`; `LocalNotificationService` delegates body selection to it

Spec: `docs/superpowers/specs/2026-04-18-slot-aware-reminder-pools-design.md`

## Test plan
- [ ] `flutter test test/services/reminder_copy_test.dart` green (13 tests)
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (no regressions)
- [ ] Manual sanity: set a meal reminder at 07:00 and 20:00; confirm bodies differ across pools

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Do NOT arm auto-merge.

---

## Self-review (completed before handoff)

- **Spec coverage:** ✓ `TimeSlot` + helper (Task 1), meal pools + picker (Task 2), mood pools + picker + midday fallback (Task 3), integrity test (Task 4), `LocalNotificationService` wire-in (Task 5), PR (Task 6).
- **Placeholder scan:** ✓ No TBD/TODO, no "add appropriate error handling," every code step has full code.
- **Type consistency:** ✓ `pickMealBody(int hour, Random random)` and `pickMoodBody(int hour, Random random)` signatures are identical across plan and spec. `mealPools` / `moodPools` names are consistent. `TimeSlot` variants consistent.
- **Minor deviation from spec:** Pool maps are public `const` (not `_mealPools`/`_moodPools`) so tests can assert membership without `@visibleForTesting` plumbing — noted in the File structure section.
