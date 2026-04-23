# Slot-aware reminder pools — design

**Date:** 2026-04-18
**Status:** Approved, ready for implementation plan
**Scope:** Local (non-Firebase) meal and mood reminders

## Problem

`LocalNotificationService` picks a reminder body uniformly at random from a single flat pool:

- Meal reminders: 4-line `_mealReminderMessages`, picked via `_random.nextInt(length)` regardless of the reminder's scheduled hour.
- Mood reminders: a single inline literal `'Wie war dein Bauchgefühl heute?'` — no pool at all.

This means a 7:30 reminder and a 21:30 reminder say the same things. Morning-specific humour ("Morgenmuffel") can't appear without risking a jarring evening fire; evening wrap-up lines can't appear without looking weird at breakfast.

We want reminder copy that matches the time of day, so each fire feels deliberate.

## Goal

Segment the meal and mood reminder pools by time-of-day bucket, and pick from the bucket matching the scheduled hour.

## Approach — chosen: B (`Map<TimeSlot, List<String>>`)

A separate file `lib/services/reminder_copy.dart` owns the pools and the hour→slot mapping. `LocalNotificationService` drops its private `_mealReminderMessages` constant and the inline mood literal, and calls the new pickers instead.

We considered an alternative (approach A: a flat `List<({TimeSlot slot, String text})>` tagged with slot, with a `TimeSlot.any` fallback). Approach A's only advantage was letting some lines appear in multiple slots via `TimeSlot.any`. Since we decided every line should be unique to its slot, that advantage evaporates — B is simpler to read, index, and test.

### Hour → slot mapping

```
morning  [05–10]
midday   [11–16]
evening  [17–22]
night    [23–04]  → falls through into evening
```

Night-hour fallback is intentional: we don't want a third/fourth pool for the edge case of a user who schedules a reminder at 02:00, and evening copy reads fine at 23:30.

### Files

**New: `lib/services/reminder_copy.dart`**

```dart
import 'dart:math';

enum TimeSlot { morning, midday, evening }

TimeSlot timeSlotForHour(int hour) {
  if (hour >= 5 && hour <= 10) return TimeSlot.morning;
  if (hour >= 11 && hour <= 16) return TimeSlot.midday;
  return TimeSlot.evening; // 17–22 and the 23–04 night wrap
}

class ReminderCopy {
  static const _mealPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [ /* 5 lines */ ],
    TimeSlot.midday:  [ /* 7 lines */ ],
    TimeSlot.evening: [ /* 7 lines */ ],
  };

  static const _moodPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [ /* 5 lines */ ],
    TimeSlot.evening: [ /* 6 lines */ ],
  };

  static String pickMealBody(int hour, Random random) {
    final pool = _mealPools[timeSlotForHour(hour)]!;
    return pool[random.nextInt(pool.length)];
  }

  static String pickMoodBody(int hour, Random random) {
    final slot = timeSlotForHour(hour);
    final pool = _moodPools[slot] ?? _moodPools[TimeSlot.evening]!;
    return pool[random.nextInt(pool.length)];
  }
}
```

The `?? _moodPools[TimeSlot.evening]!` on `pickMoodBody` handles the midday case: we deliberately don't ship a midday mood pool (no strong editorial reason to), so a user who schedules a mood reminder between 11–16 gets an evening line. This is a conscious trade-off — adding a midday pool is cheap later if needed.

**Modified: `lib/services/local_notification_service.dart`**

- Delete `_mealReminderMessages` (lines 34–39).
- In `scheduleMealReminders`, replace the body-pick (line 144–145) with `ReminderCopy.pickMealBody(hour, _random)`.
- In `scheduleMoodReminders`, replace the inline body literal `'Wie war dein Bauchgefühl heute?'` (line 208) with `ReminderCopy.pickMoodBody(hour, _random)`.
- `_random` stays in `LocalNotificationService`; we pass it in rather than have `ReminderCopy` own a second `Random` instance, so tests can seed determinism from one place and there's no hidden state in the copy module.

## Messages (30 total)

All 5 existing lines are retagged into specific slots rather than dropped — they still read well, just now bucketed.

Each body is prefixed with a single leading emoji chosen to match the message. Titles (`'Belly Buddy'`) are untouched.

### Meal — morning [05–10] (5 new)

