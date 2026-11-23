// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_onboarding_gate_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/buddy/buddy_onboarding_screen.dart';
import 'package:belly_buddy/screens/health_consent/health_consent_screen.dart';
import 'package:belly_buddy/screens/recipes/recipe_editor_screen.dart';
import 'package:belly_buddy/screens/trackers/drink/drink_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/screens/registration/steps/buddy_name_step.dart';
import 'package:belly_buddy/screens/upgrade/upgrade_required_screen.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

/// Pared-down app root: owns the upgrade decision like [BellyBuddyApp] and
/// loads the profile on start when signed in, without the splash overlay.
class _GateTestHost extends ConsumerStatefulWidget {
  const _GateTestHost();

  @override
  ConsumerState<_GateTestHost> createState() => _GateTestHostState();
}

class _GateTestHostState extends ConsumerState<_GateTestHost> {
  @override
  void initState() {
    super.initState();
    if (ref.read(isAuthenticatedProvider)) {
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    listenForUpgradeDecision(ref);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE')],
      locale: const Locale('de', 'DE'),
    );
  }
}

const _introLine = 'Hi! Ich bin neu hier — dein Belly Buddy.';
const _streakTitle = 'Wie viele Tage schaffen wir zusammen?';
const _reminderTitle = 'Darf ich mich melden, wenn ich Hunger hab?';
const _noStreakLine = 'Mit deinem nächsten Eintrag startet unser Streak!';
const _welcomeModalTitle = 'Willkommen bei Belly Buddy!';
const _optInTitle = 'Bleib auf dem Laufenden!';
const _tourSkip = 'Überspringen';

final _completedAt = DateTime(2026, 11, 1);

