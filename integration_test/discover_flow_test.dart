import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tips_row.dart';
import 'package:belly_buddy/screens/dashboard/widgets/weekly_tips_offer_sheet.dart';
import 'package:belly_buddy/screens/discover/discover_screen.dart';
import 'package:belly_buddy/screens/discover/knowledge_screen.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_section.dart';
import 'package:belly_buddy/screens/discover/widgets/knowledge_article_tile.dart';
import 'package:belly_buddy/screens/me/me_screen.dart';
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';
import '../test/helpers/widget_tester_helpers.dart';
import 'helpers/test_app.dart';
import 'helpers/welcome_driver.dart' show pumpUntilFound;

/// The weekly-tips switch inside Entdecken's opt-in card.
Finder get _optInSwitch => find.descendant(
  of: find.byKey(DiscoverTipsSection.optInKey),
  matching: find.byType(WeeklyTipsSwitch),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Fresh prefs per flow (no Buddy announcement flags carried over), and the
  // notification opt-in modal, not under test here, marked as shown.
  setUp(setNotificationModalShown);

  testWidgets(
    'Wissen: Entdecken → „Alle ›" → a category, and back by the tab',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byKey(BbBottomNav.navDiscoverKey));

      // Entdecken previews the three newest articles.
      final articles = testKnowledgeArticles();
      final section = find.byKey(DiscoverScreen.knowledgeKey);
      expect(
        find.descendant(
          of: section,
          matching: find.byType(KnowledgeArticleTile),
        ),
        findsNWidgets(3),
      );
      for (final a in articles.take(3)) {
        expect(
          find.descendant(of: section, matching: find.text(a.title)),
          findsOneWidget,
        );
      }

      await tester.tapVisible(
        find.descendant(of: section, matching: find.text('Alle ›')),
      );
      expect(find.byType(KnowledgeScreen), findsOneWidget);
      for (final (category, label) in [
        (null, 'Alle'),
        ('Gesund verdauen', 'Gesund verdauen'),
        ('Rezepte', 'Rezepte'),
        ('Persönliches', 'Persönliches'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(KnowledgeScreen.chipKey(category)),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.byType(KnowledgeArticleTile), findsNWidgets(articles.length));

      await tester.tapVisible(find.byKey(KnowledgeScreen.chipKey('Rezepte')));
      final recipe = articles.singleWhere((a) => a.category == 'Rezepte');
      expect(find.byType(KnowledgeArticleTile), findsOneWidget);
      expect(find.byKey(KnowledgeArticleTile.keyFor(recipe)), findsOneWidget);

      // Wissen lives in the Entdecken tab: its tab leads back to Entdecken.
      await tester.tapVisible(find.byKey(BbBottomNav.navDiscoverKey));
      expect(find.byType(KnowledgeScreen), findsNothing);
      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(find.byType(BbBottomNav).hitTestable(), findsOneWidget);
    },
  );

  testWidgets('opt-in: the switch on Entdecken turns the weekly tips on, '
      'and Settings show it next to „Tipps per Push"', (tester) async {
    final profileRepo = FakeProfileRepository();
    await tester.pumpWidget(
      buildTestApp(
        profileRepo: profileRepo,
        recommendationRepo: FakeRecommendationRepository(sets: []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapVisible(find.byKey(BbBottomNav.navDiscoverKey));

    expect(_optInSwitch, findsOneWidget);
    expect(find.text(DiscoverTipsSection.emptyWhileOn), findsNothing);

    await tester.tapVisible(find.byKey(WeeklyTipsSwitch.switchKey));
    expect(profileRepo.weeklyTipsWrites, [true]);
    expect(find.text(DiscoverTipsSection.emptyWhileOn), findsOneWidget);
    expect(_optInSwitch, findsNothing);

    await tester.tapVisible(find.byKey(BbBottomNav.navMeKey));
    await tester.tapVisible(find.byKey(MeScreen.settingsKey));
    await tester.tapVisible(find.text('Benachrichtigungen'));

    final weekly = find.byKey(WeeklyTipsSwitch.switchKey);
    await tester.ensureVisible(weekly);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(weekly).value, isTrue);
    // The push is a switch of its own, still off.
    final push = find.widgetWithText(SwitchListTile, 'Tipps per Push');
    await tester.ensureVisible(push);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(push).value, isFalse);
  });

  testWidgets('new tips: Home\'s row and the Entdecken dot until the Tipps '
      'are opened', (tester) async {
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
      8,
    );
    final set = testRecommendation(seenAt: null, createdAt: thisMonday);
    await tester.pumpWidget(
      buildTestApp(
        recommendationRepo: FakeRecommendationRepository(sets: [set]),
        // No new Alternativen: the dot is the new tips' alone.
        ingredientRepo: FakeIngredientRepository(groups: []),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(TipsRow.rowKey);
    final dot = find.byKey(BbBottomNav.discoverBadgeKey);
    expect(row, findsOneWidget);
    expect(find.text(TipsRow.label(set)), findsOneWidget);
    expect(dot, findsOneWidget);

    await tester.tapVisible(row);
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    expect(find.text(set.summary!), findsOneWidget);

    await tester.tapVisible(
      find.descendant(
        of: find.byType(RecommendationsScreen),
        matching: find.byTooltip('Zurück'),
      ),
    );
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byKey(TipsRow.rowKey, skipOffstage: false), findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('offer: first patterns bring the weekly-tips offer; '
      '„Zu den Tipps" opens Entdecken with the switch', (tester) async {
    final entryRepo = FakeEntryRepository()
      ..insightSource = unlockedInsightSource();
    await tester.pumpWidget(buildTestApp(entryRepo: entryRepo));
    await tester.pumpAndSettle();

    // The Buddy waves first; the sheet follows on a timer.
    await pumpUntilFound(tester, find.byType(WeeklyTipsOfferSheet));
    await tester.pumpAndSettle();
    expect(find.text(WeeklyTipsOfferSheet.body), findsOneWidget);

    await tester.tapVisible(find.byKey(WeeklyTipsOfferSheet.openKey));
    expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(_optInSwitch.hitTestable(), findsOneWidget);
    // The offer only leads there: the weekly tips stay off until switched.
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(WeeklyTipsSwitch.switchKey))
          .value,
      isFalse,
    );
  });
}
