import '../../models/insights.dart';
import '../../models/tolerance_test.dart';
import '../../utils/date_format_utils.dart';
import 'insight_copy.dart';
import 'stats_copy.dart';

/// German copy of the Verträglichkeits-Test (spec §5.4, §5.6): every result
/// is relative, an observation, never a finding; the doctor line goes with
/// the intro, the result and the stop dialog.
class TestCopy {
  const TestCopy._();

  static const pageTitle = 'Verträglichkeits-Test';

  /// „Verträglichkeits-Test: Zwiebel".
  static String title(TestSubject s) => 'Verträglichkeits-Test: ${s.name}';

  /// A group reads as its foods: „lässt du Lebensmittel mit Fruktanen
  /// weg, danach isst du sie …".
  static String introBody(TestSubject s, int leaveOut, int reintro) {
    final how = _isGroup(s)
        ? '$leaveOut Tage lässt du Lebensmittel mit ${_mit(s)} weg, danach '
              'isst du sie $reintro Tage'
        : '$leaveOut Tage lässt du ${s.name} weg, danach isst du es '
              '$reintro Tage';
    return 'So geht\'s: $how wieder ganz normal. Trag jeden Abend dein '
        'Bauchgefühl ein – dann vergleiche ich die beiden Phasen.';
  }

  /// „Ohne: 28. Nov – 2. Dez · Mit: 3. Dez – 5. Dez" for a test starting
  /// on [startsOn] (a wall-clock date).
  static String datesLine(DateTime startsOn, int leaveOut, int reintro) {
    final reintroOn = addDays(startsOn, leaveOut);
    return 'Ohne: ${day(startsOn)} – ${day(addDays(startsOn, leaveOut - 1))}'
        ' · Mit: ${day(reintroOn)} – ${day(addDays(reintroOn, reintro - 1))}';
  }

  /// „Lebensmittel mit Fruktanen sind bei dir zum Beispiel: Zwiebel,
  /// Weizenbrot."
  static String groupFoods(TestSubject group, List<String> foods) =>
      'Lebensmittel mit ${_mit(group)} sind bei dir zum Beispiel: '
      '${foods.join(', ')}.';

  static const doctor =
      'Hast du starke oder anhaltende Beschwerden, sprich bitte mit deiner '
      'Ärztin, deinem Arzt oder einer Ernährungsfachkraft.';

  static const notMedical =
      'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.';

  /// „Phase 1: ohne Zwiebel" / „Phase 2: wieder mit Zwiebel"; none once
  /// the test is over.
  static String? phaseLine(TestPhase p, TestSubject s) => switch (p) {
    TestPhase.leaveOut => 'Phase 1: ohne ${s.name}',
    TestPhase.reintro => 'Phase 2: wieder mit ${_mit(s)}',
    TestPhase.done => null,
  };

  /// „Tag 2 von 8".
  static String dayOf(int i, int total) => 'Tag $i von $total';

  /// Before the first day: „Los geht's am 28. Nov."
  static String startsOn(DateTime d) => 'Los geht\'s am ${day(d)}.';

  static String notKept(int n, TestSubject s) {
    final what = _isGroup(s)
        ? 'doch etwas mit ${_mit(s)} dabei'
        : '${s.name} doch dabei';
    return n == 1
        ? 'An 1 Tag war $what – das passiert. Diesen Tag zähle ich nicht mit.'
        : 'An $n Tagen war $what – das passiert. Diese Tage zähle ich nicht '
              'mit.';
  }

  static String notEaten(int n, TestSubject s) {
    final what = _isGroup(s)
        ? 'nichts mit ${_mit(s)} dabei'
        : '${s.name} nicht dabei';
    return n == 1
        ? 'An 1 Tag war $what – den zähle ich nicht mit.'
        : 'An $n Tagen war $what – die zähle ich nicht mit.';
  }

  static String resultHeadline(TestSubject s, TestResult r) =>
      'In den Tagen ohne ${s.name} ging es dir an ${r.goodWithout} von '
      '${r.countedWithout} Tagen gut, mit ${_mit(s)} an ${r.goodWith} von '
      '${r.countedWith}.';

