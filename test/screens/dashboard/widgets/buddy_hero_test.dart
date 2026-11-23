// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/buddy_welcome_provider.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:belly_buddy/screens/dashboard/widgets/streak_sheet.dart';
import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

import '../../../helpers/ambient_animations.dart';
import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

/// A welcome already set when the hero first reads it.
class _PresetWelcome extends BuddyWelcomeNotifier {
  _PresetWelcome(this._line);

  final String _line;

  @override
  String? build() => _line;
}

/// [FakeBuddyNotifier] that also records the hero's refreshes and shown
/// announcements.
class _FakeBuddy extends FakeBuddyNotifier {
  _FakeBuddy(super.initial);

  /// Every announcement the hero marked as shown, in order.
  final List<BuddyAnnouncement> shown = [];
  int refreshCalls = 0;

  /// How long [refresh] takes, then it publishes [afterRefresh] (if set):
  /// a slow backend.
  Duration refreshDelay = Duration.zero;
  BuddyStatus? afterRefresh;

  @override
  Future<void> refresh() async {
    refreshCalls++;
    if (refreshDelay > Duration.zero) await Future<void>.delayed(refreshDelay);
    final next = afterRefresh;
    if (next != null) push(next);
  }

  @override
  Future<void> markAnnouncementsShown(List<BuddyAnnouncement> announcements) {
    shown.addAll(announcements);
    return super.markAnnouncementsShown(announcements);
  }
}

/// [EntriesNotifier] with a seeded state; [loadEntries] loads [next] for
/// its day.
class _FakeEntries extends EntriesNotifier {
  _FakeEntries(this._initial);

  final EntriesState _initial;

  /// What the next [loadEntries] finds.
  EntriesState? next;

  /// The dates [loadEntries] was called with.
  final List<DateTime> loaded = [];

  @override
  EntriesState build() => _initial;

  @override
  Future<void> loadEntries(DateTime date) async {
    loaded.add(date);
    state = (next ?? state).copyWith(day: startOfDay(date));
  }

  /// A write's reload lands: today's entries are [s] now.
  void push(EntriesState s) => state = s;
}

BuddyStatus _status({
  int streak = 4,
  bool todayCounted = false,
  int savers = 1,
  bool hasRow = true,
  List<BuddyAnnouncement> announcements = const [],
}) => buddyStatus(
  savers: savers,
  hasRow: hasRow,
  streak: streak,
  todayCounted: todayCounted,
  announcements: announcements,
);

const _saverUsedLine = 'Puh! Dein Streak-Saver hat uns gestern gerettet 🛡';
const _streakBrokenLine = 'Neuer Anlauf — ich bin dabei!';
const _saverEarnedLine = 'Du hast einen Streak-Saver verdient! 🛡';
const _goalTitle = "Wir haben's geschafft! Neues Ziel?";
const _sheetTitle = 'Dein Streak';
const _pickTitle = 'Neues Streak-Ziel';

