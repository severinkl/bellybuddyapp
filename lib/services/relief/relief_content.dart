/// Drafts awaiting Susi's review; the review commit flips `reviewed`.
library;

enum BreathPhase { inhale, holdIn, exhale, holdOut }

/// Seconds per phase; phases with 0 s are skipped.
class BreathPattern {
  const BreathPattern({
    required this.inhale,
    this.holdIn = 0,
    required this.exhale,
    this.holdOut = 0,
  });

  final int inhale, holdIn, exhale, holdOut;

  int get cycleSeconds => inhale + holdIn + exhale + holdOut;

  BreathPhase phaseAt(int secondInStep) {
    var s = secondInStep % cycleSeconds;
    for (final (phase, length) in _phases) {
      if (s < length) return phase;
      s -= length;
    }
    return BreathPhase.inhale;
  }

  /// Whole seconds left in the phase running at [secondInStep]; at least 1.
  int secondsLeftInPhase(int secondInStep) {
    var s = secondInStep % cycleSeconds;
    for (final (_, length) in _phases) {
      if (s < length) return length - s;
      s -= length;
    }
    return 1;
  }

  List<(BreathPhase, int)> get _phases => [
    (BreathPhase.inhale, inhale),
    (BreathPhase.holdIn, holdIn),
    (BreathPhase.exhale, exhale),
    (BreathPhase.holdOut, holdOut),
  ];
}

class ReliefStep {
  const ReliefStep({
    required this.text,
    required this.seconds,
    this.breath,
    this.quiet = false,
  });

  final String text;
  final int seconds;
  final BreathPattern? breath;
  final bool quiet;
}

class ReliefExercise {
  const ReliefExercise({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.caution,
    this.reviewed = false,
  });

  final String id, title, subtitle;
  final String? caution;
  final List<ReliefStep> steps;
  final bool reviewed;

  int get totalSeconds => steps.fold(0, (sum, s) => sum + s.seconds);

  int get minutes => (totalSeconds / 60).round();
}

ReliefExercise? reliefExerciseById(String id) {
  for (final e in reliefExercises) {
    if (e.id == id) return e;
  }
  return null;
}

String breathPhaseLabel(BreathPhase p) => switch (p) {
  BreathPhase.inhale => 'Einatmen',
  BreathPhase.holdIn || BreathPhase.holdOut => 'Halten',
  BreathPhase.exhale => 'Ausatmen',
};

/// A number the safety sheet lets the user dial.
class ReliefDial {
  const ReliefDial({
    required this.number,
    required this.tel,
    required this.caption,
  });

  /// As shown, e.g. '116 117'.
  final String number;

  /// For the `tel:` URI, e.g. '116117'.
  final String tel;

  /// What follows the number, e.g. 'Rettung (Österreich, Schweiz)'.
  final String caption;
}

class ReliefCopy {
  static const title = 'Ruhe für den Bauch';
  static const cardSubtitle = 'Atmen, entspannen, Wärme – für den Moment';
  static const listIntro = 'Ich bin da. Such dir aus, was dir gerade guttut.';
  static const gutFeelingOffer =
      'Brauchst du gerade etwas Ruhe für deinen Bauch?';
  static const helpedLabel = 'Hat dir geholfen';
  static const draftMarker = 'Entwurf: noch nicht fachlich geprüft';

  static const start = 'Starten';
  static const pause = 'Pause';
  static const resume = 'Fortsetzen';
  static const back = 'Zurück';
  static const next = 'Weiter';
  static const close = 'Schließen';
  static String stepOf(int n, int total) => 'Schritt $n von $total';
  static String minutesLabel(int m) => '$m Min.';

  /// Semantics label of the pacer's phase container.
  static String phaseSemantics(String label, int secondsLeft) =>
      secondsLeft == 1
      ? '$label, noch 1 Sekunde'
      : '$label, noch $secondsLeft Sekunden';

