// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/buddy_welcome_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/first_tip_provider.dart';
import 'package:belly_buddy/providers/home_cover_provider.dart';
import 'package:belly_buddy/providers/journey_provider.dart';
import 'package:belly_buddy/providers/journey_rewards_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/buddy_hero.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/home_flame.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:belly_buddy/screens/dashboard/widgets/first_tip_offer_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_day_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_reward_list_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/streak_sheet.dart';
import 'package:belly_buddy/screens/dashboard/widgets/weekly_tips_offer_sheet.dart';
import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/need_icon.dart';
import 'package:belly_buddy/widgets/buddy/streak_badge.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';

import '../../../helpers/app_lifecycle.dart';
import '../../../helpers/ambient_animations.dart';
import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/flames.dart';
import '../../../helpers/riverpod_helpers.dart';
import '../../../helpers/widget_tester_helpers.dart';

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

  /// Whether [setStreakGoal] publishes the new goal, as the real one does
  /// (the pending announcements kept).
  bool publishGoals = false;

  @override
  Future<void> setStreakGoal(int? goal) async {
    await super.setStreakGoal(goal);
    final s = state.value;
    if (!publishGoals || s == null) return;
    push(
      BuddyStatus(
        state: s.state.copyWith(streakGoal: goal),
        hasRow: true,
        streak: s.streak,
        todayCounted: s.todayCounted,
        weekDays: s.weekDays,
        announcements: s.announcements,
        announcementKeys: s.announcementKeys,
      ),
    );
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
  Future<void> loadEntries(DateTime date, {bool refreshLatest = false}) async {
    loaded.add(date);
    state = (next ?? state).copyWith(day: startOfDay(date));
  }

  /// A write's reload lands: today's entries are [s] now.
  void push(EntriesState s) => state = s;
}

BuddyStatus _status({
  int streak = 4,
  int? goal,
  bool todayCounted = false,
  int savers = 1,
  bool hasRow = true,
  List<BuddyAnnouncement> announcements = const [],
  Map<BuddyAnnouncement, String> announcementKeys = const {},
}) => buddyStatus(
  savers: savers,
  hasRow: hasRow,
  streak: streak,
  goal: goal,
  todayCounted: todayCounted,
  announcements: announcements,
  announcementKeys: announcementKeys,
);

const _saverUsedLine = 'Puh! Dein Streak-Saver hat uns gestern gerettet 🛡';
const _streakBrokenLine = 'Neuer Anlauf — ich bin dabei!';
const _saverEarnedLine = 'Du hast einen Streak-Saver verdient! 🛡';
const _goalTitle = "Wir haben's geschafft! Neues Ziel?";
const _tipsArrivedLine = 'Neue Tipps sind da! ✨';
const _sheetTitle = 'Dein Streak';
const _rewardsButton = Key('open_rewards');
const _logButton = Key('open_log_sheet');
const _pickTitle = 'Neues Streak-Ziel';

/// The first tip's failure line while the weekly tips are off (the hero's
/// default here).
final _firstTipFailedLine = JourneyCopy.firstTipFailed(weeklyTipsOn: false);

