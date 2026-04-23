import 'dart:math';

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
}
