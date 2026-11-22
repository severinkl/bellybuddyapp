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
    'Kopf hoch, {name} ist da. Gut, dass du es notierst.',
  ];

  static const gutGood = [
    'Juhu, guter Bauchtag!',
    'Dein Bauch fühlt sich wohl – ich freu mich mit!',
    'Yeah, das nenn ich Bauchglück!',
  ];

  static const gutNeutral = [
    'Okay, notiert. Geht ja schon mal!',
    'Danke fürs Eintragen – weiter so!',
    'Ein Tag wie jeder andere – ich bin trotzdem stolz auf dich.',
  ];

  static const gutBad = [
    'Oh nein … ich drück dich. Danke, dass du es eingetragen hast.',
    'Das tut mir leid. Du bist nicht allein, ich bin da.',
    'Schwerer Bauchtag? Ich bleib bei dir.',
  ];

  static const Map<BuddyMood, List<String>> mood = {
    BuddyMood.happy: [
      'Mir geht es richtig gut, danke, dass du dich kümmerst!',
      'Schön, dass du da bist, {name} freut sich!',
      'Heute läuft es rund – {streak} Tage in Folge!',
    ],
    BuddyMood.nervous: [
      'Ich bin ein bisschen aufgeregt …',
      'Kribbelt irgendwie im Bauch. Bei dir auch?',
      'Puh, tief durchatmen – wir schaffen das.',
    ],
    BuddyMood.sad: [
      'Ich bin ein bisschen traurig heute …',
      'Ein Eintrag würde mich aufmuntern.',
      'Magst du mir erzählen, wie es dir geht?',
    ],
    BuddyMood.inLove: [
      'Ich hab dich so lieb!',
      'Du bist die Beste – oder der Beste!',
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
      'Zzz … ach, du bist es, {name} ist wach!',
    ],
    BuddyMood.empathetic: [
      'Ich bin für dich da.',
      'Ich drück dich ganz fest.',
      'Du musst nicht alles allein tragen.',
    ],
  };

  static String pick(List<String> pool, Random rnd) =>
      pool[rnd.nextInt(pool.length)];

  static String fill(String s, {required String name, int streak = 0}) =>
      s.replaceAll('{name}', name).replaceAll('{streak}', '$streak');
}
