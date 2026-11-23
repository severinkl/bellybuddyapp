// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';

import '../../../helpers/fixtures.dart';

/// [BuddyNotifier] serving a fixed first result; records the hero's calls.
class _FakeBuddy extends BuddyNotifier {
  _FakeBuddy(this._initial);

  final FutureOr<BuddyStatus?> Function() _initial;

  /// Every announcement the hero marked as shown, in order.
  final List<BuddyAnnouncement> shown = [];
  int refreshCalls = 0;

  /// How long [refresh] takes, then it publishes [afterRefresh] (if set):
  /// a slow backend.
  Duration refreshDelay = Duration.zero;
  BuddyStatus? afterRefresh;
  final List<int?> goals = [];

  @override
  Future<BuddyStatus?> build() async => _initial();

  @override
  Future<void> refresh() async {
    refreshCalls++;
    if (refreshDelay > Duration.zero) await Future<void>.delayed(refreshDelay);
    final next = afterRefresh;
    if (next != null) push(next);
  }

  @override
  Future<void> setStreakGoal(int? goal) async => goals.add(goal);

  @override
  Future<void> markAnnouncementsShown(List<BuddyAnnouncement> announcements) {
    shown.addAll(announcements);
    return super.markAnnouncementsShown(announcements);
  }

  /// Publishes [status] like a finished refresh.
  void push(BuddyStatus status) => state = AsyncData(status);
}

/// [EntriesNotifier] with a seeded state; [loadEntries] swaps in [next].
class _FakeEntries extends EntriesNotifier {
  _FakeEntries(this._initial);

  final EntriesState _initial;
  EntriesState? next;
  int loads = 0;

  @override
  EntriesState build() => _initial;

  @override
  Future<void> loadEntries(DateTime date) async {
    loads++;
    final n = next;
    if (n != null) state = n;
  }
}

BuddyStatus _status({
  int streak = 4,
  bool todayCounted = false,
  int savers = 1,
  bool hasRow = true,
  List<BuddyAnnouncement> announcements = const [],
}) => BuddyStatus(
  state: BuddyState(userId: 'u1', name: 'Bubu', savers: savers),
  hasRow: hasRow,
  streak: streak,
  todayCounted: todayCounted,
  announcements: announcements,
);

const _saverUsedLine = 'Puh! Dein Streak-Saver hat uns gestern gerettet 🛡';
const _streakBrokenLine = 'Neuer Anlauf — ich bin dabei!';
const _saverEarnedLine = 'Du hast einen Streak-Saver verdient! 🛡';
const _goalTitle = "Wir haben's geschafft! Neues Ziel?";