List<Override> _overrides({
  required FakeProfileRepository profiles,
  required FakeBuddyRepository buddies,
  UpgradeDecision decision = UpgradeDecision.ok,
}) => [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(profiles),
  buddyRepositoryProvider.overrideWithValue(buddies),
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  drinkRepositoryProvider.overrideWithValue(FakeDrinkRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  userRecipeRepositoryProvider.overrideWithValue(FakeUserRecipeRepository()),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  notificationRepositoryProvider.overrideWithValue(
    FakeNotificationRepository(),
  ),
  upgradeDecisionProvider.overrideWith((_) => Future.value(decision)),
];

String _currentPath(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

/// The locations of the whole route stack, bottom to top.
List<String> _matchedLocations(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .matches
    .map((m) => m.matchedLocation)
    .toList();

/// The topmost route's location, including routes pushed on top (the
/// configuration's uri stays at the base location for those).
String _topPath(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .last
    .matchedLocation;

FakeProfileRepository _profilesWith(UserProfile profile) =>
    FakeProfileRepository()..seedProfile(profile);

/// Reduced motion: the onboarding's step changes and the Buddy's bubble
/// show at once, so `pumpAndSettle` settles quickly on every step.
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required FakeProfileRepository profiles,
  required FakeBuddyRepository buddies,
  UpgradeDecision decision = UpgradeDecision.ok,
  Size screen = const Size(400, 860),
}) async {
  tester.view
    ..physicalSize = screen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _reduceMotion(tester);

  final container = ProviderContainer.test(
    overrides: _overrides(
      profiles: profiles,
      buddies: buddies,
      decision: decision,
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const _GateTestHost(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The Buddy's bubble. (Buddies don't tick here and the bubble only
/// rebuilds on a tick, so read it from the controller.)
String? _bubble(WidgetTester tester) =>
    tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).controller.bubble;

void main() {
  setUp(() {
    // Keep the dashboard's notification opt-in dialog out of the way unless
    // a test is about it.
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  group('Buddy onboarding gate', () {
    testWidgets('an existing user without a Buddy lands on the onboarding, '
        'cannot leave it, and lands on the dashboard after the last step', (
      tester,
    ) async {
      final buddies = FakeBuddyRepository();
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile()),
        buddies: buddies,
      );

      expect(container.read(buddyOnboardingRequiredProvider), isTrue);
      expect(_currentPath(container), RoutePaths.buddyOnboarding);
      expect(find.byType(BuddyOnboardingScreen), findsOneWidget);
      expect(find.text(_introLine), findsOneWidget);

      final router = container.read(routerProvider);
      for (final route in [
        RoutePaths.dashboard,
        RoutePaths.diary,
        RoutePaths.welcome,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(_currentPath(container), RoutePaths.buddyOnboarding);
      }

      await _tap(tester, find.byKey(BuddyOnboardingScreen.introNextKey));
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await _tap(tester, find.byKey(BuddyOnboardingScreen.nameNextKey));
      // His cheer first; then the streak moment (no entries yet).
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_bubble(tester), _noStreakLine);
      await _tap(tester, find.byKey(BuddyOnboardingScreen.momentNextKey));
      expect(_bubble(tester), _streakTitle);
      await _tap(tester, find.text('7 Tage'));
      expect(_bubble(tester), _reminderTitle);

      // Not completed before the last answer.
      expect(buddies.store[testUserId]?.onboardingCompletedAt, isNull);
      expect(_currentPath(container), RoutePaths.buddyOnboarding);

      await _tap(tester, find.byKey(BuddyOnboardingScreen.reminderLaterKey));
      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.byType(BuddyOnboardingScreen), findsNothing);
      expect(buddies.store[testUserId]?.onboardingCompletedAt, isNotNull);
      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
      expect(buddies.store[testUserId]?.name, 'Bauchi');
      // No start gift: savers are only earned at streak milestones.
      expect(buddies.store[testUserId]?.savers, 0);

      router.go(RoutePaths.diary);
      await tester.pumpAndSettle();
      expect(_currentPath(container), RoutePaths.diary);
    });

    testWidgets('killed mid-onboarding: a named Buddy resumes at the streak '
        'moment and completes once, without a saver', (tester) async {
      final buddies = FakeBuddyRepository()
        ..store[testUserId] = const BuddyState(
          userId: testUserId,
          name: 'Bauchi',
          streakGoal: 7,
        );
      final profiles = _profilesWith(testUserProfile(pushEnabled: true));
      final container = await _pumpHost(
        tester,
        profiles: profiles,
        buddies: buddies,
      );

      expect(_currentPath(container), RoutePaths.buddyOnboarding);
      expect(find.text(_introLine), findsNothing);
      expect(find.byKey(BuddyNameStep.titleKey), findsNothing);
      expect(_bubble(tester), _noStreakLine);
      await _tap(tester, find.byKey(BuddyOnboardingScreen.momentNextKey));

      // Push is on: the goal is the last step.
      await _tap(tester, find.text('14 Tage'));

      expect(_currentPath(container), RoutePaths.dashboard);
      final stored = buddies.store[testUserId]!;
      expect(stored.name, 'Bauchi');
      expect(stored.streakGoal, 14);
      expect(stored.savers, 0);
      expect(stored.onboardingCompletedAt, isNotNull);

      // The next app start passes the gate and grants nothing more.
      await tester.pumpWidget(const SizedBox.shrink());
      final restarted = await _pumpHost(
        tester,
        profiles: profiles,
        buddies: buddies,
      );
      expect(_currentPath(restarted), RoutePaths.dashboard);
      expect(find.byType(BuddyOnboardingScreen), findsNothing);
      expect(buddies.store[testUserId]!.savers, 0);
    });

    testWidgets('while onboarding, the meal and drink trackers stay '
        'reachable', (tester) async {
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile()),
        buddies: FakeBuddyRepository(),
        // The trackers' date chips need more width than 400 px in the test
        // font.
        screen: const Size(1080, 2400),
      );
      expect(_currentPath(container), RoutePaths.buddyOnboarding);
      final router = container.read(routerProvider);

      for (final (tracker, screen) in [
        (RoutePaths.mealTracker, MealTrackerScreen),
        (RoutePaths.drinkTracker, DrinkTrackerScreen),
      ]) {
        unawaited(router.push<void>(tracker));
        await tester.pumpAndSettle();
        expect(_topPath(container), tracker);
        expect(find.byType(screen), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        expect(_topPath(container), RoutePaths.buddyOnboarding);
        expect(find.byType(BuddyOnboardingScreen), findsOneWidget);
      }

      // Whatever the tracker opens on top stays too (the recipe picker's
      // „new recipe"), with no second onboarding stacked anywhere.
      unawaited(router.push<void>(RoutePaths.mealTracker));
      await tester.pumpAndSettle();
      unawaited(router.push<void>(RoutePaths.recipeNew));
      await tester.pumpAndSettle();
      expect(_topPath(container), RoutePaths.recipeNew);
      expect(find.byType(RecipeEditorScreen), findsOneWidget);
      expect(_matchedLocations(container), [
        RoutePaths.buddyOnboarding,
        RoutePaths.mealTracker,
        RoutePaths.recipeNew,
      ]);
      expect(
        find.byType(BuddyOnboardingScreen, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a completed Buddy passes the gate', (tester) async {
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile()),
        buddies: FakeBuddyRepository()
          ..store[testUserId] = BuddyState(
            userId: testUserId,
            onboardingCompletedAt: _completedAt,
          ),
      );

      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.byType(BuddyOnboardingScreen), findsNothing);
    });

    testWidgets('a Buddy backend error never blocks the app', (tester) async {
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile()),
        buddies: FakeBuddyRepository()..throwOnFetch = true,
      );

      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.dashboard);

      container.read(routerProvider).go(RoutePaths.diary);
      await tester.pumpAndSettle();
      expect(_currentPath(container), RoutePaths.diary);
    });

    testWidgets('the consent gate comes first; accepting leads into the '
        'onboarding', (tester) async {
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile(hasHealthConsent: false)),
        buddies: FakeBuddyRepository(),
      );

      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.healthConsent);

      await _tap(tester, find.byKey(HealthConsentScreen.consentCheckboxKey));
      await _tap(tester, find.byKey(HealthConsentScreen.acceptButtonKey));

      expect(container.read(buddyOnboardingRequiredProvider), isTrue);
      expect(_currentPath(container), RoutePaths.buddyOnboarding);
      expect(find.byType(BuddyOnboardingScreen), findsOneWidget);
    });

    testWidgets('the upgrade hard gate wins over the Buddy gate', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile()),
        buddies: FakeBuddyRepository(),
        decision: UpgradeDecision.hardGate,
      );

      expect(container.read(buddyOnboardingRequiredProvider), isTrue);
      expect(_currentPath(container), RoutePaths.upgradeRequired);
      expect(find.byType(UpgradeRequiredScreen), findsOneWidget);
    });

    testWidgets('a first-run user gets the spotlight tour right after the '
        'onboarding, without the old welcome modal', (tester) async {
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(
          testUserProfile(alreadySeenTutorial: false, pushEnabled: true),
        ),
        buddies: FakeBuddyRepository(),
      );

      // Nothing of the dashboard's first run under the onboarding.
      expect(_currentPath(container), RoutePaths.buddyOnboarding);
      expect(find.text(_tourSkip), findsNothing);
      expect(find.text(_welcomeModalTitle), findsNothing);

      await _tap(tester, find.byKey(BuddyOnboardingScreen.introNextKey));
      await _tap(tester, find.byKey(BuddyOnboardingScreen.nameNextKey));
      await _tap(tester, find.byKey(BuddyOnboardingScreen.momentNextKey));
      await _tap(tester, find.text('7 Tage'));

      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.text(_tourSkip), findsOneWidget);
      expect(find.text(_welcomeModalTitle), findsNothing);
    });

    testWidgets('an existing user with push on never sees the opt-in dialog '
        'after the onboarding', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = await _pumpHost(
        tester,
        profiles: _profilesWith(testUserProfile(pushEnabled: true)),
        buddies: FakeBuddyRepository(),
      );
      expect(_currentPath(container), RoutePaths.buddyOnboarding);
      expect(find.text(_optInTitle), findsNothing);

      await _tap(tester, find.byKey(BuddyOnboardingScreen.introNextKey));
      await _tap(tester, find.byKey(BuddyOnboardingScreen.nameNextKey));
      await _tap(tester, find.byKey(BuddyOnboardingScreen.momentNextKey));
      // Push is on: no reminder step; the goal finishes.
      await _tap(tester, find.text('7 Tage'));
      expect(find.text(_reminderTitle), findsNothing);

      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.text(_optInTitle), findsNothing);
    });
  });
}
