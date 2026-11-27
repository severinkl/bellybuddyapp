import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/services/insights/test_copy.dart';

const _zwiebel = TestSubject('ingredient', 'zwiebel', 'Zwiebel');
const _fructans = TestSubject('group', 'fructans', 'Fruktane');

TestResult _result(TestOutcome o, {int notKept = 0, int notEaten = 0}) =>
    TestResult(
      goodWithout: 4,
      countedWithout: 5,
      goodWith: 1,
      countedWith: 3,
      outcome: o,
      notKept: notKept,
      notEaten: notEaten,
    );

/// Every string [TestCopy] can produce, for the wording checks.
List<String> _allCopy() => [
  TestCopy.pageTitle,
  TestCopy.title(_zwiebel),
  TestCopy.introBody(_zwiebel, 5, 3),
  TestCopy.introBody(_fructans, 5, 3),
  TestCopy.datesLine(DateTime(2026, 11, 28), 5, 3),
  TestCopy.groupFoods(_fructans, ['Zwiebel', 'Weizenbrot']),
  TestCopy.doctor,
  TestCopy.notMedical,
  TestCopy.phaseLine(TestPhase.leaveOut, _zwiebel)!,
  TestCopy.phaseLine(TestPhase.reintro, _fructans)!,
  TestCopy.dayOf(2, 8),
  TestCopy.startsOn(DateTime(2026, 11, 28)),
  TestCopy.notKept(1, _zwiebel),
  TestCopy.notKept(2, _zwiebel),
  TestCopy.notEaten(1, _zwiebel),
  TestCopy.notEaten(2, _zwiebel),
  TestCopy.resultHeadline(_zwiebel, _result(TestOutcome.worse)),
  for (final o in TestOutcome.values) ...[
    TestCopy.conclusion(o, _zwiebel),
    TestCopy.badge(o),
  ],
  TestCopy.restrictive,
  TestCopy.stopTitle,
  TestCopy.stopBody,
  TestCopy.stopConfirm,
  TestCopy.stopKeep,
  TestCopy.stopAction,
  TestCopy.startAction,
  TestCopy.testAction,
  TestCopy.testActionSemantics('Zwiebel'),
  TestCopy.retest,
  TestCopy.proposal(_zwiebel),
  TestCopy.pickerTitle,
  TestCopy.pickerLine,
  TestCopy.legendNotKept,
  TestCopy.legendOpen,
  TestCopy.startFailed,
  TestCopy.stopFailed,
  TestCopy.daySemantics(
    TestDayView(
      day: DateTime(2026, 11, 28),
      phase: TestPhase.leaveOut,
      dayClass: DayClass.none,
      exposed: true,
    ),
  ),
];

