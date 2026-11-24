import 'dart:async';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/screens/dashboard/widgets/first_tip_offer_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_line.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_day_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_list_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tips_row.dart';
import 'package:belly_buddy/screens/patterns/patterns_screen.dart';
import 'package:belly_buddy/screens/patterns/patterns_unlocked_screen.dart';
import 'package:belly_buddy/screens/patterns/widgets/patterns_unlocked.dart';
import 'package:belly_buddy/screens/recipes/collection_recipe_screen.dart';
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_card.dart';
import 'package:belly_buddy/services/insights/insight_copy.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_actions.dart';
import 'package:belly_buddy/widgets/buddy/buddy_speech_bubble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';
import '../test/helpers/widget_tester_helpers.dart';
import 'helpers/test_app.dart';
import 'helpers/welcome_driver.dart' show pumpUntilFound;

const _reisBowl = 'Reis-Bowl';
const _hirseBowl = 'Hirse-Bowl';

const _letter =
    'Mir ist aufgefallen, dass oft Zwiebel dabei war. Lass uns diese Woche '
    'etwas Neues ausprobieren.';

/// The collection: both recipes fit a vegetarian with Fruktose. „Reis-Bowl"
/// is the newer one, so it ranks first: the day-1 recipe.
FakeRecipeRepository _collection() => FakeRecipeRepository()
  ..collection = [
    testRecipe(
      id: 'reis-bowl',
      title: _reisBowl,
      mealTypes: const [MealType.lunch],
      createdAt: DateTime.utc(2026, 11, 20),
      ingredients: [
        testLine('Reis', amount: '150 g'),
        testLine('Karotte', position: 1, amount: '1'),
      ],
    ),
    testRecipe(
      id: 'hirse-bowl',
      title: _hirseBowl,
      mealTypes: const [MealType.lunch],
      createdAt: DateTime.utc(2026, 11, 10),
      ingredients: [
        testLine('Hirse', amount: '80 g'),
        testLine('Frühlingszwiebelgrün', position: 1, amount: '1 EL'),
      ],
    ),
  ];

/// A vegetarian with Fruktose, the weekly tips as [weeklyTips].
FakeProfileRepository _profile({bool weeklyTips = false}) =>
    FakeProfileRepository()..seedProfile(
      testUserProfile(
        intolerances: const ['Fruktose'],
        diet: 'vegetarisch',
        weeklyTipsEnabled: weeklyTips,
      ),
    );

/// [activeDays] days with entries and [gutFeelings] Bauchgefühl entries,
/// all before today: today's dot is still empty.
FakeEntryRepository _entries({
  required int activeDays,
  required int gutFeelings,
}) => FakeEntryRepository()
  ..insightSource = insightSourceFor(
    activeDays: activeDays,
    gutFeelings: gutFeelings,
    now: DateTime.now(),
  );

/// The app over [_collection]; the Buddy is onboarded.
ProviderScope _app({
  required FakeEntryRepository entryRepo,
  FakeProfileRepository? profileRepo,
  FakeRecommendationRepository? recommendationRepo,
}) => buildTestApp(
  // This profile instead of the default one.
  seedProfile: false,
  seedBuddy: true,
  profileRepo: profileRepo ?? _profile(),
  entryRepo: entryRepo,
  recipeRepo: _collection(),
  recommendationRepo: recommendationRepo,
);

/// The set the first tip saves, unseen: a weekly letter whose focus, stored
/// second, is the Tausch-Tipp Zwiebel → Frühlingszwiebelgrün with
/// „Hirse-Bowl", after a Probier-Tipp.
Recommendation _firstTipSet() => testRecommendation(
  id: 'first-tip',
  summary: _letter,
  createdAt: DateTime.now().toUtc(),
  recommendations: [
    testRecommendationItem(
      type: 'try',
      ingredient: 'Haferflocken',
      alternative: null,
    ),
    testRecommendationItem(
      alternative: 'Frühlingszwiebelgrün',
      focus: true,
      recipeId: 'hirse-bowl',
      recipeTitle: _hirseBowl,
    ),
  ],
);

Finder _in(Type screen, Finder f) =>
    find.descendant(of: find.byType(screen), matching: f);