  static const doneLine = 'Schön, dass du dir die Zeit genommen hast.';
  static const helpedQuestion = "Hat's geholfen?";
  static const answerYes = 'Ja';
  static const answerLittle = 'Ein bisschen';
  static const answerNo = 'Nein';
  static const done = 'Fertig';
  static const thanks = 'Danke! Ich merk mir das.';
  static const thanksNo =
      'Danke, dass du es mir sagst. Probier gern eine andere Übung – '
      'und hol dir Hilfe, wenn es nicht besser wird.';

  static const safetyLine =
      'Das ersetzt keine ärztliche Hilfe. '
      'Bei starken Beschwerden: Notruf 144 (AT, CH) oder 112.';
  static const safetySheetTitle = 'Wann du Hilfe holen solltest';

  /// The done view's link to the sheet.
  static const safetyLinkLabel = safetySheetTitle;

  static const safetyIntro =
      'Die Übungen hier können dir helfen, ruhiger zu werden. '
      'Sie ersetzen keine ärztliche Hilfe und sagen nichts darüber, '
      'woher deine Beschwerden kommen.';

  static const emergencyHeading = 'Ruf sofort den Notruf, wenn du';
  static const emergencyItems = [
    'sehr starke oder plötzliche Bauchschmerzen hast,',
    'Schmerzen in der Brust oder Atemnot hast,',
    'Blut erbrichst oder viel Blut im Stuhl ist.',
  ];

  static const soonHeading = 'Geh bald zur Ärztin oder zum Arzt, wenn';
  static const soonItems = [
    'die Schmerzen neu, ungewohnt oder nicht besser werden,',
    'du Blut im Stuhl bemerkst,',
    'du Fieber hast,',
    'du dich immer wieder übergeben musst,',
    'du ungewollt abnimmst.',
  ];

  static const emergencyRowLabel = 'Notruf:';
  static const emergencyDials = [
    ReliefDial(
      number: '144',
      tel: '144',
      caption: 'Rettung (Österreich, Schweiz)',
    ),
    ReliefDial(
      number: '112',
      tel: '112',
      caption: '(Deutschland und ganz Europa)',
    ),
  ];

  static const adviceRowLabel = 'Ärztlicher Rat, wenn es kein Notfall ist:';
  static const adviceDials = [
    ReliefDial(number: '1450', tel: '1450', caption: '(Österreich)'),
    ReliefDial(number: '116 117', tel: '116117', caption: '(Deutschland)'),
  ];
  static const adviceSwitzerland =
      'in der Schweiz deine Hausarztpraxis oder der ärztliche Notfalldienst '
      'deines Kantons';

  static String dialFailed(String number) => 'Wähl bitte direkt $number.';

  /// Every plain string above, for the guard tests.
  static const allStrings = <String>[
    title,
    cardSubtitle,
    listIntro,
    gutFeelingOffer,
    helpedLabel,
    draftMarker,
    start,
    pause,
    resume,
    back,
    next,
    close,
    doneLine,
    helpedQuestion,
    answerYes,
    answerLittle,
    answerNo,
    done,
    thanks,
    thanksNo,
    safetyLine,
    safetySheetTitle,
    safetyIntro,
    emergencyHeading,
    ...emergencyItems,
    soonHeading,
    ...soonItems,
    emergencyRowLabel,
    adviceRowLabel,
    adviceSwitzerland,
  ];
}

