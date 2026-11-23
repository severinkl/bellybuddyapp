// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/buddy_welcome_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/buddy/buddy_onboarding_screen.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:belly_buddy/screens/buddy/widgets/streak_moment.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

import '../../helpers/ambient_animations.dart';
import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';

typedef _Step = BuddyOnboardingStep;

/// Counts permission requests; grants them unless [grant] is false.
class _CountingNotifications extends FakeNotificationRepository {
  int permissionRequests = 0;
  bool grant = true;

  @override
  Future<bool> requestAllPermissions() async {
    permissionRequests++;
    return grant;
  }
}

/// The real Buddy notifier, counting [completeOnboarding] calls.
class _CountingBuddy extends BuddyNotifier {
  int completeCalls = 0;

  @override
  Future<void> completeOnboarding() {
    completeCalls++;
    return super.completeOnboarding();
  }
}

/// Stand-in for the meal tracker: „speichern" logs a meal like the real
/// tracker (Buddy event) and pops; „abbrechen" just pops.
class _FakeMealTracker extends ConsumerWidget {
  const _FakeMealTracker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () {
              ref
                  .read(buddyEventsProvider.notifier)
                  .emit(
                    BuddyLogEvent(
                      EntryKind.meal,
                      LogSentiment.good,
                      at: DateTime.now(),
                      trackedAt: DateTime.now(),
                    ),
                  );
              context.pop();
            },
            child: const Text('fake-save-meal'),
          ),
          TextButton(
            onPressed: () {
              final events = ref.read(buddyEventsProvider.notifier);
              events.emit(
                BuddyLogEvent(
                  EntryKind.meal,
                  LogSentiment.good,
                  at: DateTime.now(),
                  trackedAt: DateTime.now(),
                ),
              );
              // The success screen's „Trinken eintragen": the drink event
              // replaces the meal in the single event slot.
              events.emit(
                BuddyLogEvent(
                  EntryKind.drink,
                  LogSentiment.good,
                  at: DateTime.now(),
                  trackedAt: DateTime.now(),
                ),
              );
              context.pop();
            },
            child: const Text('fake-meal-then-drink'),
          ),
          TextButton(
            onPressed: () {
              // Saved now, but backdated to last night.
              final now = DateTime.now();
              ref
                  .read(buddyEventsProvider.notifier)
                  .emit(
                    BuddyLogEvent(
                      EntryKind.meal,
                      LogSentiment.good,
                      at: now,
                      trackedAt: DateTime(now.year, now.month, now.day - 1, 20),
                    ),
                  );
              context.pop();
            },
            child: const Text('fake-save-yesterday-meal'),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('fake-cancel'),
          ),
        ],
      ),
    );
  }
}

class _Harness {
  _Harness(this.container, this.buddyRepo, this.notifications, this.buddy);

  final ProviderContainer container;
  final FakeBuddyRepository buddyRepo;
  final _CountingNotifications notifications;
  final _CountingBuddy buddy;

  BuddyState? get stored => buddyRepo.store[testUserId];
}

const _streakTitle = 'Wie viele Tage schaffen wir zusammen?';
const _reminderTitle = 'Darf ich mich melden, wenn ich Hunger hab?';
const _mealTitle = 'Ich hab Hunger! Was hast du zuletzt gegessen?';
const _bornLine = 'Tag 1! Unser Streak ist geboren.';
const _noStreakLine = 'Mit deinem nächsten Eintrag startet unser Streak!';
const _introLine = 'Hi! Ich bin neu hier — dein Belly Buddy.';

