// ignore_for_file: invalid_use_of_internal_member
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/buddy/buddy_onboarding_screen.dart';
import 'package:belly_buddy/screens/buddy/widgets/gift_reveal.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';

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
  Future<bool> completeOnboarding({bool grantGiftSaver = true}) {
    completeCalls++;
    return super.completeOnboarding(grantGiftSaver: grantGiftSaver);
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
                ),
              );
              // The success screen's „Getränk hinzufügen": the drink event
              // replaces the meal in the single event slot.
              events.emit(
                BuddyLogEvent(
                  EntryKind.drink,
                  LogSentiment.good,
                  at: DateTime.now(),
                ),
              );
              context.pop();
            },
            child: const Text('fake-meal-then-drink'),
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
const _reminderTitle = 'Darf ich dich erinnern, wenn ich Hunger habe?';
const _mealTitle = 'Ich hab Hunger! Was hast du zuletzt gegessen?';
const _giftTitle = 'Ein Geschenk für dich!';
const _giftText =
    'Ein Streak-Saver! Der rettet unseren Streak, falls du mal einen Tag '
    'vergisst.';
const _giftFullText =
    'Deine Schutzschilde sind schon voll – du bist bestens gerüstet!';
const _giftAlreadyText = "Du bist bestens gerüstet – los geht's!";
const _introLine = 'Hi! Ich bin neu hier — dein Belly Buddy.';

