// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides({FakeBuddyRepository? buddyRepo}) => [
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  buddyRepositoryProvider.overrideWithValue(buddyRepo ?? FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('DashboardScreen', () {
    testWidgets('renders feature card Tipps', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tipps'), findsOneWidget);
    });

    testWidgets('renders feature card Alternativen', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alternativen'), findsOneWidget);
    });

    testWidgets('renders feature card Rezepte', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rezepte'), findsOneWidget);
    });

    testWidgets('renders TrackerCards with Bauchgefühl and Klo', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bauchgefühl'), findsOneWidget);
      expect(find.text('Klo'), findsOneWidget);
    });

    testWidgets('renders Für dich erstellt section header', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Für dich erstellt'), findsOneWidget);
    });

    testWidgets('shows the Buddy hero with the header icons top-right', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BuddyHero), findsOneWidget);
      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(find.text('🍎 Füttern'), findsOneWidget);
      // New user without a buddy_state row: the chip still shows the streak.
      expect(find.byType(StreakChip), findsOneWidget);

      final hero = tester.getRect(find.byType(BuddyHero));
      final settings = tester.getRect(find.byKey(TutorialKeys.settings));
      final feedback = tester.getRect(find.byKey(TutorialKeys.feedback));
      expect(settings.top, hero.top);
      expect(settings.right, hero.right);
      expect(feedback.top, hero.top);
      expect(feedback.right, lessThan(settings.left));
      // The hero is the first content; the tracker cards follow below it.
      expect(
        tester.getRect(find.byKey(TutorialKeys.bauchgefuehl)).top,
        greaterThan(hero.bottom),
      );
    });

    testWidgets('390×844 phone: a big Buddy, tracker cards above the nav', (
      tester,
    ) async {
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
        greaterThanOrEqualTo(200),
      );
      // The bottom nav (64 + the 34 home-indicator inset) covers the rest.
      const navTop = 844.0 - 64 - 34;
      expect(
        tester.getRect(find.byKey(TutorialKeys.bauchgefuehl)).bottom,
        lessThanOrEqualTo(navTop),
      );
      expect(
        tester.getRect(find.byKey(TutorialKeys.klo)).bottom,
        lessThanOrEqualTo(navTop),
      );
    });

    testWidgets('mounts every dashboard tutorial target incl. the Buddy', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      for (final key in [
        TutorialKeys.buddy,
        TutorialKeys.bauchgefuehl,
        TutorialKeys.klo,
        TutorialKeys.fuerDich,
        TutorialKeys.alternativen,
        TutorialKeys.wissen,
        TutorialKeys.rezepte,
        TutorialKeys.feedback,
        TutorialKeys.settings,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
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
}
