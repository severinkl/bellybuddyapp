import 'dart:math';

import '../../widgets/buddy/buddy_pose.dart';

/// German copy pools for the Buddy. Placeholders: `{name}`, `{streak}`.
class BuddyCopy {
  const BuddyCopy._();

  static const meal = [
    'Mmmh, lecker!',
    'Danke fürs Füttern!',
    'Nom nom nom!',
    'Das sieht gut aus – für uns beide!',
  ];

  static const drink = [
    'Ahh, erfrischend!',
    'Prost! 💧',
    'Glucks, glucks – danke!',
    'Frisch gezapft, frisch getrunken!',
  ];

  static const relief = [
    'Puh, Erleichterung!',
    'Das tat bestimmt gut.',
    'Geschafft – Bauch sagt Danke!',
  ];

  static const toiletBad = [
    'Oh nein … ich drück dich. Danke, dass du es eingetragen hast.',
    'Das klingt nicht so schön. Ich bin bei dir.',
    'Kopf hoch – ich bin da. Gut, dass du es notierst.',
  ];

  static const gutGood = [
    'Juhu, guter Bauchtag!',
    'Dein Bauch fühlt sich wohl – ich freu mich mit!',
    'Yeah, das nenn ich Bauchglück!',
  ];

  static const gutNeutral = [
    'Okay, notiert. Geht ja schon mal!',
    'Danke fürs Eintragen – weiter so!',
    'Ein ganz normaler Bauchtag – und du hast dran gedacht. Stark!',
  ];

  static const gutBad = [
    'Oh nein … ich drück dich. Danke, dass du es eingetragen hast.',
    'Das tut mir leid. Du bist nicht allein, ich bin da.',
    'Schwerer Bauchtag? Ich bleib bei dir.',
  ];

  static const Map<BuddyMood, List<String>> mood = {
    BuddyMood.happy: [
      'Mir geht es richtig gut, danke, dass du dich kümmerst!',
      'Schön, dass du da bist – ich freu mich!',
      'Heute läuft es rund – {streak} Tage in Folge!',
    ],
    BuddyMood.nervous: [
      'Ich bin ein bisschen aufgeregt …',
      'Kribbelt irgendwie im Bauch. Bei dir auch?',
      'Puh, tief durchatmen – wir schaffen das.',
    ],
    BuddyMood.sad: [
      'Ich bin ein bisschen traurig heute …',
      'Ich freu mich über jeden Eintrag, wann immer du magst.',
      'Magst du mir erzählen, wie es dir geht?',
    ],
    BuddyMood.inLove: [
      'Ich hab dich so lieb!',
      'Du bist mein Lieblingsmensch!',
      'Herzchen im Bauch, überall Herzchen!',
    ],
    BuddyMood.zen: [
      'Ganz entspannt … ommm.',
      'Ein ruhiger Bauch ist ein glücklicher Bauch.',
      'Atme ein, atme aus. Alles gut.',
    ],
    BuddyMood.energetic: [
      'Wir sind heute ein Top-Team!',
      'Wow, so viel Power heute – {streak} Tage am Stück!',
      'Ich könnte Bäume ausreißen!',
    ],
    BuddyMood.hungry: [
      'Ich hab Hunger … fütterst du mich?',
      'Mein Magen knurrt – was gibt es heute?',
      'Hast du schon etwas gegessen? Ich noch nicht!',
    ],
    BuddyMood.sleepy: [
      'Guten Morgen … *gähn*',
      'Ich bin noch müde … *gähn*',
      'Zzz … oh, du bist da! Ich bin schon wach!',
    ],
    BuddyMood.asleep: [
      '*schnarch* … zzZ',
      'Zzz … nur noch fünf Minuten …',
      'Zzz … ich träum gerade vom Frühstück …',
    ],
    BuddyMood.empathetic: [
      'Ich bin für dich da.',
      'Ich drück dich ganz fest.',
      'Du musst nicht alles allein tragen.',
    ],
  };

  /// Sleepy lines for late evening / night (hour < 5 or >= 10).
  static const sleepyNight = [
    'Schon spät … *gähn* Gute Nacht bald?',
    'Mir fallen die Augen zu … *gähn*',
    '{name} meldet sich zum Schlafengehen … *gähn*',
  ];

  static String pick(List<String> pool, Random rnd) =>
      pool[rnd.nextInt(pool.length)];

  static String fill(String s, {required String name, int streak = 0}) =>
      s.replaceAll('{name}', name).replaceAll('{streak}', '$streak');
}
