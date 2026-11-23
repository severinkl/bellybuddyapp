import 'dart:math';

import 'buddy/buddy_copy.dart';

enum TimeSlot { morning, midday, evening }

/// Maps a 24-hour clock hour to a [TimeSlot]. Hours 23 and 0–4 wrap into
/// [TimeSlot.evening] — we don't ship a separate "night" pool because the
/// volume doesn't justify it, and evening copy reads fine at 23:30.
TimeSlot timeSlotForHour(int hour) {
  if (hour >= 5 && hour <= 10) return TimeSlot.morning;
  if (hour >= 11 && hour <= 16) return TimeSlot.midday;
  return TimeSlot.evening;
}

class ReminderCopy {
  static const mealPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      "🥐 Frühstück schon drin? Trag's ein.",
      '🍳 Was hat dein Bauch zum Frühstück bekommen?',
      '☕ Morgenmuffel-Frühstück: Kaffee zählt nicht als Mahlzeit.',
      '🥄 Erster Bissen des Tages — notiert?',
      "💨 Frühstück oder Luft? Sag's.",
    ],
    TimeSlot.midday: [
      '🍽️ Mittagspause — was lag auf dem Teller?',
      '🥗 Was hat dein Bauch zu Mittag bekommen?',
      '🍪 Snack oder richtige Mahlzeit? Beides eintragen.',
      "📓 Mittag im Tagebuch? Sonst vergisst du's.",
      '🍴 Zwischendurch gefuttert? Kurz notieren.',
      '✍️ Zeit zum Eintragen! Was hast du gegessen?',
      '📖 Erinnerung: Halte dein Tagebuch aktuell.',
    ],
    TimeSlot.evening: [
      '🌙 Abendessen notieren — bevor der Tag vorbei ist.',
      "🍲 Was hat's heute Abend gegeben?",
      "🍕 Abendbrot, Pizza oder Resteverwertung? Trag's ein.",
      '🌆 Letzte Mahlzeit des Tages im Kasten?',
      '🍽️ Was hat dein Bauch heute Abend abbekommen?',
      '📝 Vergiss nicht, dein Essen einzutragen!',
      '🥘 Was hast du heute gegessen? Trag es ein!',
    ],
  };

  /// Buddy-voiced meal lines; `{name}` is replaced by the Buddy's name.
  static const buddyMealPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      '🥄 {name} wartet aufs Frühstück!',
      '🥐 {name} hat Frühstückshunger. Was gab es bei dir?',
      '☕ {name} fragt: Was hast du heute früh gegessen?',
      '🍳 {name} knurrt der Magen. Trag dein Frühstück ein!',
    ],
    TimeSlot.midday: [
      "🍽️ {name} hat Hunger! Was gab's zu Mittag?",
      '🥗 {name} würde gern wissen, was auf deinem Teller lag.',
      '🍴 {name} wartet auf deinen Mittags-Eintrag.',
      '📓 {name} schaut ins Tagebuch: Was hast du gegessen?',
    ],
    TimeSlot.evening: [
      '🌙 {name} möchte wissen, was es heute Abend gab.',
      '🍲 {name} ist gespannt auf dein Abendessen!',
      '🌆 {name} fragt: Schon die letzte Mahlzeit eingetragen?',
      '📝 {name} wartet auf deinen Eintrag zum Abendbrot.',
    ],
  };

  /// Buddy-voiced mood lines (morning/evening only; midday uses evening).
  static const buddyMoodPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      '🛏️ {name} fragt: Wie hat dein Bauch geschlafen?',
      '🌅 {name} wünscht guten Morgen. Wie fühlt sich dein Bauch an?',
      '😴 {name} ist neugierig auf deinen Bauch heute früh.',
      '🤔 {name} will wissen: Brummt\'s, zwickt\'s oder ist alles chill?',
    ],
    TimeSlot.evening: [
      '🌙 {name} will wissen, wie dein Bauch sich heute anfühlt.',
      '🌆 {name} fragt: Was hat dein Bauch heute mitgemacht?',
      '📖 {name} wartet auf dein Bauch-Fazit fürs Tagebuch.',
      '🤷 {name} fragt: Wie war dein Bauchgefühl heute?',
    ],
  };

  static String _withName(String line, String name) =>
      BuddyCopy.fill(line, name: name);

  static String pickMealBody(int hour, Random random, {String? buddyName}) {
    if (buddyName != null) {
      final pool = buddyMealPools[timeSlotForHour(hour)]!;
      return _withName(pool[random.nextInt(pool.length)], buddyName);
    }
    final pool = mealPools[timeSlotForHour(hour)]!;
    return pool[random.nextInt(pool.length)];
  }

  static const moodPools = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      '😴 Morgenmuffel oder Bauch-Muffel?',
      "🤔 Brummt's, zwickt's, oder ist alles chill?",
      '🛏️ Wie hat dein Bauch geschlafen?',
      "🌅 Grummelt's schon? Sag's.",
      '📋 Bauch-Report zur Morgenlage.',
    ],
    TimeSlot.evening: [
      "🌙 Tagesende: wie geht's dem Bauch?",
      '🌆 Abend-Check — was hat dein Bauch heute mitgemacht?',
      '💨 Blähungs-Bilanz des Tages?',
      '📖 Bauch-Fazit fürs Tagebuch.',
      '✅ Zwickt, brummt, oder tiptop? Eintragen!',
      '🤷 Wie war dein Bauchgefühl heute?',
    ],
  };

  /// A fixed sample of the Buddy's meal reminder at [hour], for previews.
  static String previewMealBody(int hour, String buddyName) {
    final pool = buddyMealPools[timeSlotForHour(hour)]!;
    return _withName(pool[1 % pool.length], buddyName);
  }

  /// A fixed sample of the Buddy's gut-feeling reminder at [hour], for
  /// previews.
  static String previewMoodBody(int hour, String buddyName) {
    final pool =
        buddyMoodPools[timeSlotForHour(hour)] ??
        buddyMoodPools[TimeSlot.evening]!;
    return _withName(pool.last, buddyName);
  }

  static String pickMoodBody(int hour, Random random, {String? buddyName}) {
    final slot = timeSlotForHour(hour);
    if (buddyName != null) {
      final pool = buddyMoodPools[slot] ?? buddyMoodPools[TimeSlot.evening]!;
      return _withName(pool[random.nextInt(pool.length)], buddyName);
    }
    final pool = moodPools[slot] ?? moodPools[TimeSlot.evening]!;
    return pool[random.nextInt(pool.length)];
  }
}
