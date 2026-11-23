import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import 'package:belly_buddy/services/insights/insight_copy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/widget_tester_helpers.dart';
import 'helpers/test_app.dart';

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

    await tester.tapVisible(find.byKey(InsightCard.cardKey));
    expect(find.text(InsightCopy.patternsTitle), findsWidgets);
    expect(find.text(InsightCopy.lockedTitle), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(InsightCopy.lockedTitle), findsNothing);
    expect(find.byKey(TutorialKeys.insight), findsOneWidget);
  });

  testWidgets('unlocked: the card names Zwiebel and the page shows why', (
    tester,
  ) async {
    final entryRepo = FakeEntryRepository()
      ..insightSource = unlockedInsightSource();
    // With the weekly tips on, the Buddy has no offer to cover the card.
    await tester.pumpWidget(
      buildTestApp(entryRepo: entryRepo, weeklyTipsEnabled: true),
    );
    await tester.pumpAndSettle();

    expect(find.text(InsightCopy.noticedTitle.toUpperCase()), findsOneWidget);
    expect(
      find.text('Zwiebel war an 4 von 5 schweren Tagen dabei.'),
      findsOneWidget,
    );

    await tester.tapVisible(find.byKey(InsightCard.cardKey));
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
    expect(find.text(InsightCopy.loadError), findsNothing);
    expect(find.text('5 schwere Tage'), findsOneWidget);
  });
}
