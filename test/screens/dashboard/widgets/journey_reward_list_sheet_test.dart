import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/first_tip_provider.dart';
import 'package:belly_buddy/providers/journey_rewards_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/first_tip_offer_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_day_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_list_sheet.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/layout_checks.dart';
import '../../../helpers/riverpod_helpers.dart';

const _userId = 'u1';

const _bowl = RecipePick(id: 'r-1', title: 'Hirse-Bowl');
const _soup = RecipePick(id: 'r-3', title: 'Kürbissuppe');
const _rice = RecipePick(id: 'r-5', title: 'Karotten-Reis');

/// Day 4 earned, days 1 and 3 picked, day 3 a recipe after „Nein".
const _day4 = JourneyRewards(
  earnedDay: 4,
  picks: {1: _bowl, 3: _soup},
  tipOffer: TipOffer.declined,
);

void main() {
  late RecordingUrlOpener opener;
  late FakeFirstTipNotifier firstTip;
  late GoRouter router;

  setUp(() {
    opener = RecordingUrlOpener();
    firstTip = FakeFirstTipNotifier();
  });

  /// Home with an „open" button that opens „Deine Belohnungen" over
  /// [rewards], the reward pages stubbed; the weekly tips are [weeklyTips]
  /// (null: no profile yet).
  Future<ProviderContainer> pumpRewards(
    WidgetTester tester,
    JourneyRewards rewards, {
    bool? weeklyTips = false,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (c, ref, _) => TextButton(
                onPressed: () =>
                    showJourneyRewardListSheet(c, ref, openUrl: opener.call),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        ...stubRoutes([
          RoutePaths.collectionRecipe,
          RoutePaths.recommendations,
          RoutePaths.patterns,
          RoutePaths.discoverRecipes,
        ]),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue(_userId),
        profileProviderSeededWith(
          weeklyTips == null
              ? null
              : testUserProfile(userId: _userId, weeklyTipsEnabled: weeklyTips),
        ),
        recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        journeyRewardsSeededWith(rewards),
        firstTipProvider.overrideWith(() => firstTip),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  String location() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  Finder row(int day) => find.byKey(JourneyRewardListSheet.rowKey(day));

  Finder inRow(int day, Finder matching) =>
      find.descendant(of: row(day), matching: matching);

  /// Taps [day]'s row and lets the sheet close and the page open.
  Future<void> tapRow(WidgetTester tester, int day) async {
    await tester.tap(row(day));
    await tester.pumpAndSettle();
  }

  testWidgets('the list shows every earned day', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRewards(tester, _day4);

    expect(find.text('Deine Belohnungen'), findsOneWidget);
    for (var day = 1; day <= 7; day++) {
      expect(inRow(day, find.text('Tag $day')), findsOneWidget);
    }
    expect(inRow(1, find.text('Dein erstes Rezept')), findsOneWidget);
    expect(inRow(1, find.text('Hirse-Bowl')), findsOneWidget);
    expect(inRow(2, find.text('Ein Wissen-Häppchen')), findsOneWidget);
    expect(
      inRow(2, find.text('Low FODMAP kurz und knackig · myfodmap.at')),
      findsOneWidget,
    );
    expect(inRow(3, find.text('Ein Rezept für dich')), findsOneWidget);
    expect(inRow(3, find.text('Kürbissuppe')), findsOneWidget);
    expect(inRow(4, find.text('Ein Spruch von mir')), findsOneWidget);
    expect(
      inRow(4, find.text('Du machst das super. Ich bin gern dabei.')),
      findsOneWidget,
    );
    for (final day in [1, 2, 3]) {
      expect(inRow(day, find.byIcon(Icons.chevron_right)), findsOneWidget);
    }
    expect(inRow(4, find.byIcon(Icons.chevron_right)), findsNothing);
    for (final day in [1, 2, 3, 4]) {
      expect(inRow(day, find.byIcon(Icons.lock_outline)), findsNothing);
    }
    expect(
      tester.getSemantics(row(1)),
      isSemantics(
        label: 'Tag 1: Dein erstes Rezept, Hirse-Bowl',
        isButton: true,
        hasTapAction: true,
      ),
    );

    // Not earned yet: locked, no detail, no tap.
    for (final (day, title) in [
      (5, 'Noch ein Rezept für dich'),
      (6, 'Eine Vorschau auf deine Muster'),
      (7, 'Deine ersten Muster'),
    ]) {
      expect(inRow(day, find.text(title)), findsOneWidget);
      expect(inRow(day, find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(inRow(day, find.byIcon(Icons.chevron_right)), findsNothing);
      expect(
        tester.getSemantics(row(day)),
        isSemantics(
          label: 'Tag $day: $title, kommt noch',
          isButton: false,
          hasTapAction: false,
        ),
      );
    }
    await tester.tap(row(5));
    await tester.pumpAndSettle();
    expect(find.byType(JourneyRewardListSheet), findsOneWidget);
    expect(location(), '/');
    semantics.dispose();
  });

  testWidgets('row 1 opens the recipe', (tester) async {
    await pumpRewards(tester, _day4);
    await tapRow(tester, 1);

    expect(find.byType(JourneyRewardListSheet), findsNothing);
    expect(location(), '/collection/r-1');
  });

  testWidgets('row 1 without a pick says so and opens the recipes', (
    tester,
  ) async {
    await pumpRewards(tester, const JourneyRewards(earnedDay: 1));

    expect(
      inRow(
        1,
        find.text('Rezepte, die zu dir passen, findest du unter Entdecken.'),
      ),
      findsOneWidget,
    );
    await tapRow(tester, 1);

    expect(location(), RoutePaths.discoverRecipes);
  });

  testWidgets('row 2 opens the article in the in-app browser', (tester) async {
    await pumpRewards(tester, _day4);
    await tapRow(tester, 2);

    expect(find.byType(JourneyRewardListSheet), findsNothing);
    expect(opener.urls, [
      Uri.parse('https://www.myfodmap.at/low-fodmap-kurz-und-knackig'),
    ]);
    expect(opener.modes, [LaunchMode.inAppBrowserView]);
    expect(location(), '/');
  });

  testWidgets('row 2: a failed launch says so', (tester) async {
    opener.result = false;
    await pumpRewards(tester, _day4);
    await tapRow(tester, 2);

    expect(
      find.text('Der Artikel konnte nicht geöffnet werden.'),
      findsOneWidget,
    );
  });

  testWidgets('row 3 declined opens its recipe', (tester) async {
    await pumpRewards(tester, _day4);
    await tapRow(tester, 3);

    expect(location(), '/collection/r-3');
  });

  testWidgets('row 3 accepted opens the Tipps', (tester) async {
    await pumpRewards(tester, _day4.copyWith(tipOffer: TipOffer.accepted));

    expect(inRow(3, find.text('Dein erster Tipp')), findsOneWidget);
    expect(inRow(3, find.text('Zu deinen Tipps')), findsOneWidget);
    // The recipe stored meanwhile is not the reward.
    expect(find.text('Kürbissuppe'), findsNothing);
    await tapRow(tester, 3);

    expect(location(), RoutePaths.recommendations);
  });

  group('row 3 while the offer waits (weekly tips off)', () {
    final offered = _day4.copyWith(tipOffer: TipOffer.offered);

    /// The list over [offered], row 3 tapped: the list closes, the offer
    /// opens.
    Future<ProviderContainer> openOffer(WidgetTester tester) async {
      final container = await pumpRewards(tester, offered);
      expect(inRow(3, find.text('Dein erster Tipp')), findsOneWidget);
      expect(inRow(3, find.text('Wartet auf deine Antwort')), findsOneWidget);
      expect(inRow(3, find.byIcon(Icons.chevron_right)), findsOneWidget);
      // The recipe stored meanwhile is not the reward.
      expect(find.text('Kürbissuppe'), findsNothing);
      await tapRow(tester, 3);
      expect(find.byType(JourneyRewardListSheet), findsNothing);
      expect(find.byType(FirstTipOfferSheet), findsOneWidget);
      return container;
    }

    TipOffer? offerOf(ProviderContainer c) =>
        c.read(journeyRewardsProvider)?.tipOffer;

    testWidgets('yes → the first tip is requested, a SnackBar says so', (
      tester,
    ) async {
      await openOffer(tester);
      await tester.tap(find.byKey(FirstTipOfferSheet.yesKey));
      await tester.pumpAndSettle();

      expect(firstTip.accepts, 1);
      expect(
        find.text(
          'Ich mach dir jetzt deinen ersten Tipp. Das dauert einen Moment ✨',
        ),
        findsOneWidget,
      );
      expect(location(), '/');
    });

    testWidgets('yes with a failing opt-in → the switch\'s failure', (
      tester,
    ) async {
      firstTip.acceptResult = false;
      await openOffer(tester);
      await tester.tap(find.byKey(FirstTipOfferSheet.yesKey));
      await tester.pumpAndSettle();

      expect(firstTip.accepts, 1);
      expect(find.text(WeeklyTipsSwitch.failure), findsOneWidget);
    });

    testWidgets('no → declined, no request, the day-3 recipe sheet', (
      tester,
    ) async {
      final container = await openOffer(tester);
      await tester.tap(find.byKey(FirstTipOfferSheet.noKey));
      await tester.pumpAndSettle();

      expect(firstTip.accepts, 0);
      expect(offerOf(container), TipOffer.declined);
      expect(
        find.text('Alles klar! Dann hier ein Rezept für dich.'),
        findsOneWidget,
      );
      expect(find.text('Kürbissuppe'), findsOneWidget);

      await tester.tap(find.byKey(JourneyDaySheet.primaryKey));
      await tester.pumpAndSettle();
      expect(location(), '/collection/r-3');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no, then „Später" → declined, nothing opened', (tester) async {
      final container = await openOffer(tester);
      await tester.tap(find.byKey(FirstTipOfferSheet.noKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(JourneyDaySheet.laterKey));
      await tester.pumpAndSettle();

      expect(offerOf(container), TipOffer.declined);
      expect(location(), '/');
    });

    testWidgets('dismissed → nothing stored, no request: the Buddy still '
        'asks', (tester) async {
      final container = await openOffer(tester);
      await tester.tapAt(const Offset(10, 10)); // the modal barrier
      await tester.pumpAndSettle();

      expect(find.byType(FirstTipOfferSheet), findsNothing);
      expect(firstTip.accepts, 0);
      expect(offerOf(container), TipOffer.offered);
      expect(find.byType(JourneyDaySheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(location(), '/');
    });
  });

  testWidgets('row 3 while the weekly tips are unknown: waiting, no tap', (
    tester,
  ) async {
    await pumpRewards(
      tester,
      _day4.copyWith(tipOffer: TipOffer.offered),
      weeklyTips: null,
    );

    expect(inRow(3, find.text('Dein erster Tipp')), findsOneWidget);
    expect(inRow(3, find.text('Wartet auf deine Antwort')), findsOneWidget);
    expect(inRow(3, find.byIcon(Icons.chevron_right)), findsNothing);
    expect(find.text('Kürbissuppe'), findsNothing);
    await tapRow(tester, 3);

    expect(find.byType(JourneyRewardListSheet), findsOneWidget);
    expect(find.byType(FirstTipOfferSheet), findsNothing);
    expect(firstTip.accepts, 0);
  });

  testWidgets('row 4 has no tap', (tester) async {
    await pumpRewards(tester, _day4);
    await tapRow(tester, 4);

    expect(find.byType(JourneyRewardListSheet), findsOneWidget);
    expect(location(), '/');
    expect(opener.urls, isEmpty);
  });

  testWidgets('row 5 opens its recipe', (tester) async {
    await pumpRewards(
      tester,
      _day4.copyWith(earnedDay: 5, picks: const {1: _bowl, 3: _soup, 5: _rice}),
    );

    expect(inRow(5, find.text('Karotten-Reis')), findsOneWidget);
    await tapRow(tester, 5);

    expect(location(), '/collection/r-5');
  });

  testWidgets('row 6 opens Muster', (tester) async {
    await pumpRewards(tester, _day4.copyWith(earnedDay: 6));

    expect(inRow(6, find.text('Beispiel')), findsOneWidget);
    await tapRow(tester, 6);

    expect(location(), RoutePaths.patterns);
  });

  testWidgets('row 7 once the patterns are freed opens Muster', (tester) async {
    await pumpRewards(
      tester,
      _day4.copyWith(earnedDay: 7, patternsFreed: true),
    );

    expect(inRow(7, find.text('Muster ansehen')), findsOneWidget);
    await tester.ensureVisible(row(7));
    await tester.pumpAndSettle();
    await tapRow(tester, 7);

    expect(location(), RoutePaths.patterns);
  });

  testWidgets('fits 375×667 @1.3', (tester) async {
    final errors = await collectFlutterErrors(
      () => pumpRewards(
        tester,
        const JourneyRewards(
          earnedDay: 7,
          patternsFreed: true,
          picks: {1: _bowl, 3: _soup, 5: _rice},
          tipOffer: TipOffer.declined,
        ),
        size: const Size(375, 667),
        textScale: 1.3,
      ),
    );
    final more = await collectFlutterErrors(() async {
      await tester.ensureVisible(row(7));
      await tester.pumpAndSettle();
    });

    expect(verticalOverflows([...errors, ...more]), isEmpty);
    expect(
      [...errors, ...more].where((e) => !e.contains('overflowed')),
      isEmpty,
    );
    expect(tester.getRect(row(7)).bottom, lessThanOrEqualTo(667));
  });
}
