import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_rewards_sheet.dart';

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
  late GoRouter router;

  setUp(() => opener = RecordingUrlOpener());

  /// Home with an „open" button that opens „Deine Belohnungen" over
  /// [rewards], the reward pages stubbed.
  Future<void> pumpRewards(
    WidgetTester tester,
    JourneyRewards rewards, {
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
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () =>
                    showJourneyRewardsSheet(c, openUrl: opener.call),
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          profileProviderSeededWith(testUserProfile(userId: _userId)),
          recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
          journeyRewardsSeededWith(rewards),
        ],
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String location() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  Finder row(int day) => find.byKey(JourneyRewardsSheet.rowKey(day));

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
    expect(find.byType(JourneyRewardsSheet), findsOneWidget);
    expect(location(), '/');
    semantics.dispose();
  });

  testWidgets('row 1 opens the recipe', (tester) async {
    await pumpRewards(tester, _day4);
    await tapRow(tester, 1);

    expect(find.byType(JourneyRewardsSheet), findsNothing);
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

    expect(find.byType(JourneyRewardsSheet), findsNothing);
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

  testWidgets('row 4 has no tap', (tester) async {
    await pumpRewards(tester, _day4);
    await tapRow(tester, 4);

    expect(find.byType(JourneyRewardsSheet), findsOneWidget);
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
    expect(tester.getRect(row(7)).bottom, lessThanOrEqualTo(667));
  });
}
