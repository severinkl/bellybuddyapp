import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../providers/buddy_events_provider.dart';
import '../../../providers/buddy_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/logger.dart';
import '../../../widgets/buddy/buddy.dart';
import '../../../widgets/buddy/streak_chip.dart';
import '../../../widgets/common/bb_button.dart';
import '../../buddy/streak_goal_picker.dart';

/// The hero's clock (mood, event age). Follows the Buddy's clock
/// ([buddyTodayProvider]) unless overridden; tests pin it.
final buddyClockProvider = Provider<DateTime Function()>(
  (ref) => ref.watch(buddyTodayProvider),
);

/// Lines the hero plays one after another: the follow-up after a log and
/// the [BuddyAnnouncement]s.
enum _Cue {
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

/// The Buddy at the top of the dashboard: streak chip, the animated Buddy
/// with its speech bubble, and the „🍎 Füttern" shortcut to the meal
/// tracker.
///
/// The mood follows today's entries (re-derived on every change and every
/// minute). Everything it says waits until it is visible (`TickerMode` on,
/// i.e. the dashboard is not under the splash or covered by another route
/// or tab): the first mood line, the follow-up to a fresh [BuddyLogEvent]
/// (which also reloads today's entries) and the Buddy's announcements.
/// Without a Buddy status (loading, error, signed out) the Buddy still
/// shows, named 'Buddy', without the streak chip. Its height is a share of
/// the screen height, clamped.
class BuddyHero extends ConsumerStatefulWidget {
  const BuddyHero({super.key});

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
  static const _changeGoalTitle = 'Neues Streak-Ziel';

  late final BuddyController _buddy;
  late final AppLifecycleListener _lifecycle;
  final math.Random _rnd = math.Random();
  Timer? _moodTimer;

  /// Mood derived from today's entries.
  late BuddyMood _careMood;

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

  /// Whether the first mood line was said (or replaced by announcements).
  /// Waits for the Buddy status (real name and streak) and visibility.
  bool _greeted = false;

  /// `TickerMode` of the hero (false until the first dependency update).
  bool _visible = false;

  /// The new-goal sheet is due but the hero was hidden; shown once visible.
  bool _goalSheetDeferred = false;

  /// From a reached goal's celebration until its sheet has closed.
  bool _goalCelebrating = false;

  /// The StreakChip's goal sheet is open.
  bool _chipSheetOpen = false;

  /// The local day for which "today counted" was already thanked for or
  /// known before a log, so "Danke! 🔥 …" is said once per day.
  DateTime? _countedDay;

  DateTime _now() => ref.read(buddyClockProvider)();

  @override
  void initState() {
    super.initState();
    _careMood = _deriveCareMood();
    _buddy = BuddyController(mood: _careMood);
    _moodTimer = Timer.periodic(_moodInterval, (_) => _updateCareMood());
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    ref.listenManual(entriesProvider, (_, _) => _updateCareMood());
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
    _updateCareMood();
    _afterFrame(_consumeEvent);
  }

  // --- Mood -----------------------------------------------------------------

  BuddyMood _deriveCareMood() {
    final now = _now();
    return deriveBuddyMood(
      TodayCare.fromEntries(ref.read(entriesProvider), now),
      now,
    );
  }

  void _updateCareMood() {
    if (!mounted) return;
    final care = _deriveCareMood();
    if (care == _careMood) return;
    _careMood = care;
    _applyMood();
    if (_override == null) _sayMoodLine();
  }

  void _setOverride(BuddyMood? mood) {
    _override = mood;
    _applyMood();
  }

  void _applyMood() => _buddy.mood = _override ?? _careMood;

  String _moodLine(BuddyMood mood) {
    final status = ref.read(buddyProvider).value;
    return moodLine(
      mood,
      name: status?.state.name ?? 'Buddy',
      streak: status?.streak ?? 0,
      now: _now(),
      rnd: _rnd,
    );
  }

  /// Says the current mood's line unless something else holds the stage.
  void _sayMoodLine() {
    if (!_greeted || _cueRunning || _followUpPending) return;
    _whenVisible(() => _buddy.say(_moodLine(_buddy.mood)));
  }

  /// The first mood line, once the Buddy status is known and the hero is
  /// visible. Pending announcements speak first instead.
  void _maybeGreet() => _whenVisible(() {
    if (_greeted) return;
    final buddy = ref.read(buddyProvider);
    if (buddy.isLoading && !buddy.hasValue) return; // first load running
    if (buddy.value?.announcements.isNotEmpty ?? false) return;
    _greeted = true;
    _sayMoodLine();
  });

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
    if (!_followUpPending) {
      _followUpPending = true;
      _enqueue(const [_Cue.followUp]);
    }
    unawaited(_reloadEntries());
  });

  /// Trackers don't refresh [entriesProvider]; reload today so the mood
  /// reflects the new entry.
  Future<void> _reloadEntries() async {
    try {
      await ref.read(entriesProvider.notifier).loadEntries(_now());
    } catch (e, st) {
      _log.error("Reloading today's entries failed", e, st);
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
      _say(_moodLine(_buddy.mood));
    }
  }

  // --- Cue queue --------------------------------------------------------------

  void _say(String line) => _buddy.say(line, duration: _cueLineDuration);

  void _enqueue(Iterable<_Cue> cues) {
    _cues.addAll(cues);
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

  /// The cue on stage has ended: its announcement counts as shown.
  void _markPlayed() {
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
    if (goal != null) unawaited(_saveGoal(goal));
    _nextCue();
  }

  /// The StreakChip's tap: sets or changes the streak goal. Ignored while a
  /// reached goal is celebrated (its own sheet follows) or the sheet is
  /// already open, so sheets never stack.
  Future<void> _changeGoal() async {
    if (_goalCelebrating || _chipSheetOpen) return;
    final streak = ref.read(buddyProvider).value?.streak ?? 0;
    _chipSheetOpen = true;
    final int? goal;
    try {
      goal = await showStreakGoalSheet(
        context,
        currentStreak: streak,
        title: _changeGoalTitle,
      );
    } finally {
      _chipSheetOpen = false;
    }
    if (!mounted || goal == null) return;
    await _saveGoal(goal);
  }

  Future<void> _saveGoal(int goal) async {
    try {
      await ref.read(buddyProvider.notifier).setStreakGoal(goal);
    } catch (e, st) {
      _log.error('Saving the new streak goal failed', e, st);
    }
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(buddyProvider).value;
    final height =
        (MediaQuery.sizeOf(context).height * AppConstants.buddyHeroHeightFactor)
            .clamp(
              AppConstants.buddyHeroMinHeight,
              AppConstants.buddyHeroMaxHeight,
            );
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // As tall as the dashboard's header icons, which sit on its right.
          SizedBox(
            height: AppConstants.iconBadgeLg,
            child: Align(
              alignment: Alignment.centerLeft,
              child: status == null
                  ? null
                  : StreakChip(
                      streak: status.streak,
                      savers: status.state.savers,
                      todayCounted: status.todayCounted,
                      onTap: streakGoalChoices(status.streak).isEmpty
                          ? null
                          : () => unawaited(_changeGoal()),
                    ),
            ),
          ),
          Expanded(
            child: BuddyStage(
              controller: _buddy,
              name: status?.state.name ?? 'Buddy',
              onPoke: _sayMoodLine,
            ),
          ),
          AppConstants.gap8,
          BbButton(
            label: '🍎 Füttern',
            onPressed: () => context.push(RoutePaths.mealTracker),
          ),
        ],
      ),
    );
  }
}