Finder _inRow(int day, Finder f) => find.descendant(
  of: find.byKey(JourneyRewardListSheet.rowKey(day)),
  matching: f,
);

/// The app bar's back arrow of [screen].
Future<void> _back(WidgetTester tester, Type screen) =>
    tester.tapVisible(_in(screen, find.byTooltip('Zurück')));

/// What the Buddy on Home says. Held still, he doesn't tick, and a new line
/// reaches his drawn bubble only on a tick: read from his controller.
String? _heroBubble(WidgetTester tester) => tester
    .widget<AnimatedBuddy>(
      find.descendant(
        of: find.byType(BuddyHero),
        matching: find.byType(AnimatedBuddy),
      ),
    )
    .controller
    .bubble;

/// Waits for [sheet], which the Buddy opens after his cue (a timer), and
/// lets it settle.
Future<void> _pumpUntilSheet(WidgetTester tester, Type sheet) async {
  await pumpUntilFound(tester, find.byType(sheet));
  await tester.pumpAndSettle();
}

/// Longer than any cue the Buddy plays before his sheet or page (the wave
/// before an offer, the celebration before a reward or „Muster frei!"),
/// with 2 s to spare on a loaded device: a sheet still missing after it
/// isn't coming.
final _cueBeforeSheet =
    [
      buddyActionDuration(BuddyAction.wave),
      buddyActionDuration(BuddyAction.celebrate),
    ].reduce((a, b) => a > b ? a : b) +
    const Duration(seconds: 2);

