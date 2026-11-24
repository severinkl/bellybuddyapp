import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/home_cover_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_actions.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/app_lifecycle.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

/// [HomeCoverNotifier] that records each page Home was left for (null: a
/// tab).
class _RecordingCover extends HomeCoverNotifier {
  final left = <Future<void>?>[];

  @override
  void leftHome(Future<void>? page) {
    left.add(page);
    super.leftHome(page);
  }
}

void main() {
  late RecordingUrlOpener opener;
  late GoRouter router;

  /// Home's cover, recording what Home was left for.
  late _RecordingCover cover;

  setUp(() {
    opener = RecordingUrlOpener();
    cover = _RecordingCover();
  });

  /// Home with an „open" button that opens [day]'s reward over [rewards],
  /// the reward pages stubbed.
  Future<void> pumpOpen(
    WidgetTester tester,
    int day,
    JourneyRewards rewards,
  ) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (c, ref, _) => TextButton(
                onPressed: () => unawaited(
                  openJourneyReward(c, ref, day, openUrl: opener.call),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        ...stubRoutes([
          RoutePaths.collectionRecipe,
          RoutePaths.patterns,
          RoutePaths.discoverRecipes,
        ]),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          profileProviderSeededWith(testUserProfile(userId: 'u1')),
          journeyRewardsSeededWith(rewards),
          homeCoveredProvider.overrideWith(() => cover),
        ],
        child: germanRouterApp(router),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String location() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  group('openJourneyReward: Home left', () {
    testWidgets('a recipe page: left with the page, which completes once '
        'it is closed', (tester) async {
      await pumpOpen(
        tester,
        1,
        const JourneyRewards(
          earnedDay: 1,
          picks: {1: RecipePick(id: 'r1', title: 'Apfel-Reis')},
        ),
      );
      expect(location(), RoutePaths.collectionRecipeFor('r1'));
      expect(cover.left, hasLength(1));
      var closed = false;
      unawaited(cover.left.single!.whenComplete(() => closed = true));

      router.pop();
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('Muster (day 6): left with the page', (tester) async {
      await pumpOpen(tester, 6, const JourneyRewards(earnedDay: 6));

      expect(location(), RoutePaths.patterns);
      expect(cover.left.single, isNotNull);
    });

    testWidgets('no pick: the recipes, left for a tab', (tester) async {
      await pumpOpen(tester, 1, const JourneyRewards(earnedDay: 1));

      expect(location(), RoutePaths.discoverRecipes);
      expect(cover.left, [null]);
    });

    for (final (name, back) in [
      // iOS: the in-app browser closed, the app never left resumed.
      ('a touch', (WidgetTester t) => t.tapAt(const Offset(790, 590))),
      // Android's Custom Tabs, or iOS once the app went to the background.
      ('a resume', (WidgetTester t) async => returnFromBackground()),
    ]) {
      testWidgets('day 2: the article covers Home until the user is back '
          '($name)', (tester) async {
        await pumpOpen(tester, 2, const JourneyRewards(earnedDay: 2));
        final container = ProviderScope.containerOf(
          tester.element(find.text('open')),
        );

        expect(opener.urls, hasLength(1));
        expect(location(), '/');
        expect(cover.left, hasLength(1));
        await tester.pump(const Duration(minutes: 5));
        expect(container.read(homeCoveredProvider), isTrue);

        await back(tester);
        await tester.pump();

        expect(container.read(homeCoveredProvider), isFalse);
      });
    }

    testWidgets('day 2, the launch failed: the SnackBar, Home not covered', (
      tester,
    ) async {
      opener.result = false;
      await pumpOpen(tester, 2, const JourneyRewards(earnedDay: 2));

      expect(opener.urls, hasLength(1));
      expect(find.text(JourneyCopy.articleFailure), findsOneWidget);
      expect(cover.left, isEmpty);
      expect(
        ProviderScope.containerOf(
          tester.element(find.text('open')),
        ).read(homeCoveredProvider),
        isFalse,
      );
    });

    testWidgets('day 4: nothing opened, Home never left', (tester) async {
      await pumpOpen(tester, 4, const JourneyRewards(earnedDay: 4));

      expect(location(), '/');
      expect(cover.left, isEmpty);
    });
  });
}
