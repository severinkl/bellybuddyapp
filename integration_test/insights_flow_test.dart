import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import 'package:belly_buddy/screens/patterns/patterns_screen.dart';
import 'package:belly_buddy/screens/patterns/widgets/patterns_locked.dart';
import 'package:belly_buddy/services/insights/insight_copy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fakes.dart';
import 'helpers/test_app.dart';

/// Noon, [daysAgo] local days back.
DateTime _noon(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, 12);
}

GutFeelingEntry _gut(int daysAgo, {required int value}) => GutFeelingEntry(
  id: 'gut-$daysAgo',
  trackedAt: _noon(daysAgo),
  bloating: value,
  gas: value,
  cramps: value,
  fullness: value,
);

/// Five hard days (Zwiebel in the meal before 4 of them) and six good days
/// without it.
InsightSource _unlockedSource() {
  const hardDaysAgo = [2, 4, 6, 8, 10];
  const goodDaysAgo = [3, 5, 7, 9, 11, 13];
  final gutFeelings = [
    for (final d in hardDaysAgo) _gut(d, value: 5),
    for (final d in goodDaysAgo) _gut(d, value: 1),
  ];
  return InsightSource(
    meals: [
      for (final d in hardDaysAgo.take(4))
        InsightMeal(
          trackedAt: _noon(d).subtract(const Duration(hours: 3)),
          ingredients: const ['Zwiebel'],
        ),
      for (final d in goodDaysAgo)
        InsightMeal(
          trackedAt: _noon(d).subtract(const Duration(hours: 3)),
          ingredients: const ['Reis'],
        ),
    ],
    gutFeelings: gutFeelings,
    activityInstants: [for (final g in gutFeelings) g.trackedAt],
  );
}

Future<void> _openCard(WidgetTester tester) async {
  final card = find.byKey(InsightCard.cardKey);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The notification opt-in modal would cover the card.
  setUp(setNotificationModalShown);

  testWidgets('locked: the card opens the Muster page and back', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(entryRepo: FakeEntryRepository()));
    await tester.pumpAndSettle();

    expect(find.text(InsightCopy.learningTitle.toUpperCase()), findsOneWidget);

    await _openCard(tester);
    expect(find.text(PatternsScreen.title), findsWidgets);
    expect(find.text(PatternsLocked.title), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(PatternsLocked.title), findsNothing);
    expect(find.byKey(TutorialKeys.insight), findsOneWidget);
  });

  testWidgets('unlocked: the card names Zwiebel and the page shows why', (
    tester,
  ) async {
    final entryRepo = FakeEntryRepository()..insightSource = _unlockedSource();
    await tester.pumpWidget(buildTestApp(entryRepo: entryRepo));
    await tester.pumpAndSettle();

    expect(find.text(InsightCopy.noticedTitle.toUpperCase()), findsOneWidget);
    expect(
      find.text('Zwiebel war an 4 von 5 schweren Tagen dabei.'),
      findsOneWidget,
    );

    await _openCard(tester);
    expect(find.text(InsightCopy.columnsTitle.toUpperCase()), findsOneWidget);
    expect(find.text(InsightCopy.calendarHeader(11)), findsOneWidget);
    expect(find.text('6 gute Tage'), findsOneWidget);
    expect(find.text('5 schwere Tage'), findsOneWidget);
    expect(find.textContaining('Zwiebel'), findsWidgets);

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text(PatternsScreen.errorText), findsNothing);
    expect(find.text('5 schwere Tage'), findsOneWidget);
  });
}
