import 'package:belly_buddy/services/daily_review/daily_review_copy.dart';
import 'package:belly_buddy/services/daily_review/daily_review_rules.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meals', () {
    expect(
      DailyReviewCopy.meals(1, yesterday: false),
      'Heute hast du 1 Mahlzeit eingetragen.',
    );
    expect(
      DailyReviewCopy.meals(3, yesterday: true),
      'Gestern hast du 3 Mahlzeiten eingetragen.',
    );
  });

  test('alternative', () {
    expect(
      DailyReviewCopy.alternative(
        'Zwiebel',
        'Frühlingszwiebel (grün)',
        yesterday: false,
      ),
      'Statt Zwiebel könntest du morgen Frühlingszwiebel (grün) probieren.',
    );
    expect(
      DailyReviewCopy.alternative('Zwiebel', 'Lauch', yesterday: true),
      'Statt Zwiebel könntest du heute Lauch probieren.',
    );
  });

  test('none', () {
    expect(
      DailyReviewCopy.none(yesterday: false),
      'Für morgen hab ich keine Alternative für dich. Genieß deinen Abend!',
    );
    expect(
      DailyReviewCopy.none(yesterday: true),
      'Für heute hab ich keine Alternative für dich.',
    );
  });

  test('gut, recent, titles', () {
    expect(
      DailyReviewCopy.gut(GutFeelingRatingLevel.gut),
      'Dein Bauchgefühl zuletzt: Gut.',
    );
    expect(
      DailyReviewCopy.recent('Zwiebel', 4),
      'Zwiebel war in 4 deiner Mahlzeiten der letzten zwei Wochen.',
    );
    expect(
      DailyReviewCopy.title(ReviewDay(DateTime(2026), yesterday: false)),
      'Dein Tagesrückblick 🌙',
    );
    expect(
      DailyReviewCopy.title(ReviewDay(DateTime(2026), yesterday: true)),
      'Dein Rückblick auf gestern 🌙',
    );
  });

  test('notificationBody', () {
    expect(
      DailyReviewCopy.notificationBody(null),
      '🌙 Dein Tagesrückblick ist da.',
    );
    expect(
      DailyReviewCopy.notificationBody('Bobo'),
      '🌙 Bobo hat auf deinen Tag geschaut. Dein Tagesrückblick ist da.',
    );
    expect(
      DailyReviewCopy.notificationBody('  Bobo '),
      '🌙 Bobo hat auf deinen Tag geschaut. Dein Tagesrückblick ist da.',
    );
    expect(
      DailyReviewCopy.notificationBody('   '),
      '🌙 Dein Tagesrückblick ist da.',
    );
  });

  test('locked: „morgen" today, „heute" for yesterday; without a pick the '
      'Plus line', () {
    expect(
      DailyReviewCopy.locked(yesterday: false),
      'Für morgen hätte ich eine Alternative für dich.',
    );
    expect(
      DailyReviewCopy.locked(yesterday: true),
      'Für heute hätte ich eine Alternative für dich.',
    );
    expect(
      DailyReviewCopy.lockedNoPick,
      'Mit Belly Buddy Plus schaue ich jeden Abend nach einer Alternative '
      'für dich.',
    );
  });

  test('the fixed lines, exact', () {
    expect(DailyReviewCopy.gutHard, 'Ich bin für dich da. 💛');
    expect(DailyReviewCopy.gutAsk, 'Magst du noch dein Bauchgefühl eintragen?');
    expect(DailyReviewCopy.gutAskButton, 'Bauchgefühl eintragen');
    expect(DailyReviewCopy.tryIt, 'Probiere ich');
    expect(DailyReviewCopy.skip, 'Passt nicht für mich');
    expect(
      DailyReviewCopy.saved,
      'Gemerkt! Du findest es unter Entdecken › Alternativen.',
    );
    expect(DailyReviewCopy.savedOpen, 'Ansehen');
    expect(DailyReviewCopy.upsell, 'Mehr erfahren');
    expect(
      DailyReviewCopy.failed,
      'Das hat nicht geklappt. Versuch es später noch einmal.',
    );
    expect(DailyReviewCopy.close, 'Schließen');
    expect(
      DailyReviewCopy.cueLine,
      'Magst du kurz auf deinen Tag schauen? Er wartet gleich unter mir. 🌙',
    );
    expect(DailyReviewCopy.forget, 'Nicht mehr merken');
    expect(DailyReviewCopy.viewAlternatives, 'Alternativen ansehen ›');
  });

  test('no string contains solltest, wegen, Diagnose, Auslöser, zu viel', () {
    final strings = <String>[
      for (final y in [false, true]) ...[
        DailyReviewCopy.title(ReviewDay(DateTime(2026), yesterday: y)),
        for (final n in [1, 3]) DailyReviewCopy.meals(n, yesterday: y),
        DailyReviewCopy.alternative('Zwiebel', 'Lauch', yesterday: y),
        DailyReviewCopy.none(yesterday: y),
        DailyReviewCopy.locked(yesterday: y),
      ],
      for (final l in GutFeelingRatingLevel.values) DailyReviewCopy.gut(l),
      DailyReviewCopy.recent('Zwiebel', 3),
      DailyReviewCopy.notificationBody(null),
      DailyReviewCopy.notificationBody('Bobo'),
      DailyReviewCopy.gutHard,
      DailyReviewCopy.gutAsk,
      DailyReviewCopy.gutAskButton,
      DailyReviewCopy.tryIt,
      DailyReviewCopy.skip,
      DailyReviewCopy.saved,
      DailyReviewCopy.savedOpen,
      DailyReviewCopy.lockedNoPick,
      DailyReviewCopy.upsell,
      DailyReviewCopy.failed,
      DailyReviewCopy.close,
      DailyReviewCopy.cueLine,
      DailyReviewCopy.forget,
      DailyReviewCopy.viewAlternatives,
    ];
    for (final s in strings) {
      for (final w in [
        'solltest',
        'wegen',
        'Diagnose',
        'Auslöser',
        'zu viel',
      ]) {
        expect(s.toLowerCase().contains(w.toLowerCase()), isFalse, reason: s);
      }
    }
  });
}
