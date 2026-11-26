import 'dart:math';

import '../../providers/buddy_provider.dart' show BuddyAnnouncement;
import '../../widgets/buddy/buddy_pose.dart';
import '../journey/journey_copy.dart';
import 'daily_care.dart';

/// German copy pools for the Buddy. Placeholders: `{name}`, `{streak}`.
/// Every line the dashboard's Buddy says (his resting lines, the moods',
/// [announcementLine]s, JourneyCopy's lines for Home) fits three lines of
/// his bubble (about 60 characters with a 20-character name), so it is
/// never cut or drawn smaller.
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
  /// ([nextCareAction]); [CareAction.feed] when no meter is low.
  static const care = <CareAction, List<String>>{
    CareAction.breakfast: [
      "Guten Morgen! Was gab's zum Frühstück? 🍳",
      'Lust auf Frühstück? ☕',
    ],
    CareAction.lunch: [
      'Lust auf Mittagessen? 🍝',
      "Mahlzeit! Was gab's bei dir zu Mittag?",
    ],
    CareAction.snack: [
      'Ein kleiner Snack für zwischendurch? 🍎',
      'Ich hätte Lust auf einen Snack!',
    ],
    CareAction.dinner: [
      "Was gab's zum Abendessen? 🍲",
      'Zeit fürs Abendessen? 🍲',
    ],
    CareAction.drink: [
      'Hast du Durst? 💧',
      'Schluck für Schluck: Was hast du getrunken?',
    ],
    CareAction.gutFeeling: [
      "Wie geht's deinem Bauch heute? 🙂",
      'Erzähl mir, wie sich dein Bauch anfühlt.',
    ],
    CareAction.feed: [
      "Mir geht's richtig gut, danke dir! 💚",
      'Du hast toll für uns gesorgt!',
      'Rundum zufrieden – danke dir!',
    ],
  };

  /// Right after a log, when what he asks for next is more of the same
  /// (a drink logged for earlier leaves Trinken the lowest): he thanks for
  /// it first instead of the [care] line („Hast du Durst?" just after a
  /// drink).
  static const careAfterLog = <CareAction, List<String>>{
    CareAction.drink: ['Danke fürs Trinken! 💧', 'Ahh, das tat gut! 💧'],
  };

  /// What the dashboard's Buddy says for [announcement]: a streak-saver
  /// used or earned, a broken streak, new tips, a failed first tip (whether
  /// the weekly tips stay on, [weeklyTipsOn]); null for those that end in
  /// a sheet or page instead.
  static String? announcementLine(
    BuddyAnnouncement announcement, {
    required bool weeklyTipsOn,
  }) => switch (announcement) {
    BuddyAnnouncement.saverUsed => saverUsed,
    BuddyAnnouncement.streakBroken => streakBroken,
    BuddyAnnouncement.saverEarned => saverEarned,
    BuddyAnnouncement.tipsArrived => tipsArrived,
    BuddyAnnouncement.firstTipFailed => JourneyCopy.firstTipFailed(
      weeklyTipsOn: weeklyTipsOn,
    ),
    BuddyAnnouncement.goalReached ||
    BuddyAnnouncement.weeklyTipsOffer ||
    BuddyAnnouncement.firstTipOffer ||
    BuddyAnnouncement.journeyReward ||
    BuddyAnnouncement.patternsUnlocked => null,
  };

  static const saverUsed = 'Puh! Dein Streak-Saver hat uns gestern gerettet 🛡';
  static const streakBroken = 'Neuer Anlauf — ich bin dabei!';
  static const saverEarned = 'Du hast einen Streak-Saver verdient! 🛡';
  static const tipsArrived = 'Neue Tipps sind da! ✨';

  /// His ask for reminders while they are off (its sheet's line; the
  /// explanation below it, [remindersAskBody]).
  static const remindersAsk =
      'Darf ich dich ab und zu ans Eintragen erinnern? 🔔';
  static const remindersAskBody =
      'Deine Erinnerungen sind gerade aus. Schaltest du sie ein, sag ich dir '
      'Bescheid, wenn Essen und Bauchgefühl dran sind. Ändern kannst du das '
      'jederzeit in den Einstellungen.';

  /// His thanks once they are on.
  static const remindersOn = 'Danke! Ich sag dir Bescheid 🔔';

  /// Home's thanks for today's first counted entry, with the [streak].
  static String streakThanks(int streak) =>
      'Danke! 🔥 $streak ${streak == 1 ? 'Tag' : 'Tage'}';

  /// The dashboard's next-action button's label (its need's sticker icon
  /// leads it): the meal the time of day asks for, logging a need
  /// („Trinken eintragen") or „Essen eintragen".
  static String careButton(CareAction action) => switch (action) {
    CareAction.breakfast => 'Frühstück eintragen',
    CareAction.lunch => 'Mittagessen eintragen',
    CareAction.snack => 'Snack eintragen',
    CareAction.dinner => 'Abendessen eintragen',
    CareAction.drink => CareNeed.drink.logLabel,
    CareAction.gutFeeling => CareNeed.gutFeeling.logLabel,
    CareAction.feed => CareNeed.food.logLabel,
  };

  /// Sleepy lines outside the morning: late evening and night.
  static const sleepyNight = [
    'Schon spät … *gähn* Gute Nacht bald?',
    'Mir fallen die Augen zu … *gähn*',
    '{name} geht jetzt schlafen … *gähn*',
  ];

  static String pick(List<String> pool, Random rnd) =>
      pool[rnd.nextInt(pool.length)];

  static String fill(String s, {required String name, int streak = 0}) =>
      s.replaceAll('{name}', name).replaceAll('{streak}', '$streak');
}
