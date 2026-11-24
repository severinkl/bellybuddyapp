import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/config/app_theme.dart';
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

  group('gutFeelingScore', () {
    test('is the worst of the four gut symptoms', () {
      expect(gutFeelingScore(makeEntry()), 1);
      expect(gutFeelingScore(makeEntry(bloating: 3)), 3);
      expect(gutFeelingScore(makeEntry(gas: 2, cramps: 4)), 4);
      expect(gutFeelingScore(makeEntry(cramps: 5, fullness: 5)), 5);
      expect(gutFeelingScore(makeEntry(fullness: 2)), 2);
    });

    test('ignores the mood values', () {
      final entry = makeEntry(
        stress: 5,
        happiness: 5,
        energy: 5,
        focus: 5,
        bodyFeel: 5,
      );
      expect(gutFeelingScore(entry), 1);
    });
  });

  group('gutFeelingLevelFor', () {
    test('maps whole scores 1 / 2 / 3 / 4-5', () {
      expect(gutFeelingLevelFor(1), GutFeelingRatingLevel.spiGut);
      expect(gutFeelingLevelFor(2), GutFeelingRatingLevel.gut);
      expect(gutFeelingLevelFor(3), GutFeelingRatingLevel.mittel);
      expect(gutFeelingLevelFor(4), GutFeelingRatingLevel.schlecht);
      expect(gutFeelingLevelFor(5), GutFeelingRatingLevel.schlecht);
    });

    test('keeps the thresholds for means between whole scores', () {
      expect(gutFeelingLevelFor(1.5), GutFeelingRatingLevel.spiGut);
      expect(gutFeelingLevelFor(1.51), GutFeelingRatingLevel.gut);
      expect(gutFeelingLevelFor(2.5), GutFeelingRatingLevel.gut);
      expect(gutFeelingLevelFor(3.5), GutFeelingRatingLevel.mittel);
      expect(gutFeelingLevelFor(3.51), GutFeelingRatingLevel.schlecht);
    });
  });

  group('calculateGutFeelingRating', () {
    test('all 1s returns sehr gut', () {
      final rating = calculateGutFeelingRating(makeEntry());
      expect(rating.score, 1);
      expect(rating.level, GutFeelingRatingLevel.spiGut);
      expect(rating.color, AppTheme.gutFeelingGood);
    });

    test('Krämpfe 5 and Völlegefühl 5 is schlecht', () {
      final rating = calculateGutFeelingRating(
        makeEntry(cramps: 5, fullness: 5),
      );
      expect(rating.score, 5);
      expect(rating.level, GutFeelingRatingLevel.schlecht);
      expect(rating.color, AppTheme.gutFeelingBad);
    });

    test('Blähbauch 3 alone is mittel', () {
      final rating = calculateGutFeelingRating(makeEntry(bloating: 3));
      expect(rating.score, 3);
      expect(rating.level, GutFeelingRatingLevel.mittel);
      expect(rating.color, AppTheme.gutFeelingNeutral);
    });

    test('one symptom at 2 is gut', () {
      final rating = calculateGutFeelingRating(makeEntry(gas: 2));
      expect(rating.level, GutFeelingRatingLevel.gut);
    });

    test('a symptom at 4 is already schlecht', () {
      final rating = calculateGutFeelingRating(makeEntry(fullness: 4));
      expect(rating.level, GutFeelingRatingLevel.schlecht);
    });

    test('bad mood does not change the rating', () {
      final rating = calculateGutFeelingRating(
        makeEntry(stress: 5, happiness: 5, energy: 5, focus: 5, bodyFeel: 5),
      );
      expect(rating.level, GutFeelingRatingLevel.spiGut);
    });
  });

  group('gutFeelingScoreLabel', () {
    test('no symptom reads as no complaints', () {
      expect(gutFeelingScoreLabel(1), 'Keine Beschwerden');
    });

    test('otherwise names the strongest symptom value', () {
      expect(gutFeelingScoreLabel(3), 'Stärkstes Symptom: 3 von 5');
      expect(gutFeelingScoreLabel(5), 'Stärkstes Symptom: 5 von 5');
    });
  });

  group('gutFeelingSubtitle', () {
    test('all 1s returns Alles gut', () {
      final entry = makeEntry();
      expect(gutFeelingSubtitle(entry), 'Alles gut');
    });

    test('single physical symptom > 1', () {
      final entry = makeEntry(bloating: 3);
      expect(gutFeelingSubtitle(entry), 'Blähbauch');
    });

    test('multiple symptoms', () {
      final entry = makeEntry(bloating: 2, cramps: 4);
      expect(gutFeelingSubtitle(entry), 'Blähbauch, Krämpfe');
    });

    test('mood values > 1 included', () {
      final entry = makeEntry(stress: 3, happiness: 4);
      expect(gutFeelingSubtitle(entry), 'gestresst, traurig');
    });

    test('mood values null excluded', () {
      final entry = makeEntry(stress: null, happiness: null);
      expect(gutFeelingSubtitle(entry), 'Alles gut');
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
