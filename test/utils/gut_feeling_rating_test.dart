import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';

void main() {
  GutFeelingEntry makeEntry({
    int bloating = 1,
    int gas = 1,
    int cramps = 1,
    int fullness = 1,
    int? stress,
    int? happiness,
    int? energy,
    int? focus,
    int? bodyFeel,
  }) {
    return GutFeelingEntry(
      id: 'test',
      trackedAt: DateTime(2026, 1, 1),
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
  }

  group('calculateGutFeelingRating', () {
    test('all 1s returns sehr gut', () {
      final rating = calculateGutFeelingRating(makeEntry());
      expect(rating.avg, 1.0);
      expect(rating.level, GutFeelingRatingLevel.spiGut);
    });

    test('all 5s returns schlecht', () {
      final rating = calculateGutFeelingRating(
        makeEntry(bloating: 5, gas: 5, cramps: 5, fullness: 5),
      );
      expect(rating.avg, 5.0);
      expect(rating.level, GutFeelingRatingLevel.schlecht);
    });

    test('average 2.0 returns gut', () {
      final rating = calculateGutFeelingRating(
        makeEntry(bloating: 1, gas: 2, cramps: 2, fullness: 3),
      );
      expect(rating.avg, 2.0);
      expect(rating.level, GutFeelingRatingLevel.gut);
    });

    test('average 3.0 returns durchschnittlich', () {
      final rating = calculateGutFeelingRating(
        makeEntry(bloating: 3, gas: 3, cramps: 3, fullness: 3),
      );
      expect(rating.avg, 3.0);
      expect(rating.level, GutFeelingRatingLevel.durchschnittlich);
    });

    test('includes mood values when present', () {
      final rating = calculateGutFeelingRating(
        makeEntry(
          bloating: 1, gas: 1, cramps: 1, fullness: 1,
          stress: 5, happiness: 5, energy: 5, focus: 5, bodyFeel: 5,
        ),
      );
      // (4*1 + 5*5) / 9 = 29/9 ≈ 3.22
      expect(rating.avg, closeTo(3.22, 0.01));
      expect(rating.level, GutFeelingRatingLevel.durchschnittlich);
    });

    test('ignores null mood values', () {
      final rating = calculateGutFeelingRating(
        makeEntry(stress: 5),
      );
      // (4*1 + 5) / 5 = 9/5 = 1.8
      expect(rating.avg, closeTo(1.8, 0.01));
      expect(rating.level, GutFeelingRatingLevel.gut);
    });
  });

  group('getValueColor', () {
    test('low values return green', () {
      expect(getValueColor(1), const Color(0xFF40BF40));
      expect(getValueColor(2), const Color(0xFF40BF40));
    });

    test('medium values return yellow', () {
      expect(getValueColor(3), const Color(0xFFE6B800));
    });

    test('high values return red', () {
      expect(getValueColor(4), const Color(0xFFD93636));
      expect(getValueColor(5), const Color(0xFFD93636));
    });
  });
}