- "🥐 Frühstück schon drin? Trag's ein."
- "🍳 Was hat dein Bauch zum Frühstück bekommen?"
- "☕ Morgenmuffel-Frühstück: Kaffee zählt nicht als Mahlzeit."
- "🥄 Erster Bissen des Tages — notiert?"
- "💨 Frühstück oder Luft? Sag's."

### Meal — midday [11–16] (5 new + 2 retagged)

- "🍽️ Mittagspause — was lag auf dem Teller?"
- "🥗 Was hat dein Bauch zu Mittag bekommen?"
- "🍪 Snack oder richtige Mahlzeit? Beides eintragen."
- "📓 Mittag im Logbuch? Sonst vergisst du's."
- "🍴 Zwischendurch gefuttert? Kurz notieren."
- "✍️ Zeit zum Eintragen! Was hast du gegessen?" *(retagged)*
- "📖 Erinnerung: Halte dein Essens-Tagebuch aktuell." *(retagged)*

### Meal — evening [17–22] (5 new + 2 retagged)

- "🌙 Abendessen notieren — bevor der Tag vorbei ist."
- "🍲 Was hat's heute Abend gegeben?"
- "🍕 Abendbrot, Pizza oder Resteverwertung? Trag's ein."
- "🌆 Letzte Mahlzeit des Tages im Kasten?"
- "🍽️ Was hat dein Bauch heute Abend abbekommen?"
- "📝 Vergiss nicht, deine Mahlzeiten zu tracken!" *(retagged)*
- "🥘 Was hast du heute gegessen? Trag es ein!" *(retagged)*

### Mood — morning [05–10] (5 new)

- "😴 Morgenmuffel oder Bauch-Muffel?"
- "🤔 Brummt's, zwickt's, oder ist alles chill?"
- "🛏️ Wie hat dein Bauch geschlafen?"
- "🌅 Grummelt's schon? Sag's."
- "📋 Bauch-Report zur Morgenlage."

### Mood — evening [17–22] (5 new + 1 retagged)

- "🌙 Tagesende: wie geht's dem Bauch?"
- "🌆 Abend-Check — was hat dein Bauch heute mitgemacht?"
- "💨 Blähungs-Bilanz des Tages?"
- "📖 Bauch-Fazit fürs Logbuch."
- "✅ Zwickt, brummt, oder tiptop? Eintragen!"
- "🤷 Wie war dein Bauchgefühl heute?" *(retagged)*

**Pool sizes:** meal 5/7/7, mood 5/–/6. Total: 30 variants.

## Testing

**New: `test/services/reminder_copy_test.dart`** (~60 LOC)

- Table test for `timeSlotForHour` covering boundary hours: 0, 4, 5, 10, 11, 16, 17, 22, 23 → asserts expected bucket (including night→evening wrap).
- Per-slot test for `pickMealBody` with `Random(42)`: asserts the returned body is a member of the corresponding pool for hours in each bucket (morning, midday, evening).
- Per-slot test for `pickMoodBody` for morning and evening hours.
- Midday-mood fallback test: `pickMoodBody(13, Random(42))` returns a string from the evening pool.
- Pool-integrity sanity: each pool `isNotEmpty`, and every line is unique across all meal pools combined and across all mood pools combined (enforces the "no cross-bucket flow" rule).

No changes to `local_notification_service.dart` tests — the scheduling logic is unchanged.

## Risk

Zero schema, zero data, zero rollout risk. Pure copy + refactor. The notification IDs, channels, scheduling mode, payloads, and permission flow are untouched. If anything regresses it will be: a user sees a reminder body they didn't see before, in the bucket matching the time they set.

## Out of scope

- Midday mood pool (falls through to evening for now).
- Weekday/weekend variants.
- User-editable pools.
- Server-driven copy / Firebase push body changes — FCM path is untouched.

## Acceptance

- `lib/services/reminder_copy.dart` exists with `TimeSlot`, `timeSlotForHour`, and `ReminderCopy` as specified.
- `LocalNotificationService._mealReminderMessages` is gone.
- `scheduleMealReminders` and `scheduleMoodReminders` call `ReminderCopy.pickMealBody` / `pickMoodBody` with the scheduled `hour` and `_random`.
- `reminder_copy_test.dart` passes.
- `flutter analyze` clean; `dart format` applied.
