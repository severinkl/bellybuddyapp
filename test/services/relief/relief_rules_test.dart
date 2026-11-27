import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:belly_buddy/services/relief/relief_rules.dart';
import 'package:flutter_test/flutter_test.dart';

GutFeelingEntry _entry(
  DateTime at, {
  int bloating = 1,
  int gas = 1,
  int cramps = 1,
  int fullness = 1,
  int? stress,
  int? happiness,
  int? energy,
  int? focus,
  int? bodyFeel,
}) => GutFeelingEntry(
  id: 'e',
  trackedAt: at,
  bloating: bloating,
  gas: gas,
  cramps: cramps,
  fullness: fullness,
  stress: stress,
  happiness: happiness,
  energy: energy,
  focus: focus,
  bodyFeel: bodyFeel,
);

final _ids = {for (final e in reliefExercises) e.id};

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

  group('tryParseReliefAnswers', () {
    test('corrupt json gives null, no json an empty map', () {
      expect(tryParseReliefAnswers('not json', knownIds: _ids), isNull);
      expect(tryParseReliefAnswers(null, knownIds: _ids), isEmpty);
      expect(tryParseReliefAnswers('[1]', knownIds: _ids), isNull);
    });

    test('unknown ids and answers are dropped', () {
      expect(
        tryParseReliefAnswers(
          '{"x":"yes","waerme":"maybe","waerme2":1}',
          knownIds: _ids,
        ),
        isEmpty,
      );
    });

    test('valid entries are kept', () {
      expect(tryParseReliefAnswers('{"waerme":"little"}', knownIds: _ids), {
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
    group('offersRelief, the matrix', () {
      // Plain wall clock, no zone: as the tracker sees it.
      final now = DateTime(2026, 11, 27, 12);

      test('Krämpfe 4 right now offers', () {
        expect(offersRelief(_entry(now, cramps: 4), now: now), isTrue);
      });

      test('Blähungen 4 and Völlegefühl 5 offer too', () {
        expect(offersRelief(_entry(now, gas: 4), now: now), isTrue);
        expect(offersRelief(_entry(now, fullness: 5), now: now), isTrue);
      });

      test('every symptom at 3 does not offer', () {
        expect(
          offersRelief(
            _entry(now, bloating: 3, gas: 3, cramps: 3, fullness: 3),
            now: now,
          ),
          isFalse,
        );
      });

      test('Blähbauch 5 exactly 2 h ago offers, a minute earlier not', () {
        final edge = now.subtract(const Duration(hours: 2));
        expect(offersRelief(_entry(edge, bloating: 5), now: now), isTrue);
        expect(
          offersRelief(
            _entry(edge.subtract(const Duration(minutes: 1)), bloating: 5),
            now: now,
          ),
          isFalse,
        );
      });

      test('up to 5 min ahead offers, 10 min ahead not', () {
        expect(
          offersRelief(
            _entry(now.add(const Duration(minutes: 5)), bloating: 5),
            now: now,
          ),
          isTrue,
        );
        expect(
          offersRelief(
            _entry(now.add(const Duration(minutes: 10)), bloating: 5),
            now: now,
          ),
          isFalse,
        );
      });

      test('high mood values with symptoms at 1 do not offer', () {
        expect(
          offersRelief(
            _entry(
              now,
              stress: 5,
              happiness: 5,
              energy: 5,
              focus: 5,
              bodyFeel: 5,
            ),
            now: now,
          ),
          isFalse,
        );
      });
    });
  });
}