  /// A group's conclusion speaks of „Lebensmittel mit Fruktanen" (plural).
  static String conclusion(TestOutcome o, TestSubject s) {
    final g = _isGroup(s);
    final foods = 'Lebensmittel mit ${_mit(s)}';
    return switch (o) {
      TestOutcome.worse =>
        'Mit ${_mit(s)} ging es dir in diesem Test deutlich schlechter. Das '
            'könnte heißen, dass du ${g ? foods : s.name} gerade nicht so gut '
            'verträgst.',
      TestOutcome.slightlyWorse =>
        'Mit ${_mit(s)} ging es dir etwas schlechter. Acht Tage sind kurz – '
            'wenn du magst, wiederhol den Test später.',
      TestOutcome.noDifference =>
        g
            ? '$foods haben in diesem Test keinen klaren Unterschied gemacht.'
            : '${s.name} hat in diesem Test keinen klaren Unterschied '
                  'gemacht.',
      TestOutcome.better =>
        g
            ? 'Mit ${_mit(s)} ging es dir in diesem Test nicht schlechter – '
                  '$foods scheinen gerade kein Problem für dich zu sein.'
            : 'Mit ${_mit(s)} ging es dir in diesem Test nicht schlechter – '
                  '${s.name} scheint gerade kein Problem für dich zu sein.',
      TestOutcome.unclear =>
        'Dafür hab ich zu wenige Tage mit Bauchgefühl. Magst du es nochmal '
            'versuchen?',
    };
  }

  /// The result as shown, in order: headline, conclusion, the not-kept and
  /// not-eaten lines (when there are any), the observation note and the
  /// doctor line.
  static List<String> resultLines(TestSubject s, TestResult r) => [
    resultHeadline(s, r),
    conclusion(r.outcome, s),
    if (r.notKept > 0) notKept(r.notKept, s),
    if (r.notEaten > 0) notEaten(r.notEaten, s),
    notMedical,
    doctor,
  ];

  /// The „getestet" badge on a stats row.
  static String badge(TestOutcome o) => switch (o) {
    TestOutcome.worse => 'getestet: deutlich schlechter',
    TestOutcome.slightlyWorse => 'getestet: etwas schlechter',
    TestOutcome.noDifference => 'getestet: kein klarer Unterschied',
    TestOutcome.better => 'getestet: kein Problem',
    TestOutcome.unclear => 'getestet: unklar',
  };

  static const restrictive =
      'Gerade schlage ich keinen Test vor. In deinen Einträgen ist die '
      'Auswahl schon recht klein – etwas wegzulassen würde sie noch kleiner '
      'machen. Wenn du herausfinden willst, was dir guttut, kann dir eine '
      'Ernährungsfachkraft dabei helfen.';

  static const stopAction = 'Test beenden';
  static const stopTitle = 'Test beenden?';
  static const stopBody =
      'Kein Problem – hör auf deinen Bauch. Das Ergebnis zeige ich dann '
      'nicht.';
  static const stopConfirm = 'Beenden';
  static const stopKeep = 'Weitermachen';
  static const stopFailed =
      'Das hat gerade nicht geklappt. Versuch es bitte nochmal.';

  static const startAction = 'Test starten';
  static const startFailed =
      'Der Test konnte gerade nicht starten. Versuch es bitte nochmal.';

  /// A stats row's and the closing line's action.
  static const testAction = 'Testen';

  /// „Testen" to a screen reader on a row: „Zwiebel testen".
  static String testActionSemantics(String name) => '$name testen';

  static const retest = 'Nochmal testen';

  /// The Muster card's proposal.
  static String proposal(TestSubject s) => 'Magst du ${s.name} testen?';

  static const pickerTitle = 'Was magst du testen?';
  static const pickerLine =
      'Such dir eine FODMAP-Gruppe aus. Für einzelne Zutaten tipp bei '
      '„Genauer hingeschaut" auf „Testen".';

