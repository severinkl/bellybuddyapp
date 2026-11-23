// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_step.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides({
  FakeBuddyRepository? buddyRepo,
  FakeEntryRepository? entryRepo,
  FakeProfileRepository? profileRepo,
  UserProfile? profile,
}) => [
  profileRepositoryProvider.overrideWithValue(
    profileRepo ??
        (profile == null
            ? FakeProfileRepository()
            : (FakeProfileRepository()..seedProfile(profile))),
  ),
  entryRepositoryProvider.overrideWithValue(entryRepo ?? FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  buddyRepositoryProvider.overrideWithValue(buddyRepo ?? FakeBuddyRepository()),
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
String _markedCopy(TutorialStep step) => step.richText.map((span) {
  final text = span.toPlainText();
  final bold = (span as TextSpan).style?.fontWeight == FontWeight.w700;
  return bold ? '**$text**' : text;
}).join();

const _tourSkip = 'Überspringen';
const _welcomeModalTitle = 'Willkommen bei Belly Buddy!';
const _optInTitle = 'Bleib auf dem Laufenden!';

void main() {
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
        ..insightProgress = const InsightProgress(
          activeDays: 2,
          gutFeelingEntries: 1,
        );
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(entryRepo: entryRepo),
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
      expect(entryRepo.insightProgressFetches, hasLength(1));
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
            'Leben. Der **Ring** zeigt, was er heute schon bekommen hat – '
            'tipp auf eine Blase, um es einzutragen.',
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
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyNotificationModalShown: true,
      });
    });

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

    /// The bordered box [need]'s bubble draws (its shadow falls below it).
    Rect bubbleBox(WidgetTester tester, CareNeed need) => tester.getRect(
      find
          .descendant(
            of: find.byKey(CareRing.needKey(need)),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );

    for (final (name, size, padding) in [
      (
        '393×852',
        const Size(393, 852),
        const FakeViewPadding(top: 59, bottom: 34),
      ),
      ('375×667', const Size(375, 667), const FakeViewPadding(top: 20)),
    ]) {
      testWidgets('$name: a bubble opens its own tracker, at its centre and '
          'on its lower edge; the button opens the suggested one', (
        tester,
      ) async {
        final router = await pumpPhone(tester, size, padding);
        expect(find.text('🍝 Mittagessen eintragen'), findsOneWidget);

        for (final MapEntry(key: need, value: path) in trackers.entries) {
          final box = bubbleBox(tester, need);
          await tapOpens(
            tester,
            router,
            box.center,
            path,
            reason: '$need centre',
          );
          // On its shadow, just above the bubble's visual bottom.
          await tapOpens(
            tester,
            router,
            Offset(
              box.center.dx,
              box.bottom + AppConstants.careNeedShadowOffset.dy - 1,
            ),
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
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyNotificationModalShown: true,
      });
    });

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

      expect(find.text('🍽 1/3'), findsOneWidget);
      expect(find.text('🍽 0/3'), findsNothing);
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
      expect(find.text('🍽 0/3'), findsOneWidget);

      // Twice: each round leaves the providers in another order.
      for (final meals in [1, 2]) {
        // Sign-out: Home goes, the app drops the user's entries.
        router.go(RoutePaths.welcome);
        await settle(tester);
        container.invalidate(entriesProvider);
        // Sign-in: the account has [meals] meals today; Home is built again.
        entryRepo.seedResult(
          testEntryQueryResult(
            meals: [
              for (var h = 0; h < meals; h++)
                testMealEntry(trackedAt: DateTime(2026, 11, 23, 8 + h)),
            ],
            toiletEntries: const [],
            gutFeelings: const [],
            drinks: const [],
          ),
        );
        router.go(RoutePaths.dashboard);
        await settle(tester);

        expect(find.text('🍽 $meals/3'), findsOneWidget, reason: '$meals');
      }
    });
  });

  group('DashboardScreen first run', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyNotificationModalShown: true,
      });
    });

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
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyNotificationModalShown: true,
      });
    });

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
}
