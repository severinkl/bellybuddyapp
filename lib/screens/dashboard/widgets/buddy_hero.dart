import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../providers/buddy_events_provider.dart';
import '../../../providers/buddy_provider.dart';
import '../../../providers/buddy_welcome_provider.dart';
import '../../../providers/daily_care_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/tracker_routes.dart';
import '../../../services/buddy/buddy_copy.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/logger.dart';
import '../../../widgets/buddy/buddy.dart';
import '../../../widgets/buddy/streak_chip.dart';
import '../../../widgets/common/bb_button.dart';
import '../../buddy/streak_goal_picker.dart';
import 'care_ring.dart';
import 'streak_sheet.dart';
import 'tutorial/tutorial_keys.dart';

/// Lines the hero plays one after another: the onboarding's welcome (ahead
/// of all others), the follow-up after a log and the [BuddyAnnouncement]s.
enum _Cue {
  welcome(null),
  followUp(null),
  saverUsed(BuddyAnnouncement.saverUsed),
  streakBroken(BuddyAnnouncement.streakBroken),
  saverEarned(BuddyAnnouncement.saverEarned),
  goalReached(BuddyAnnouncement.goalReached);

  const _Cue(this.announcement);

  /// The announcement this cue plays, if any.
  final BuddyAnnouncement? announcement;
}

_Cue _cueFor(BuddyAnnouncement a) =>
    _Cue.values.firstWhere((cue) => cue.announcement == a);

/// The Buddy at the top of the dashboard: the streak chip (opens „Dein
/// Streak"), his speech bubble, the Buddy inside the [CareRing] of his four
/// daily needs (tapping a need's bubble opens its tracker; tapping the
/// Buddy makes him talk), and a button that opens the tracker for the next
/// thing to log ([nextCareAction]).
///
/// The mood follows today's entries (re-derived on every change and every
/// minute); his resting line names what he needs next ([BuddyCopy.care]),
/// except while empathetic, in love, asleep or at night. Every write
/// reloads [entriesProvider]; the hero moves it on to the new day once his
/// clock has passed midnight (minute tick, resume, shown again), and the
/// ring shows its day. Everything it says waits until it is
/// visible (`TickerMode` on, i.e. the dashboard is not under the splash or
/// covered by another route or tab): the first line, the follow-up to a
/// fresh [BuddyLogEvent] and the Buddy's announcements. Without a Buddy
/// status (loading, error, signed out) the Buddy still shows, named
/// 'Buddy', without the streak chip.
class BuddyHero extends ConsumerStatefulWidget {
  const BuddyHero({super.key});

  /// The next-action button under the ring.
  static const actionKey = Key('buddy_hero_next_action');

  @override
  ConsumerState<BuddyHero> createState() => _BuddyHeroState();
}

class _BuddyHeroState extends ConsumerState<BuddyHero> {
  static const _log = AppLogger('BuddyHero');

  /// Log events older than this are dropped without a follow-up.
  static const _eventMaxAge = Duration(minutes: 2);
  static const _followUpDelay = Duration(milliseconds: 600);

  /// The follow-up waits at most this long for the Buddy refresh the log
  /// started, so "Danke! 🔥" sees the new streak on a slow connection.
  static const _refreshWait = Duration(seconds: 3);
  static const _moodInterval = Duration(minutes: 1);

  /// How long a follow-up or announcement line stays up; the next cue waits
  /// for it.
  static const _cueLineDuration = Duration(seconds: 4);

  static const _saverUsedLine =
      'Puh! Dein Streak-Saver hat uns gestern gerettet 🛡';
  static const _streakBrokenLine = 'Neuer Anlauf — ich bin dabei!';
  static const _saverEarnedLine = 'Du hast einen Streak-Saver verdient! 🛡';
  static const _newGoalTitle = "Wir haben's geschafft! Neues Ziel?";

  late final BuddyController _buddy;

  late final AppLifecycleListener _lifecycle;
  final math.Random _rnd = math.Random();
  Timer? _moodTimer;

  /// Today's care, derived from the loaded day's entries (see
  /// [_deriveCare]): re-derived on every change of it, every minute and
  /// on resume. The ring, his mood and the next action all follow it.
  late DailyCare _care;
  late DateTime _careAt;

  /// Mood derived from today's entries.
  BuddyMood get _careMood => deriveBuddyMood(_care, _careAt);

  /// What he needs next, from today's entries and the time of day.
  CareAction get _careAction => nextCareAction(_care, _careAt);

