// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/first_tip_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_line.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_list_sheet.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

const _userId = 'u1';

/// The app's clock: the 23rd, after lunch.
final _now = DateTime(2026, 11, 23, 14);

/// Two journey days, the second today: day 2's dot is filled.
final _day2Today = lockedInsights(
  activeDays: 2,
  gutFeelings: 1,
  journey: [
    JourneyDay(DateTime(2026, 11, 22), gutFeeling: true),
    JourneyDay(DateTime(2026, 11, 23), gutFeeling: false),
  ],
);

/// Every dot filled, Bauchgefühl done: unlocked.
final _unlocked = Insights(
  progress: const InsightProgress(activeDays: 7, gutFeelingEntries: 3),
  calendar: const [],
  goodDays: const DayColumn(days: 0),
  hardDays: const DayColumn(days: 0),
  noticed: const [],
  pick: const NothingYetPick(),
  journey: [
    for (var i = 0; i < 7; i++)
      JourneyDay(DateTime(2026, 11, 17 + i), gutFeeling: i < 3),
  ],
);

final _line = find.byKey(JourneyRewardLineView.lineKey);

/// Day 2, earned today ([_day2Today]).
final _day2EarnedToday = JourneyRewards(
  earnedDay: 2,
  earnedOn: DateTime(2026, 11, 23),
);

void main() {
  /// The line alone on a page of a router with the reward pages stubbed,
  /// over [insights] and the [rewards] (null: the real rewards, e.g. none
  /// without the journey).
  Future<ProviderContainer> pumpLine(
    WidgetTester tester, {
    required Insights insights,
    JourneyRewards? rewards,
    bool? journey = true,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Padding(
              padding: AppConstants.paddingMd,
              child: JourneyRewardLineView(),
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
      overrides: <Override>[
        currentUserIdProvider.overrideWithValue(_userId),
        buddyClockProvider.overrideWithValue(() => _now),
        profileProviderSeededWith(
          testUserProfile(userId: _userId, weeklyTipsEnabled: false),
        ),
        recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        insightsProviderSeededWith(insights),
        journeySeededWith(journey),
        if (rewards != null) journeyRewardsSeededWith(rewards),
        firstTipProvider.overrideWith(() => FakeFirstTipNotifier()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('„Heute: Ein Wissen-Häppchen" → tap → „Deine Belohnungen"', (
    tester,
  ) async {
    await pumpLine(tester, insights: _day2Today, rewards: _day2EarnedToday);

    expect(_line, findsOneWidget);
    expect(
      find.descendant(
        of: _line,
        matching: find.text('Heute: Ein Wissen-Häppchen'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _line,
        matching: find.byIcon(Icons.card_giftcard_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _line, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );

    await tester.tap(_line);
    await tester.pumpAndSettle();

    expect(find.byType(JourneyRewardListSheet), findsOneWidget);
    expect(find.text(JourneyCopy.rewardsTitle), findsOneWidget);
  });

  testWidgets('a double tap opens „Deine Belohnungen" once', (tester) async {
    await pumpLine(tester, insights: _day2Today, rewards: _day2EarnedToday);

    await tester.tap(_line);
    await tester.tap(_line);
    await tester.pumpAndSettle();

    expect(find.byType(JourneyRewardListSheet), findsOneWidget);
  });

  testWidgets('no reward line without the journey', (tester) async {
    await pumpLine(tester, insights: _day2Today, journey: false);
    await tester.pump();

    expect(_line, findsNothing);
    expect(find.textContaining('Heute'), findsNothing);
  });

  testWidgets('nothing while unlocked', (tester) async {
    await pumpLine(
      tester,
      insights: _unlocked,
      rewards: const JourneyRewards(earnedDay: 7),
    );

    expect(_line, findsNothing);
    expect(find.textContaining('Heute'), findsNothing);
    expect(find.textContaining('Bald'), findsNothing);
  });

  testWidgets('semantics: one button with the text and the hint', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpLine(tester, insights: _day2Today, rewards: _day2EarnedToday);

    expect(
      tester.getSemantics(_line),
      isSemantics(
        label: 'Heute: Ein Wissen-Häppchen',
        hint: JourneyCopy.openRewards,
        isButton: true,
        hasTapAction: true,
      ),
    );
    // One node: the text isn't read a second time.
    expect(find.bySemanticsLabel('Heute: Ein Wissen-Häppchen'), findsOneWidget);

    tester.semantics.tap(find.semantics.byLabel('Heute: Ein Wissen-Häppchen'));
    await tester.pumpAndSettle();
    expect(find.byType(JourneyRewardListSheet), findsOneWidget);
    handle.dispose();
  });
}