/// The card's reward line, scrolled into view, with [text].
Future<void> _expectRewardLine(WidgetTester tester, String text) async {
  final line = find.byKey(JourneyRewardLineView.lineKey);
  await tester.ensureVisible(line);
  await tester.pumpAndSettle();
  expect(find.descendant(of: line, matching: find.text(text)), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The notification opt-in modal, not under test here, marked as shown;
  // each flow starts a new journey, nothing earned or announced.
  setUp(() async {
    await setNotificationModalShown();
    await clearJourneyPrefs(testUserId);
  });

  testWidgets('day 1: the Buddy gives the first recipe, and the card names '
      "tomorrow's reward and opens „Deine Belohnungen\"", (tester) async {
    await tester.pumpWidget(
      _app(entryRepo: _entries(activeDays: 1, gutFeelings: 0)),
    );
    await tester.pumpAndSettle();

    // He celebrates first; the sheet follows on a timer.
    await _pumpUntilSheet(tester, JourneyDaySheet);
    expect(
      find.text('Willkommen an Tag 1! Hier ist dein erstes Rezept für dich.'),
      findsOneWidget,
    );
    expect(_in(JourneyDaySheet, find.text(_reisBowl)), findsOneWidget);
    expect(_in(JourneyDaySheet, find.text(_hirseBowl)), findsNothing);

    final open = find.byKey(JourneyDaySheet.primaryKey);
    expect(
      find.descendant(of: open, matching: find.text('Rezept ansehen')),
      findsOneWidget,
    );
    await tester.tapVisible(open);

    expect(find.byType(JourneyDaySheet), findsNothing);
    expect(find.byType(CollectionRecipeScreen), findsOneWidget);
    expect(_in(CollectionRecipeScreen, find.text(_reisBowl)), findsWidgets);

    await _back(tester, CollectionRecipeScreen);
    expect(find.byType(DashboardScreen), findsOneWidget);
    // Shown once: back on Home, no sheet again.
    expect(find.byType(JourneyDaySheet), findsNothing);

    await _expectRewardLine(tester, 'Heute wartet: Ein Wissen-Häppchen');
    await tester.tapVisible(find.byKey(JourneyRewardLineView.lineKey));

    expect(find.text(JourneyCopy.rewardsTitle), findsOneWidget);
    expect(_inRow(1, find.text('Dein erstes Rezept')), findsOneWidget);
    expect(_inRow(1, find.text(_reisBowl)), findsOneWidget);
    expect(_inRow(1, find.byIcon(Icons.chevron_right)), findsOneWidget);
    // Tag 2 not earned yet: locked, nothing to open.
    expect(_inRow(2, find.text('Ein Wissen-Häppchen')), findsOneWidget);
    expect(_inRow(2, find.byIcon(Icons.lock_outline)), findsOneWidget);
    expect(
      _inRow(2, find.textContaining(JourneyCopy.articleTitle)),
      findsNothing,
    );
  });

  testWidgets('day 3, „Ja, gern": the weekly tips on, the first tip on its '
      'way, then „Neue Tipps" with the letter, the focus and its recipe', (
    tester,
  ) async {
    final profileRepo = _profile();
    final request = Completer<void>();
    final tipsRepo = FakeRecommendationRepository()
      ..firstTipSet = _firstTipSet()
      ..firstTipGate = request
      // The weekly tips as stored on the server when a request arrives:
      // only a write that succeeded counts.
      ..optedIn = () => profileRepo.storedProfile?.weeklyTipsEnabled ?? false;
    await tester.pumpWidget(
      _app(
        entryRepo: _entries(activeDays: 3, gutFeelings: 1),
        profileRepo: profileRepo,
        recommendationRepo: tipsRepo,
      ),
    );
    await tester.pumpAndSettle();

    // He waves first; the offer follows on a timer.
    await _pumpUntilSheet(tester, FirstTipOfferSheet);
    // The bubble glues the closing ✨ to the word before it.
    expect(
      find.text(
        glueClosingSymbol(
          'Ich hab genug für deinen ersten Tipp! Soll ich ihn dir machen? ✨',
        ),
      ),
      findsOneWidget,
    );
    // Nothing is sent before the answer.
    expect(tipsRepo.firstTipRequests, isEmpty);

    await tester.tapVisible(find.byKey(FirstTipOfferSheet.yesKey));

    expect(find.byType(FirstTipOfferSheet), findsNothing);
    expect(profileRepo.weeklyTipsWrites, [true]);
    expect(_heroBubble(tester), JourneyCopy.firstTipStarted);
    // One request, made once the opt-in was stored, with the profile's
    // intolerances and diet; its answer is held until here.
    expect(tipsRepo.firstTipRequestOptIns, [true]);
    final [sent] = tipsRepo.firstTipRequests;
    expect(sent.intolerances, ['Fruktose']);
    expect(sent.diet, 'vegetarisch');
    expect(find.byKey(TipsRow.rowKey), findsNothing);

    request.complete();
    final row = find.byKey(TipsRow.rowKey);
    await pumpUntilFound(tester, row);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.textContaining('✨ Neue Tipps')),
      findsOneWidget,
    );
    expect(tipsRepo.firstTipRequests, hasLength(1));

    await tester.tapVisible(row);
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    // „Dein Wochenbrief", drawn in capitals.
    expect(find.text('DEIN WOCHENBRIEF'), findsOneWidget);
    expect(find.text(_letter), findsOneWidget);

    // The focus first: Zwiebel, with „Fokus der Woche" and its recipe.
    final focus = find.byType(RecommendationCard).first;
    expect(tester.widget<RecommendationCard>(focus).item.ingredient, 'Zwiebel');
    expect(
      find.descendant(of: focus, matching: find.text('Fokus der Woche')),
      findsOneWidget,
    );
    expect(find.text('Fokus der Woche'), findsOneWidget);
    final link = find.descendant(
      of: focus,
      matching: find.text('Passendes Rezept: $_hirseBowl'),
    );
    expect(link, findsOneWidget);

    await tester.tapVisible(link);
    expect(find.byType(CollectionRecipeScreen), findsOneWidget);
    expect(_in(CollectionRecipeScreen, find.text(_hirseBowl)), findsWidgets);
    expect(tipsRepo.firstTipRequests, hasLength(1));
  });

  testWidgets('day 3, „Nein, danke": a recipe instead; after a restart no '
      'offer, no request, the card names day 4 and „Deine Belohnungen" '
      "keeps day 3's recipe", (tester) async {
    final entryRepo = _entries(activeDays: 3, gutFeelings: 1);
    final profileRepo = _profile();
    final tipsRepo = FakeRecommendationRepository()
      ..firstTipSet = _firstTipSet();
    ProviderScope app() => _app(
      entryRepo: entryRepo,
      profileRepo: profileRepo,
      recommendationRepo: tipsRepo,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await _pumpUntilSheet(tester, FirstTipOfferSheet);
    await tester.tapVisible(find.byKey(FirstTipOfferSheet.noKey));

    expect(find.byType(FirstTipOfferSheet), findsNothing);
    expect(find.byType(JourneyDaySheet), findsOneWidget);
    expect(
      find.text('Alles klar! Dann hier ein Rezept für dich.'),
      findsOneWidget,
    );
    // Another recipe than day 1's.
    expect(_in(JourneyDaySheet, find.text(_hirseBowl)), findsOneWidget);

    final later = find.byKey(JourneyDaySheet.laterKey);
    expect(
      find.descendant(of: later, matching: find.text('Später')),
      findsOneWidget,
    );
    await tester.tapVisible(later);
    expect(find.byType(JourneyDaySheet), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(CollectionRecipeScreen), findsNothing);

    // A restart: a new app over the same preferences (and server).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump(_cueBeforeSheet);
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(FirstTipOfferSheet), findsNothing);
    expect(find.byType(JourneyDaySheet), findsNothing);
    await _expectRewardLine(tester, 'Heute wartet: Ein Spruch von mir');
    expect(tipsRepo.firstTipRequests, isEmpty);
    expect(profileRepo.weeklyTipsWrites, isEmpty);

    // Day 3's recipe is kept; day 4 is next, locked.
    await tester.tapVisible(find.byKey(JourneyRewardLineView.lineKey));
    expect(find.text(JourneyCopy.rewardsTitle), findsOneWidget);
    expect(_inRow(3, find.text('Ein Rezept für dich')), findsOneWidget);
    expect(_inRow(3, find.text(_hirseBowl)), findsOneWidget);
    expect(_inRow(4, find.text('Ein Spruch von mir')), findsOneWidget);
    expect(_inRow(4, find.byIcon(Icons.lock_outline)), findsOneWidget);
  });

  testWidgets('day 7 with the day-3 offer still open: „Muster frei!" → '
      '„Muster ansehen" → the Muster page, unlocked; back on Home the offer '
      'follows', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    // On the journey since before: with 7 days it wouldn't start now.
    await prefs.setBool(
      '${AppConstants.keyInsightJourneyPrefix}$testUserId',
      true,
    );
    final tipsRepo = FakeRecommendationRepository();
    // The weekly tips off and the day-3 offer never answered on this
    // device: both are due, the celebration first.
    await tester.pumpWidget(
      _app(
        entryRepo: _entries(activeDays: 7, gutFeelings: 3),
        recommendationRepo: tipsRepo,
      ),
    );
    await tester.pumpAndSettle();

    // He celebrates first; the page follows on a timer, before the offer.
    await pumpUntilFound(tester, find.byType(PatternsUnlockedScreen));
    await tester.pumpAndSettle();
    expect(find.text('Muster frei!'), findsOneWidget);
    expect(find.byType(FirstTipOfferSheet), findsNothing);

    final open = find.byKey(PatternsUnlockedScreen.openKey);
    expect(
      find.descendant(of: open, matching: find.text('Muster ansehen')),
      findsOneWidget,
    );
    await tester.tapVisible(open);

    expect(find.byType(PatternsUnlockedScreen), findsNothing);
    expect(find.byType(PatternsScreen), findsOneWidget);
    expect(find.byType(PatternsUnlocked), findsOneWidget);
    expect(find.text(InsightCopy.lockedTitle), findsNothing);
    // The offer waits while the Muster page covers Home.
    await tester.pump(_cueBeforeSheet);
    await tester.pumpAndSettle();
    expect(find.byType(FirstTipOfferSheet), findsNothing);

    await _back(tester, PatternsScreen);
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Back on Home: he waves, then asks.
    await _pumpUntilSheet(tester, FirstTipOfferSheet);
    expect(
      find.text(
        glueClosingSymbol(
          'Ich hab genug für deinen ersten Tipp! Soll ich ihn dir machen? ✨',
        ),
      ),
      findsOneWidget,
    );
    await tester.tapVisible(find.byKey(FirstTipOfferSheet.noKey));
    expect(
      find.text('Alles klar! Dann hier ein Rezept für dich.'),
      findsOneWidget,
    );
    await tester.tapVisible(find.byKey(JourneyDaySheet.laterKey));

    expect(find.byType(JourneyDaySheet), findsNothing);
    expect(find.byType(PatternsUnlockedScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(tipsRepo.firstTipRequests, isEmpty);
  });
}