  /// Temporary mood on top of [_careMood] (empathetic after a bad log for
  /// this dashboard visit, in love while celebrating a reached goal).
  BuddyMood? _override;

  final Queue<_Cue> _cues = Queue();
  Timer? _cueTimer;

  /// The cue on stage; its announcement is marked shown when it ends.
  _Cue? _playing;

  /// Announcements queued or playing, not yet marked shown; they stay
  /// pending in [buddyProvider] meanwhile and must not be queued twice.
  final Set<BuddyAnnouncement> _taken = {};

  /// From a cue's start until its line has been up long enough (incl. the
  /// goal sheet); mood lines wait meanwhile.
  bool _cueRunning = false;

  /// A log's follow-up is queued and not said yet.
  bool _followUpPending = false;

  /// The Buddy refresh of the latest log ([BuddyEventsNotifier.lastRefresh]).
  Future<void>? _logRefresh;

  /// The need of the log the pending follow-up answers.
  CareNeed? _loggedNeed;

  /// When a drink was last logged here (the entry's time may lie earlier).
  DateTime? _drinkLoggedAt;

  /// After a drink he doesn't ask for the next one this soon: he thanks
  /// for it instead ([BuddyCopy.careAfterLog]).
  static const _thirstPause = Duration(minutes: 30);

  /// Whether a drink was logged, or taken, within [_thirstPause] of [now].
  bool _justDrank(DateTime now) => [_drinkLoggedAt, _care.lastDrinkAt].any(
    (t) => t != null && !t.isAfter(now) && now.difference(t) < _thirstPause,
  );

  /// The line he said last; a pool never repeats it right away (a few taps
  /// in a row each get another line).
  String? _lastLine;

  /// Whether the first mood line was said (or replaced by the welcome or
  /// announcements). Waits for the Buddy status (real name and streak) and
  /// visibility.
  bool _greeted = false;

  /// The line of [_Cue.welcome] ([buddyWelcomeProvider]'s, once taken).
  String _welcome = BuddyWelcomeNotifier.line;

  /// `TickerMode` of the hero (false until the first dependency update).
  bool _visible = false;

  /// The new-goal sheet is due but the hero was hidden; shown once visible.
  bool _goalSheetDeferred = false;

  /// From a reached goal's celebration until its sheet has closed.
  bool _goalCelebrating = false;

  /// The StreakChip's „Dein Streak" sheet is open.
  bool _chipSheetOpen = false;

  /// The local day for which "today counted" was already thanked for or
  /// known before a log, so "Danke! 🔥 …" is said once per day.
  DateTime? _countedDay;

  DateTime _now() => ref.read(buddyClockProvider)();

  @override
  void initState() {
    super.initState();
    _deriveCare();
    _buddy = BuddyController(mood: _careMood);
    // Hidden, the hero skips the minute ticks; it catches up once visible.
    _moodTimer = Timer.periodic(_moodInterval, (_) {
      if (_visible) _updateCare();
    });
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    // The care itself, not the entries it derives from: a listener of
    // entriesProvider that reads dailyCareProvider can get its previous
    // value (dependents are told in subscription order), which left the
    // ring on an empty day after a load until the next minute tick.
    ref.listenManual(dailyCareProvider, (_, _) => _updateCare());
    ref.listenManual(buddyEventsProvider, (_, event) {
      if (event != null) _afterFrame(_consumeEvent);
    });
    ref.listenManual(
      buddyProvider,
      (_, next) => _onStatus(next),
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _afterFrame(() {
        // What changed while hidden was never said; it isn't now either.
        _updateCare(speak: false);
        _consumeEvent();
        _takeAnnouncements();
        _maybeGreet();
        if (_goalSheetDeferred) unawaited(_askForNewGoal());
      });
    } else if (_override == BuddyMood.empathetic) {
      // Leaving the dashboard ends this visit's empathy.
      _setOverride(null);
    }
  }

  @override
  void dispose() {
    _moodTimer?.cancel();
    _cueTimer?.cancel();
    _lifecycle.dispose();
    _buddy.dispose();
    super.dispose();
  }

  /// Runs [fn] only while the hero is visible: nothing is said or played
  /// while the dashboard is hidden.
  void _whenVisible(VoidCallback fn) {
    if (_visible) fn();
  }

  /// Runs [fn] after the current frame (provider writes are not allowed
  /// while building).
  void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _onResume() {
    _updateCare();
    _afterFrame(_consumeEvent);
  }

