import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_actions.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

void main() {
  late RecordingUrlOpener opener;
  late GoRouter router;

  /// What `onLeave` heard: each page it left Home for (null: a tab).
  late List<Future<void>?> left;

  setUp(() {
    opener = RecordingUrlOpener();
    left = [];
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
                  openJourneyReward(
                    c,
                    ref,
                    day,
                    openUrl: opener.call,
                    onLeave: left.add,
                  ),
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
        ],
        child: germanRouterApp(router),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String location() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  group('openJourneyReward: onLeave', () {
    testWidgets('a recipe page: told with the page, which completes once '
        'it is closed', (tester) async {
      await pumpOpen(
        tester,
        1,
        const JourneyRewards(
          earnedDay: 1,
          picks: {1: RecipePick(id: 'r1', title: 'Apfel-Reis')},
        ),
      );
      expect(location(), '/collection/r1');
      expect(left, hasLength(1));
      var closed = false;
      unawaited(left.single!.whenComplete(() => closed = true));

      router.pop();
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('Muster (day 6): told with the page', (tester) async {
      await pumpOpen(tester, 6, const JourneyRewards(earnedDay: 6));

      expect(location(), RoutePaths.patterns);
      expect(left.single, isNotNull);
    });

    testWidgets('no pick: the recipes, told without a page', (tester) async {
      await pumpOpen(tester, 1, const JourneyRewards(earnedDay: 1));

      expect(location(), RoutePaths.discoverRecipes);
      expect(left, [null]);
    });

    testWidgets('day 2: the article over the app, Home never left', (
      tester,
    ) async {
      await pumpOpen(tester, 2, const JourneyRewards(earnedDay: 2));

      expect(opener.urls, hasLength(1));
      expect(left, isEmpty);
    });

    testWidgets('day 4: nothing opened, Home never left', (tester) async {
      await pumpOpen(tester, 4, const JourneyRewards(earnedDay: 4));

      expect(location(), '/');
      expect(left, isEmpty);
    });
  });
}