void main() {
  late DateTime now;
  late _FakeBuddy buddy;
  late _FakeEntries entries;
  late ValueNotifier<bool> visible;

  setUp(() {
    // This directory's flutter_test_config.dart stops Buddy tickers; the
    // hero's bubble and actions need them.
    AnimatedBuddy.tickerEnabled = true;
    now = DateTime(2026, 11, 22, 14);
    buddy = _FakeBuddy(() => _status());
    entries = _FakeEntries(const EntriesState());
    visible = ValueNotifier(true);
  });

  tearDown(() {
    visible.dispose();
    AnimatedBuddy.tickerEnabled = false;
  });

  /// Pumps the hero on `/` of a router with a `/meal-tracker` stub page;
  /// `TickerMode` follows [visible].
  Future<ProviderContainer> pumpHero(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    final container = ProviderContainer.test(
      overrides: [
        buddyClockProvider.overrideWithValue(() => now),
        buddyProvider.overrideWith(() => buddy),
        entriesProvider.overrideWith(() => entries),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, on, child) => TickerMode(enabled: on, child: child!),
              child: const SingleChildScrollView(child: BuddyHero()),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.mealTracker,
          builder: (_, _) => const Scaffold(body: Text('meal-tracker-page')),
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
    // Buddy load, first-frame callbacks and a few Buddy ticks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

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

  void emit(ProviderContainer c, LogSentiment sentiment, {DateTime? at}) => c
      .read(buddyEventsProvider.notifier)
      .emit(BuddyLogEvent(EntryKind.meal, sentiment, at: at ?? now));

  group('BuddyHero', () {
    testWidgets('renders the animated Buddy and the Füttern button', (
      tester,
    ) async {
      await pumpHero(tester);

      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(find.text('🍎 Füttern'), findsOneWidget);
    });

    testWidgets('no entries at 14:00 → hungry, greets with a hungry line', (
      tester,
    ) async {
      await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.hungry);
      expect(BuddyCopy.mood[BuddyMood.hungry], contains(c.bubble));
      expect(find.text(c.bubble!), findsOneWidget);
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

    testWidgets('tapping the StreakChip lets the user set a new goal', (
      tester,
    ) async {
      await pumpHero(tester);

      await tester.tap(find.byType(StreakChip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Neues Streak-Ziel'), findsOneWidget);
      // Streak 4: the next three goals.
      expect(find.text('7 Tage'), findsOneWidget);
      expect(find.text('30 Tage'), findsOneWidget);

      await tester.tap(find.text('14 Tage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Neues Streak-Ziel'), findsNothing);
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

      expect(find.text('Neues Streak-Ziel'), findsOneWidget);
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
      await tester.tap(find.byType(StreakChip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Neues Streak-Ziel'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsOneWidget);
      expect(find.text('Neues Streak-Ziel'), findsNothing);

      await tester.tap(find.text('14 Tage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(buddy.goals, [14]);

      // Done: the chip works again.
      await tester.tap(find.byType(StreakChip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Neues Streak-Ziel'), findsOneWidget);
    });

    testWidgets('a goal reached while the StreakChip sheet is open does not '
        'stack its own sheet on top', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 7));
      await pumpHero(tester);
      await tester.tap(find.byType(StreakChip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Neues Streak-Ziel'), findsOneWidget);

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
      expect(find.text('Neues Streak-Ziel'), findsOneWidget);
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
    });

    testWidgets('no goal left above the streak → the chip is no button', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 100));
      await pumpHero(tester);

      expect(tester.widget<StreakChip>(find.byType(StreakChip)).onTap, isNull);
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

      await tester.tap(find.text('14 Tage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
      entries.next = EntriesState(meals: [testMealEntry(trackedAt: now)]);

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();

      expect(container.read(buddyEventsProvider), isNull);
      expect(entries.loads, 1);
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
      entries.next = EntriesState(meals: [testMealEntry(trackedAt: now)]);

      emit(container, LogSentiment.good);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.happy);
      expect(c.bubble, isNot(startsWith('Danke!')));
      expect([
        ...BuddyCopy.mood[BuddyMood.happy]!.map(_fill),
      ], contains(c.bubble));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a mood change during the follow-up delay says nothing extra', (
      tester,
    ) async {
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      await tick(tester);
      expect(controller(tester).bubble, isNull);
      entries.next = EntriesState(meals: [testMealEntry(trackedAt: now)]);

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
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

    testWidgets('a stale event (older than 2 min) is dropped silently', (
      tester,
    ) async {
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
      expect(entries.loads, 0);
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
      expect(BuddyCopy.mood[BuddyMood.hungry], contains(c.bubble));
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

      await tester.tap(find.text('30 Tage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(buddy.goals, [30]);
    });

    testWidgets('height follows the screen (clamped)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHero(tester);

      expect(
        tester.getSize(find.byType(BuddyHero)).height,
        moreOrLessEquals(844 * 0.47),
      );
      expect(
        tester.getSize(find.byType(AnimatedBuddy)).height,
        greaterThanOrEqualTo(200),
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
      expect(BuddyCopy.mood[BuddyMood.hungry], contains(c.bubble));
    });

    testWidgets('tapping „Füttern" pushes the meal tracker', (tester) async {
      await pumpHero(tester);

      await tester.tap(find.text('🍎 Füttern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('meal-tracker-page'), findsOneWidget);
    });
  });
}

/// A happy pool line as `moodLine` fills it for Bubu with streak 5.
String _fill(String line) => BuddyCopy.fill(line, name: 'Bubu', streak: 5);
