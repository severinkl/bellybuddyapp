import 'dart:math';

import '../../widgets/buddy/buddy_pose.dart';
import 'daily_care.dart';

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

  /// The dashboard's resting line for what he needs next
  /// ([nextCareAction]); [CareAction.feed] when nothing is open.
  static const care = <CareAction, List<String>>{
    CareAction.breakfast: [
      "Guten Morgen! Was gab's zum Frühstück? 🍳",
      'Frühstück fehlt mir noch – mein Bauch knurrt!',
    ],
    CareAction.lunch: [
      'Mittag fehlt mir noch! 🍝',
      "Mahlzeit! Was gab's bei dir zu Mittag?",
    ],
    CareAction.snack: [
      'Ein kleiner Snack für zwischendurch? 🍎',
      'Ich hätte Lust auf einen Snack!',
    ],
    CareAction.dinner: [
      "Was gab's zum Abendessen? 🍲",
      'Abendessen fehlt mir noch!',
    ],
    CareAction.drink: [
      'Ich hab Durst – ein Glas Wasser? 💧',
      'Schluck für Schluck: Was hast du getrunken?',
    ],
    CareAction.gutFeeling: [
      "Wie geht's deinem Bauch heute? 🙂",
      'Erzähl mir, wie sich dein Bauch anfühlt.',
    ],
    CareAction.feed: [
      'Alles erledigt – ich bin rundum zufrieden! 💚',
      'Heute hast du toll für uns gesorgt!',
      'Ring voll, Bauch glücklich – danke dir!',
    ],
  };

  /// Right after a log, when what he asks for next is more of the same
  /// (one glass of six): he thanks for it first instead of the [care] line
  /// („Ich hab Durst" just after a drink).
  static const careAfterLog = <CareAction, List<String>>{
    CareAction.drink: [
      'Danke fürs Trinken! Ein Glas mehr schadet nie. 💧',
      'Ahh, das tat gut! Später gern noch eins. 💧',
    ],
  };

  /// The dashboard's next-action button: the meal the time of day asks
  /// for, logging a need („💧 Trinken eintragen") or „🍽 Essen eintragen".
  static String careButton(CareAction action) => switch (action) {
    CareAction.breakfast => '🍳 Frühstück eintragen',
    CareAction.lunch => '🍝 Mittagessen eintragen',
    CareAction.snack => '🍎 Snack eintragen',
    CareAction.dinner => '🍲 Abendessen eintragen',
    CareAction.drink => _log(CareNeed.drink),
    CareAction.gutFeeling => _log(CareNeed.gutFeeling),
    CareAction.feed => '🍽 ${CareNeed.food.logLabel}',
  };

  static String _log(CareNeed need) => '${need.emoji} ${need.logLabel}';

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