void main() {
  late DateTime now;
  late _FakeBuddy buddy;
  late _FakeEntries entries;
  late ValueNotifier<bool> visible;
  late GoRouter router;

  // The hero's bubble and actions need ticking Buddies.
  tickBuddiesInTests();

  setUp(() {
    now = DateTime(2026, 11, 22, 14);
    buddy = _FakeBuddy(() => _status());
    entries = _FakeEntries(const EntriesState());
    visible = ValueNotifier(true);
  });

  tearDown(() {
    visible.dispose();
  });

  /// Pumps the hero on Home (`/dashboard`) of a router with stub pages for
  /// the Tagebuch and the trackers; `TickerMode` follows [visible].
  Future<ProviderContainer> pumpHero(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    final container = ProviderContainer.test(
      overrides: [
        buddyClockProvider.overrideWithValue(() => now),
        currentUserIdProvider.overrideWithValue('u1'),
        buddyProvider.overrideWith(() => buddy),
        entriesProvider.overrideWith(() => entries),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      initialLocation: RoutePaths.dashboard,
      routes: [
        GoRoute(
          path: RoutePaths.dashboard,
          builder: (_, _) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, on, child) => TickerMode(enabled: on, child: child!),
              child: const SingleChildScrollView(child: BuddyHero()),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.diary,
          builder: (_, _) => const Scaffold(body: Text('diary-page')),
        ),
        ...stubRoutes([
          RoutePaths.mealTracker,
          RoutePaths.drinkTracker,
          RoutePaths.gutFeelingTracker,
          RoutePaths.toiletTracker,
        ]),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router),
      ),
    );
    // Buddy load, first-frame callbacks and a few Buddy ticks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  /// The path of the router's top page (a pushed tracker included).
  String location() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  BuddyController controller(WidgetTester tester) =>
      tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).controller;

  /// Lets a pending `say()` reach the bubble (the controller notifies on
  /// its next tick).
  Future<void> tick(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 16));

  /// Advances the Buddy's own clock by [d]: it ticks at most 50 ms per
  /// frame, so one long pump would not expire a bubble.
  Future<void> advance(WidgetTester tester, Duration d) async {
    const step = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < d; t += step) {
      await tester.pump(step);
    }
  }

  /// Taps the StreakChip and lets „Dein Streak" open.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(StreakChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// In an open goal list: selects [goal], confirms with „Ziel festlegen"
  /// and lets the sheet close.
  Future<void> chooseGoal(WidgetTester tester, String goal) async {
    await tester.ensureVisible(find.text(goal));
    await tester.tap(find.text(goal));
    await tester.pump();
    await tester.ensureVisible(find.byKey(StreakGoalChooser.confirmKey));
    await tester.tap(find.byKey(StreakGoalChooser.confirmKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// In „Dein Streak": „Ziel ändern" → the goal list.
  Future<void> openGoalList(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(StreakSheet.changeGoalKey));
    await tester.tap(find.byKey(StreakSheet.changeGoalKey));
    await tester.pump();
  }

  /// The care pool [action]'s lines as the hero fills them for Bubu.
  List<String> careLines(CareAction action) => [
    for (final l in BuddyCopy.care[action]!) BuddyCopy.fill(l, name: 'Bubu'),
  ];

  void emit(ProviderContainer c, LogSentiment sentiment, {DateTime? at}) => c
      .read(buddyEventsProvider.notifier)
      .emit(
        BuddyLogEvent(
          EntryKind.meal,
          sentiment,
          at: at ?? now,
          trackedAt: at ?? now,
        ),
      );

  group('BuddyHero', () {
    testWidgets('renders the Buddy in the care ring and the next action', (
      tester,
    ) async {
      await pumpHero(tester);

      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CareRing),
          matching: find.byType(AnimatedBuddy),
        ),
        findsOneWidget,
      );
      // 14:00, nothing eaten: lunch.
      expect(find.text('🍝 Mittagessen eintragen'), findsOneWidget);
      expect(find.byKey(BuddyHero.actionKey), findsOneWidget);
    });

    testWidgets('no entries at 14:00 → hungry, asks for lunch', (tester) async {
      await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.hungry);
      expect(careLines(CareAction.lunch), contains(c.bubble));
    });

    testWidgets('lunch logged → he asks for a drink, Trinken glows', (
      tester,
    ) async {
      entries = _FakeEntries(
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      expect(careLines(CareAction.drink), contains(controller(tester).bubble));
      expect(find.text('💧 Trinken eintragen'), findsOneWidget);
      expect(
        tester.widget<CareRing>(find.byType(CareRing)).highlight,
        CareNeed.drink,
      );
      expect(find.text('🍽 1/3'), findsOneWidget);
    });

    testWidgets('a bad log keeps the empathetic line, not a care line', (
      tester,
    ) async {
      final container = await pumpHero(tester);
      await tick(tester);
      emit(container, LogSentiment.bad);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.empathetic);
      expect(careLines(CareAction.lunch), isNot(contains(c.bubble)));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('at night he says a sleepy line instead of a care line', (
      tester,
    ) async {
      now = DateTime(2026, 11, 22, 23);
      await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.sleepy);
      expect(
        BuddyCopy.sleepyNight.map((l) => BuddyCopy.fill(l, name: 'Bubu')),
        contains(c.bubble),
      );
    });

    testWidgets('a pending welcome is his first line, once', (tester) async {
      final container = await pumpHero(
        tester,
        extra: [
          buddyWelcomeProvider.overrideWith(
            () => _PresetWelcome(BuddyWelcomeNotifier.line),
          ),
        ],
      );
      await tick(tester);

      expect(controller(tester).bubble, BuddyWelcomeNotifier.line);
      expect(container.read(buddyWelcomeProvider), isNull);
    });

    testWidgets('the welcome holds the stage: the first meal\'s follow-up '
        'waits for it', (tester) async {
      // Sign-up: the first meal's event is still pending when the
      // onboarding opens the dashboard.
      visible.value = false;
      buddy = _FakeBuddy(() => _status(streak: 0, savers: 0));
      final container = await pumpHero(
        tester,
        extra: [
          buddyWelcomeProvider.overrideWith(
            () => _PresetWelcome(BuddyWelcomeNotifier.line),
          ),
        ],
      );
      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 1, savers: 0, todayCounted: true));
      await tester.pump();

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tick(tester);
      expect(controller(tester).bubble, BuddyWelcomeNotifier.line);

      // Past the follow-up's delay: still the welcome.
      await tester.pump(const Duration(milliseconds: 700));
      await tick(tester);
      expect(controller(tester).bubble, BuddyWelcomeNotifier.line);

      // Then the thanks for the meal.
      await tester.pump(const Duration(seconds: 4));
      await tick(tester);
      expect(controller(tester).bubble, 'Danke! 🔥 1 Tag');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('announcements pending at first sight: the welcome still '
        'comes first and is taken', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.saverEarned]),
      );
      final container = await pumpHero(
        tester,
        extra: [
          buddyWelcomeProvider.overrideWith(
            () => _PresetWelcome(BuddyWelcomeNotifier.line),
          ),
        ],
      );
      await tick(tester);

      expect(controller(tester).bubble, BuddyWelcomeNotifier.line);
      expect(container.read(buddyWelcomeProvider), isNull);

      await tester.pump(const Duration(seconds: 4));
      await tick(tester);
      expect(controller(tester).bubble, _saverEarnedLine);
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [BuddyAnnouncement.saverEarned]);
    });

    testWidgets('a meal logged 1 h ago → happy', (tester) async {
      entries = _FakeEntries(
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);

      expect(controller(tester).mood, BuddyMood.happy);
    });

    testWidgets('shows the StreakChip with the Buddy status', (tester) async {
      await pumpHero(tester);

      final chip = tester.widget<StreakChip>(find.byType(StreakChip));
      expect(chip.streak, 4);
      expect(chip.todayCounted, isFalse);
    });

    testWidgets('the StreakChip opens „Dein Streak"; „Ziel ändern" sets a '
        'new goal', (tester) async {
      await pumpHero(tester);

      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);
      expect(find.text('Streak-Saver: 1'), findsOneWidget);

      await openGoalList(tester);
      expect(find.text(_pickTitle), findsOneWidget);
      // Streak 4: the next goals.
      expect(find.text('7 Tage'), findsOneWidget);
      expect(find.text('14 Tage'), findsOneWidget);

      await chooseGoal(tester, '14 Tage');

      expect(find.text(_pickTitle), findsNothing);
      expect(buddy.goals, [14]);
    });

    testWidgets('a double tap on the StreakChip opens one sheet', (
      tester,
    ) async {
      await pumpHero(tester);

      await tester.tap(find.byType(StreakChip));
      await tester.tap(find.byType(StreakChip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('the StreakChip is ignored while a reached goal is '
        'celebrated and its sheet is open', (tester) async {
      buddy = _FakeBuddy(
        () => _status(
          streak: 7,
          announcements: const [BuddyAnnouncement.goalReached],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      // Celebrating: a chip tap opens nothing.
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsOneWidget);
      expect(find.text(_sheetTitle), findsNothing);

      await chooseGoal(tester, '14 Tage');
      expect(buddy.goals, [14]);

      // Done: the chip works again.
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('a goal reached while the StreakChip sheet is open does not '
        'stack its own sheet on top', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 7));
      await pumpHero(tester);
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);

      buddy.push(
        _status(
          streak: 7,
          announcements: const [BuddyAnnouncement.goalReached],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_goalTitle), findsNothing);
      expect(find.text(_sheetTitle), findsOneWidget);
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
    });

    testWidgets('no goal left above the streak → „Dein Streak" without '
        '„Ziel ändern"', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 100));
      await pumpHero(tester);

      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);
      expect(find.byKey(StreakSheet.changeGoalKey), findsNothing);
    });

    testWidgets('new user without a Buddy row → chip shows 0 Tage', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 0, savers: 0, hasRow: false));
      await pumpHero(tester);

      expect(find.text('🔥 0 Tage'), findsOneWidget);
      expect(controller(tester).mood, BuddyMood.hungry);
    });

    testWidgets('buddyProvider error → no StreakChip, Buddy still shown', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => throw Exception('no buddy_state table'));
      entries = _FakeEntries(
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      expect(find.byType(StreakChip), findsNothing);
      expect(find.byType(AnimatedBuddy), findsOneWidget);
      final c = controller(tester);
      expect(c.mood, BuddyMood.happy);
      expect(c.bubble, isNotNull);
      expect(c.bubble, isNot(contains('0 Tage')));
      expect(
        tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).name,
        'Buddy',
      );
    });

    testWidgets('uses the Buddy name from the status', (tester) async {
      await pumpHero(tester);

      expect(
        tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).name,
        'Bubu',
      );
    });

    testWidgets('saverUsed → hug and the saver line; marked shown once it '
        'has played', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.saverUsed]),
      );
      final container = await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.currentAction, BuddyAction.hug);
      expect(c.bubble, _saverUsedLine);
      expect(find.text(_saverUsedLine), findsOneWidget);
      // Still pending while it plays: lost if the app closes now.
      expect(buddy.shown, isEmpty);
      expect(container.read(buddyProvider).value!.announcements, [
        BuddyAnnouncement.saverUsed,
      ]);

      // The announcement holds the stage; nothing else is queued.
      await tester.pump(const Duration(seconds: 4));
      expect(buddy.shown, [BuddyAnnouncement.saverUsed]);
      expect(container.read(buddyProvider).value!.announcements, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [BuddyAnnouncement.saverUsed]);
    });

    testWidgets('a status update while an announcement plays does not '
        'replay it', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.saverUsed]),
      );
      await pumpHero(tester);
      await tick(tester);
      expect(controller(tester).bubble, _saverUsedLine);

      // A refresh lands mid-line, the announcement still pending.
      await tester.pump(const Duration(seconds: 2));
      buddy.push(_status(announcements: const [BuddyAnnouncement.saverUsed]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tick(tester);

      expect(buddy.shown, [BuddyAnnouncement.saverUsed]);
      // A replay would be marked again once its line ended.
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [BuddyAnnouncement.saverUsed]);
    });

    testWidgets('streakBroken then saverEarned play one after another', (
      tester,
    ) async {
      buddy = _FakeBuddy(
        () => _status(
          announcements: const [
            BuddyAnnouncement.streakBroken,
            BuddyAnnouncement.saverEarned,
          ],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.bubble, _streakBrokenLine);
      expect(buddy.shown, isEmpty);

      await tester.pump(const Duration(seconds: 4));
      await tick(tester);
      expect(c.bubble, _saverEarnedLine);
      expect(c.currentAction, BuddyAction.celebrate);
      expect(buddy.shown, [BuddyAnnouncement.streakBroken]);
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [
        BuddyAnnouncement.streakBroken,
        BuddyAnnouncement.saverEarned,
      ]);
    });

    testWidgets('goalReached → celebrate in love, then the new-goal sheet', (
      tester,
    ) async {
      buddy = _FakeBuddy(
        () => _status(
          streak: 7,
          announcements: const [BuddyAnnouncement.goalReached],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.currentAction, BuddyAction.celebrate);
      expect(c.mood, BuddyMood.inLove);
      expect(buddy.shown, isEmpty);

      // The sheet opens once the celebration has played.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsOneWidget);
      expect(buddy.shown, isEmpty);

      await chooseGoal(tester, '14 Tage');

      expect(find.text(_goalTitle), findsNothing);
      expect(buddy.goals, [14]);
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
      expect(c.mood, BuddyMood.hungry);
    });

    testWidgets('goalReached → dismissing the sheet sets no goal', (
      tester,
    ) async {
      buddy = _FakeBuddy(
        () => _status(
          streak: 7,
          announcements: const [BuddyAnnouncement.goalReached],
        ),
      );
      await pumpHero(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // modal barrier
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_goalTitle), findsNothing);
      expect(buddy.goals, isEmpty);
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
    });

    testWidgets('fresh log that counts today → „Danke! 🔥 N Tage"', (
      tester,
    ) async {
      final container = await pumpHero(tester);

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      expect(container.read(buddyEventsProvider), isNull);

      // The tracker's save reloads today's entries.
      entries.push(EntriesState(meals: [testMealEntry(trackedAt: now)]));
      await tester.pump();
      expect(controller(tester).mood, BuddyMood.happy);

      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);
      expect(controller(tester).bubble, 'Danke! 🔥 5 Tage');
      expect(find.text('Danke! 🔥 5 Tage'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a slow refresh: the follow-up waits for it and thanks', (
      tester,
    ) async {
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      buddy
        ..refreshDelay = const Duration(milliseconds: 1500)
        ..afterRefresh = _status(streak: 5, todayCounted: true);

      emit(container, LogSentiment.good);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);
      // Still refreshing: nothing said yet.
      expect(controller(tester).bubble, isNull);

      await tester.pump(const Duration(seconds: 1));
      await tick(tester);
      expect(controller(tester).bubble, 'Danke! 🔥 5 Tage');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a refresh slower than 3 s: the follow-up goes on without it', (
      tester,
    ) async {
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      buddy
        ..refreshDelay = const Duration(seconds: 10)
        ..afterRefresh = _status(streak: 5, todayCounted: true);

      emit(container, LogSentiment.good);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 3));
      await tick(tester);

      final c = controller(tester);
      expect(c.bubble, isNotNull);
      expect(c.bubble, isNot(startsWith('Danke!')));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('first counted day → „Danke! 🔥 1 Tag"', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 0, savers: 0));
      final container = await pumpHero(tester);

      emit(container, LogSentiment.neutral);
      buddy.push(_status(streak: 1, savers: 0, todayCounted: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      expect(controller(tester).bubble, 'Danke! 🔥 1 Tag');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('another log on a counted day → follow-up is the mood line', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 5, todayCounted: true));
      final container = await pumpHero(tester);

      emit(container, LogSentiment.good);
      await tester.pump();
      entries.push(EntriesState(meals: [testMealEntry(trackedAt: now)]));
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.happy);
      expect(c.bubble, isNot(startsWith('Danke!')));
      // Lunch logged at 14:00: he asks for a drink next.
      expect(careLines(CareAction.drink), contains(c.bubble));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a mood change during the follow-up delay says nothing extra', (
      tester,
    ) async {
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      await tick(tester);
      expect(controller(tester).bubble, isNull);

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      // The log's entries land while the follow-up waits.
      entries.push(EntriesState(meals: [testMealEntry(trackedAt: now)]));
      await tick(tester);

      // Mood flipped to happy, but the bubble waits for the follow-up.
      expect(controller(tester).mood, BuddyMood.happy);
      expect(controller(tester).bubble, isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a bad log → empathetic while on the dashboard', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 5, todayCounted: true));
      final container = await pumpHero(tester);

      emit(container, LogSentiment.bad);
      await tester.pump();
      expect(controller(tester).mood, BuddyMood.empathetic);

      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);
      expect(
        BuddyCopy.mood[BuddyMood.empathetic],
        contains(controller(tester).bubble),
      );

      // Leaving the dashboard ends the visit: back to the care mood.
      visible.value = false;
      await tester.pump();
      expect(controller(tester).mood, BuddyMood.hungry);
      visible.value = true;
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a stale event (older than 2 min) is dropped silently; '
        "today's entries don't depend on it", (tester) async {
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone

      emit(
        container,
        LogSentiment.good,
        at: now.subtract(const Duration(minutes: 3)),
      );
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      expect(container.read(buddyEventsProvider), isNull);
      expect(controller(tester).bubble, isNull);
      // The log's own write reloaded today's entries already.
      expect(entries.loaded, isEmpty);
    });

    testWidgets('an event while hidden waits until the hero is visible', (
      tester,
    ) async {
      final container = await pumpHero(tester);
      visible.value = false;
      await tester.pump();

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(buddyEventsProvider), isNotNull);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      expect(container.read(buddyEventsProvider), isNull);
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);
      expect(controller(tester).bubble, 'Danke! 🔥 5 Tage');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('announcements wait until the hero is visible', (tester) async {
      final container = await pumpHero(tester);
      visible.value = false;
      await tester.pump();

      buddy.push(_status(announcements: const [BuddyAnnouncement.saverEarned]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(buddy.shown, isEmpty);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tick(tester);
      expect(controller(tester).bubble, _saverEarnedLine);
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [BuddyAnnouncement.saverEarned]);
      expect(container.read(buddyProvider).value!.announcements, isEmpty);
    });

    testWidgets('mounted hidden (e.g. under the splash): greets once shown', (
      tester,
    ) async {
      visible.value = false;
      await pumpHero(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(controller(tester).bubble, isNull);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tick(tester);

      final c = controller(tester);
      expect(careLines(CareAction.lunch), contains(c.bubble));
    });

    testWidgets('mounted hidden: announcements play once shown, no greeting', (
      tester,
    ) async {
      visible.value = false;
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.saverUsed]),
      );
      await pumpHero(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(controller(tester).bubble, isNull);
      expect(buddy.shown, isEmpty);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tick(tester);

      expect(controller(tester).bubble, _saverUsedLine);
      await tester.pump(const Duration(seconds: 5));
      expect(controller(tester).bubble, _saverUsedLine);
      expect(buddy.shown, [BuddyAnnouncement.saverUsed]);
    });

    testWidgets('goal sheet waits while the hero is hidden', (tester) async {
      buddy = _FakeBuddy(
        () => _status(
          streak: 7,
          announcements: const [BuddyAnnouncement.goalReached],
        ),
      );
      await pumpHero(tester);
      visible.value = false;
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsNothing);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsOneWidget);

      await chooseGoal(tester, '30 Tage');
      expect(buddy.goals, [30]);
    });

    testWidgets('the ring follows the screen (clamped)', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHero(tester);

      // min(260, 393 × 0.72, 852 × 0.3) = 255.6
      expect(
        tester.getSize(find.byType(CareRing)).height,
        moreOrLessEquals(255.6),
      );
      expect(
        tester.getSize(find.byType(AnimatedBuddy)).height,
        greaterThanOrEqualTo(180),
      );
    });

    testWidgets('mood is re-derived every minute', (tester) async {
      now = DateTime(2026, 11, 22, 9, 59);
      await pumpHero(tester);
      expect(controller(tester).mood, BuddyMood.sleepy);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      expect(controller(tester).bubble, isNull);

      now = DateTime(2026, 11, 22, 10);
      await tester.pump(const Duration(minutes: 1));
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.hungry);
      // Still before 10:30: breakfast.
      expect(careLines(CareAction.breakfast), contains(c.bubble));
    });

    testWidgets('the slot changes with the clock: button follows', (
      tester,
    ) async {
      now = DateTime(2026, 11, 22, 10, 29);
      await pumpHero(tester);
      expect(find.text('🍳 Frühstück eintragen'), findsOneWidget);

      now = DateTime(2026, 11, 22, 10, 30);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(find.text('🍝 Mittagessen eintragen'), findsOneWidget);
    });

    testWidgets('hidden, the minute ticks wait; shown again, he catches up '
        'without a line', (tester) async {
      now = DateTime(2026, 11, 22, 10, 29);
      await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      visible.value = false;
      await tester.pump();

      now = DateTime(2026, 11, 22, 10, 30);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('🍳 Frühstück eintragen'), findsOneWidget);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tick(tester);
      expect(find.text('🍝 Mittagessen eintragen'), findsOneWidget);
      expect(controller(tester).bubble, isNull);
    });

    testWidgets('resumed the next morning: the ring and its Tagebuch tap '
        'move to the new day together', (tester) async {
      now = DateTime(2026, 11, 22, 21);
      entries = _FakeEntries(
        EntriesState(
          day: DateTime(2026, 11, 22),
          meals: [
            testMealEntry(
              trackedAt: DateTime(2026, 11, 22, 19),
              title: 'Abendbrot',
            ),
          ],
        ),
      );
      final container = await pumpHero(tester);
      expect(find.text('🍽 1/3'), findsOneWidget);

      now = DateTime(2026, 11, 23, 8);
      entries.next = const EntriesState(); // nothing logged yet today
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(entries.loaded.map(startOfDay), [DateTime(2026, 11, 23)]);
      expect(find.text('🍽 0/3'), findsOneWidget);

      await tester.tap(find.byKey(CareRing.needKey(CareNeed.food)));
      await tester.pump();
      expect(location(), RoutePaths.diary);
      expect(container.read(diaryDateProvider), DateTime(2026, 11, 23));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('open across midnight: the minute tick loads the new day', (
      tester,
    ) async {
      now = DateTime(2026, 11, 22, 23, 59);
      entries = _FakeEntries(
        EntriesState(
          day: DateTime(2026, 11, 22),
          meals: [
            testMealEntry(
              trackedAt: DateTime(2026, 11, 22, 19),
              title: 'Abendbrot',
            ),
          ],
        ),
      );
      await pumpHero(tester);
      expect(find.text('🍽 1/3'), findsOneWidget);

      now = DateTime(2026, 11, 23, 0, 0, 30);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(entries.loaded.map(startOfDay), [DateTime(2026, 11, 23)]);
      expect(find.text('🍽 0/3'), findsOneWidget);
    });

    testWidgets('the next-action button opens its tracker', (tester) async {
      await pumpHero(tester);

      await tester.tap(find.byKey(BuddyHero.actionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('page:${RoutePaths.mealTracker}'), findsOneWidget);
    });

    testWidgets('next-action button opens the suggested tracker', (
      tester,
    ) async {
      // Before 05:00 no meal is due; with nothing logged, a drink is.
      now = DateTime(2026, 11, 22, 4);
      await pumpHero(tester);
      expect(find.text('💧 Trinken eintragen'), findsOneWidget);

      await tester.tap(find.byKey(BuddyHero.actionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(location(), RoutePaths.drinkTracker);
      expect(find.text('page:${RoutePaths.drinkTracker}'), findsOneWidget);
    });

    testWidgets('ring tap opens the Tagebuch on today', (tester) async {
      final container = await pumpHero(tester);
      container.read(diaryDateProvider.notifier).set(DateTime(2026, 11, 18));

      // The ring's top edge, clear of the Buddy inside it.
      final ring = tester.getRect(find.byKey(CareRing.tapKey));
      await tester.tapAt(ring.topCenter + const Offset(0, 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(location(), RoutePaths.diary);
      expect(find.text('diary-page'), findsOneWidget);
      expect(container.read(diaryDateProvider), startOfDay(now));
    });

    testWidgets('tapping the Buddy pokes, no navigation', (tester) async {
      await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      expect(controller(tester).bubble, isNull);

      await tester.tap(find.byType(AnimatedBuddy));
      await tick(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(location(), RoutePaths.dashboard);
      expect(find.text('diary-page'), findsNothing);
      // 14:00, nothing eaten: his lunch line.
      expect(careLines(CareAction.lunch), contains(controller(tester).bubble));
    });

    testWidgets('no week row on Home: it lives in „Dein Streak"', (
      tester,
    ) async {
      await pumpHero(tester);

      expect(find.byType(StreakChip), findsOneWidget);
      expect(find.byType(StreakWeekRow), findsNothing);
    });
  });
}