  /// The legend: a day's marker, and a day still to come.
  static const legendNotKept = 'nicht eingehalten / nicht gegessen';
  static const legendOpen = 'noch offen';

  /// A test day to a screen reader: „28. Nov: gut, nicht eingehalten".
  static String daySemantics(TestDayView d) {
    final marker = switch (d.phase) {
      TestPhase.leaveOut when d.exposed => ', nicht eingehalten',
      TestPhase.reintro when !d.exposed && d.dayClass != DayClass.none =>
        ', nicht gegessen',
      _ => '',
    };
    return '${day(d.day)}: ${InsightCopy.dayClassLabel(d.dayClass)}$marker';
  }

  /// A day still to come: „2. Dez: noch offen".
  static String openDaySemantics(DateTime d) => '${day(d)}: $legendOpen';

  /// [d] as „28. Nov".
  static String day(DateTime d) => '${d.day}. ${kMonthShortNames[d.month - 1]}';

  // --- Home and reminders (spec §5.5) ---------------------------------------

  /// The notification on the first reintroduction day; a group reads as
  /// its foods („Ab heute dürfen Lebensmittel mit Fruktanen …").
  static String reintroNotification(TestSubject s) =>
      '${_backOnThePlate(s)} – ich schau, wie\'s deinem Bauch damit geht.';

  /// The notification on the result day.
  static const resultNotification =
      'Dein Verträglichkeits-Test ist fertig. Magst du reinschauen?';

  /// The Buddy's offer on Home.
  static const offerTitle = 'Magst du was ausprobieren?';

  /// A group reads as its foods („waren oft Lebensmittel mit Fruktanen").
  static String offerBody(TestSubject s) {
    final often = _isGroup(s)
        ? 'waren oft Lebensmittel mit ${_mit(s)}'
        : 'war oft ${s.name}';
    return 'An schweren Tagen $often dabei. Wollen wir testen, ob dein '
        'Bauch ohne besser klarkommt? 5 Tage ohne, dann 3 Tage mit.';
  }

  static const offerOpen = 'Ansehen';
  static const offerLater = 'Später';

  /// The Buddy's line on the first reintroduction day.
  static String reintroLine(TestSubject s) =>
      '${_backOnThePlate(s)}. Trag abends dein Bauchgefühl ein!';

  /// „Ab heute darf Zwiebel wieder auf den Teller" / „Ab heute dürfen
  /// Lebensmittel mit Fruktanen wieder auf den Teller".
  static String _backOnThePlate(TestSubject s) => _isGroup(s)
      ? 'Ab heute dürfen Lebensmittel mit ${_mit(s)} wieder auf den Teller'
      : 'Ab heute darf ${s.name} wieder auf den Teller';

  /// The Buddy's line once the result is there.
  static const doneLine = 'Dein Test ist fertig – schau mal in die Muster.';

  /// The daily review's line while a test runs: „Verträglichkeits-Test:
  /// heute ohne Zwiebel (Tag 2 von 8)"; none once it is over.
  static String? dailyReviewLine(ToleranceTestView t) {
    final what = switch (t.phase) {
      TestPhase.leaveOut => 'ohne ${t.subject.name}',
      TestPhase.reintro => 'wieder mit ${_mit(t.subject)}',
      TestPhase.done => null,
    };
    if (what == null) return null;
    return '$pageTitle: heute $what (Tag ${t.dayIndex} von ${t.totalDays})';
  }

  /// The six FODMAP groups, in the catalog's order, with their short names.
  static const groups = [
    TestSubject('group', 'fructans', 'Fruktane'),
    TestSubject('group', 'gos', 'GOS'),
    TestSubject('group', 'lactose', 'Laktose'),
    TestSubject('group', 'fructose', 'Fruktose'),
    TestSubject('group', 'sorbitol', 'Sorbit'),
    TestSubject('group', 'mannitol', 'Mannit'),
  ];

  static bool _isGroup(TestSubject s) => s.kind == 'group';

  static String _mit(TestSubject s) =>
      StatsCopy.nameAfterMit(s.kind, s.key, s.name);
}