  // --- Mood -----------------------------------------------------------------

  /// The care of the loaded day ([dailyCareProvider]), at [_careAt].
  void _deriveCare() {
    _careAt = _now();
    _care = ref.read(dailyCareProvider);
  }

  /// Once the loaded day is over by his clock (midnight passed, or the app
  /// slept through it), loads the new one for the ring. After the frame:
  /// this may run while the entries notify.
  void _followDay() {
    bool over() {
      final day = ref.read(entriesProvider).day;
      return day != null && !isSameDay(day, _careAt);
    }

    if (!over()) return;
    _afterFrame(() {
      if (over()) unawaited(_loadToday());
    });
  }

  /// Re-derives today's care; a new mood or next action gets its line,
  /// unless not to [speak].
  void _updateCare({bool speak = true}) {
    if (!mounted) return;
    final (care, mood, action) = (_care, _careMood, _careAction);
    _deriveCare();
    _followDay();
    final moodChanged = _careMood != mood;
    final actionChanged = _careAction != action;
    // The ring, its glow and the button follow the entries and the clock.
    if (_care != care || actionChanged) setState(() {});
    if (!moodChanged && !actionChanged) return;
    if (moodChanged) _applyMood();
    if (speak && _override == null) _sayMoodLine();
  }

  void _setOverride(BuddyMood? mood) {
    _override = mood;
    _applyMood();
  }

  void _applyMood() => _buddy.mood = _override ?? _careMood;

  /// His resting line: what he needs next by day, else the [mood]'s line
  /// (empathetic, in love, asleep, or at night); never the line he just
  /// said. Right after a log of [justLogged], when he would ask for more of
  /// the same, he thanks for it instead ([BuddyCopy.careAfterLog]); after a
  /// drink he does so for [_thirstPause].
  String _moodLine(BuddyMood mood, {CareNeed? justLogged}) {
    final status = ref.read(buddyProvider).value;
    final name = status?.state.name ?? 'Buddy';
    final now = _now();
    final byDay = DayParts.isDay(now);
    const moodOnly = {BuddyMood.empathetic, BuddyMood.inLove, BuddyMood.asleep};
    if (byDay && !moodOnly.contains(mood)) {
      final action = _careAction;
      final moreOfTheSame =
          (justLogged != null && justLogged == action.need) ||
          (action == CareAction.drink && _justDrank(now));
      final pool =
          (moreOfTheSame ? BuddyCopy.careAfterLog[action] : null) ??
          BuddyCopy.care[action]!;
      final lines = [for (final l in pool) BuddyCopy.fill(l, name: name)];
      final fresh = [
        for (final l in lines)
          if (l != _lastLine) l,
      ];
      return BuddyCopy.pick(fresh.isEmpty ? lines : fresh, _rnd);
    }
    return moodLine(
      mood,
      name: name,
      streak: status?.streak ?? 0,
      now: now,
      rnd: _rnd,
      avoid: _lastLine,
    );
  }

  /// Says the current mood's line unless something else holds the stage.
  void _sayMoodLine() {
    if (!_greeted || _cueRunning || _followUpPending) return;
    _whenVisible(() => _speak(_moodLine(_buddy.mood)));
  }

  /// Says [line] (for [duration], else the bubble's default) and remembers
  /// it as his last.
  void _speak(String line, {Duration? duration}) {
    _lastLine = line;
    duration == null ? _buddy.say(line) : _buddy.say(line, duration: duration);
  }

  /// The first mood line, once the Buddy status is known and the hero is
  /// visible. A pending welcome or announcements greet instead.
  void _maybeGreet() => _whenVisible(() {
    if (_takeWelcome()) {
      if (!_cueRunning) _nextCue();
      return;
    }
    if (_greeted) return;
    final buddy = ref.read(buddyProvider);
    if (buddy.isLoading && !buddy.hasValue) return; // first load running
    if (buddy.value?.announcements.isNotEmpty ?? false) return;
    _greeted = true;
    _sayMoodLine();
  });

  /// Takes the onboarding's pending welcome ([buddyWelcomeProvider]) ahead
  /// of every queued cue: it greets, and a log's follow-up or the
  /// announcements wait for it. False if none is pending.
  bool _takeWelcome() {
    final line = ref.read(buddyWelcomeProvider.notifier).take();
    if (line == null) return false;
    _welcome = line;
    _greeted = true;
    _cues.addFirst(_Cue.welcome);
    return true;
  }