void main() {
  // These Buddies must tick: reactions, blinks, waking up.
  tickBuddiesInTests();

  group('buddyOnboardingSteps', () {
    const after = BuddyOnboardingEntry.afterRegistration;
    const gate = BuddyOnboardingEntry.gate;

    final table = <(BuddyOnboardingEntry, bool, bool), List<_Step>>{
      (after, false, false): [
        _Step.firstMeal,
        _Step.streakMoment,
        _Step.streakGoal,
        _Step.reminder,
      ],
      (after, false, true): [
        _Step.firstMeal,
        _Step.streakMoment,
        _Step.streakGoal,
      ],
      (after, true, false): [
        _Step.firstMeal,
        _Step.streakMoment,
        _Step.streakGoal,
        _Step.reminder,
      ],
      (after, true, true): [
        _Step.firstMeal,
        _Step.streakMoment,
        _Step.streakGoal,
      ],
      (gate, false, false): [
        _Step.intro,
        _Step.name,
        _Step.streakMoment,
        _Step.streakGoal,
        _Step.reminder,
      ],
      (gate, false, true): [
        _Step.intro,
        _Step.name,
        _Step.streakMoment,
        _Step.streakGoal,
      ],
      (gate, true, false): [
        _Step.streakMoment,
        _Step.streakGoal,
        _Step.reminder,
      ],
      (gate, true, true): [_Step.streakMoment, _Step.streakGoal],
    };

    for (final MapEntry(key: (entry, hasRow, remindersOn), value: steps)
        in table.entries) {
      test('${entry.name}, hasRow: $hasRow, reminders on: $remindersOn', () {
        expect(
          buddyOnboardingSteps(
            entry: entry,
            hasRow: hasRow,
            remindersAlreadyOn: remindersOn,
          ),
          steps,
        );
      });
    }
  });

  test('streakMomentLine', () {
    expect(streakMomentLine(0), _noStreakLine);
    expect(streakMomentLine(1), _bornLine);
    expect(streakMomentLine(5), 'Unser Streak: 5 Tage! Weiter so.');
  });

  group('BuddyOnboardingScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    void reduceMotion(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    /// Lets step switches, route transitions and Buddy reactions play.
    /// The Buddy ticks forever, so never `pumpAndSettle`.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// A reaction shows for a while, then the Buddy asks the step's
    /// question again.
    Future<void> afterReaction(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pump();
      await tester.tap(find.byKey(key));
      await settle(tester);
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump();
      await tester.tap(find.text(text));
      await settle(tester);
    }

    /// On the goal step: selects [goal] and confirms with „Ziel festlegen".
    Future<void> pickGoal(WidgetTester tester, String goal) async {
      await tapText(tester, goal);
      await tapKey(tester, BuddyOnboardingScreen.goalConfirmKey);
    }

    Future<_Harness> pumpOnboarding(
      WidgetTester tester, {
      BuddyOnboardingEntry entry = BuddyOnboardingEntry.afterRegistration,
      bool pushEnabled = false,
      BuddyState? existingRow,
      Set<DateTime>? activityDays,
      List<Override> extraOverrides = const [],
      Size screen = const Size(400, 860),
    }) async {
      tester.view
        ..physicalSize = screen
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 20);
      addTearDown(tester.view.reset);

      final buddyRepo = FakeBuddyRepository();
      if (existingRow != null) buddyRepo.store[testUserId] = existingRow;
      final entries = FakeEntryRepository();
      if (activityDays != null) entries.seedActivityDays(activityDays);
      final notifications = _CountingNotifications();
      final buddy = _CountingBuddy();
      final profiles = FakeProfileRepository()
        ..seedProfile(testUserProfile(pushEnabled: pushEnabled));

      final container = ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue(testUserId),
          buddyRepositoryProvider.overrideWithValue(buddyRepo),
          entryRepositoryProvider.overrideWithValue(entries),
          profileRepositoryProvider.overrideWithValue(profiles),
          notificationRepositoryProvider.overrideWithValue(notifications),
          buddyProvider.overrideWith(() => buddy),
          ...extraOverrides,
        ],
      );
      await container.read(profileProvider.notifier).fetchProfile();

      final router = GoRouter(
        initialLocation: RoutePaths.buddyOnboarding,
        initialExtra: entry,
        routes: [
          GoRoute(
            path: RoutePaths.buddyOnboarding,
            builder: (_, state) {
              final extra = state.extra;
              return BuddyOnboardingScreen(
                entry: extra is BuddyOnboardingEntry
                    ? extra
                    : BuddyOnboardingEntry.gate,
              );
            },
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (_, _) => const _FakeMealTracker(),
          ),
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (_, _) => const Scaffold(body: Text('dashboard-stub')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: germanRouterApp(router),
        ),
      );
      await settle(tester);
      return _Harness(container, buddyRepo, notifications, buddy);
    }

    /// [finder] lies fully inside the visible area: the screen minus the
    /// keyboard ([keyboard] px).
    void expectOnScreen(
      WidgetTester tester,
      Finder finder, {
      double keyboard = 0,
    }) {
      final rect = tester.getRect(finder);
      final visibleBottom = tester.view.physicalSize.height - keyboard;
      expect(
        rect.top >= 0 && rect.bottom <= visibleBottom,
        isTrue,
        reason: '$finder at $rect, visible down to $visibleBottom',
      );
    }

    Future<bool?> modalShownPref() async =>
        (await SharedPreferences.getInstance()).getBool(
          AppConstants.keyNotificationModalShown,
        );

    /// The goal row for [days] shows as the selected one.
    bool goalSelected(WidgetTester tester, int days) => find
        .descendant(
          of: find.byKey(StreakGoalPicker.goalKey(days)),
          matching: find.byIcon(Icons.check_circle),
        )
        .evaluate()
        .isNotEmpty;

    testWidgets('the goal step: his tip starts selected; a tap selects '
        'another goal without leaving the step; „Ziel festlegen" saves it '
        'and goes on', (tester) async {
      final h = await pumpOnboarding(tester, entry: BuddyOnboardingEntry.gate);
      await tapKey(tester, BuddyOnboardingScreen.introNextKey);
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await tapKey(tester, BuddyOnboardingScreen.nameNextKey);
      await afterReaction(tester);
      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);
      expect(find.text(_streakTitle), findsOneWidget);

      expect(goalSelected(tester, 14), isTrue);
      expect(find.byKey(BuddyOnboardingScreen.goalConfirmKey), findsOneWidget);
      expect(find.text('Ziel festlegen'), findsOneWidget);

      for (final days in [30, 50]) {
        await tapText(tester, '$days Tage');
        expect(find.text(_streakTitle), findsOneWidget, reason: '$days');
        expect(goalSelected(tester, days), isTrue, reason: '$days');
        expect(goalSelected(tester, 14), isFalse, reason: '$days');
      }
      // His tip keeps its badge.
      expect(
        find.descendant(
          of: find.byKey(StreakGoalPicker.goalKey(14)),
          matching: find.text('Mein Tipp'),
        ),
        findsOneWidget,
      );
      expect(h.stored?.streakGoal, isNull);

      await tapKey(tester, BuddyOnboardingScreen.goalConfirmKey);
      expect(h.stored?.streakGoal, 50);
      expect(find.text(_reminderTitle), findsOneWidget);
    });

    testWidgets('the goal as the last step: „Ziel festlegen" shows that it is '
        'working while the onboarding completes', (tester) async {
      final h = await pumpOnboarding(tester, pushEnabled: true);
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(find.text(_streakTitle), findsOneWidget);

      await tapText(tester, '30 Tage');
      h.buddyRepo.saveHold = Completer<void>();
      await tester.tap(find.byKey(BuddyOnboardingScreen.goalConfirmKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('dashboard-stub'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(BuddyOnboardingScreen.goalConfirmKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // The choice is made: the goals no longer react.
      await tester.tap(find.text('7 Tage'), warnIfMissed: false);
      await tester.pump();
      expect(goalSelected(tester, 30), isTrue);

      h.buddyRepo.saveHold!.complete();
      await settle(tester);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.streakGoal, 30);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
    });

    testWidgets('after registration: first meal, „Tag 1", goal, reminder '
        'later, then the dashboard with his welcome — no streak saver', (
      tester,
    ) async {
      final h = await pumpOnboarding(tester);

      expect(find.text(_mealTitle), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-save-meal');

      // The streak moment: born today, with this week's row.
      expect(find.text(_bornLine), findsOneWidget);
      expect(find.bySemanticsLabel('Streak: 1 Tag'), findsOneWidget);
      expect(find.byKey(StreakWeekRow.todayKey), findsOneWidget);
      expect(find.text(kStreakRuleText), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);

      // The goal, explained, with his tip.
      expect(find.text(_streakTitle), findsOneWidget);
      expect(find.text('Warum ein Ziel?'), findsOneWidget);
      expect(find.text('Mein Tipp'), findsOneWidget);
      await pickGoal(tester, '14 Tage');
      expect(h.stored?.streakGoal, 14);

      // The reminder ask previews his real reminders at the profile times.
      expect(find.text(_reminderTitle), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(
        find.text('🍲 Buddy ist gespannt auf dein Abendessen!'),
        findsOneWidget,
      );
      expect(find.text('BEISPIEL'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('Geschenk'), findsNothing);
      expect(find.textContaining('Streak-Saver'), findsNothing);
      // Not done before the last answer.
      expect(h.buddy.completeCalls, 0);

      await tapKey(tester, BuddyOnboardingScreen.reminderLaterKey);
      expect(await modalShownPref(), isTrue);
      expect(h.notifications.permissionRequests, 0);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.buddy.completeCalls, 1);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
      expect(h.stored?.savers ?? 0, 0);
      expect(h.container.read(buddyWelcomeProvider), BuddyWelcomeNotifier.line);
    });

    testWidgets('after registration without a meal: no streak moment; back '
        'skips it too', (tester) async {
      await pumpOnboarding(tester);

      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(find.text(_bornLine), findsNothing);
      expect(find.text(_streakTitle), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(_mealTitle), findsOneWidget);

      // Not past the first step.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(_mealTitle), findsOneWidget);
    });

    testWidgets('„Erinnerungen aktivieren" asks for permission, turns push '
        'on and finishes', (tester) async {
      final h = await pumpOnboarding(tester);
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      await pickGoal(tester, '7 Tage');

      await tapKey(tester, BuddyOnboardingScreen.reminderYesKey);

      expect(h.notifications.permissionRequests, 1);
      expect(await modalShownPref(), isTrue);
      expect(h.container.read(profileProvider).value?.pushEnabled, isTrue);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
    });

    testWidgets('reminders already on: the goal is the last step, and '
        'completing marks the opt-in as offered', (tester) async {
      final h = await pumpOnboarding(tester, pushEnabled: true);
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(await modalShownPref(), isNull);

      await pickGoal(tester, '7 Tage');

      expect(find.text(_reminderTitle), findsNothing);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(await modalShownPref(), isTrue);
      expect(h.stored?.streakGoal, 7);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
    });

    testWidgets('leaving the tracker without a meal stays; a log earlier '
        'today still starts the streak', (tester) async {
      final h = await pumpOnboarding(tester, pushEnabled: true);
      // Logged before opening the tracker: no advance on its own …
      h.container
          .read(buddyEventsProvider.notifier)
          .emit(
            BuddyLogEvent(
              EntryKind.meal,
              LogSentiment.good,
              at: DateTime.now(),
              trackedAt: DateTime.now(),
            ),
          );
      await settle(tester);
      expect(find.text(_mealTitle), findsOneWidget);

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-cancel');
      expect(find.text(_mealTitle), findsOneWidget);

      // … but today counts, so „Später" leads to the streak moment.
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(find.text(_bornLine), findsOneWidget);
    });

    testWidgets('a meal backdated to yesterday does not start today\'s '
        'streak', (tester) async {
      await pumpOnboarding(tester, pushEnabled: true);

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-save-yesterday-meal');

      // Nothing counts for today: no „Tag 1!", no moment; on to the goal.
      expect(find.text(_bornLine), findsNothing);
      expect(find.text(_streakTitle), findsOneWidget);
    });

    testWidgets('a meal followed by a drink in the tracker still counts', (
      tester,
    ) async {
      await pumpOnboarding(tester, pushEnabled: true);

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-meal-then-drink');

      expect(find.text(_bornLine), findsOneWidget);
    });

    testWidgets('gate without a Buddy: intro, name, streak moment, goal, '
        'reminder, dashboard', (tester) async {
      final h = await pumpOnboarding(tester, entry: BuddyOnboardingEntry.gate);

      expect(find.text(_introLine), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.introNextKey);

      expect(find.byKey(BuddyNameStep.titleKey), findsOneWidget);
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), '   ');
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.descendant(
                of: find.byKey(BuddyOnboardingScreen.nameNextKey),
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await tapKey(tester, BuddyOnboardingScreen.nameNextKey);
      expect(h.stored?.name, 'Bauchi');

      // He cheers with his new name first; then the streak moment (no
      // entries yet: no count, just the week and the rule).
      expect(find.text(_noStreakLine), findsNothing);
      await afterReaction(tester);
      expect(find.text(_noStreakLine), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Streak:')), findsNothing);
      expect(find.text(kStreakRuleText), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);

      expect(find.text(_streakTitle), findsOneWidget);
      await pickGoal(tester, '14 Tage');
      expect(find.text(_reminderTitle), findsOneWidget);
      // The previews use his name.
      expect(
        find.text('🍲 Bauchi ist gespannt auf dein Abendessen!'),
        findsOneWidget,
      );
      await tapKey(tester, BuddyOnboardingScreen.reminderLaterKey);

      expect(find.text(_mealTitle), findsNothing);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
      expect(h.stored?.savers, 0);
    });

    testWidgets('gate with an existing Buddy shows the current streak', (
      tester,
    ) async {
      final today = DateTime(2026, 11, 25);
      await pumpOnboarding(
        tester,
        entry: BuddyOnboardingEntry.gate,
        pushEnabled: true,
        existingRow: const BuddyState(userId: testUserId, name: 'Bauchi'),
        activityDays: {
          for (var i = 0; i < 3; i++)
            DateTime(today.year, today.month, today.day - i),
        },
        extraOverrides: [buddyTodayProvider.overrideWithValue(() => today)],
      );

      expect(find.text(_introLine), findsNothing);
      expect(find.text('Unser Streak: 3 Tage! Weiter so.'), findsOneWidget);
      expect(find.bySemanticsLabel('Streak: 3 Tage'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Diese Woche eingetragen: Montag, Dienstag, '
          'Mittwoch',
        ),
        findsOneWidget,
      );
      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);
      expect(find.text(_streakTitle), findsOneWidget);
      // 3 days in: 7 is still open, and his tip stays on 14.
      expect(find.text('7 Tage'), findsOneWidget);
      await pickGoal(tester, '7 Tage');
      expect(find.text('dashboard-stub'), findsOneWidget);
    });

    testWidgets('completing keeps the savers a user already has', (
      tester,
    ) async {
      final h = await pumpOnboarding(
        tester,
        entry: BuddyOnboardingEntry.gate,
        pushEnabled: true,
        existingRow: const BuddyState(userId: testUserId, savers: 2),
      );

      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);
      await pickGoal(tester, '7 Tage');

      expect(h.stored?.onboardingCompletedAt, isNotNull);
      expect(h.stored?.savers, 2);
      expect(find.text('dashboard-stub'), findsOneWidget);
    });

    testWidgets('no goal left to pick: the streak-goal step is skipped', (
      tester,
    ) async {
      final today = DateTime(2026, 11, 22);
      final h = await pumpOnboarding(
        tester,
        pushEnabled: true,
        activityDays: {
          for (var i = 0; i < 110; i++)
            DateTime(today.year, today.month, today.day - i),
        },
        extraOverrides: [buddyTodayProvider.overrideWithValue(() => today)],
      );

      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(find.text('Unser Streak: 110 Tage! Weiter so.'), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);

      expect(find.text(_streakTitle), findsNothing);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
    });

    testWidgets('the keyboard\'s done action confirms the name', (
      tester,
    ) async {
      final h = await pumpOnboarding(tester, entry: BuddyOnboardingEntry.gate);
      await tapKey(tester, BuddyOnboardingScreen.introNextKey);

      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(h.stored?.name, 'Bauchi');
      await afterReaction(tester);
      expect(find.text(_noStreakLine), findsOneWidget);
    });

    testWidgets('completing fails: the step stays and „Ziel festlegen" can '
        'be tapped again', (tester) async {
      final h = await pumpOnboarding(tester, pushEnabled: true);
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      h.buddyRepo.throwOnSave = true;

      await pickGoal(tester, '7 Tage');
      expect(find.text('dashboard-stub'), findsNothing);
      expect(
        find.text('Das hat nicht geklappt. Bitte versuch es noch einmal.'),
        findsOneWidget,
      );
      expect(find.text(_streakTitle), findsOneWidget);

      h.buddyRepo.throwOnSave = false;
      // The snackbar covers the bottom of the screen until it is gone.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await tapKey(tester, BuddyOnboardingScreen.goalConfirmKey);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.streakGoal, 7);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
    });

    group('small phone (375×667): actions visible without scrolling', () {
      const phone = Size(375, 667);

      testWidgets('first meal, streak moment, goal and reminder', (
        tester,
      ) async {
        await pumpOnboarding(tester, screen: phone);

        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.mealLogKey));
        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.mealLaterKey));
        await tester.tap(find.byKey(BuddyOnboardingScreen.mealLogKey));
        await settle(tester);
        await tester.tap(find.text('fake-save-meal'));
        await settle(tester);

        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.momentNextKey));
        await tester.tap(find.byKey(BuddyOnboardingScreen.momentNextKey));
        await settle(tester);

        // The first goals, his tip and „Ziel festlegen" without scrolling.
        for (final goal in ['7 Tage', '14 Tage']) {
          expectOnScreen(tester, find.text(goal));
        }
        expectOnScreen(
          tester,
          find.byKey(BuddyOnboardingScreen.goalConfirmKey),
        );
        await tester.tap(find.text('7 Tage'));
        await settle(tester);
        await tester.tap(find.byKey(BuddyOnboardingScreen.goalConfirmKey));
        await settle(tester);

        expectOnScreen(
          tester,
          find.byKey(BuddyOnboardingScreen.reminderYesKey),
        );
        expectOnScreen(
          tester,
          find.byKey(BuddyOnboardingScreen.reminderLaterKey),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('intro and name, also above the keyboard', (tester) async {
        await pumpOnboarding(
          tester,
          entry: BuddyOnboardingEntry.gate,
          screen: phone,
        );

        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.introNextKey));
        await tester.tap(find.byKey(BuddyOnboardingScreen.introNextKey));
        await settle(tester);

        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.nameNextKey));

        const keyboard = 260.0;
        await tester.tap(find.byKey(BuddyNameStep.fieldKey));
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
        await settle(tester);

        expect(tester.takeException(), isNull);
        expectOnScreen(
          tester,
          find.byKey(BuddyOnboardingScreen.nameNextKey),
          keyboard: keyboard,
        );
      });
    });

    testWidgets('reduced motion: the whole walk completes', (tester) async {
      reduceMotion(tester);
      final h = await pumpOnboarding(tester);

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-save-meal');
      expect(find.text(_bornLine), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.momentNextKey);
      await pickGoal(tester, '7 Tage');
      await tapKey(tester, BuddyOnboardingScreen.reminderLaterKey);

      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
    });
  });
}
