// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_step.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_offers_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/buddy_welcome_provider.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tips_row.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

/// The app's clock in the insight-card tests, pinned: their entries
/// ([insightSourceFor]) lie before it, in the insights' window on any date.
final _insightsNow = DateTime(2026, 11, 23, 14);

/// The signed-in user's id, switchable (sign-in as another user).
final _user = SwitchableUserId();

List<Override> _overrides({
  FakeBuddyRepository? buddyRepo,
  FakeEntryRepository? entryRepo,
  FakeProfileRepository? profileRepo,
  FakeRecommendationRepository? recommendationRepo,
  UserProfile? profile,
  bool switchableUser = false,
}) => [
  recommendationRepositoryProvider.overrideWithValue(
    recommendationRepo ?? FakeRecommendationRepository(),
  ),
  profileRepositoryProvider.overrideWithValue(
    profileRepo ??
        (profile == null
            ? FakeProfileRepository()
            : (FakeProfileRepository()..seedProfile(profile))),
  ),
  entryRepositoryProvider.overrideWithValue(entryRepo ?? FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  buddyRepositoryProvider.overrideWithValue(buddyRepo ?? FakeBuddyRepository()),
  if (switchableUser)
    _user.override
  else
    currentUserIdProvider.overrideWithValue(testUserId),
  isAuthenticatedProvider.overrideWithValue(true),
];

/// A Buddy whose onboarding is done, so the onboarding gate stays off.
FakeBuddyRepository _onboardedBuddy() => FakeBuddyRepository()
  ..store[testUserId] = BuddyState(
    userId: testUserId,
    onboardingCompletedAt: DateTime(2026, 11, 1),
  );

/// Lets the dashboard load and run its first-run prompts.
Future<void> _settleFirstRun(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Home and a stand-in Ich as tabs of an indexed-stack shell, as in the
/// app: a tab is built on its first visit and kept from then on.
Future<(ProviderContainer, GoRouter)> _pumpTabs(
  WidgetTester tester, {
  required FakeProfileRepository profileRepo,
  required String initialLocation,
  FakeEntryRepository? entryRepo,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => shell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.dashboard,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.me,
                builder: (_, _) => const Scaffold(body: Text('Ich')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer.test(
    overrides: _overrides(
      profileRepo: profileRepo,
      buddyRepo: _onboardedBuddy(),
      entryRepo: entryRepo,
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: germanRouterApp(router),
    ),
  );
  await tester.pumpAndSettle();
  return (container, router);
}

Future<void> _go(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pumpAndSettle();
}

/// A step's copy with its bold parts in `**`.
/// The level the ring's meter of [need] shows (null for Klo).
double? _meter(WidgetTester tester, CareNeed need) => tester
    .widget<NeedMeter>(
      find.descendant(
        of: find.byKey(CareRing.needKey(need)),
        matching: find.byType(NeedMeter),
      ),
    )
    .level;

String _markedCopy(TutorialStep step) => step.richText.map((span) {
  final text = span.toPlainText();
  final bold = (span as TextSpan).style?.fontWeight == FontWeight.w700;
  return bold ? '**$text**' : text;
}).join();

const _tourSkip = 'Überspringen';
const _welcomeModalTitle = 'Willkommen bei Belly Buddy!';
const _optInTitle = 'Bleib auf dem Laufenden!';

/// Home in the app: the real router and shell under [AppTestHost], whose
/// root keeps the tips loaded (its sign-in load brings [tips]'s sets).
Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  FakeRecommendationRepository? tips,
}) async {
  final container = ProviderContainer.test(
    overrides: baseOverrides(tips: tips),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AppTestHost()),
  );
  await _settleFirstRun(tester);
  return container;
}

/// A tip set that nobody opened yet.
FakeRecommendationRepository _unseenTips() => FakeRecommendationRepository(
  sets: [testRecommendation(createdAt: DateTime(2026, 11, 16))],
);

void main() {
  // No opt-in dialog over Home and no Buddy announcement flags set; a test
  // that needs other prefs sets its own.
  setUp(
    () => SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    }),
  );

  group('DashboardScreen Neue Tipps row', () {
    testWidgets('an unseen tip set shows the row under the insight card', (
      tester,
    ) async {
      await _pumpHome(tester, tips: _unseenTips());

      expect(find.byKey(TipsRow.rowKey), findsOneWidget);
      expect(find.text('✨ Neue Tipps · Woche 47'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(TipsRow.rowKey)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(InsightCard.cardKey)).bottom,
        ),
      );
    });

    testWidgets('tapping it opens the Tipps', (tester) async {
      // Tall and wide: the row clear of the bar, the Tipps laid out for the
      // width of a real font.
      tester.view
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = await _pumpHome(tester, tips: _unseenTips());

      await tester.tap(find.byKey(TipsRow.rowKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        RoutePaths.recommendations,
      );
      expect(find.byType(RecommendationsScreen), findsOneWidget);
    });

    testWidgets('no row when every set is seen', (tester) async {
      await _pumpHome(tester);

      expect(find.byKey(TipsRow.rowKey, skipOffstage: false), findsNothing);
    });

    testWidgets('pull-to-refresh brings tips that came since', (tester) async {
      final repo = FakeRecommendationRepository();
      await _pumpHome(tester, tips: repo);
      expect(find.byKey(TipsRow.rowKey, skipOffstage: false), findsNothing);

      repo.sets = [testRecommendation(createdAt: DateTime(2026, 11, 16))];
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      await _settleFirstRun(tester);

      expect(find.byKey(TipsRow.rowKey), findsOneWidget);
    });

    testWidgets('fits 375×667 at text scale 1.3 with the row', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpHome(tester, tips: _unseenTips());

      expect(find.byKey(TipsRow.rowKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DashboardScreen', () {
    testWidgets('renders the care ring with all four needs', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CareRing), findsOneWidget);
      for (final label in ['Essen', 'Trinken', 'Bauchgefühl', 'Klo']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('Home shows chip, ring, one button and the insight card, '
        'nothing else', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Für dich erstellt', skipOffstage: false), findsNothing);
      expect(find.text('Heute', skipOffstage: false), findsNothing);
      expect(find.byIcon(Icons.settings, skipOffstage: false), findsNothing);
      expect(
        find.byIcon(Icons.feedback_outlined, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(StreakWeekRow, skipOffstage: false), findsNothing);

      expect(find.byType(BuddyHero), findsOneWidget);
      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(find.byKey(BuddyHero.actionKey), findsOneWidget);
      expect(
        find.byKey(InsightCard.cardKey, skipOffstage: false),
        findsOneWidget,
      );
      // New user without a buddy_state row: the chip still shows the streak.
      expect(find.byType(StreakChip), findsOneWidget);

      // Top to bottom: the hero (chip, ring, button), then the card.
      final hero = tester.getRect(find.byType(BuddyHero));
      expect(
        tester.getRect(find.byType(StreakChip)).top,
        lessThan(tester.getRect(find.byType(CareRing)).top),
      );
      expect(
        tester.getRect(find.byKey(BuddyHero.actionKey)).top,
        greaterThan(tester.getRect(find.byType(CareRing)).bottom),
      );
      expect(
        tester.getRect(find.byKey(InsightCard.cardKey)).top,
        greaterThan(hero.bottom),
      );
    });

    testWidgets('the insight card shows the progress toward the first '
        'patterns', (tester) async {
      final entryRepo = FakeEntryRepository()
        ..insightSource = insightSourceFor(
          activeDays: 2,
          gutFeelings: 1,
          now: _insightsNow,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(entryRepo: entryRepo),
          buddyClockProvider.overrideWithValue(() => _insightsNow),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'Noch 5 Tage, dann zeig ich dir erste Muster.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      // Loaded once on mount: the dashboard's load joins the card's.
      expect(entryRepo.insightSourceCalls, 1);
    });

    testWidgets('pull-to-refresh fetches the insights again', (tester) async {
      final entryRepo = FakeEntryRepository()
        ..insightSource = insightSourceFor(
          activeDays: 2,
          gutFeelings: 1,
          now: _insightsNow,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(entryRepo: entryRepo),
          buddyClockProvider.overrideWithValue(() => _insightsNow),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      entryRepo.insightSource = insightSourceFor(
        activeDays: 3,
        gutFeelings: 1,
        now: _insightsNow,
      );

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(entryRepo.insightSourceCalls, 2);
      expect(
        find.text(
          'Noch 4 Tage, dann zeig ich dir erste Muster.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('deleting the 3rd gut-feeling entry locks the card again, '
        'without pull-to-refresh', (tester) async {
      final entryRepo = FakeEntryRepository()
        ..insightSource = insightSourceFor(
          activeDays: 7,
          gutFeelings: 3,
          now: _insightsNow,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(entryRepo: entryRepo),
          buddyClockProvider.overrideWithValue(() => _insightsNow),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Unlocked, no meals: nothing stands out yet.
      expect(
        find.text(
          'Noch fällt mir nichts Eindeutiges auf – trag weiter ein, dann '
          'sehe ich mehr.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );

      entryRepo.insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 2,
        now: _insightsNow,
      );
      await container
          .read(entriesProvider.notifier)
          .deleteByType('gutFeeling', 'gut-1');
      await tester.pump(const Duration(milliseconds: 100));

      expect(entryRepo.insightSourceCalls, 2);
      expect(
        find.text(
          'Noch 1 Bauchgefühl-Eintrag, dann zeig ich dir erste Muster.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('back in the foreground on a new day, the insights are '
        'computed again', (tester) async {
      var now = DateTime(2026, 11, 23, 23, 50);
      final entryRepo = FakeEntryRepository()
        ..insightSource = insightSourceFor(
          activeDays: 2,
          gutFeelings: 1,
          now: now,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(entryRepo: entryRepo),
          buddyClockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(entryRepo.insightSourceCalls, 1);

      // The same day: nothing.
      returnFromBackground();
      await tester.pump();
      expect(entryRepo.insightSourceCalls, 1);

      // The device slept past midnight; its timer stood still.
      now = DateTime(2026, 11, 24, 7);
      returnFromBackground();
      await tester.pump();
      expect(entryRepo.insightSourceCalls, 2);
      expect(entryRepo.insightSourceRequests.last.now, now);
    });

    testWidgets('after a user change the card never shows the previous '
        "user's numbers", (tester) async {
      final entryRepo = FakeEntryRepository()
        ..insightSource = insightSourceFor(
          activeDays: 2,
          gutFeelings: 1,
          now: _insightsNow,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(entryRepo: entryRepo, switchableUser: true),
          buddyClockProvider.overrideWithValue(() => _insightsNow),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text(
          'Noch 5 Tage, dann zeig ich dir erste Muster.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      final card = find.byKey(InsightCard.cardKey, skipOffstage: false);

      // The next user's insights load: no card meanwhile.
      entryRepo.holdInsightSource = true;
      _user.set(container, 'u2');
      await tester.pump();
      expect(entryRepo.insightSourceRequests.last.userId, 'u2');
      expect(card, findsNothing);

      // Their first load fails: still none of the previous user's numbers.
      entryRepo.heldInsightSources.single.completeError(Exception('offline'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(card, findsNothing);

      // Loaded later: their own numbers.
      entryRepo
        ..holdInsightSource = false
        ..insightSource = insightSourceFor(
          activeDays: 1,
          gutFeelings: 0,
          now: _insightsNow,
        );
      await container.read(insightsProvider.notifier).refresh();
      await tester.pump();
      expect(
        find.text(
          'Noch 6 Tage, dann zeig ich dir erste Muster.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('390×844 phone: a big Buddy, the ring and its button above '
        'the nav', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.getSize(find.byType(AnimatedBuddy)).height,
        greaterThanOrEqualTo(180),
      );
      // The bottom nav (64 + the 34 home-indicator inset) covers the rest.
      const navTop = 844.0 - 64 - 34;
      expect(
        tester
            .getRect(find.byKey(CareRing.needKey(CareNeed.gutFeeling)))
            .bottom,
        lessThanOrEqualTo(navTop),
      );
      expect(
        tester.getRect(find.byKey(CareRing.needKey(CareNeed.toilet))).bottom,
        lessThanOrEqualTo(navTop),
      );
      expect(
        tester.getRect(find.byKey(BuddyHero.actionKey)).bottom,
        lessThanOrEqualTo(navTop),
      );
    });

    testWidgets('mounts the tour targets on Home: Buddy, next action, insight '
        'card', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget(find.byKey(TutorialKeys.buddy)), isA<BuddyHero>());
      expect(
        find.descendant(
          of: find.byKey(TutorialKeys.nextAction),
          matching: find.byKey(BuddyHero.actionKey),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget(find.byKey(TutorialKeys.insight, skipOffstage: false)),
        isA<InsightCard>(),
      );
    });

    test('tour has 7 steps over the new keys', () {
      expect(dashboardTutorialSteps.map((s) => s.targetKey), [
        TutorialKeys.buddy,
        TutorialKeys.nextAction,
        TutorialKeys.plus,
        TutorialKeys.insight,
        TutorialKeys.tagebuch,
        TutorialKeys.entdecken,
        TutorialKeys.ich,
      ]);
      expect(dashboardTutorialSteps.map(_markedCopy), [
        'Das ist dein **Buddy**! Jeder Eintrag hält euren 🔥 **Streak** am '
            'Leben. Seine **Blasen** füllen sich, wenn du einträgst, und '
            'leeren sich langsam – tipp auf eine, um einzutragen.',
        'Dieser Knopf schlägt dir den **nächsten Eintrag** vor – passend zur '
            'Tageszeit.',
        'Hier trägst du **alles** ein: Essen, Trinken, Bauchgefühl und Klo.',
        'Sobald genug Einträge da sind, zeig ich dir hier, **was mir an '
            'deinem Bauch auffällt**.',
        'Im **Tagebuch** siehst du alle deine Einträge, Tag für Tag.',
        'Unter **Entdecken** findest du Tipps, Alternativen, deine Rezepte '
            'und Wissen rund um die Verdauung.',
        'Unter **Ich** kannst du mich umbenennen, dein Streak-Ziel ändern und '
            'alles einstellen.',
      ]);
      // The old tour's false or outdated claims are gone.
      for (final step in dashboardTutorialSteps) {
        final text = step.richText.map((s) => s.toPlainText()).join();
        for (final banned in ['Serie', 'Speisen', 'tracken', '1 x pro Tag']) {
          expect(text, isNot(contains(banned)), reason: text);
        }
      }
    });

    testWidgets('a failing Buddy never fails loading or pull-to-refresh', (
      tester,
    ) async {
      final buddyRepo = FakeBuddyRepository()..throwOnFetch = true;
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(buddyRepo: buddyRepo),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(find.byType(StreakChip), findsNothing);
      final fetchesAfterLoad = buddyRepo.fetchCount;

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(buddyRepo.fetchCount, greaterThan(fetchesAfterLoad));
      expect(find.byType(AnimatedBuddy), findsOneWidget);
    });

    testWidgets('loads the Buddy once on mount (no double fetch)', (
      tester,
    ) async {
      final buddyRepo = FakeBuddyRepository();
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(buddyRepo: buddyRepo),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(buddyRepo.fetchCount, 1);
    });
  });

  group('DashboardScreen taps on a phone', () {
    const trackers = {
      CareNeed.food: RoutePaths.mealTracker,
      CareNeed.drink: RoutePaths.drinkTracker,
      CareNeed.gutFeeling: RoutePaths.gutFeelingTracker,
      CareNeed.toilet: RoutePaths.toiletTracker,
    };

    /// Home at 14:00 (nothing logged: lunch is next) on a [size] phone
    /// with [padding], under a router with the Tagebuch and the trackers.
    Future<GoRouter> pumpPhone(
      WidgetTester tester,
      Size size,
      FakeViewPadding padding,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = padding;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: RoutePaths.dashboard,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (_, _) => const DashboardScreen(),
          ),
          ...stubRoutes([RoutePaths.diary, ...trackers.values]),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(
            profile: testUserProfile(),
            buddyRepo: _onboardedBuddy(),
          ),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 14),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: germanRouterApp(router),
        ),
      );
      await _settleFirstRun(tester);
      return router;
    }

    String location(GoRouter router) =>
        router.routerDelegate.currentConfiguration.last.matchedLocation;

    /// Taps at [at], expects [path] on top, then goes back Home.
    Future<void> tapOpens(
      WidgetTester tester,
      GoRouter router,
      Offset at,
      String path, {
      required String reason,
    }) async {
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(location(router), path, reason: reason);
      router.go(RoutePaths.dashboard);
      await tester.pumpAndSettle();
    }

    /// The circle of [need]'s meter.
    Rect meterCircle(WidgetTester tester, CareNeed need) => tester.getRect(
      find.descendant(
        of: find.byKey(CareRing.needKey(need)),
        matching: find.byType(NeedMeter),
      ),
    );

    for (final (name, size, padding) in [
      (
        '393×852',
        const Size(393, 852),
        const FakeViewPadding(top: 59, bottom: 34),
      ),
      ('375×667', const Size(375, 667), const FakeViewPadding(top: 20)),
    ]) {
      testWidgets('$name: a bubble opens its own tracker, on its meter and '
          'on its lower edge; the button opens the suggested one', (
        tester,
      ) async {
        final router = await pumpPhone(tester, size, padding);
        expect(find.text('🍝 Mittagessen eintragen'), findsOneWidget);

        for (final MapEntry(key: need, value: path) in trackers.entries) {
          await tapOpens(
            tester,
            router,
            meterCircle(tester, need).center,
            path,
            reason: '$need meter',
          );
          // Just above the bubble's bottom, under its last line.
          final bubble = tester.getRect(find.byKey(CareRing.needKey(need)));
          await tapOpens(
            tester,
            router,
            Offset(bubble.center.dx, bubble.bottom - 1),
            path,
            reason: '$need lower edge',
          );
        }

        await tapOpens(
          tester,
          router,
          tester.getCenter(find.byKey(BuddyHero.actionKey)),
          RoutePaths.mealTracker,
          reason: 'next-action button',
        );
      });
    }
  });

  group('DashboardScreen shows the signed-in user\'s day', () {
    final now = DateTime(2026, 11, 23, 14);
    EntryQueryResult lunchToday() => testEntryQueryResult(
      meals: [testMealEntry(trackedAt: DateTime(2026, 11, 23, 12))],
      toiletEntries: const [],
      gutFeelings: const [],
      drinks: const [],
    );

    /// A few frames, well under the hero's one-minute tick.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('after sign-up / onboarding: the ring shows the day as soon '
        'as it loads', (tester) async {
      final entryRepo = FakeEntryRepository()..seedResult(lunchToday());
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(
            profile: testUserProfile(),
            buddyRepo: _onboardedBuddy(),
            entryRepo: entryRepo,
          ),
          buddyClockProvider.overrideWithValue(() => now),
        ],
      );
      await settle(tester);

      // Lunch at 12:00, 2 h ago.
      expect(_meter(tester, CareNeed.food), closeTo(0.66, 0.005));
    });

    testWidgets('after signing out and in again: Home shows the new day '
        'without a tab switch', (tester) async {
      final entryRepo = FakeEntryRepository()
        ..seedResult(
          testEntryQueryResult(
            meals: const [],
            toiletEntries: const [],
            gutFeelings: const [],
            drinks: const [],
          ),
        );
      final router = GoRouter(
        initialLocation: RoutePaths.dashboard,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (_, _) => const DashboardScreen(),
          ),
          ...stubRoutes([RoutePaths.welcome]),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(
            profile: testUserProfile(),
            buddyRepo: _onboardedBuddy(),
            entryRepo: entryRepo,
          ),
          buddyClockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: germanRouterApp(router),
        ),
      );
      await settle(tester);
      expect(_meter(tester, CareNeed.food), AppConstants.careMeterFloor);

      // Twice: each round leaves the providers in another order.
      for (final (meal, level) in [
        (DateTime(2026, 11, 23, 12), 0.66),
        (DateTime(2026, 11, 23, 13), 0.83),
      ]) {
        // Sign-out: Home goes, the app drops the user's entries.
        router.go(RoutePaths.welcome);
        await settle(tester);
        container.invalidate(entriesProvider);
        // Sign-in: the account has a [meal] today; Home is built again.
        entryRepo.seedResult(
          testEntryQueryResult(
            meals: [testMealEntry(trackedAt: meal)],
            toiletEntries: const [],
            gutFeelings: const [],
            drinks: const [],
          ),
        );
        router.go(RoutePaths.dashboard);
        await settle(tester);

        expect(
          _meter(tester, CareNeed.food),
          closeTo(level, 0.005),
          reason: '$meal',
        );
      }
    });
  });

  group('DashboardScreen first run', () {
    testWidgets('a new user gets the spotlight tour directly, without a '
        'welcome modal', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(
          profile: testUserProfile(alreadySeenTutorial: false),
          buddyRepo: _onboardedBuddy(),
        ),
      );
      await _settleFirstRun(tester);

      expect(find.text(_tourSkip), findsOneWidget);
      expect(find.text(_welcomeModalTitle), findsNothing);
    });

    testWidgets('right after the Buddy onboarding he welcomes the user '
        'first; the tour follows once he has said it', (tester) async {
      final container = ProviderContainer.test(
        overrides: _overrides(
          profile: testUserProfile(alreadySeenTutorial: false),
          buddyRepo: _onboardedBuddy(),
        ),
      );
      // As the onboarding's last step does before it opens Home.
      container
          .read(buddyWelcomeProvider.notifier)
          .set(BuddyWelcomeNotifier.line);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.theme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await _settleFirstRun(tester);

      BuddyController buddy() =>
          tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).controller;
      expect(buddy().bubble, BuddyWelcomeNotifier.line);
      expect(find.text(_tourSkip), findsNothing);

      // His line has had its time: now the tour.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(_tourSkip), findsOneWidget);
    });

    testWidgets('the opt-in dialog asks while push is off', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(
          profile: testUserProfile(),
          buddyRepo: _onboardedBuddy(),
        ),
      );
      await _settleFirstRun(tester);

      expect(find.text(_optInTitle), findsOneWidget);
    });

    testWidgets('push on but the opt-in never offered on this device '
        '(reinstall): the dialog still asks', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(
          profile: testUserProfile(pushEnabled: true),
          buddyRepo: _onboardedBuddy(),
        ),
      );
      await _settleFirstRun(tester);

      expect(find.text(_optInTitle), findsOneWidget);
    });

    testWidgets('no tour and no opt-in dialog while the Buddy onboarding '
        'gate is about to take over', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(
          profile: testUserProfile(alreadySeenTutorial: false),
        ),
      );
      await _settleFirstRun(tester);

      expect(find.text(_tourSkip), findsNothing);
      expect(find.text(_welcomeModalTitle), findsNothing);
      expect(find.text(_optInTitle), findsNothing);
    });
  });

  group('DashboardScreen tour replay', () {
    testWidgets('replay from Ich starts the tour on Home once', (tester) async {
      final profileRepo = FakeProfileRepository()
        ..seedProfile(testUserProfile());
      final (container, router) = await _pumpTabs(
        tester,
        profileRepo: profileRepo,
        initialLocation: RoutePaths.me,
      );
      expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);

      // „Tutorial wiederholen": Home is built for the first time after it.
      container.read(tutorialProvider.notifier).requestReplay();
      await _go(tester, router, RoutePaths.dashboard);

      expect(find.text(_tourSkip), findsOneWidget);
      expect(container.read(tutorialProvider), isFalse);

      await tester.tap(find.text(_tourSkip));
      await tester.pumpAndSettle();
      expect(find.text(_tourSkip), findsNothing);
      expect(profileRepo.tutorialUpdateCalled, isTrue);

      // Back on Home later: the request was taken, no second tour.
      await _go(tester, router, RoutePaths.me);
      await _go(tester, router, RoutePaths.dashboard);
      expect(find.text(_tourSkip), findsNothing);
    });

    testWidgets('replay while Home is already built', (tester) async {
      final profileRepo = FakeProfileRepository()
        ..seedProfile(testUserProfile());
      final (container, router) = await _pumpTabs(
        tester,
        profileRepo: profileRepo,
        initialLocation: RoutePaths.dashboard,
      );
      // Seen before: Home opens without the tour.
      expect(find.text(_tourSkip), findsNothing);
      await _go(tester, router, RoutePaths.me);

      // As „Tutorial wiederholen" does: request, then go Home.
      container.read(tutorialProvider.notifier).requestReplay();
      await _go(tester, router, RoutePaths.dashboard);

      expect(find.text(_tourSkip), findsOneWidget);
      expect(container.read(tutorialProvider), isFalse);

      await tester.tap(find.text(_tourSkip));
      await tester.pumpAndSettle();
      expect(profileRepo.tutorialUpdateCalled, isTrue);

      await _go(tester, router, RoutePaths.me);
      await _go(tester, router, RoutePaths.dashboard);
      expect(find.text(_tourSkip), findsNothing);
    });

    testWidgets('replay works after Home\'s first load failed', (tester) async {
      final profileRepo = FakeProfileRepository()
        ..seedProfile(testUserProfile());
      // Offline: today's entries fail to load.
      final entryRepo = FakeEntryRepository()
        ..fetchForDateError = Exception('offline');
      final (container, router) = await _pumpTabs(
        tester,
        profileRepo: profileRepo,
        entryRepo: entryRepo,
        initialLocation: RoutePaths.dashboard,
      );
      await _go(tester, router, RoutePaths.me);

      container.read(tutorialProvider.notifier).requestReplay();
      await _go(tester, router, RoutePaths.dashboard);

      expect(find.text(_tourSkip), findsOneWidget);
      expect(container.read(tutorialProvider), isFalse);
    });
  });

  group('DashboardScreen Buddy offers', () {
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));

    testWidgets('an unseen tip set is offered to the Buddy', (tester) async {
      final container = await _pumpHome(tester, tips: _unseenTips());

      final status = container.read(buddyProvider).value!;
      expect(status.announcements, [BuddyAnnouncement.tipsArrived]);
      expect(
        status.announcementKeys[BuddyAnnouncement.tipsArrived],
        endsWith('_rec-1'),
      );
    });

    testWidgets('an offer made while the Buddy failed to load comes once he '
        'loads', (tester) async {
      final buddies = onboardedBuddyRepository()..throwOnFetch = true;
      final container = ProviderContainer.test(
        overrides: baseOverrides(tips: _unseenTips(), buddies: buddies),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AppTestHost(),
        ),
      );
      await _settleFirstRun(tester);
      expect(container.read(buddyOffersProvider), isNotEmpty);
      expect(container.read(buddyProvider).hasValue, isFalse);

      buddies.throwOnFetch = false;
      await container.read(buddyProvider.notifier).reload();
      await _settleFirstRun(tester);

      expect(container.read(buddyProvider).value!.announcements, [
        BuddyAnnouncement.tipsArrived,
      ]);
    });

    testWidgets('repeated offers queue it once', (tester) async {
      final entryRepo = FakeEntryRepository()
        ..insightSource = insightSourceFor(
          activeDays: 7,
          gutFeelings: 3,
          now: _insightsNow,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: [
          ..._overrides(entryRepo: entryRepo, profile: testUserProfile()),
          buddyClockProvider.overrideWithValue(() => _insightsNow),
        ],
      );
      await _settleFirstRun(tester);
      final container = containerOf(tester);
      expect(container.read(buddyProvider).value!.announcements, [
        BuddyAnnouncement.weeklyTipsOffer,
      ]);

      // The insights recompute after each write: unlocked, locked again,
      // unlocked again, so the offer comes once more.
      for (final gutFeelings in [3, 2, 3]) {
        entryRepo.insightSource = insightSourceFor(
          activeDays: 7,
          gutFeelings: gutFeelings,
          now: _insightsNow,
        );
        await container
            .read(entriesProvider.notifier)
            .deleteByType('gutFeeling', 'gut-1');
        await tester.pump(const Duration(milliseconds: 100));
        // Locked again (2 gut-feeling entries), the offer is withdrawn.
        expect(
          container.read(buddyOffersProvider),
          gutFeelings == 3
              ? {BuddyAnnouncement.weeklyTipsOffer: weeklyTipsOfferSuffix}
              : isEmpty,
          reason: '$gutFeelings gut-feeling entries',
        );
      }

      expect(entryRepo.insightSourceCalls, 4);
      expect(container.read(buddyProvider).value!.announcements, [
        BuddyAnnouncement.weeklyTipsOffer,
      ]);
    });
  });
}