void main() {
  late DateTime now;
  late _FakeBuddy buddy;
  late _FakeEntries entries;
  late ValueNotifier<bool> visible;

  /// Whether Home holds the hero; false disposes it, while a sheet it opened
  /// stays open.
  late ValueNotifier<bool> heroShown;
  late GoRouter router;

  /// What [unseenTipSetProvider] and [weeklyTipsEnabledProvider] hold; the
  /// latter switchable once pumped ([weeklyTipsSwitch]).
  late Recommendation? unseenTipSet;
  late bool? weeklyTips;
  late NotifierProvider<Switchable<bool?>, bool?> weeklyTipsSwitch;

  /// Whether the user is on the journey, their rewards (kept in memory)
  /// and the first tip's notifier.
  late bool? journey;
  late JourneyRewards? rewards;
  late FakeFirstTipNotifier firstTip;

  /// The links the hero opened (day 2's article).
  late RecordingUrlOpener opener;

  /// Whether the router sends „Muster frei!" elsewhere (to the Tagebuch),
  /// as a gate's redirect does.
  late bool redirectUnlocked;

  // The hero's bubble and actions need ticking Buddies.
  tickBuddiesInTests();

  setUp(() {
    now = DateTime(2026, 11, 22, 14);
    buddy = _FakeBuddy(() => _status());
    entries = _FakeEntries(const EntriesState());
    visible = ValueNotifier(true);
    heroShown = ValueNotifier(true);
    unseenTipSet = null;
    weeklyTips = false;
    journey = false;
    rewards = null;
    firstTip = FakeFirstTipNotifier();
    opener = RecordingUrlOpener();
    redirectUnlocked = false;
  });

  tearDown(() {
    visible.dispose();
    heroShown.dispose();
  });

  /// Pumps the hero on Home (`/dashboard`) of a router with stub pages for
  /// the Tagebuch, the trackers and Entdecken; `TickerMode` follows
  /// [visible]. Below the hero, a button opens „Deine Belohnungen" as the
  /// journey card's line does ([openRewards]).
  Future<ProviderContainer> pumpHero(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    weeklyTipsSwitch = NotifierProvider<Switchable<bool?>, bool?>(
      () => Switchable(weeklyTips),
    );
    final container = ProviderContainer.test(
      overrides: [
        buddyClockProvider.overrideWithValue(() => now),
        currentUserIdProvider.overrideWithValue('u1'),
        buddyProvider.overrideWith(() => buddy),
        entriesProvider.overrideWith(() => entries),
        unseenTipSetProvider.overrideWithValue(unseenTipSet),
        weeklyTipsEnabledProvider.overrideWith(
          (ref) => ref.watch(weeklyTipsSwitch),
        ),
        journeySeededWith(journey),
        journeyRewardsSeededWith(rewards),
        firstTipProvider.overrideWith(() => firstTip),
        recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    final rootNavigator = GlobalKey<NavigatorState>();
    router = GoRouter(
      navigatorKey: rootNavigator,
      observers: [
        HomeCoverObserver(
          () => container.read(homeCoveredProvider.notifier),
          navigators: [rootNavigator],
        ),
      ],
      initialLocation: RoutePaths.dashboard,
      redirect: (_, state) =>
          redirectUnlocked &&
              state.matchedLocation == RoutePaths.patternsUnlocked
          ? RoutePaths.diary
          : null,
      routes: [
        GoRoute(
          path: RoutePaths.dashboard,
          builder: (_, _) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, on, child) => TickerMode(enabled: on, child: child!),
              child: ValueListenableBuilder<bool>(
                valueListenable: heroShown,
                builder: (_, shown, _) => shown
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            BuddyHero(openUrl: opener.call),
                            Consumer(
                              builder: (context, ref, _) => TextButton(
                                key: _rewardsButton,
                                onPressed: () => showJourneyRewardListSheet(
                                  context,
                                  ref,
                                  openUrl: opener.call,
                                ),
                                child: const Text('Belohnungen'),
                              ),
                            ),
                            // The bottom bar's „Eintragen" (its sheet on the
                            // root navigator, as in the app).
                            Builder(
                              builder: (context) => TextButton(
                                key: _logButton,
                                onPressed: () => showLogSheet(
                                  context,
                                  day: startOfDay(now),
                                  now: now,
                                ),
                                child: const Text('Eintragen'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
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
          RoutePaths.discover,
          RoutePaths.discoverRecipes,
          RoutePaths.collectionRecipe,
          RoutePaths.recommendations,
          RoutePaths.patterns,
          RoutePaths.patternsUnlocked,
          RoutePaths.settingsNotifications,
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

  /// The sticker icon leading the next-action button.
  NeedIcon actionIcon(WidgetTester tester) => tester.widget<NeedIcon>(
    find.descendant(
      of: find.byKey(BuddyHero.actionKey),
      matching: find.byType(NeedIcon),
    ),
  );

  /// The streak flame behind the Buddy (not its badge's).
  Finder flameFinder() => find.descendant(
    of: find.byType(HomeFlame),
    matching: find.byType(StreakFlame),
  );

  /// The painter of the streak flame behind the Buddy.
  FlamePainter homeFlame(WidgetTester tester) =>
      flamePainter(tester, flameFinder());

  /// What he says, also while a page covers Home.
  String? bubbleBehind(WidgetTester tester) => tester
      .widget<AnimatedBuddy>(find.byType(AnimatedBuddy, skipOffstage: false))
      .controller
      .bubble;

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

  /// Opens „Deine Belohnungen" from Home, as the journey card's line does.
  Future<void> openRewards(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(_rewardsButton));
    await tester.tap(find.byKey(_rewardsButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Taps the StreakBadge and lets „Dein Streak" open.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(StreakBadge));
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

  /// Lets a celebration play and the sheet that follows it open.
  Future<void> afterCelebration(WidgetTester tester) async {
    await tester.pump(buddyActionDuration(BuddyAction.celebrate));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Lets the wave play and the offer that follows it open.
  Future<void> afterWave(WidgetTester tester) async {
    await tester.pump(buddyActionDuration(BuddyAction.wave));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Taps [key] in the open weekly-tips offer and lets it close.
  Future<void> closeOffer(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
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

  /// The 22nd with a drink at 12:00 and a Bauchgefühl at 08:00, plus
  /// [meals]: at 14:00 with nothing eaten he is hungry for lunch, a meal
  /// makes him happy (Trinken at 43 % is then the lowest).
  EntriesState beforeLunch({List<MealEntry> meals = const []}) => EntriesState(
    meals: meals,
    drinks: [testDrinkEntry(trackedAt: DateTime(2026, 11, 22, 12))],
    gutFeelings: [testGutFeelingEntry(trackedAt: DateTime(2026, 11, 22, 8))],
  );

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
      // 14:00, nothing eaten: lunch, led by the Essen sticker.
      expect(find.text('Mittagessen eintragen'), findsOneWidget);
      expect(find.byKey(BuddyHero.actionKey), findsOneWidget);
      expect(actionIcon(tester).need, CareNeed.food);
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
      expect(find.text('Trinken eintragen'), findsOneWidget);
      expect(actionIcon(tester).need, CareNeed.drink);
      expect(
        tester.widget<CareRing>(find.byType(CareRing)).highlight,
        CareNeed.drink,
      );
      // Lunch an hour ago: Essen well filled.
      expect(
        needMeterLevel(tester, CareNeed.food),
        greaterThan(AppConstants.careMeterHigh),
      );
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

    testWidgets('every load reaches the ring at once: its loading step, '
        'then the day (no minute tick needed)', (tester) async {
      await pumpHero(tester);
      final day = DateTime(2026, 11, 22);
      // Two loads: Riverpod tells the hero and the care log in an order
      // that alternates, so both orders are covered.
      for (final (meal, level) in [
        (DateTime(2026, 11, 22, 13), 0.83),
        (DateTime(2026, 11, 22, 13, 30), 0.915),
      ]) {
        entries.push(EntriesState(isLoading: true, day: day));
        await tester.pump();
        entries.push(
          EntriesState(
            day: day,
            meals: [testMealEntry(trackedAt: meal)],
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400)); // meter fills

        expect(
          needMeterLevel(tester, CareNeed.food),
          closeTo(level, 0.005),
          reason: '$meal',
        );
      }
    });

    testWidgets('meal 1 h ago, drink 2 h ago, Bauchgefühl this morning → '
        'happy', (tester) async {
      entries = _FakeEntries(
        beforeLunch(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);

      expect(controller(tester).mood, BuddyMood.happy);
    });

    testWidgets('no streak chip on Home: the StreakBadge at the flame, with '
        'the Buddy status', (tester) async {
      await pumpHero(tester);

      expect(find.byType(StreakChip), findsNothing);
      final badge = tester.widget<StreakBadge>(find.byType(StreakBadge));
      expect(badge.streak, 4);
      expect(badge.lit, isFalse);
      // In the ring, over him (the hero has no row above the ring).
      expect(
        find.descendant(
          of: find.byType(CareRing),
          matching: find.byType(StreakBadge),
        ),
        findsOneWidget,
      );

      buddy.push(_status(streak: 0));
      await tester.pump();
      expect(tester.widget<StreakBadge>(find.byType(StreakBadge)).streak, 0);
    });

    for (final (name, size, scale) in [
      ('402×874', const Size(402 - 48, 874), 1.0),
      ('375×667 at text scale 1.3', const Size(375 - 48, 667), 1.3),
      ('375×667 at text scale 2', const Size(375 - 48, 667), 2.0),
    ]) {
      for (final streak in [5, 128]) {
        testWidgets('$name, streak $streak: the badge sits at the flame\'s '
            'lower right, next to his feet, clear of the need bubbles', (
          tester,
        ) async {
          // The hero's width on that phone (the harness has no side padding).
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          buddy = _FakeBuddy(() => _status(streak: streak, todayCounted: true));
          await pumpHero(tester);

          final badge = tester.getRect(find.byType(StreakBadge));
          final flame = tester.getRect(flameFinder());
          final square = tester.getRect(find.byKey(CareRing.buddyKey));
          final ring = tester.getRect(find.byType(CareRing));
          final base = flame.bottom - flame.height * FlamePainter.baseInset;
          // At its lower right: its right edge, its base.
          expect(badge.right, moreOrLessEquals(flame.right));
          expect(badge.center.dy, moreOrLessEquals(base));
          expect(badge.left, greaterThan(square.left));
          // Next to his feet, in the ring.
          expect(badge.top, greaterThan(square.center.dy));
          expect(badge.bottom, lessThanOrEqualTo(ring.bottom));
          for (final need in CareNeed.values) {
            expect(
              badge.overlaps(
                tester.getRect(find.byKey(CareRing.needKey(need))),
              ),
              isFalse,
              reason: '$need',
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets("the flame glows behind the Buddy: Home's flame for the "
        "streak and today, placed by the ring's square and middle, under "
        'him', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 42, todayCounted: true));
      await pumpHero(tester);

      final flame = tester.widget<HomeFlame>(find.byType(HomeFlame));
      expect(flame.streak, 42);
      expect(flame.lit, isTrue);
      final ring = tester.getRect(find.byType(CareRing));
      expect(
        flame.buddy.shift(ring.topLeft),
        rectMoreOrLessEquals(tester.getRect(find.byKey(CareRing.buddyKey))),
      );
      expect(
        flame.middle.shift(ring.topLeft).center,
        offsetMoreOrLessEquals(ring.center),
      );

      // Painted before him, so under him.
      expect(
        find
            .descendant(
              of: find.byType(CareRing),
              matching: find.byWidgetPredicate(
                (w) => w is HomeFlame || w is AnimatedBuddy,
              ),
            )
            .evaluate()
            .map((e) => e.widget.runtimeType),
        [HomeFlame, AnimatedBuddy],
      );
    });

    testWidgets("glimmt before today's first entry, brennt after; streak 0 "
        'an ember', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 5));
      await pumpHero(tester);
      expect(homeFlame(tester).look, FlameLook.ember);
      expect(tester.widget<StreakFlame>(flameFinder()).streak, 5);

      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      expect(homeFlame(tester).look, FlameLook.lit);

      buddy.push(_status(streak: 0));
      await tester.pump();
      expect(homeFlame(tester).look, FlameLook.ember);
    });

    testWidgets('an entry while Home is covered ignites it once Home shows '
        'again', (tester) async {
      await pumpHero(tester);

      visible.value = false;
      buddy.push(_status(todayCounted: true));
      await tester.pump(const Duration(seconds: 1));
      expect(homeFlame(tester).burst, isNull);

      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(homeFlame(tester).burst, greaterThan(0));
    });

    testWidgets('the StreakBadge opens „Dein Streak"; „Ziel ändern" sets a '
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

    testWidgets('a double tap on the StreakBadge opens one sheet', (
      tester,
    ) async {
      await pumpHero(tester);

      await tester.tap(find.byType(StreakBadge));
      await tester.tap(find.byType(StreakBadge));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('the StreakBadge is ignored while a reached goal is '
        'celebrated and its sheet is open', (tester) async {
      buddy = _FakeBuddy(
        () => _status(
          streak: 7,
          announcements: const [BuddyAnnouncement.goalReached],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      // Celebrating: a badge tap opens nothing.
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_goalTitle), findsOneWidget);
      expect(find.text(_sheetTitle), findsNothing);

      await chooseGoal(tester, '14 Tage');
      expect(buddy.goals, [14]);

      // Done: the badge works again.
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('a goal reached while the StreakBadge sheet is open does not '
        'stack its own sheet on top: it waits until that closed', (
      tester,
    ) async {
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
      expect(buddy.shown, isEmpty);

      await tester.tapAt(const Offset(10, 10)); // „Dein Streak"'s barrier
      await tester.pump();
      await tester.pump();
      await afterCelebration(tester);

      expect(find.text(_sheetTitle), findsNothing);
      expect(find.text(_goalTitle), findsOneWidget);
      await chooseGoal(tester, '14 Tage');
      expect(buddy.goals, [14]);
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
    });

    testWidgets('a goal reached while „Dein Streak" is open, and a new goal '
        'picked there: no celebration, nor a second goal sheet', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 7, goal: 7))
        ..publishGoals = true;
      await pumpHero(tester);
      await openSheet(tester);

      buddy.push(
        _status(
          streak: 7,
          goal: 7,
          announcements: const [BuddyAnnouncement.goalReached],
          announcementKeys: {
            BuddyAnnouncement.goalReached: '${testUserId}_goalReached_7',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(buddy.shown, isEmpty);

      await openGoalList(tester);
      await chooseGoal(tester, '14 Tage');
      expect(buddy.goals, [14]);
      await tester.pump();
      await tester.pump();
      await tick(tester);

      expect(find.text(_sheetTitle), findsNothing);
      expect(controller(tester).currentAction, isNot(BuddyAction.celebrate));
      expect(controller(tester).mood, isNot(BuddyMood.inLove));
      await afterCelebration(tester);
      expect(find.text(_goalTitle), findsNothing);
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
    });

    testWidgets('a goal reached while „Deine Belohnungen" is open: the new '
        'goal waits until it closed', (tester) async {
      journey = true;
      rewards = const JourneyRewards(earnedDay: 2);
      buddy = _FakeBuddy(() => _status(streak: 7));
      await pumpHero(tester);
      await openRewards(tester);
      expect(find.byType(JourneyRewardListSheet), findsOneWidget);

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
      expect(find.byType(JourneyRewardListSheet), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // the list's barrier
      // Closed, then the next frame plays what waited.
      await tester.pump();
      await tester.pump();
      await afterCelebration(tester);

      expect(find.byType(JourneyRewardListSheet), findsNothing);
      expect(find.text(_goalTitle), findsOneWidget);
      expect(buddy.shown, isEmpty);
      await chooseGoal(tester, '14 Tage');
      expect(buddy.goals, [14]);
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

    testWidgets('new user without a Buddy row → the badge shows 0', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 0, savers: 0, hasRow: false));
      await pumpHero(tester);

      expect(tester.widget<StreakBadge>(find.byType(StreakBadge)).streak, 0);
      expect(controller(tester).mood, BuddyMood.hungry);
    });

    testWidgets('buddyProvider error → no StreakBadge, Buddy still shown', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => throw Exception('no buddy_state table'));
      entries = _FakeEntries(
        beforeLunch(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      expect(find.byType(StreakBadge), findsNothing);
      expect(find.byType(StreakFlame), findsNothing);
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
      // Drawn with the shield glued to its word.
      expect(find.text(glueClosingSymbol(_saverUsedLine)), findsOneWidget);
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

    testWidgets('tipsArrived → celebrate and „Neue Tipps sind da! ✨"; marked '
        'shown once played', (tester) async {
      unseenTipSet = testRecommendation();
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.tipsArrived]),
      );
      final container = await pumpHero(tester);
      await tick(tester);

      final c = controller(tester);
      expect(c.currentAction, BuddyAction.celebrate);
      expect(c.bubble, _tipsArrivedLine);
      expect(buddy.shown, isEmpty);

      await tester.pump(const Duration(seconds: 4));
      expect(buddy.shown, [BuddyAnnouncement.tipsArrived]);
      expect(container.read(buddyProvider).value!.announcements, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [BuddyAnnouncement.tipsArrived]);
    });

    testWidgets('tipsArrived whose set was seen before it played: no '
        'celebration, he greets with his line instead', (tester) async {
      // unseenTipSet: null, the set was opened meanwhile.
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.tipsArrived]),
      );
      await pumpHero(tester);

      final c = controller(tester);
      for (var i = 0; i < 10; i++) {
        await tick(tester);
        expect(c.bubble, isNot(_tipsArrivedLine));
      }
      expect(c.currentAction, isNot(BuddyAction.celebrate));
      expect(buddy.shown, [BuddyAnnouncement.tipsArrived]);
      // 14:00, nothing eaten: lunch.
      expect(careLines(CareAction.lunch), contains(c.bubble));
    });

    testWidgets('weeklyTipsOffer → wave, then the sheet; „Zu den '
        'Einstellungen" opens the notification settings', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      final container = await pumpHero(tester);
      await tick(tester);

      expect(controller(tester).currentAction, BuddyAction.wave);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WeeklyTipsOfferSheet), findsNothing);

      // The sheet opens once the wave has played.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsOneWidget);
      expect(buddy.shown, isEmpty);

      await closeOffer(tester, WeeklyTipsOfferSheet.openKey);

      expect(location(), RoutePaths.settingsNotifications);
      expect(buddy.shown, [BuddyAnnouncement.weeklyTipsOffer]);
      // Covered by the settings: the next cue waits until Home is back.
      expect(container.read(homeCoveredProvider), isTrue);
    });

    testWidgets('„Später" stays on Home and marks it shown', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      await pumpHero(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsOneWidget);

      await closeOffer(tester, WeeklyTipsOfferSheet.laterKey);

      expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
      expect(location(), RoutePaths.dashboard);
      expect(buddy.shown, [BuddyAnnouncement.weeklyTipsOffer]);
    });

    testWidgets('weeklyTipsOffer is skipped when the weekly tips are '
        'already on', (tester) async {
      weeklyTips = true;
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      await pumpHero(tester);
      await tick(tester);

      expect(controller(tester).currentAction, isNot(BuddyAction.wave));
      expect(buddy.shown, [BuddyAnnouncement.weeklyTipsOffer]);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
    });

    testWidgets('weeklyTipsOffer plays while the profile is reloading (the '
        'weekly tips unknown)', (tester) async {
      weeklyTips = null;
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      await pumpHero(tester);
      await tick(tester);

      expect(controller(tester).currentAction, BuddyAction.wave);
      await tester.pump(const Duration(seconds: 1, milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsOneWidget);
      expect(buddy.shown, isEmpty);
    });

    testWidgets('the StreakBadge is ignored while the weekly-tips offer is on '
        'stage', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      await pumpHero(tester);

      // Waving: a badge tap opens nothing.
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsOneWidget);
      expect(find.text(_sheetTitle), findsNothing);

      await closeOffer(tester, WeeklyTipsOfferSheet.laterKey);

      // Done: the badge works again.
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('an offer due while „Dein Streak" is open waits until it '
        'closes', (tester) async {
      await pumpHero(tester);
      await openSheet(tester);
      expect(find.text(_sheetTitle), findsOneWidget);

      buddy.push(
        _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
      expect(find.text(_sheetTitle), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // „Dein Streak"'s barrier
      await tester.pump();
      await tester.pump();
      await afterWave(tester);

      expect(find.text(_sheetTitle), findsNothing);
      expect(find.byType(WeeklyTipsOfferSheet), findsOneWidget);
      expect(buddy.shown, isEmpty);
      await closeOffer(tester, WeeklyTipsOfferSheet.laterKey);
      expect(buddy.shown, [BuddyAnnouncement.weeklyTipsOffer]);
    });

    group('journey rewards', () {
      /// Day 1 with its recipe picked.
      const day1 = JourneyRewards(
        earnedDay: 1,
        picks: {1: RecipePick(id: 'r1', title: 'Apfel-Reis')},
      );

      testWidgets('journeyReward day 1 → celebrate, the sheet, „Rezept '
          'ansehen" opens the recipe; marked shown', (tester) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).currentAction, BuddyAction.celebrate);
        expect(find.byType(JourneyDaySheet), findsNothing);

        // The sheet opens once the celebration has played.
        await afterCelebration(tester);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
        expect(find.text(JourneyCopy.day1Line), findsOneWidget);
        expect(find.text('Apfel-Reis'), findsOneWidget);
        expect(buddy.shown, isEmpty);

        await closeOffer(tester, JourneyDaySheet.primaryKey);

        expect(location(), RoutePaths.collectionRecipeFor('r1'));
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('a reward that opens a page: the next cue waits until Home '
          'is back', (tester) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [
              BuddyAnnouncement.journeyReward,
              BuddyAnnouncement.firstTipFailed,
            ],
          ),
        );
        await pumpHero(tester);
        await afterCelebration(tester);

        await closeOffer(tester, JourneyDaySheet.primaryKey);
        expect(location(), RoutePaths.collectionRecipeFor('r1'));

        await advance(tester, const Duration(seconds: 6));
        expect(bubbleBehind(tester), isNot(_firstTipFailedLine));
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tick(tester);

        expect(location(), RoutePaths.dashboard);
        expect(controller(tester).bubble, _firstTipFailedLine);
        await tester.pump(const Duration(seconds: 4));
        expect(buddy.shown, [
          BuddyAnnouncement.journeyReward,
          BuddyAnnouncement.firstTipFailed,
        ]);
      });

      for (final (name, back) in [
        // iOS: the in-app browser closed, the app never left resumed.
        ('a touch', (WidgetTester t) => t.tapAt(const Offset(790, 590))),
        // Android's Custom Tabs, or iOS once the app went to the background.
        ('a resume', (WidgetTester t) async => returnFromBackground()),
      ]) {
        testWidgets('day 2: the article opens over the app; the next cue '
            'waits until the user is back ($name)', (tester) async {
          journey = true;
          rewards = const JourneyRewards(earnedDay: 2);
          buddy = _FakeBuddy(
            () => _status(
              announcements: const [
                BuddyAnnouncement.journeyReward,
                BuddyAnnouncement.firstTipFailed,
              ],
            ),
          );
          await pumpHero(tester);
          await afterCelebration(tester);
          expect(find.text(JourneyCopy.day2Line), findsOneWidget);

          await closeOffer(tester, JourneyDaySheet.primaryKey);
          expect(opener.urls, [Uri.parse(JourneyCopy.articleUrl)]);
          expect(location(), RoutePaths.dashboard);

          // Reading: nothing is said, nor marked shown, under the browser.
          await advance(tester, const Duration(seconds: 6));
          expect(bubbleBehind(tester), isNot(_firstTipFailedLine));
          expect(buddy.shown, [BuddyAnnouncement.journeyReward]);

          await back(tester);
          await tester.pump();
          await tester.pump();
          await tick(tester);

          expect(controller(tester).bubble, _firstTipFailedLine);
          await tester.pump(const Duration(seconds: 4));
          expect(buddy.shown, [
            BuddyAnnouncement.journeyReward,
            BuddyAnnouncement.firstTipFailed,
          ]);
        });
      }

      testWidgets('day 2, the launch failed: the next cue goes on', (
        tester,
      ) async {
        journey = true;
        rewards = const JourneyRewards(earnedDay: 2);
        opener.result = false;
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [
              BuddyAnnouncement.journeyReward,
              BuddyAnnouncement.firstTipFailed,
            ],
          ),
        );
        await pumpHero(tester);
        await afterCelebration(tester);

        await closeOffer(tester, JourneyDaySheet.primaryKey);
        await tick(tester);

        expect(opener.urls, [Uri.parse(JourneyCopy.articleUrl)]);
        expect(find.text(JourneyCopy.articleFailure), findsOneWidget);
        expect(controller(tester).bubble, _firstTipFailedLine);
      });

      testWidgets('a tracker opened from Home as the celebration ends: the '
          'sheet waits until Home is back', (tester) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await pumpHero(tester);
        // Just before the sheet is due: a need bubble opens its tracker.
        await advance(
          tester,
          buddyActionDuration(BuddyAction.celebrate) -
              const Duration(milliseconds: 100),
        );
        await tester.tap(find.byKey(CareRing.needKey(CareNeed.gutFeeling)));
        // Not over the page on its way in, nor once it covers Home.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byType(JourneyDaySheet), findsNothing);
        }
        await tester.pump(const Duration(seconds: 3));
        expect(location(), RoutePaths.gutFeelingTracker);
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(buddy.shown, isEmpty);

        router.pop();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(location(), RoutePaths.dashboard);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
        await closeOffer(tester, JourneyDaySheet.laterKey);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('„Eintragen" open as the sheet comes due: it waits until '
          '„Eintragen" closed', (tester) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await pumpHero(tester);
        await tester.ensureVisible(find.byKey(_logButton));
        await tester.tap(find.byKey(_logButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(LogSheet), findsOneWidget);

        await afterCelebration(tester);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(buddy.shown, isEmpty);

        await tester.tapAt(const Offset(10, 10)); // „Eintragen"'s barrier
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(LogSheet), findsNothing);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
      });

      testWidgets('a line due while „Eintragen" is open waits until it '
          'closed', (tester) async {
        journey = true;
        rewards = const JourneyRewards(
          earnedDay: 3,
          tipOffer: TipOffer.accepted,
          firstTip: FirstTipState.failed,
        );
        await pumpHero(tester);
        await tester.ensureVisible(find.byKey(_logButton));
        await tester.tap(find.byKey(_logButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        buddy.push(
          _status(announcements: const [BuddyAnnouncement.firstTipFailed]),
        );
        await tester.pump();
        await advance(tester, const Duration(seconds: 5));
        expect(bubbleBehind(tester), isNot(_firstTipFailedLine));
        expect(buddy.shown, isEmpty);

        await tester.tapAt(const Offset(10, 10)); // „Eintragen"'s barrier
        await tester.pump();
        await tester.pump();
        await tick(tester);
        expect(controller(tester).bubble, _firstTipFailedLine);
      });

      testWidgets('„Später" stays on Home and marks it shown', (tester) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await pumpHero(tester);
        await afterCelebration(tester);

        await closeOffer(tester, JourneyDaySheet.laterKey);

        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(location(), RoutePaths.dashboard);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('journeyReward while „Dein Streak" is open waits until it '
          'closed', (tester) async {
        journey = true;
        rewards = day1;
        await pumpHero(tester);
        await openSheet(tester);
        expect(find.text(_sheetTitle), findsOneWidget);

        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();
        await afterCelebration(tester);
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(find.text(_sheetTitle), findsOneWidget);

        await tester.tapAt(const Offset(10, 10)); // „Dein Streak"'s barrier
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(find.text(_sheetTitle), findsNothing);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
        expect(buddy.shown, isEmpty);
        await closeOffer(tester, JourneyDaySheet.laterKey);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('journeyReward while „Deine Belohnungen" is open waits '
          'until it closed', (tester) async {
        journey = true;
        rewards = day1;
        await pumpHero(tester);
        await openRewards(tester);
        expect(find.byType(JourneyRewardListSheet), findsOneWidget);

        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();
        await afterCelebration(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(find.byType(JourneyRewardListSheet), findsOneWidget);

        await tester.tapAt(const Offset(10, 10)); // the list's barrier
        // Closed, then the next frame plays what waited.
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(find.byType(JourneyRewardListSheet), findsNothing);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
        expect(buddy.shown, isEmpty);
        await closeOffer(tester, JourneyDaySheet.laterKey);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('a line while „Deine Belohnungen" is open waits until it '
          'closed', (tester) async {
        journey = true;
        rewards = const JourneyRewards(
          earnedDay: 3,
          tipOffer: TipOffer.accepted,
          firstTip: FirstTipState.failed,
        );
        await pumpHero(tester);
        await openRewards(tester);

        buddy.push(
          _status(announcements: const [BuddyAnnouncement.firstTipFailed]),
        );
        await tester.pump();
        await advance(tester, const Duration(seconds: 1));
        expect(bubbleBehind(tester), isNot(_firstTipFailedLine));
        expect(buddy.shown, isEmpty);

        await tester.tapAt(const Offset(10, 10)); // the list's barrier
        await tester.pump();
        await tester.pump();
        await tick(tester);

        expect(controller(tester).bubble, _firstTipFailedLine);
        await tester.pump(const Duration(seconds: 4));
        expect(buddy.shown, [BuddyAnnouncement.firstTipFailed]);
      });

      testWidgets('journeyReward while „Deine Belohnungen" is open, whose row '
          'opens a page: it waits until Home is back', (tester) async {
        journey = true;
        rewards = day1;
        await pumpHero(tester);
        await openRewards(tester);
        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();
        await afterCelebration(tester);
        expect(find.byType(JourneyDaySheet), findsNothing);

        // Day 1's row: the list closes, the recipe opens over Home.
        await tester.tap(find.byKey(JourneyRewardListSheet.rowKey(1)));
        await tester.pump();
        expect(location(), RoutePaths.collectionRecipeFor('r1'));
        // Not over the page on its way in, nor once it covers Home.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(JourneyDaySheet), findsNothing);
        }
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(buddy.shown, isEmpty);

        router.pop();
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(location(), RoutePaths.dashboard);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
        await closeOffer(tester, JourneyDaySheet.laterKey);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('a page that „Deine Belohnungen" opened and that never '
          'closes (Home gone to instead): the cue comes once Home is back', (
        tester,
      ) async {
        journey = true;
        rewards = day1;
        await pumpHero(tester);
        await openRewards(tester);
        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();
        await afterCelebration(tester);

        await tester.tap(find.byKey(JourneyRewardListSheet.rowKey(1)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(location(), RoutePaths.collectionRecipeFor('r1'));

        // Replaced, not popped: the page's future never completes.
        router.go(RoutePaths.dashboard);
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(location(), RoutePaths.dashboard);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
      });

      testWidgets('a page that „Deine Belohnungen" opened, replaced by a go '
          'to Home on its way in (Home never hidden): the cue comes', (
        tester,
      ) async {
        journey = true;
        rewards = day1;
        await pumpHero(tester);
        await openRewards(tester);
        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();

        await tester.tap(find.byKey(JourneyRewardListSheet.rowKey(1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(location(), RoutePaths.collectionRecipeFor('r1'));

        // Replaced mid-transition: the page's future never completes, and
        // Home was never hidden.
        router.go(RoutePaths.dashboard);
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(location(), RoutePaths.dashboard);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
      });

      testWidgets('a page that „Deine Belohnungen" opened and that closes on '
          'its way in: the cue then shows on Home', (tester) async {
        journey = true;
        rewards = day1;
        await pumpHero(tester);
        await openRewards(tester);
        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();
        await afterCelebration(tester);

        await tester.tap(find.byKey(JourneyRewardListSheet.rowKey(1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(JourneyDaySheet), findsNothing);
        router.pop(); // mid-transition: Home was never hidden
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(location(), RoutePaths.dashboard);
        expect(find.byType(JourneyDaySheet), findsOneWidget);
      });

      testWidgets('journeyReward waits while the hero is hidden', (
        tester,
      ) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await pumpHero(tester);
        visible.value = false;
        await tester.pump();
        await afterCelebration(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(JourneyDaySheet), findsNothing);

        visible.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(JourneyDaySheet), findsOneWidget);
      });

      testWidgets('a cue cut short comes again', (tester) async {
        journey = true;
        rewards = day1;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        final container = await pumpHero(tester);
        await afterCelebration(tester);
        expect(find.byType(JourneyDaySheet), findsOneWidget);

        // The hero goes away with its sheet open (the app closing), then
        // the sheet closes.
        heroShown.value = false;
        await tester.pump();
        expect(find.byType(BuddyHero), findsNothing);
        await closeOffer(tester, JourneyDaySheet.primaryKey);

        expect(location(), RoutePaths.dashboard);
        expect(buddy.shown, isEmpty);
        expect(container.read(buddyProvider).value!.announcements, [
          BuddyAnnouncement.journeyReward,
        ]);
      });

      testWidgets('no day to announce (the rewards gone meanwhile): no '
          'celebration, no sheet, marked shown', (tester) async {
        journey = true;
        rewards = null;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).currentAction, isNot(BuddyAction.celebrate));
        await afterCelebration(tester);
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });

      testWidgets('superseded while it waited (day 3, the offer open now): '
          'no celebration, no sheet, marked shown', (tester) async {
        journey = true;
        rewards = const JourneyRewards(earnedDay: 2);
        final container = await pumpHero(tester);
        await openSheet(tester);
        buddy.push(
          _status(announcements: const [BuddyAnnouncement.journeyReward]),
        );
        await tester.pump();
        (container.read(journeyRewardsProvider.notifier)
                as SeededJourneyRewardsNotifier)
            .set(
              const JourneyRewards(earnedDay: 3, tipOffer: TipOffer.offered),
            );

        await tester.tapAt(const Offset(10, 10)); // „Dein Streak"'s barrier
        await tester.pump();
        await tester.pump();
        await tick(tester);

        expect(controller(tester).currentAction, isNot(BuddyAction.celebrate));
        await afterCelebration(tester);
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(buddy.shown, [BuddyAnnouncement.journeyReward]);
      });
    });

    group('journey user, firstTipOffer → the first-tip sheet', () {
      /// Day 3, the offer open, day 3's recipe already picked.
      const day3 = JourneyRewards(
        earnedDay: 3,
        tipOffer: TipOffer.offered,
        picks: {3: RecipePick(id: 'r3', title: 'Bohnen-Topf')},
      );

      setUp(() {
        journey = true;
        rewards = day3;
        buddy = _FakeBuddy(
          () => _status(announcements: const [BuddyAnnouncement.firstTipOffer]),
        );
      });

      testWidgets('wave, then the first-tip sheet, never the old one', (
        tester,
      ) async {
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).currentAction, BuddyAction.wave);
        await afterWave(tester);
        expect(find.byType(FirstTipOfferSheet), findsOneWidget);
        expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
        expect(buddy.shown, isEmpty);
      });

      testWidgets('yes → accept called once, the Buddy says firstTipStarted', (
        tester,
      ) async {
        await pumpHero(tester);
        await afterWave(tester);

        await closeOffer(tester, FirstTipOfferSheet.yesKey);
        await tick(tester);

        expect(firstTip.accepts, 1);
        expect(controller(tester).bubble, JourneyCopy.firstTipStarted);
        expect(find.byType(JourneyDaySheet), findsNothing);
        // The line holds the stage, then the offer counts as shown.
        expect(buddy.shown, isEmpty);
        await tester.pump(const Duration(seconds: 4));
        expect(buddy.shown, [BuddyAnnouncement.firstTipOffer]);
        expect(firstTip.accepts, 1);
      });

      testWidgets('yes with a failing opt-in → the SnackBar, nothing said', (
        tester,
      ) async {
        firstTip.acceptResult = FirstTipAcceptance.failed;
        await pumpHero(tester);
        await afterWave(tester);

        await closeOffer(tester, FirstTipOfferSheet.yesKey);
        await tick(tester);

        expect(firstTip.accepts, 1);
        expect(find.text(WeeklyTipsSwitch.failure), findsOneWidget);
        expect(controller(tester).bubble, isNot(JourneyCopy.firstTipStarted));
        expect(buddy.shown, [BuddyAnnouncement.firstTipOffer]);
      });

      testWidgets('yes while the profile is not ready → not answered: no '
          'SnackBar, still pending, it comes again', (tester) async {
        firstTip.acceptResult = FirstTipAcceptance.notReady;
        final container = await pumpHero(tester);
        await afterWave(tester);

        await closeOffer(tester, FirstTipOfferSheet.yesKey);
        await tick(tester);

        expect(firstTip.accepts, 1);
        expect(find.byType(SnackBar), findsNothing);
        expect(controller(tester).bubble, isNot(JourneyCopy.firstTipStarted));
        expect(
          container.read(journeyRewardsProvider)!.tipOffer,
          TipOffer.offered,
        );
        expect(buddy.shown, isEmpty);
        expect(container.read(buddyProvider).value!.announcements, [
          BuddyAnnouncement.firstTipOffer,
        ]);

        // The next status update: the offer again.
        firstTip.acceptResult = FirstTipAcceptance.started;
        buddy.push(
          _status(announcements: const [BuddyAnnouncement.firstTipOffer]),
        );
        await tester.pump();
        await tester.pump();
        await afterWave(tester);
        expect(find.byType(FirstTipOfferSheet), findsOneWidget);
        await closeOffer(tester, FirstTipOfferSheet.yesKey);
        await tick(tester);
        expect(controller(tester).bubble, JourneyCopy.firstTipStarted);
      });

      testWidgets('no → declined, the day-3 recipe sheet with day3AfterNoLine, '
          'no accept', (tester) async {
        final container = await pumpHero(tester);
        await afterWave(tester);

        await closeOffer(tester, FirstTipOfferSheet.noKey);

        expect(
          container.read(journeyRewardsProvider)!.tipOffer,
          TipOffer.declined,
        );
        expect(find.byType(JourneyDaySheet), findsOneWidget);
        expect(find.text(JourneyCopy.day3AfterNoLine), findsOneWidget);
        expect(find.text('Bohnen-Topf'), findsOneWidget);
        expect(buddy.shown, isEmpty);

        await closeOffer(tester, JourneyDaySheet.primaryKey);

        expect(location(), RoutePaths.collectionRecipeFor('r3'));
        expect(firstTip.accepts, 0);
        expect(buddy.shown, [BuddyAnnouncement.firstTipOffer]);
      });

      testWidgets('no, then the recipe: the next cue waits until Home is '
          'back', (tester) async {
        unseenTipSet = testRecommendation();
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [
              BuddyAnnouncement.firstTipOffer,
              BuddyAnnouncement.tipsArrived,
            ],
          ),
        );
        await pumpHero(tester);
        await afterWave(tester);
        await closeOffer(tester, FirstTipOfferSheet.noKey);
        await closeOffer(tester, JourneyDaySheet.primaryKey);
        expect(location(), RoutePaths.collectionRecipeFor('r3'));

        await advance(tester, const Duration(seconds: 6));
        expect(bubbleBehind(tester), isNot(_tipsArrivedLine));
        expect(buddy.shown, [BuddyAnnouncement.firstTipOffer]);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tick(tester);

        expect(controller(tester).bubble, _tipsArrivedLine);
      });

      testWidgets('dismissed → declined, no second sheet, no accept', (
        tester,
      ) async {
        final container = await pumpHero(tester);
        await afterWave(tester);

        await tester.tapAt(const Offset(10, 10)); // the offer's barrier
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          container.read(journeyRewardsProvider)!.tipOffer,
          TipOffer.declined,
        );
        expect(find.byType(FirstTipOfferSheet), findsNothing);
        expect(find.byType(JourneyDaySheet), findsNothing);
        expect(firstTip.accepts, 0);
        expect(buddy.shown, [BuddyAnnouncement.firstTipOffer]);
      });

      for (final (name, close) in [
        ('„Ja, gern"', FirstTipOfferSheet.yesKey),
        ('„Nein, danke"', FirstTipOfferSheet.noKey),
        ('a dismissal', null),
      ]) {
        testWidgets('the hero gone before $name: nothing stored, nothing '
            'requested, still pending', (tester) async {
          final container = await pumpHero(tester);
          await afterWave(tester);
          expect(find.byType(FirstTipOfferSheet), findsOneWidget);

          heroShown.value = false;
          await tester.pump();
          if (close == null) {
            await tester.tapAt(const Offset(10, 10)); // the offer's barrier
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          } else {
            await closeOffer(tester, close);
          }

          expect(find.byType(FirstTipOfferSheet), findsNothing);
          expect(find.byType(JourneyDaySheet), findsNothing);
          expect(
            container.read(journeyRewardsProvider)!.tipOffer,
            TipOffer.offered,
          );
          expect(firstTip.accepts, 0);
          expect(buddy.shown, isEmpty);
          expect(container.read(buddyProvider).value!.announcements, [
            BuddyAnnouncement.firstTipOffer,
          ]);
        });
      }

      testWidgets('answered meanwhile („Deine Belohnungen"): no sheet, marked '
          'shown', (tester) async {
        rewards = const JourneyRewards(
          earnedDay: 3,
          tipOffer: TipOffer.declined,
        );
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).currentAction, isNot(BuddyAction.wave));
        await afterWave(tester);
        expect(find.byType(FirstTipOfferSheet), findsNothing);
        expect(buddy.shown, [BuddyAnnouncement.firstTipOffer]);
      });

      testWidgets('journey undecided: no offer', (tester) async {
        journey = null;
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).currentAction, isNot(BuddyAction.wave));
        await afterWave(tester);
        expect(find.byType(FirstTipOfferSheet), findsNothing);
        expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
        expect(firstTip.accepts, 0);
      });

      testWidgets('journey undecided by the end of the wave (another user): '
          'no sheet', (tester) async {
        final container = await pumpHero(tester);
        await tick(tester);
        expect(controller(tester).currentAction, BuddyAction.wave);

        (container.read(journeyProvider.notifier) as SeededJourneyNotifier).set(
          null,
        );
        await afterWave(tester);

        expect(find.byType(FirstTipOfferSheet), findsNothing);
        expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
        expect(firstTip.accepts, 0);
      });
    });

    group('patternsUnlocked', () {
      setUp(() {
        journey = true;
        rewards = const JourneyRewards(earnedDay: 7, patternsFreed: true);
      });

      testWidgets('patternsUnlocked → celebrate, then /patterns-unlocked', (
        tester,
      ) async {
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [BuddyAnnouncement.patternsUnlocked],
          ),
        );
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).currentAction, BuddyAction.celebrate);
        expect(location(), RoutePaths.dashboard);

        await afterCelebration(tester);

        expect(location(), RoutePaths.patternsUnlocked);
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);
      });

      testWidgets('the next cue waits until Home is visible again', (
        tester,
      ) async {
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [
              BuddyAnnouncement.patternsUnlocked,
              BuddyAnnouncement.firstTipFailed,
            ],
          ),
        );
        await pumpHero(tester);
        await afterCelebration(tester);
        expect(location(), RoutePaths.patternsUnlocked);

        await tester.pump(const Duration(seconds: 6));
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tick(tester);

        expect(location(), RoutePaths.dashboard);
        expect(controller(tester).bubble, _firstTipFailedLine);
        await tester.pump(const Duration(seconds: 4));
        expect(buddy.shown, [
          BuddyAnnouncement.patternsUnlocked,
          BuddyAnnouncement.firstTipFailed,
        ]);
      });

      testWidgets('then the open day-3 offer: its sheet waits until Home is '
          'back from „Muster frei!"', (tester) async {
        rewards = const JourneyRewards(
          earnedDay: 7,
          patternsFreed: true,
          tipOffer: TipOffer.offered,
        );
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [
              BuddyAnnouncement.patternsUnlocked,
              BuddyAnnouncement.firstTipOffer,
            ],
          ),
        );
        await pumpHero(tester);
        await afterCelebration(tester);
        expect(location(), RoutePaths.patternsUnlocked);

        await tester.pump(const Duration(seconds: 6));
        expect(find.byType(FirstTipOfferSheet), findsNothing);
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tick(tester);
        expect(location(), RoutePaths.dashboard);

        await afterWave(tester);
        expect(find.byType(FirstTipOfferSheet), findsOneWidget);
        expect(firstTip.accepts, 0);
      });

      testWidgets('„Muster frei!" closed during its transition (Home never '
          'hidden): the next cue still comes', (tester) async {
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [
              BuddyAnnouncement.patternsUnlocked,
              BuddyAnnouncement.firstTipFailed,
            ],
          ),
        );
        await pumpHero(tester);
        // The celebration ends: pushed, its transition just begun.
        await tester.pump(buddyActionDuration(BuddyAction.celebrate));
        await tester.pump();
        expect(location(), RoutePaths.patternsUnlocked);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tick(tester);

        expect(location(), RoutePaths.dashboard);
        expect(controller(tester).bubble, _firstTipFailedLine);
      });

      testWidgets('marked shown once the page showed, not as it is pushed', (
        tester,
      ) async {
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [BuddyAnnouncement.patternsUnlocked],
          ),
        );
        await pumpHero(tester);
        // The celebration ends and pushes the page; no frame yet.
        await tester.binding.delayed(
          buddyActionDuration(BuddyAction.celebrate),
        );
        expect(buddy.shown, isEmpty);

        await tester.pump();
        expect(location(), RoutePaths.patternsUnlocked);
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);
      });

      testWidgets('a push that never shows (redirected): still pending, it '
          'comes again once Home is back', (tester) async {
        redirectUnlocked = true;
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [BuddyAnnouncement.patternsUnlocked],
          ),
        );
        final container = await pumpHero(tester);
        await afterCelebration(tester);
        expect(location(), RoutePaths.diary);
        await tester.pump(const Duration(seconds: 1));
        expect(buddy.shown, isEmpty);
        expect(container.read(buddyProvider).value!.announcements, [
          BuddyAnnouncement.patternsUnlocked,
        ]);

        redirectUnlocked = false;
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tick(tester);
        expect(location(), RoutePaths.dashboard);
        expect(controller(tester).currentAction, BuddyAction.celebrate);
        await afterCelebration(tester);

        expect(location(), RoutePaths.patternsUnlocked);
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);
      });

      testWidgets('the hero gone before the page showed (the app closing): '
          'still pending', (tester) async {
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [BuddyAnnouncement.patternsUnlocked],
          ),
        );
        final container = await pumpHero(tester);
        await tester.binding.delayed(
          buddyActionDuration(BuddyAction.celebrate),
        );
        heroShown.value = false;
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(BuddyHero), findsNothing);
        expect(buddy.shown, isEmpty);
        expect(container.read(buddyProvider).value!.announcements, [
          BuddyAnnouncement.patternsUnlocked,
        ]);
      });

      testWidgets('patternsUnlocked waits while the hero is hidden', (
        tester,
      ) async {
        buddy = _FakeBuddy(
          () => _status(
            announcements: const [BuddyAnnouncement.patternsUnlocked],
          ),
        );
        await pumpHero(tester);
        visible.value = false;
        await tester.pump();
        await afterCelebration(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(location(), RoutePaths.dashboard);
        expect(buddy.shown, isEmpty);

        visible.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(location(), RoutePaths.patternsUnlocked);
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);
      });

      testWidgets('patternsUnlocked waits while „Dein Streak" is open', (
        tester,
      ) async {
        await pumpHero(tester);
        await openSheet(tester);

        buddy.push(
          _status(announcements: const [BuddyAnnouncement.patternsUnlocked]),
        );
        await tester.pump();
        await afterCelebration(tester);
        expect(location(), RoutePaths.dashboard);
        expect(find.text(_sheetTitle), findsOneWidget);

        await tester.tapAt(const Offset(10, 10)); // „Dein Streak"'s barrier
        await tester.pump();
        await tester.pump();
        await afterCelebration(tester);

        expect(location(), RoutePaths.patternsUnlocked);
        expect(buddy.shown, [BuddyAnnouncement.patternsUnlocked]);
      });
    });

    testWidgets('firstTipFailed → the line, once', (tester) async {
      journey = true;
      rewards = const JourneyRewards(
        earnedDay: 3,
        tipOffer: TipOffer.accepted,
        firstTip: FirstTipState.failed,
      );
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.firstTipFailed]),
      );
      final container = await pumpHero(tester);
      await tick(tester);

      expect(controller(tester).bubble, _firstTipFailedLine);
      expect(buddy.shown, isEmpty);

      await tester.pump(const Duration(seconds: 4));
      expect(buddy.shown, [BuddyAnnouncement.firstTipFailed]);
      expect(container.read(buddyProvider).value!.announcements, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      expect(buddy.shown, [BuddyAnnouncement.firstTipFailed]);
    });

    for (final (weekly, line) in [
      (true, JourneyCopy.firstTipFailed(weeklyTipsOn: true)),
      (false, JourneyCopy.firstTipFailed(weeklyTipsOn: false)),
      (null, JourneyCopy.firstTipFailed(weeklyTipsOn: false)),
    ]) {
      testWidgets('firstTipFailed, the weekly tips $weekly: says they stay on '
          'only when they are', (tester) async {
        journey = true;
        weeklyTips = weekly;
        rewards = const JourneyRewards(
          earnedDay: 3,
          tipOffer: TipOffer.accepted,
          firstTip: FirstTipState.failed,
        );
        buddy = _FakeBuddy(
          () =>
              _status(announcements: const [BuddyAnnouncement.firstTipFailed]),
        );
        await pumpHero(tester);
        await tick(tester);

        expect(controller(tester).bubble, line);
      });
    }

    testWidgets('fresh log that counts today → „Danke! 🔥 N Tage"', (
      tester,
    ) async {
      entries = _FakeEntries(beforeLunch());
      final container = await pumpHero(tester);
      expect(controller(tester).mood, BuddyMood.hungry);

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      expect(container.read(buddyEventsProvider), isNull);

      // The tracker's save reloads today's entries.
      entries.push(beforeLunch(meals: [testMealEntry(trackedAt: now)]));
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

    testWidgets('Home covered during the follow-up\'s delay (the tour '
        'opening): the thanks waits until Home is free, then comes', (
      tester,
    ) async {
      buddy = _FakeBuddy(() => _status(streak: 0, savers: 0));
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone

      emit(container, LogSentiment.neutral);
      buddy.push(_status(streak: 1, savers: 0, todayCounted: true));
      await tester.pump();
      final tour = Completer<void>();
      unawaited(
        container
            .read(homeCoveredProvider.notifier)
            .whileOpen(() => tour.future),
      );
      // Long past the delay: nothing said behind the cover.
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(bubbleBehind(tester), isNot('Danke! 🔥 1 Tag'));
      }

      tour.complete();
      await tester.pump();
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
      entries = _FakeEntries(beforeLunch());
      final container = await pumpHero(tester);

      emit(container, LogSentiment.good);
      await tester.pump();
      entries.push(beforeLunch(meals: [testMealEntry(trackedAt: now)]));
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      final c = controller(tester);
      expect(c.mood, BuddyMood.happy);
      expect(c.bubble, isNot(startsWith('Danke!')));
      // Lunch logged at 14:00: no meter under 35 %, he is content.
      expect(careLines(CareAction.feed), contains(c.bubble));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('right after a drink, while he still wants more, he thanks '
        'for it instead of asking for a drink', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 5, todayCounted: true));
      final lunch = testMealEntry(trackedAt: DateTime(2026, 11, 22, 13));
      entries = _FakeEntries(EntriesState(meals: [lunch]));
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone

      // Logged now for this morning: the meter stays at the floor.
      final drankAt = now.subtract(const Duration(hours: 4));
      container
          .read(buddyEventsProvider.notifier)
          .emit(
            BuddyLogEvent(
              EntryKind.drink,
              LogSentiment.good,
              at: now,
              trackedAt: drankAt,
            ),
          );
      await tester.pump();
      entries.push(
        EntriesState(
          meals: [lunch],
          drinks: [testDrinkEntry(trackedAt: drankAt)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);

      // Trinken is still the lowest: a drink is what he asks for next …
      expect(
        needMeterLevel(tester, CareNeed.drink),
        AppConstants.careMeterFloor,
      );
      expect(find.text('Trinken eintragen'), findsOneWidget);
      // … but not now: he thanks for this one.
      final c = controller(tester);
      expect(careLines(CareAction.drink), isNot(contains(c.bubble)));
      expect(
        BuddyCopy.careAfterLog[CareAction.drink]!.map(
          (l) => BuddyCopy.fill(l, name: 'Bubu'),
        ),
        contains(c.bubble),
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('taps in the half hour after a drink never ask for another '
        'one; later they may again', (tester) async {
      buddy = _FakeBuddy(() => _status(streak: 5, todayCounted: true));
      final lunch = testMealEntry(trackedAt: DateTime(2026, 11, 22, 13));
      entries = _FakeEntries(EntriesState(meals: [lunch]));
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone

      // Logged now for this morning: the meter stays at the floor.
      final drankAt = now.subtract(const Duration(hours: 4));
      container
          .read(buddyEventsProvider.notifier)
          .emit(
            BuddyLogEvent(
              EntryKind.drink,
              LogSentiment.good,
              at: now,
              trackedAt: drankAt,
            ),
          );
      await tester.pump();
      entries.push(
        EntriesState(
          meals: [lunch],
          drinks: [testDrinkEntry(trackedAt: drankAt)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tick(tester);
      await advance(tester, const Duration(seconds: 6)); // follow-up gone

      final thanks = BuddyCopy.careAfterLog[CareAction.drink]!
          .map((l) => BuddyCopy.fill(l, name: 'Bubu'))
          .toList();
      final said = <String?>[];
      Future<void> tapAt(DateTime at) async {
        now = at;
        await tester.tap(find.byType(AnimatedBuddy));
        await tick(tester);
        said.add(controller(tester).bubble);
        await tester.pump(const Duration(milliseconds: 300));
      }

      final loggedAt = now;
      for (var i = 0; i < 6; i++) {
        await tapAt(loggedAt.add(Duration(minutes: 5 * i)));
        expect(thanks, contains(said.last), reason: 'tap $i');
      }
      // The rotation still never repeats a line right away.
      for (var i = 1; i < said.length; i++) {
        expect(said[i], isNot(said[i - 1]));
      }

      // Half an hour on he may be thirsty again.
      await tapAt(loggedAt.add(const Duration(minutes: 31)));
      expect(careLines(CareAction.drink), contains(said.last));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tapping the Buddy again and again never repeats the line '
        'he just said', (tester) async {
      await pumpHero(tester);
      final said = <String?>[controller(tester).bubble];
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byType(AnimatedBuddy));
        await tick(tester);
        said.add(controller(tester).bubble);
        await tester.pump(const Duration(milliseconds: 300));
      }
      for (var i = 1; i < said.length; i++) {
        expect(said[i], isNot(said[i - 1]), reason: 'tap $i: ${said[i]}');
      }
    });

    testWidgets('a mood change during the follow-up delay says nothing extra', (
      tester,
    ) async {
      entries = _FakeEntries(beforeLunch());
      final container = await pumpHero(tester);
      await advance(tester, const Duration(seconds: 3)); // greeting gone
      await tick(tester);
      expect(controller(tester).bubble, isNull);

      emit(container, LogSentiment.good);
      buddy.push(_status(streak: 5, todayCounted: true));
      await tester.pump();
      // The log's entries land while the follow-up waits.
      entries.push(beforeLunch(meals: [testMealEntry(trackedAt: now)]));
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

    testWidgets('a goal picked elsewhere while its sheet waited (Home '
        'hidden): no goal sheet, his love ends', (tester) async {
      Map<BuddyAnnouncement, String> keys(int goal) => {
        BuddyAnnouncement.goalReached: '${testUserId}_goalReached_$goal',
      };
      buddy = _FakeBuddy(
        () => _status(
          streak: 7,
          goal: 7,
          announcements: const [BuddyAnnouncement.goalReached],
          announcementKeys: keys(7),
        ),
      );
      await pumpHero(tester);
      await tick(tester);
      expect(controller(tester).currentAction, BuddyAction.celebrate);
      visible.value = false;
      await tester.pump();
      await afterCelebration(tester);
      expect(find.text(_goalTitle), findsNothing);

      // „Dein Streak" on the Ich tab: a new goal.
      buddy.push(
        _status(
          streak: 7,
          goal: 14,
          announcements: const [BuddyAnnouncement.goalReached],
          announcementKeys: keys(7),
        ),
      );
      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_goalTitle), findsNothing);
      expect(controller(tester).mood, isNot(BuddyMood.inLove));
      expect(buddy.shown, [BuddyAnnouncement.goalReached]);
    });

    testWidgets('the offer sheet waits while the hero is hidden', (
      tester,
    ) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      await pumpHero(tester);
      visible.value = false;
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
      expect(buddy.shown, isEmpty);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyTipsOfferSheet), findsOneWidget);

      await closeOffer(tester, WeeklyTipsOfferSheet.laterKey);
      expect(buddy.shown, [BuddyAnnouncement.weeklyTipsOffer]);
    });

    testWidgets('weekly tips switched on while the offer sheet waited: no '
        'sheet, marked shown', (tester) async {
      buddy = _FakeBuddy(
        () => _status(announcements: const [BuddyAnnouncement.weeklyTipsOffer]),
      );
      final container = await pumpHero(tester);
      visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));

      // Switched on elsewhere (Entdecken, Settings) meanwhile.
      container.read(weeklyTipsSwitch.notifier).set(true);
      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
      expect(buddy.shown, [BuddyAnnouncement.weeklyTipsOffer]);
    });

    group('his bubble over his head', () {
      /// About 140 characters: four lines in his bubble.
      const longLine =
          'Oh, ich habe so viel zu erzählen! Heute geht es um dein Essen, '
          'dein Trinken und dein Bauchgefühl, und alles trägst du ganz '
          'einfach hier ein.';

      /// The top of the Buddy's head, as drawn in his square.
      double head(WidgetTester tester) {
        final square = tester.getRect(find.byKey(CareRing.buddyKey));
        return square.top + BuddyLayout(square.size).headTop;
      }

      Rect bubbleRect(WidgetTester tester) =>
          tester.getRect(find.byType(BuddySpeechBubble));

      /// Lets his greeting show and run out: then he says nothing.
      Future<void> afterGreeting(WidgetTester tester) async {
        await pumpUntil(
          tester,
          () => controller(tester).bubble != null,
          max: 40,
        );
        expect(controller(tester).bubble, isNotNull, reason: 'his greeting');
        await pumpUntil(tester, () => controller(tester).bubble == null);
        expect(controller(tester).bubble, isNull);
      }

      testWidgets('no reserved bubble slot: the ring sits right under the '
          'band left for his bubble and the flame (where the chip row was), '
          'and never moves while he talks', (tester) async {
        await pumpHero(tester);
        await afterGreeting(tester);

        final hero = tester.getRect(find.byType(BuddyHero));
        final ring = tester.getRect(find.byType(CareRing));
        expect(ring.top - hero.top, AppConstants.homeHeadroom);
        // The band holds nothing of its own.
        expect(
          find.descendant(
            of: find.byType(BuddyHero),
            matching: find.byType(StreakChip),
          ),
          findsNothing,
        );
        expect(
          tester.widget<HomeFlame>(find.byType(HomeFlame)).headroom,
          AppConstants.homeHeadroom,
        );

        controller(tester).say('Hallo, schön dich zu sehen!');
        await tick(tester);
        expect(bubbleRect(tester).isEmpty, isFalse);
        expect(tester.getRect(find.byType(CareRing)), ring);
      });

      testWidgets('his bubble floats over his head while he talks, then is '
          'gone', (tester) async {
        await pumpHero(tester);
        await afterGreeting(tester);

        controller(tester).say('Hallo, schön dich zu sehen!');
        await tick(tester);
        final hero = tester.getRect(find.byType(BuddyHero));
        final ring = tester.getRect(find.byType(CareRing));
        final bubble = bubbleRect(tester);
        expect(bubble.isEmpty, isFalse);
        expect(bubble.bottom, closeTo(head(tester), 0.5));
        expect(bubble.center.dx, closeTo(ring.center.dx, 0.5));
        expect(bubble.top, greaterThanOrEqualTo(hero.top));
        expect(
          bubble.width,
          lessThanOrEqualTo(AppConstants.buddyBubbleOverlayMaxWidth),
        );

        await advance(tester, const Duration(seconds: 4));
        expect(tester.getSize(find.byType(BuddySpeechBubble)).isEmpty, isTrue);
      });

      testWidgets('a four-line line is scaled down to stay inside the hero at '
          '375×667, text scale 1.3', (tester) async {
        tester.view
          ..physicalSize = const Size(375, 667)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpHero(tester);
        await afterGreeting(tester);

        controller(tester).say(longLine);
        await tick(tester);
        await tester.pump(const Duration(milliseconds: 1300));

        final hero = tester.getRect(find.byType(BuddyHero));
        final bubble = bubbleRect(tester);
        expect(bubble.isEmpty, isFalse);
        expect(bubble.top, greaterThanOrEqualTo(hero.top - 0.01));
        expect(bubble.bottom, closeTo(head(tester), 0.5));
        // Too tall for the room over his head: drawn smaller than laid out.
        expect(
          tester.getSize(find.byType(BuddySpeechBubble)).height,
          greaterThan(bubble.height + 1),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('while he talks, Essen and Trinken still open under his '
          'bubble', (tester) async {
        // The hero's width on a 393-wide phone (the harness has no side
        // padding): the ring's middle is narrower than the bubble, so it
        // covers both top bubbles.
        tester.view
          ..physicalSize = const Size(345, 852)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpHero(tester);
        await afterGreeting(tester);

        for (final (need, path) in [
          (CareNeed.food, RoutePaths.mealTracker),
          (CareNeed.drink, RoutePaths.drinkTracker),
        ]) {
          controller(tester).say(longLine);
          await tick(tester);
          final overlap = bubbleRect(
            tester,
          ).intersect(tester.getRect(find.byKey(CareRing.needKey(need))));
          expect(overlap.isEmpty, isFalse, reason: '$need');

          await tester.tapAt(overlap.center);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(location(), path, reason: '$need');

          router.go(RoutePaths.dashboard);
          await tester.pump(const Duration(milliseconds: 500));
        }
      });
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
      expect(find.text('Frühstück eintragen'), findsOneWidget);

      now = DateTime(2026, 11, 22, 10, 30);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(find.text('Mittagessen eintragen'), findsOneWidget);
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
      expect(find.text('Frühstück eintragen'), findsOneWidget);

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tick(tester);
      expect(find.text('Mittagessen eintragen'), findsOneWidget);
      expect(controller(tester).bubble, isNull);
    });

    testWidgets("resumed the next morning: yesterday's meal still counts", (
      tester,
    ) async {
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
      await pumpHero(tester);
      final evening = needMeterLevel(tester, CareNeed.food)!;

      now = DateTime(2026, 11, 23, 8);
      // Nothing logged yet today; the load brings yesterday's meal along.
      entries.next = EntriesState(
        latestBefore: LatestEntries(meal: DateTime(2026, 11, 22, 19)),
      );
      returnFromBackground();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // meter drains

      expect(entries.loaded.map(startOfDay), [DateTime(2026, 11, 23)]);
      // An hour after the night pause: lower than last night, not empty.
      final morning = needMeterLevel(tester, CareNeed.food)!;
      expect(morning, lessThan(evening));
      expect(morning, greaterThan(AppConstants.careMeterFloor));
    });

    testWidgets('open across midnight: the meters carry over', (tester) async {
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
      final beforeMidnight = needMeterLevel(tester, CareNeed.food)!;
      expect(beforeMidnight, greaterThan(AppConstants.careMeterFloor));

      // The minute tick loads the new day, which brings the meal along as
      // the latest before it.
      now = DateTime(2026, 11, 23, 0, 0, 30);
      entries.next = EntriesState(
        latestBefore: LatestEntries(meal: DateTime(2026, 11, 22, 19)),
      );
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(entries.loaded.map(startOfDay), [DateTime(2026, 11, 23)]);
      expect(needMeterLevel(tester, CareNeed.food), beforeMidnight);

      // The night pause held it; from 07:00 it drains again.
      now = DateTime(2026, 11, 23, 7, 30);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(needMeterLevel(tester, CareNeed.food), lessThan(beforeMidnight));
    });

    testWidgets('the meters drain with the minute tick', (tester) async {
      entries = _FakeEntries(
        EntriesState(
          drinks: [testDrinkEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);
      final before = needMeterLevel(tester, CareNeed.drink)!;

      // Still lunch time and the same mood: only the meter moves.
      now = DateTime(2026, 11, 22, 14, 59);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Mittagessen eintragen'), findsOneWidget);
      expect(needMeterLevel(tester, CareNeed.drink), lessThan(before));
    });

    for (final (name, meal, from, to, before, after) in [
      (
        'at the floor',
        DateTime(2026, 11, 22, 7),
        DateTime(2026, 11, 22, 13),
        DateTime(2026, 11, 22, 14),
        'zuletzt vor 6 Std',
        'zuletzt vor 7 Std',
      ),
      (
        'in the night pause',
        DateTime(2026, 11, 22, 21),
        DateTime(2026, 11, 22, 22, 30),
        DateTime(2026, 11, 22, 23, 30),
        'zuletzt vor 1 Std',
        'zuletzt vor 2 Std',
      ),
    ]) {
      testWidgets('the minute tick refreshes what a bubble says while its '
          'meter holds still ($name)', (tester) async {
        final handle = tester.ensureSemantics();
        now = from;
        entries = _FakeEntries(
          EntriesState(meals: [testMealEntry(trackedAt: meal)]),
        );
        await pumpHero(tester);
        String? spoken() => tester
            .getSemantics(find.byKey(CareRing.needKey(CareNeed.food)))
            .value;
        final level = needMeterLevel(tester, CareNeed.food);
        expect(spoken(), before);

        now = to;
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
        expect(spoken(), after);
        expect(needMeterLevel(tester, CareNeed.food), level);
        handle.dispose();
      });
    }

    testWidgets('dinner logged, Essen lowest late in the evening: a snack, '
        'not dinner again', (tester) async {
      // Essen 0.32, Trinken 0.575, Bauchgefühl 0.66.
      now = DateTime(2026, 11, 22, 21, 30);
      entries = _FakeEntries(
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 17, 30))],
          drinks: [testDrinkEntry(trackedAt: DateTime(2026, 11, 22, 20))],
          gutFeelings: [
            testGutFeelingEntry(trackedAt: DateTime(2026, 11, 22, 12)),
          ],
        ),
      );
      await pumpHero(tester);
      await tick(tester);

      expect(find.text('Snack eintragen'), findsOneWidget);
      expect(find.text('Abendessen eintragen'), findsNothing);
      expect(careLines(CareAction.snack), contains(controller(tester).bubble));
    });

    testWidgets("Klo's line ages with the clock, though no meter moves", (
      tester,
    ) async {
      now = DateTime(2026, 11, 22, 12);
      entries = _FakeEntries(
        EntriesState(
          toiletEntries: [
            testToiletEntry(trackedAt: DateTime(2026, 11, 22, 11)),
          ],
        ),
      );
      await pumpHero(tester);
      expect(find.text('vor 1 Std'), findsOneWidget);

      // Still lunch time, every meter still at the floor.
      now = DateTime(2026, 11, 22, 13);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(find.text('vor 2 Std'), findsOneWidget);
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
      // Lunch at 13:00: at 14:00 Trinken is the lowest.
      entries = _FakeEntries(
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 13))],
        ),
      );
      await pumpHero(tester);
      expect(find.text('Trinken eintragen'), findsOneWidget);

      await tester.tap(find.byKey(BuddyHero.actionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(location(), RoutePaths.drinkTracker);
      expect(find.text('page:${RoutePaths.drinkTracker}'), findsOneWidget);
    });

    testWidgets('a bubble opens its own tracker', (tester) async {
      await pumpHero(tester);

      for (final (need, path) in [
        (CareNeed.food, RoutePaths.mealTracker),
        (CareNeed.drink, RoutePaths.drinkTracker),
        (CareNeed.gutFeeling, RoutePaths.gutFeelingTracker),
        (CareNeed.toilet, RoutePaths.toiletTracker),
      ]) {
        await tester.tap(find.byKey(CareRing.needKey(need)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(location(), path, reason: '$need');
        expect(find.text('page:$path'), findsOneWidget);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
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

      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.byType(StreakWeekRow), findsNothing);
    });
  });
}
