// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
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
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides({
  FakeBuddyRepository? buddyRepo,
  FakeEntryRepository? entryRepo,
  UserProfile? profile,
}) => [
  profileRepositoryProvider.overrideWithValue(
    profile == null
        ? FakeProfileRepository()
        : (FakeProfileRepository()..seedProfile(profile)),
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

    testWidgets('mounts the Buddy tour target on the hero', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Home's only tour target now: the Buddy. The counters, „Für dich"
      // tiles, feedback and settings are gone from Home; Task 8 removes
      // their steps from the tour.
      expect(find.byKey(TutorialKeys.buddy), findsOneWidget);
      expect(tester.widget(find.byKey(TutorialKeys.buddy)), isA<BuddyHero>());
    });

    test('the tour starts with the Buddy step', () {
      expect(dashboardTutorialSteps, hasLength(11));
      expect(dashboardTutorialSteps.first.targetKey, TutorialKeys.buddy);
      final text = dashboardTutorialSteps.first.richText
          .map((s) => s.toPlainText())
          .join();
      expect(text, startsWith('Das ist dein Buddy'));
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
        find.byType(CustomScrollView),
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
}