  // --- Buddy status -----------------------------------------------------------

  void _onStatus(AsyncValue<BuddyStatus?> next) {
    if (next.isLoading && !next.hasValue) return; // first load still running
    final status = next.value;
    _noteCountedIfIdle(status);
    _maybeGreet();
    if (status != null && status.announcements.isNotEmpty) {
      _afterFrame(_takeAnnouncements);
    }
  }

  /// Remembers that today already counts, unless a log's follow-up is still
  /// to come (that one thanks for it).
  void _noteCountedIfIdle(BuddyStatus? status) {
    if (status == null || !status.todayCounted) return;
    if (_followUpPending || ref.read(buddyEventsProvider) != null) return;
    _countedDay = startOfDay(_now());
  }

  /// Hands the pending announcements not queued yet to the cue queue. They
  /// stay pending in [buddyProvider] until played (see [_nextCue]), so one
  /// cut short (app closed) comes again.
  void _takeAnnouncements() => _whenVisible(() {
    final status = ref.read(buddyProvider).value;
    if (status == null) return;
    final fresh = [
      for (final a in status.announcements)
        if (!_taken.contains(a)) a,
    ];
    if (fresh.isEmpty) return;
    _taken.addAll(fresh);
    _greeted = true; // the announcements greet instead
    _enqueue(fresh.map(_cueFor));
  });

  // --- Log events -------------------------------------------------------------

  void _consumeEvent() => _whenVisible(() {
    if (ref.read(buddyEventsProvider) == null) return;
    final events = ref.read(buddyEventsProvider.notifier);
    final event = events.consume();
    if (event == null) return;
    if (_now().difference(event.at) > _eventMaxAge) {
      _noteCountedIfIdle(ref.read(buddyProvider).value);
      return;
    }
    if (event.sentiment == LogSentiment.bad) {
      _setOverride(BuddyMood.empathetic);
    }
    _logRefresh = events.lastRefresh;
    _loggedNeed = _needOf(event.kind);
    if (event.kind == EntryKind.drink) _drinkLoggedAt = event.at;
    if (!_followUpPending) {
      _followUpPending = true;
      _enqueue(const [_Cue.followUp]);
    }
  });

  /// Loads the entries of [_careAt]'s day.
  Future<void> _loadToday() async {
    try {
      await ref.read(entriesProvider.notifier).loadEntries(_careAt);
    } catch (e, st) {
      _log.error("Loading today's entries failed", e, st);
    }
  }

  /// Says the follow-up once the log's Buddy refresh is done (waiting at
  /// most [_refreshWait]), then holds the stage.
  Future<void> _followUpAfterRefresh() async {
    final refresh = _logRefresh;
    _logRefresh = null;
    if (refresh != null) {
      try {
        await refresh.timeout(_refreshWait);
      } on TimeoutException {
        // Slow backend: go on with what is known.
      }
    }
    if (!mounted) return;
    _sayFollowUp();
    _holdStage();
  }

  void _sayFollowUp() {
    _followUpPending = false;
    final status = ref.read(buddyProvider).value;
    final today = startOfDay(_now());
    if (status != null && status.todayCounted && _countedDay != today) {
      _countedDay = today;
      final days = status.streak == 1 ? 'Tag' : 'Tage';
      _say('Danke! 🔥 ${status.streak} $days');
    } else {
      _say(_moodLine(_buddy.mood, justLogged: _loggedNeed));
    }
    _loggedNeed = null;
  }

  static CareNeed _needOf(EntryKind kind) => switch (kind) {
    EntryKind.meal => CareNeed.food,
    EntryKind.drink => CareNeed.drink,
    EntryKind.gutFeeling => CareNeed.gutFeeling,
    EntryKind.toilet => CareNeed.toilet,
  };

  // --- Cue queue --------------------------------------------------------------

  void _say(String line) => _speak(line, duration: _cueLineDuration);

  void _enqueue(Iterable<_Cue> cues) {
    _cues.addAll(cues);
    _takeWelcome();
    if (!_cueRunning) _nextCue();
  }

  void _holdStage() => _cueTimer = Timer(_cueLineDuration, _nextCue);

