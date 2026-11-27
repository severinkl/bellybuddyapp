import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('six exercises with unique ids in spec order', () {
    expect(reliefExercises.map((e) => e.id).toList(), [
      'bauchatmung',
      'box_atmung',
      'muskelentspannung',
      'bauchmassage',
      'waerme',
      'gedanken',
    ]);
    expect(reliefExerciseById('waerme')?.title, 'Wärme');
    expect(reliefExerciseById('nope'), isNull);
  });

  test('durations match the spec', () {
    expect(reliefExercises.map((e) => e.totalSeconds).toList(), [
      180,
      180,
      220,
      240,
      690,
      180,
    ]);
    expect(reliefExercises.map((e) => e.minutes).toList(), [3, 3, 4, 4, 12, 3]);
  });

  test('every breathing step is whole cycles', () {
    for (final e in reliefExercises) {
      for (final s in e.steps.where((s) => s.breath != null)) {
        expect(s.seconds % s.breath!.cycleSeconds, 0, reason: e.id);
      }
    }
    final b = reliefExerciseById('bauchatmung')!.steps[2].breath!;
    expect([b.inhale, b.holdIn, b.exhale, b.holdOut], [4, 0, 6, 0]);
    final x = reliefExerciseById('box_atmung')!.steps[2].breath!;
    expect([x.inhale, x.holdIn, x.exhale, x.holdOut], [4, 4, 4, 4]);
  });

  test('only the warmth timer is quiet', () {
    final quiet = [
      for (final e in reliefExercises)
        for (var i = 0; i < e.steps.length; i++)
          if (e.steps[i].quiet) (e.id, i, e.steps[i].seconds),
    ];
    expect(quiet, [('waerme', 3, 600)]);
  });

  test('cautions: massage, warmth and both breathing; not gedanken', () {
    for (final id in ['bauchmassage', 'waerme', 'bauchatmung', 'box_atmung']) {
      expect(reliefExerciseById(id)!.caution, isNotNull, reason: id);
    }
    expect(reliefExerciseById('gedanken')!.caution, isNull);
  });

  test('nothing is reviewed yet', () {
    expect(reliefExercises.every((e) => !e.reviewed), isTrue);
  });

  test('phaseAt walks the box', () {
    const p = BreathPattern(inhale: 4, holdIn: 4, exhale: 4, holdOut: 4);
    expect(p.cycleSeconds, 16);
    for (var s = 0; s < 4; s++) {
      expect(p.phaseAt(s), BreathPhase.inhale);
    }
    for (var s = 4; s < 8; s++) {
      expect(p.phaseAt(s), BreathPhase.holdIn);
    }
    for (var s = 8; s < 12; s++) {
      expect(p.phaseAt(s), BreathPhase.exhale);
    }
    for (var s = 12; s < 16; s++) {
      expect(p.phaseAt(s), BreathPhase.holdOut);
    }
    expect(p.phaseAt(16), BreathPhase.inhale);
    expect(p.secondsLeftInPhase(0), 4);
    expect(p.secondsLeftInPhase(3), 1);
    expect(p.secondsLeftInPhase(16), 4);
  });

  test('phaseAt skips empty holds', () {
    const p = BreathPattern(inhale: 4, exhale: 6);
    expect(p.cycleSeconds, 10);
    expect(p.phaseAt(3), BreathPhase.inhale);
    expect(p.phaseAt(4), BreathPhase.exhale);
    expect(p.phaseAt(9), BreathPhase.exhale);
    expect(p.phaseAt(10), BreathPhase.inhale);
    expect(p.secondsLeftInPhase(4), 6);
    expect(p.secondsLeftInPhase(9), 1);
  });

  test('phase labels', () {
    expect(breathPhaseLabel(BreathPhase.inhale), 'Einatmen');
    expect(breathPhaseLabel(BreathPhase.holdIn), 'Halten');
    expect(breathPhaseLabel(BreathPhase.exhale), 'Ausatmen');
    expect(breathPhaseLabel(BreathPhase.holdOut), 'Halten');
  });

  test('copy helpers', () {
    expect(ReliefCopy.stepOf(2, 4), 'Schritt 2 von 4');
    expect(ReliefCopy.minutesLabel(3), '3 Min.');
    expect(ReliefCopy.dialFailed('144'), 'Wähl bitte direkt 144.');
    expect(
      ReliefCopy.phaseSemantics('Einatmen', 3),
      'Einatmen, noch 3 Sekunden',
    );
    expect(ReliefCopy.phaseSemantics('Halten', 1), 'Halten, noch 1 Sekunde');
    expect(ReliefCopy.safetyLinkLabel, ReliefCopy.safetySheetTitle);
  });

  test('no promise words', () {
    final promise = RegExp(r'\b(wirkt|garantiert|sofort besser)\b');
    final texts = <String>[
      ...ReliefCopy.allStrings,
      for (final e in reliefExercises) ...[
        e.title,
        e.subtitle,
        ?e.caution,
        for (final s in e.steps) s.text,
      ],
    ];
    expect(texts.length, greaterThan(30));
    for (final t in texts) {
      expect(promise.hasMatch(t), isFalse, reason: t);
    }
  });
}