const List<ReliefExercise> reliefExercises = [
  ReliefExercise(
    id: 'bauchatmung',
    title: 'Bauchatmung',
    subtitle: 'Ruhig in den Bauch atmen',
    caution: 'Wenn dir schwindlig wird, atme einfach wieder ganz normal.',
    steps: [
      ReliefStep(
        seconds: 20,
        text:
            'Mach es dir bequem. Du kannst sitzen oder liegen. '
            'Leg eine Hand auf deinen Bauch.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Atme ganz normal weiter. Spür, wie sich deine Hand mit dem Atem '
            'hebt und senkt. Du musst nichts ändern.',
      ),
      ReliefStep(
        seconds: 120,
        breath: BreathPattern(inhale: 4, exhale: 6),
        text:
            'Atme langsam durch die Nase ein, bis sich dein Bauch hebt. '
            'Atme durch den Mund etwas länger wieder aus. '
            'Vielen tut dieser lange Ausatem gut.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Lass den Atem wieder von allein fließen. '
            'Bleib noch einen Moment so, wie du bist.',
      ),
    ],
  ),
  ReliefExercise(
    id: 'box_atmung',
    title: 'Box-Atmung',
    subtitle: 'Vier Seiten, je vier Sekunden',
    caution:
        'Hör auf, wenn dir schwindlig wird. Halte die Luft nie mit Druck an.',
    steps: [
      ReliefStep(
        seconds: 20,
        text:
            'Setz dich bequem und aufrecht hin. '
            'Deine Schultern dürfen locker sein.',
      ),
      ReliefStep(
        seconds: 15,
        text:
            'Stell dir ein Quadrat vor. Jede Seite dauert vier Sekunden: '
            'einatmen, halten, ausatmen, halten.',
      ),
      ReliefStep(
        seconds: 128,
        breath: BreathPattern(inhale: 4, holdIn: 4, exhale: 4, holdOut: 4),
        text:
            'Folg einfach dem Kreis. Ein durch die Nase, aus durch den Mund. '
            'Ist das Halten unangenehm, lass es weg und atme nur ruhig.',
      ),
      ReliefStep(
        seconds: 17,
        text:
            'Lass das Quadrat los und atme in deinem eigenen Tempo. '
            'Gut gemacht.',
      ),
    ],
  ),
  ReliefExercise(
    id: 'muskelentspannung',
    title: 'Muskeln entspannen',
    subtitle: 'Kurze Progressive Muskelentspannung',
    caution:
        'Spann nur so fest an, dass es angenehm bleibt – nie so, dass es weh '
        'tut. Deinen Bauch lässt du heute locker.',
    steps: [
      ReliefStep(
        seconds: 20,
        text:
            'Setz oder leg dich bequem hin. Wir spannen nacheinander ein paar '
            'Muskeln kurz an und lassen sie wieder los. '
            'Dein Bauch darf dabei ganz in Ruhe bleiben.',
      ),
      ReliefStep(
        seconds: 7,
        text: 'Mach mit beiden Händen eine feste Faust. Halte die Spannung.',
      ),
      ReliefStep(
        seconds: 25,
        text: 'Und loslassen. Spür, wie deine Hände weich und warm werden.',
      ),
      ReliefStep(
        seconds: 7,
        text: 'Winkle die Arme an und spann die Oberarme an. Halten.',
      ),
      ReliefStep(
        seconds: 25,
        text: 'Lass los. Deine Arme dürfen schwer werden.',
      ),
      ReliefStep(
        seconds: 7,
        text: 'Zieh die Schultern hoch zu den Ohren. Halten.',
      ),
      ReliefStep(
        seconds: 25,
        text: 'Lass sie sinken. Spür, wie viel Platz dein Nacken jetzt hat.',
      ),
      ReliefStep(
        seconds: 7,
        text: 'Kneif die Augen zusammen und runzle die Stirn. Halten.',
      ),
      ReliefStep(
        seconds: 25,
        text:
            'Lass dein Gesicht ganz weich werden. Auch der Kiefer darf locker sein.',
      ),
      ReliefStep(
        seconds: 7,
        text: 'Zieh die Zehen zu dir hin und spann die Beine an. Halten.',
      ),
      ReliefStep(
        seconds: 25,
        text: 'Lass los. Deine Beine liegen schwer und ruhig.',
      ),
      ReliefStep(
        seconds: 40,
        text:
            'Atme ein paar Mal ruhig durch. Spür deinen ganzen Körper: Hände, '
            'Arme, Schultern, Gesicht, Beine. Alles darf schwer und warm sein.',
      ),
    ],
  ),
  ReliefExercise(
    id: 'bauchmassage',
    title: 'Sanfte Bauchmassage',
    subtitle: 'Im Uhrzeigersinn, ganz ohne Druck',
    caution:
        'Bitte nicht bei starken oder neuen Schmerzen, nach einer Operation am '
        'Bauch und in der Schwangerschaft nur nach ärztlichem Rat. '
        'Wenn es weh tut, hör auf.',
    steps: [
      ReliefStep(
        seconds: 20,
        text:
            'Leg dich auf den Rücken und stell die Beine an. '
            'Ein Kissen unter den Knien kann angenehm sein.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Reib deine Hände aneinander, bis sie warm sind. '
            'Leg sie dann flach auf deinen Bauch.',
      ),
      ReliefStep(
        seconds: 30,
        text:
            'Atme ein paar Mal ruhig in deine Hände. Du musst noch nichts tun.',
      ),
      ReliefStep(
        seconds: 90,
        text:
            'Beginn unten rechts an deinem Bauch, nah am Hüftknochen. Streich '
            'mit der flachen Hand langsam hinauf bis unter die Rippen, quer '
            'hinüber zur linken Seite und links wieder hinunter. '
            'Ganz sanft, wieder und wieder.',
      ),
      ReliefStep(
        seconds: 60,
        text:
            'Mach die Kreise so groß oder klein, wie es sich gut anfühlt. '
            'Ist eine Stelle empfindlich, lass sie aus.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Lass deine Hände zum Schluss ruhig auf dem Bauch liegen und spür nach.',
      ),
    ],
  ),
  ReliefExercise(
    id: 'waerme',
    title: 'Wärme',
    subtitle: 'Wärmflasche oder Kirschkernkissen',
    caution:
        'Nur warm, nie heiß: kein kochendes Wasser, immer ein Tuch zwischen '
        'Haut und Wärme. Schlaf nicht mit der Wärmflasche ein. Nicht bei '
        'Fieber und nicht an Stellen, an denen du wenig spürst.',
    steps: [
      ReliefStep(
        seconds: 30,
        text:
            'Füll deine Wärmflasche mit warmem, nicht kochendem Wasser, etwa '
            'zu zwei Dritteln. Drück die Luft heraus und schraub sie gut zu.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Wickle sie in ein Handtuch oder steck sie in ihren Bezug. '
            'Ein warmes Kirschkernkissen geht genauso.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Leg dich bequem hin und leg die Wärme auf deinen Bauch. '
            'Prüf kurz: Fühlt es sich angenehm warm an?',
      ),
      ReliefStep(
        seconds: 600,
        quiet: true,
        text:
            'Jetzt darfst du einfach liegen. '
            'Du kannst das Handy weglegen – ich passe auf die Zeit auf.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Nimm die Wärme wieder weg und schau kurz auf deine Haut. '
            'Ist sie stark gerötet, nimm beim nächsten Mal ein dickeres Tuch.',
      ),
    ],
  ),
  ReliefExercise(
    id: 'gedanken',
    title: 'Gedanken beruhigen',
    subtitle: '5-4-3-2-1: im Moment ankommen',
    steps: [
      ReliefStep(
        seconds: 20,
        text:
            'Wenn der Bauch weh tut, kreisen oft auch die Gedanken. '
            'Wir holen dich jetzt ein Stück ins Hier und Jetzt.',
      ),
      ReliefStep(
        seconds: 35,
        text:
            'Schau dich um. Nenn in Gedanken fünf Dinge, die du sehen kannst.',
      ),
      ReliefStep(
        seconds: 35,
        text:
            'Spür vier Dinge, die du gerade berührst: den Boden, den Stoff '
            'deiner Kleidung, deine Hände …',
      ),
      ReliefStep(
        seconds: 30,
        text: 'Hör hin. Welche drei Geräusche kannst du hören?',
      ),
      ReliefStep(
        seconds: 25,
        text:
            'Welche zwei Dinge kannst du riechen? '
            'Fällt dir nichts ein, denk an zwei Gerüche, die du magst.',
      ),
      ReliefStep(
        seconds: 20,
        text:
            'Und eine Sache, die du schmecken kannst – '
            'oder nimm einen Schluck Wasser.',
      ),
      ReliefStep(
        seconds: 15,
        text:
            'Atme einmal lange aus. Du bist hier. '
            'Und du hast gerade gut für dich gesorgt.',
      ),
    ],
  ),
];
