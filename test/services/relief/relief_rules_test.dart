import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:belly_buddy/services/relief/relief_rules.dart';
import 'package:flutter_test/flutter_test.dart';

GutFeelingEntry _entry(DateTime at, {int bloating = 1, int cramps = 1}) =>
    GutFeelingEntry(
      id: 'e',
      trackedAt: at,
      bloating: bloating,
      gas: 1,
      cramps: cramps,
      fullness: 1,
    );

void main() {
  group('orderedExercises', () {
    test('yes first, no last, rest in content order', () {
      final ordered = orderedExercises(reliefExercises, {
        'gedanken': ReliefAnswer.yes,
        'bauchatmung': ReliefAnswer.no,
      });
      expect(ordered.first.id, 'gedanken');
      expect(ordered.last.id, 'bauchatmung');
      final middle = ordered.sublist(1, ordered.length - 1).map((e) => e.id);
      expect(
        middle,
        reliefExercises
            .map((e) => e.id)
            .where((id) => id != 'gedanken' && id != 'bauchatmung'),
      );
      expect(ordered.length, reliefExercises.length);
    });
  });

  group('parseReliefAnswers', () {
    test('invalid json gives an empty map', () {
      expect(parseReliefAnswers('not json'), isEmpty);
      expect(parseReliefAnswers(null), isEmpty);
      expect(parseReliefAnswers('[1]'), isEmpty);
    });

    test('unknown ids and answers are dropped', () {
      expect(
        parseReliefAnswers('{"x":"yes","waerme":"maybe","waerme2":1}'),
        isEmpty,
      );
    });

    test('valid entries are kept', () {
      expect(parseReliefAnswers('{"waerme":"little"}'), {
        'waerme': ReliefAnswer.little,
      });
    });
  });

  group('offersRelief', () {
    final now = DateTime.utc(2026, 11, 27, 12);

    test('true for a fresh strong symptom', () {
      expect(
        offersRelief(
          _entry(now.subtract(const Duration(minutes: 30)), cramps: 4),
          now: now,
        ),
        isTrue,
      );
    });

    test('false for mild symptoms or an old entry', () {
      expect(offersRelief(_entry(now, bloating: 3), now: now), isFalse);
      expect(
        offersRelief(
          _entry(now.subtract(const Duration(hours: 3)), bloating: 5),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