void main() {
  test('result headline: „In den Tagen ohne Zwiebel ging es dir an 4 von 5 '
      'Tagen gut, mit Zwiebel an 1 von 3."', () {
    expect(
      TestCopy.resultHeadline(_zwiebel, _result(TestOutcome.worse)),
      'In den Tagen ohne Zwiebel ging es dir an 4 von 5 Tagen gut, mit '
      'Zwiebel an 1 von 3.',
    );
    // „mit Fruktanen" (dative plural), „ohne Fruktane".
    expect(
      TestCopy.resultHeadline(_fructans, _result(TestOutcome.worse)),
      'In den Tagen ohne Fruktane ging es dir an 4 von 5 Tagen gut, mit '
      'Fruktanen an 1 von 3.',
    );
  });

  test('each outcome has its conclusion and every result carries the doctor '
      'line and „kein medizinischer Befund"', () {
    expect(
      TestCopy.conclusion(TestOutcome.worse, _zwiebel),
      'Mit Zwiebel ging es dir in diesem Test deutlich schlechter. Das könnte '
      'heißen, dass du Zwiebel gerade nicht so gut verträgst.',
    );
    expect(
      TestCopy.conclusion(TestOutcome.slightlyWorse, _zwiebel),
      'Mit Zwiebel ging es dir etwas schlechter. Acht Tage sind kurz – wenn '
      'du magst, wiederhol den Test später.',
    );
    expect(
      TestCopy.conclusion(TestOutcome.noDifference, _zwiebel),
      'Zwiebel hat in diesem Test keinen klaren Unterschied gemacht.',
    );
    expect(
      TestCopy.conclusion(TestOutcome.better, _zwiebel),
      'Mit Zwiebel ging es dir in diesem Test nicht schlechter – Zwiebel '
      'scheint gerade kein Problem für dich zu sein.',
    );
    expect(
      TestCopy.conclusion(TestOutcome.unclear, _zwiebel),
      'Dafür hab ich zu wenige Tage mit Bauchgefühl. Magst du es nochmal '
      'versuchen?',
    );
    for (final o in TestOutcome.values) {
      final lines = TestCopy.resultLines(_zwiebel, _result(o));
      expect(lines, contains(TestCopy.conclusion(o, _zwiebel)));
      expect(lines, contains(TestCopy.doctor));
      expect(lines, contains(TestCopy.notMedical));
    }
    expect(
      TestCopy.notMedical,
      'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.',
    );
    expect(
      TestCopy.doctor,
      'Hast du starke oder anhaltende Beschwerden, sprich bitte mit deiner '
      'Ärztin, deinem Arzt oder einer Ernährungsfachkraft.',
    );
  });

  test('not kept: „An 1 Tag war Zwiebel doch dabei – das passiert. Diesen '
      'Tag zähle ich nicht mit." / plural „An 2 Tagen … Diese Tage …"', () {
    expect(
      TestCopy.notKept(1, _zwiebel),
      'An 1 Tag war Zwiebel doch dabei – das passiert. Diesen Tag zähle ich '
      'nicht mit.',
    );
    expect(
      TestCopy.notKept(2, _zwiebel),
      'An 2 Tagen war Zwiebel doch dabei – das passiert. Diese Tage zähle ich '
      'nicht mit.',
    );
    expect(
      TestCopy.notEaten(1, _zwiebel),
      'An 1 Tag war Zwiebel nicht dabei – den zähle ich nicht mit.',
    );
    expect(
      TestCopy.notEaten(3, _zwiebel),
      'An 3 Tagen war Zwiebel nicht dabei – die zähle ich nicht mit.',
    );
    // Shown under the result only when there are any.
    final lines = TestCopy.resultLines(
      _zwiebel,
      _result(TestOutcome.worse, notKept: 2, notEaten: 1),
    );
    expect(lines, contains(TestCopy.notKept(2, _zwiebel)));
    expect(lines, contains(TestCopy.notEaten(1, _zwiebel)));
    expect(
      TestCopy.resultLines(_zwiebel, _result(TestOutcome.worse)),
      isNot(contains(startsWith('An '))),
    );
  });

  test('no copy contains „Diagnose", „Auslöser" or „verursacht"', () {
    for (final line in _allCopy()) {
      for (final word in [
        'Diagnose',
        'Auslöser',
        'verursacht',
        'Behandlung',
        'verträgst du nicht',
      ]) {
        expect(line, isNot(contains(word)), reason: line);
      }
    }
  });

  test('the five badges', () {
    expect(TestOutcome.values.map(TestCopy.badge), [
      'getestet: deutlich schlechter',
      'getestet: etwas schlechter',
      'getestet: kein klarer Unterschied',
      'getestet: kein Problem',
      'getestet: unklar',
    ]);
  });

  test('intro, dates as „d. MMM", phases, stop dialog and restrictive', () {
    expect(TestCopy.title(_zwiebel), 'Verträglichkeits-Test: Zwiebel');
    expect(
      TestCopy.introBody(_zwiebel, 5, 3),
      'So geht\'s: 5 Tage lässt du Zwiebel weg, danach isst du es 3 Tage '
      'wieder ganz normal. Trag jeden Abend dein Bauchgefühl ein – dann '
      'vergleiche ich die beiden Phasen.',
    );
    // 28 Nov + 5 → 2 Dez; reintro 3 Dez – 5 Dez.
    expect(
      TestCopy.datesLine(DateTime(2026, 11, 28), 5, 3),
      'Ohne: 28. Nov – 2. Dez · Mit: 3. Dez – 5. Dez',
    );
    expect(
      TestCopy.groupFoods(_fructans, ['Zwiebel', 'Weizenbrot', 'Knoblauch']),
      'Fruktane stecken bei dir zum Beispiel in Zwiebel, Weizenbrot, '
      'Knoblauch.',
    );
    expect(
      TestCopy.phaseLine(TestPhase.leaveOut, _zwiebel),
      'Phase 1: ohne Zwiebel',
    );
    expect(
      TestCopy.phaseLine(TestPhase.reintro, _fructans),
      'Phase 2: wieder mit Fruktanen',
    );
    expect(TestCopy.phaseLine(TestPhase.done, _zwiebel), isNull);
    expect(TestCopy.dayOf(2, 8), 'Tag 2 von 8');
    expect(TestCopy.proposal(_zwiebel), 'Magst du Zwiebel testen?');
    expect(TestCopy.stopTitle, 'Test beenden?');
    expect(
      TestCopy.stopBody,
      'Kein Problem – hör auf deinen Bauch. Das Ergebnis zeige ich dann '
      'nicht.',
    );
    expect(TestCopy.stopConfirm, 'Beenden');
    expect(TestCopy.stopKeep, 'Weitermachen');
    expect(
      TestCopy.restrictive,
      'Gerade schlage ich keinen Test vor. In deinen Einträgen ist die Auswahl '
      'schon recht klein – etwas wegzulassen würde sie noch kleiner machen. '
      'Wenn du herausfinden willst, was dir guttut, kann dir eine '
      'Ernährungsfachkraft dabei helfen.',
    );
  });

  test('the six groups, in the catalog order', () {
    expect(TestCopy.groups.map((g) => g.key), [
      'fructans',
      'gos',
      'lactose',
      'fructose',
      'sorbitol',
      'mannitol',
    ]);
    expect(TestCopy.groups.map((g) => g.name), [
      'Fruktane',
      'GOS',
      'Laktose',
      'Fruktose',
      'Sorbit',
      'Mannit',
    ]);
    expect(TestCopy.groups.every((g) => g.kind == 'group'), isTrue);
  });
}