  void _nextCue() {
    _cueTimer?.cancel();
    if (!mounted) {
      _cueRunning = false;
      return;
    }
    _markPlayed();
    if (_cues.isEmpty) {
      _cueRunning = false;
      return;
    }
    _cueRunning = true;
    final cue = _playing = _cues.removeFirst();
    switch (cue) {
      case _Cue.welcome:
        _say(_welcome);
        _holdStage();
      case _Cue.followUp:
        _cueTimer = Timer(
          _followUpDelay,
          () => unawaited(_followUpAfterRefresh()),
        );
      case _Cue.saverUsed:
        _buddy.play(BuddyAction.hug);
        _say(_saverUsedLine);
        _holdStage();
      case _Cue.streakBroken:
        _say(_streakBrokenLine);
        _holdStage();
      case _Cue.saverEarned:
        _buddy.play(BuddyAction.celebrate);
        _say(_saverEarnedLine);
        _holdStage();
      case _Cue.goalReached:
        _goalCelebrating = true;
        _buddy.play(BuddyAction.celebrate);
        _setOverride(BuddyMood.inLove);
        _cueTimer = Timer(
          buddyActionDuration(BuddyAction.celebrate),
          () => unawaited(_askForNewGoal()),
        );
    }
  }

  /// The cue on stage has ended: its announcement counts as shown, and a
  /// welcome as said (Home's tour waits for it).
  void _markPlayed() {
    if (_playing == _Cue.welcome) {
      ref.read(buddyWelcomeProvider.notifier).markPlayed();
    }
    final played = _playing?.announcement;
    _playing = null;
    if (played == null) return;
    _taken.remove(played);
    unawaited(
      ref.read(buddyProvider.notifier).markAnnouncementsShown([played]),
    );
  }

  /// After the goal celebration: offers the next goal, then continues.
  /// Waits until the hero is visible again if it was hidden meanwhile.
  Future<void> _askForNewGoal() async {
    if (!_visible) {
      _goalSheetDeferred = true;
      return;
    }
    _goalSheetDeferred = false;
    final streak = ref.read(buddyProvider).value?.streak ?? 0;
    int? goal;
    // With the StreakChip's sheet open the user is picking a goal already.
    if (!_chipSheetOpen && streakGoalChoices(streak).isNotEmpty) {
      goal = await showStreakGoalSheet(
        context,
        currentStreak: streak,
        title: _newGoalTitle,
      );
      if (!mounted) return;
    }
    _goalCelebrating = false;
    _setOverride(null);
    if (goal != null) unawaited(saveStreakGoal(ref, goal));
    _nextCue();
  }

  /// The StreakChip's tap: „Dein Streak", where the goal can be set or
  /// changed. Ignored while a reached goal is celebrated (its own sheet
  /// follows) or the sheet is already open, so sheets never stack.
  Future<void> _openStreakSheet() async {
    final status = ref.read(buddyProvider).value;
    if (status == null || _goalCelebrating || _chipSheetOpen) return;
    _chipSheetOpen = true;
    try {
      await openStreakSheetAndSaveGoal(
        context,
        ref,
        status: status,
        today: _now(),
      );
    } finally {
      _chipSheetOpen = false;
    }
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(buddyProvider).value;
    final action = _careAction;
    final name = status?.state.name ?? 'Buddy';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Keeps its height while the chip waits for the Buddy status.
        SizedBox(
          height: AppConstants.iconBadgeLg,
          child: Align(
            alignment: Alignment.centerLeft,
            child: status == null
                ? null
                : StreakChip(
                    streak: status.streak,
                    todayCounted: status.todayCounted,
                    onTap: () => unawaited(_openStreakSheet()),
                  ),
          ),
        ),
        AppConstants.gap8,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final diameter = CareRing.diameterFor(
              width,
              MediaQuery.sizeOf(context).height,
            );
            final buddySide = diameter * AppConstants.careRingBuddyFactor;
            return Column(
              children: [
                BuddyBubbleSlot(
                  controller: _buddy,
                  width: width,
                  buddyArea: Size.square(buddySide),
                ),
                CareRing(
                  care: _care,
                  diameter: diameter,
                  highlight: action.need,
                  onNeed: (need) => openTracker(context, need),
                  buddy: AnimatedBuddy(
                    controller: _buddy,
                    name: name,
                    onPoke: _sayMoodLine,
                  ),
                ),
              ],
            );
          },
        ),
        AppConstants.gap12,
        KeyedSubtree(
          key: TutorialKeys.nextAction,
          child: BbButton(
            tapKey: BuddyHero.actionKey,
            label: BuddyCopy.careButton(action),
            onPressed: () => openTracker(context, action.need ?? CareNeed.food),
          ),
        ),
      ],
    );
  }
}