void main() {
  group('buddyOnboardingSteps', () {
    const after = BuddyOnboardingEntry.afterRegistration;
    const gate = BuddyOnboardingEntry.gate;

    final table = <(BuddyOnboardingEntry, bool, bool), List<_Step>>{
      (after, false, false): [
        _Step.streakGoal,
        _Step.reminder,
        _Step.firstMeal,
        _Step.gift,
      ],
      (after, false, true): [_Step.streakGoal, _Step.firstMeal, _Step.gift],
      (after, true, false): [
        _Step.streakGoal,
        _Step.reminder,
        _Step.firstMeal,
        _Step.gift,
      ],
      (after, true, true): [_Step.streakGoal, _Step.firstMeal, _Step.gift],
      (gate, false, false): [
        _Step.intro,
        _Step.name,
        _Step.streakGoal,
        _Step.reminder,
        _Step.gift,
      ],
      (gate, false, true): [
        _Step.intro,
        _Step.name,
        _Step.streakGoal,
        _Step.gift,
      ],
      (gate, true, false): [_Step.streakGoal, _Step.reminder, _Step.gift],
      (gate, true, true): [_Step.streakGoal, _Step.gift],
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
          child: MaterialApp.router(
            theme: AppTheme.theme,
            routerConfig: router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de', 'DE')],
            locale: const Locale('de', 'DE'),
          ),
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

    testWidgets('after registration: goal, reminder later, meal later, '
        'gift once, then the dashboard', (tester) async {
      final h = await pumpOnboarding(tester);

      expect(find.text(_streakTitle), findsOneWidget);
      await tapText(tester, '7 Tage');
      expect(h.stored?.streakGoal, 7);

      expect(find.text(_reminderTitle), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.reminderLaterKey);
      expect(await modalShownPref(), isTrue);
      expect(h.notifications.permissionRequests, 0);

      expect(find.text(_mealTitle), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);

      expect(find.text(_giftTitle), findsOneWidget);
      expect(find.byKey(BuddyOnboardingScreen.finishKey), findsNothing);
      await tapKey(tester, GiftReveal.boxKey);
      await tester.tap(find.byKey(GiftReveal.boxKey), warnIfMissed: false);
      await settle(tester);

      expect(h.buddy.completeCalls, 1);
      expect(h.stored?.savers, 1);
      expect(h.stored?.onboardingCompletedAt, isNotNull);
      expect(find.text(_giftText), findsOneWidget);
      expect(find.text('🛡 Streak-Saver'), findsOneWidget);

      await tapKey(tester, BuddyOnboardingScreen.finishKey);
      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.buddy.completeCalls, 1);
    });

    testWidgets('reminder „Ja, gerne" asks for permission and turns push on', (
      tester,
    ) async {
      final h = await pumpOnboarding(tester);
      await tapText(tester, '7 Tage');

      await tapKey(tester, BuddyOnboardingScreen.reminderYesKey);

      expect(h.notifications.permissionRequests, 1);
      expect(await modalShownPref(), isTrue);
      expect(h.container.read(profileProvider).value?.pushEnabled, isTrue);
      expect(find.text(_mealTitle), findsOneWidget);
    });

    testWidgets('reminders already on: no reminder step', (tester) async {
      await pumpOnboarding(tester, pushEnabled: true);
      await tapText(tester, '7 Tage');

      expect(find.text(_reminderTitle), findsNothing);
      expect(find.text(_mealTitle), findsOneWidget);
    });

    testWidgets('reminders already on: completing marks the opt-in as '
        'offered, so the dashboard won\'t ask', (tester) async {
      await pumpOnboarding(tester, pushEnabled: true);
      await tapText(tester, '7 Tage');
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(await modalShownPref(), isNull);

      await tapKey(tester, GiftReveal.boxKey);
      await tester.tap(find.byKey(GiftReveal.boxKey), warnIfMissed: false);
      await settle(tester);

      expect(find.text(_giftText), findsOneWidget);
      expect(await modalShownPref(), isTrue);
    });

    testWidgets('a meal logged in the tracker advances after the pop', (
      tester,
    ) async {
      await pumpOnboarding(tester, pushEnabled: true);
      await tapText(tester, '7 Tage');

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      expect(find.text('fake-save-meal'), findsOneWidget);
      await tapText(tester, 'fake-save-meal');

      expect(find.text(_giftTitle), findsOneWidget);
      expect(find.text('Mmmh! Danke!'), findsOneWidget);
    });

    testWidgets('leaving the tracker without a meal stays; „Später" '
        'advances', (tester) async {
      final h = await pumpOnboarding(tester, pushEnabled: true);
      // A meal logged before the step does not count.
      h.container
          .read(buddyEventsProvider.notifier)
          .emit(
            BuddyLogEvent(
              EntryKind.meal,
              LogSentiment.good,
              at: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          );
      await tapText(tester, '7 Tage');

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-cancel');

      expect(find.text(_mealTitle), findsOneWidget);
      expect(find.text(_giftTitle), findsNothing);

      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      expect(find.text(_giftTitle), findsOneWidget);
    });

    testWidgets('gate without a Buddy: intro, name, goal, reminder, gift', (
      tester,
    ) async {
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

      expect(find.text(_streakTitle), findsOneWidget);
      await tapText(tester, '14 Tage');
      expect(find.text(_reminderTitle), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.reminderLaterKey);

      // The gate has no first-meal step.
      expect(find.text(_mealTitle), findsNothing);
      expect(find.text(_giftTitle), findsOneWidget);
    });

    testWidgets('gate with an existing Buddy starts at the streak goal', (
      tester,
    ) async {
      await pumpOnboarding(
        tester,
        entry: BuddyOnboardingEntry.gate,
        pushEnabled: true,
        existingRow: const BuddyState(userId: testUserId, name: 'Bauchi'),
      );

      expect(find.text(_introLine), findsNothing);
      expect(find.text(_streakTitle), findsOneWidget);
      await tapText(tester, '7 Tage');
      expect(find.text(_giftTitle), findsOneWidget);
    });

    testWidgets('gift with a full saver stock: no saver is promised', (
      tester,
    ) async {
      final h = await pumpOnboarding(
        tester,
        entry: BuddyOnboardingEntry.gate,
        pushEnabled: true,
        existingRow: const BuddyState(userId: testUserId, savers: 2),
      );

      await tapText(tester, '7 Tage');
      await tapKey(tester, GiftReveal.boxKey);

      expect(h.stored?.onboardingCompletedAt, isNotNull);
      expect(h.stored?.savers, 2);
      expect(find.text(_giftText), findsNothing);
      expect(find.text(_giftFullText), findsOneWidget);
      // The card claims no saver either.
      expect(find.text('🛡 Schutzschilde voll'), findsOneWidget);
      expect(find.text('🛡 Streak-Saver'), findsNothing);
      await tapKey(tester, BuddyOnboardingScreen.finishKey);
      expect(find.text('dashboard-stub'), findsOneWidget);
    });

    testWidgets('gift when the onboarding was already completed (no new '
        'saver, stock not full): no saver is promised', (tester) async {
      final h = await pumpOnboarding(
        tester,
        entry: BuddyOnboardingEntry.gate,
        pushEnabled: true,
        existingRow: BuddyState(
          userId: testUserId,
          onboardingCompletedAt: DateTime.utc(2026, 11, 1),
        ),
      );

      await tapText(tester, '7 Tage');
      await tapKey(tester, GiftReveal.boxKey);

      expect(h.stored?.savers, 0);
      expect(find.text(_giftText), findsNothing);
      expect(find.text(_giftFullText), findsNothing);
      expect(find.text(_giftAlreadyText), findsOneWidget);
      expect(find.text('🛡 Bestens gerüstet'), findsOneWidget);
      expect(find.text('🛡 Streak-Saver'), findsNothing);
    });

    testWidgets('no goal left to pick: the streak-goal step is skipped', (
      tester,
    ) async {
      final today = DateTime(2026, 11, 22);
      await pumpOnboarding(
        tester,
        pushEnabled: true,
        activityDays: {
          for (var i = 0; i < 110; i++)
            DateTime(today.year, today.month, today.day - i),
        },
        extraOverrides: [buddyTodayProvider.overrideWithValue(() => today)],
      );

      expect(find.text(_streakTitle), findsNothing);
      expect(find.text(_mealTitle), findsOneWidget);
    });

    testWidgets('system back goes to the previous step; not past the first', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tapText(tester, '7 Tage');
      expect(find.text(_reminderTitle), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(_streakTitle), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(_streakTitle), findsOneWidget);
    });

    testWidgets('a meal followed by a drink in the tracker still counts', (
      tester,
    ) async {
      await pumpOnboarding(tester, pushEnabled: true);
      await tapText(tester, '7 Tage');

      await tapKey(tester, BuddyOnboardingScreen.mealLogKey);
      await tapText(tester, 'fake-meal-then-drink');

      expect(find.text(_giftTitle), findsOneWidget);
      expect(find.text('Mmmh! Danke!'), findsOneWidget);
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
      expect(find.text(_streakTitle), findsOneWidget);
    });

    group('small phone (375×667): actions visible without scrolling', () {
      const phone = Size(375, 667);

      testWidgets('streak goal, reminder, first meal and the opened gift', (
        tester,
      ) async {
        await pumpOnboarding(tester, screen: phone);

        for (final goal in ['7 Tage', '14 Tage', '30 Tage']) {
          expectOnScreen(tester, find.text(goal));
        }
        await tester.tap(find.text('7 Tage'));
        await settle(tester);

        expectOnScreen(
          tester,
          find.byKey(BuddyOnboardingScreen.reminderYesKey),
        );
        expectOnScreen(
          tester,
          find.byKey(BuddyOnboardingScreen.reminderLaterKey),
        );
        await tester.tap(find.byKey(BuddyOnboardingScreen.reminderLaterKey));
        await settle(tester);

        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.mealLogKey));
        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.mealLaterKey));
        await tester.tap(find.byKey(BuddyOnboardingScreen.mealLaterKey));
        await settle(tester);

        expectOnScreen(tester, find.byKey(GiftReveal.boxKey));
        await tester.tap(find.byKey(GiftReveal.boxKey));
        await settle(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expectOnScreen(tester, find.byKey(BuddyOnboardingScreen.finishKey));
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

      await tapText(tester, '7 Tage');
      await tapKey(tester, BuddyOnboardingScreen.reminderLaterKey);
      await tapKey(tester, BuddyOnboardingScreen.mealLaterKey);
      await tapKey(tester, GiftReveal.boxKey);
      expect(find.text(_giftText), findsOneWidget);
      await tapKey(tester, BuddyOnboardingScreen.finishKey);

      expect(find.text('dashboard-stub'), findsOneWidget);
      expect(h.stored?.savers, 1);
    });
  });
}
