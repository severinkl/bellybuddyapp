import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/constants.dart';
import '../../../providers/buddy_events_provider.dart';
import '../../../providers/buddy_offers_provider.dart';
import '../../../providers/buddy_provider.dart';
import '../../../providers/buddy_welcome_provider.dart';
import '../../../providers/care_log_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/home_cover_provider.dart';
import '../../../providers/journey_provider.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../providers/today_provider.dart';
import '../../../router/route_names.dart';
import '../../../router/tracker_routes.dart';
import '../../../services/buddy/buddy_copy.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../services/buddy/care_now.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../services/journey/journey_copy.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/logger.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/buddy/buddy.dart';
import '../../../widgets/buddy/streak_chip.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/weekly_tips_switch.dart';
import '../../buddy/streak_goal_picker.dart';
import 'care_ring.dart';
import 'journey_reward_actions.dart';
import 'journey_reward_sheet.dart';
import 'streak_sheet.dart';
import 'tutorial/tutorial_keys.dart';
import 'weekly_tips_offer_sheet.dart';

/// Lines the hero plays one after another: the onboarding's welcome (ahead
/// of all others), the follow-up after a log and the [BuddyAnnouncement]s.
enum _Cue {
  welcome(null),
  followUp(null),
  saverUsed(BuddyAnnouncement.saverUsed),
  streakBroken(BuddyAnnouncement.streakBroken),
  saverEarned(BuddyAnnouncement.saverEarned),
  goalReached(BuddyAnnouncement.goalReached, endsInSheet: true),
  tipsArrived(BuddyAnnouncement.tipsArrived),
  weeklyTipsOffer(BuddyAnnouncement.weeklyTipsOffer, endsInSheet: true),
  firstTipOffer(BuddyAnnouncement.firstTipOffer, endsInSheet: true),
  journeyReward(BuddyAnnouncement.journeyReward, endsInSheet: true),
  patternsUnlocked(BuddyAnnouncement.patternsUnlocked, endsInSheet: true),
  firstTipFailed(BuddyAnnouncement.firstTipFailed);

  const _Cue(this.announcement, {this.endsInSheet = false});

  /// The announcement this cue plays, if any.
  final BuddyAnnouncement? announcement;

  /// Whether the cue ends in a sheet or page (the new goal, the weekly-tips
  /// or first-tip offer, a day's reward, „Muster frei!").
  final bool endsInSheet;
}

_Cue _cueFor(BuddyAnnouncement a) => switch (a) {
  BuddyAnnouncement.saverUsed => _Cue.saverUsed,
  BuddyAnnouncement.streakBroken => _Cue.streakBroken,
  BuddyAnnouncement.saverEarned => _Cue.saverEarned,
  BuddyAnnouncement.goalReached => _Cue.goalReached,
  BuddyAnnouncement.tipsArrived => _Cue.tipsArrived,
  BuddyAnnouncement.weeklyTipsOffer => _Cue.weeklyTipsOffer,
  BuddyAnnouncement.firstTipOffer => _Cue.firstTipOffer,
  BuddyAnnouncement.journeyReward => _Cue.journeyReward,
  BuddyAnnouncement.patternsUnlocked => _Cue.patternsUnlocked,
  BuddyAnnouncement.firstTipFailed => _Cue.firstTipFailed,
};

/// The Buddy at the top of the dashboard: the streak chip (opens „Dein
/// Streak"), his speech bubble, the Buddy inside the [CareRing] of his four
/// needs (tapping a need's bubble opens its tracker; tapping the Buddy
/// makes him talk), and a button that opens the tracker for the next thing
/// to log ([nextCareAction]).
///
/// The need meters, his mood and the next action follow [careNowProvider]
/// (when each need was last logged, seen from the current minute); a new
/// mood or next action gets his resting line, which names what he needs
/// next ([BuddyCopy.care]), except while empathetic, in love, asleep or at
/// night. Every write reloads [entriesProvider]; the hero moves it on to
/// the new day when the day changes ([todayProvider]), and the meters
/// carry over (the new day's load brings the latest entries before it).
/// Everything it says waits until it is visible (`TickerMode` on, i.e. the
/// dashboard is not under the splash or covered by another route or tab):
/// the first line, the follow-up to a fresh [BuddyLogEvent] and the
/// Buddy's announcements. His cues and their sheets also wait while Home is
/// covered ([homeCoveredProvider]: a sheet over it, a page on its way in).
/// Without a Buddy status (loading, error, signed out) the Buddy still
/// shows, named 'Buddy', without the streak chip.
class BuddyHero extends ConsumerStatefulWidget {
  const BuddyHero({super.key, this.openUrl = launchUrl});

  /// Opens day 2's article (a reward); tests record it.
  final UrlOpener openUrl;

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

  /// How long a follow-up or announcement line stays up; the next cue waits
  /// for it.
  static const _cueLineDuration = Duration(seconds: 4);

  static const _saverUsedLine =
      'Puh! Dein Streak-Saver hat uns gestern gerettet 🛡';
  static const _streakBrokenLine = 'Neuer Anlauf — ich bin dabei!';
  static const _saverEarnedLine = 'Du hast einen Streak-Saver verdient! 🛡';
  static const _newGoalTitle = "Wir haben's geschafft! Neues Ziel?";
  static const _tipsArrivedLine = 'Neue Tipps sind da! ✨';

  late final BuddyController _buddy;

  final math.Random _rnd = math.Random();

  /// His needs right now: the meters, his mood from them and the next
  /// action.
  CareNow get _care => ref.read(careNowProvider);

  /// Temporary mood on top of [_care]'s (empathetic after a bad log for
  /// this dashboard visit, in love while celebrating a reached goal).
  BuddyMood? _override;

  final Queue<_Cue> _cues = Queue();
  Timer? _cueTimer;

  /// The cue on stage; its announcement is marked shown when it ends.
  _Cue? _playing;

  /// Announcements queued or playing, not yet marked shown; they stay
  /// pending in [buddyProvider] meanwhile and must not be queued twice.
  final Set<BuddyAnnouncement> _taken = {};

  /// From a cue's start until its line has been up long enough (incl. its
  /// sheet); mood lines wait meanwhile.
  bool _cueRunning = false;

  /// A cue of the running queue played (not every one was withdrawn).
  bool _cuePlayed = false;

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

  /// Whether a drink was logged here within [_thirstPause] of [now]. (One
  /// taken that recently fills Trinken, so it never asks for a drink.)
  bool _justDrank(DateTime now) {
    final at = _drinkLoggedAt;
    return at != null && !at.isAfter(now) && now.difference(at) < _thirstPause;
  }

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

  /// A cue's sheet or page (the new goal, the weekly-tips offer, a day's
  /// reward, „Muster frei!") that came due while the hero was hidden or
  /// Home was covered ([homeCoveredProvider]); shown once Home is free
  /// again ([_resume]).
  Future<void> Function()? _deferredSheet;

  /// A cue that ends in a sheet or page is on stage (a celebration before
  /// it, the weekly-tips offer's wave): from its start until it closed.
  bool get _sheetCueOnStage => _playing?.endsInSheet ?? false;

  /// Whether his cues and their sheets may play: the hero is visible and
  /// nothing covers Home ([homeCoveredProvider]).
  bool get _homeFree => _visible && !ref.read(homeCoveredProvider);

  /// The router whose top route [_onRoute] follows.
  GoRouter? _router;

  /// The local day for which "today counted" was already thanked for or
  /// known before a log, so "Danke! 🔥 …" is said once per day.
  DateTime? _countedDay;

  DateTime _now() => ref.read(buddyClockProvider)();

  @override
  void initState() {
    super.initState();
    _buddy = BuddyController(mood: _care.mood);
    ref.listenManual(careNowProvider, _onCare);
    ref.listenManual(todayProvider, (_, _) => _followDay());
    ref.listenManual(buddyEventsProvider, (_, event) {
      if (event != null) _afterFrame(_consumeEvent);
    });
    ref.listenManual(
      buddyProvider,
      (_, next) => _onStatus(next),
      fireImmediately: true,
    );
    ref.listenManual(homeCoveredProvider, (_, covered) {
      if (!covered) _afterFrame(_resume);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router?..routerDelegate.addListener(_onRoute);
    }
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    final cover = ref.read(homeCoveredProvider.notifier);
    if (visible) {
      _afterFrame(() {
        // Shown again: what left Home no longer covers it.
        cover.homeShown();
        _consumeEvent();
        _takeAnnouncements();
        _maybeGreet();
        _resume();
      });
    } else {
      // Hidden, Home's visibility holds the cues: a page that covered it
      // no longer needs to.
      _afterFrame(cover.homeHidden);
      // Leaving the dashboard ends this visit's empathy.
      if (_override == BuddyMood.empathetic) _setOverride(null);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _cueTimer?.cancel();
    _buddy.dispose();
    super.dispose();
  }

  /// The router moved: back on Home's route (a page popped, or replaced by
  /// a `go` to Home, even on its way in while Home was never hidden), what
  /// left Home no longer covers it ([HomeCoverNotifier.homeShown]).
  void _onRoute() {
    final top = _router?.routerDelegate.currentConfiguration.lastOrNull;
    if (top?.matchedLocation != RoutePaths.dashboard) return;
    _afterFrame(ref.read(homeCoveredProvider.notifier).homeShown);
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

  // --- Mood -----------------------------------------------------------------

  /// A new day: once the loaded day is over, loads the new one for the
  /// ring. After the frame, where provider writes are always allowed.
  void _followDay() {
    bool over() {
      final day = ref.read(entriesProvider).day;
      return day != null && !isSameDay(day, ref.read(todayProvider));
    }

    if (!over()) return;
    _afterFrame(() {
      if (over()) unawaited(_loadToday());
    });
  }

  /// His needs moved on (a log, the clock): a new mood or next action gets
  /// its line. Hidden, he says nothing, and what changed meanwhile is never
  /// said ([_sayMoodLine]).
  void _onCare(CareNow? previous, CareNow next) {
    final moodChanged = previous?.mood != next.mood;
    if (!moodChanged && previous?.action == next.action) return;
    if (moodChanged) _applyMood();
    if (_override == null) _sayMoodLine();
  }

  void _setOverride(BuddyMood? mood) {
    _override = mood;
    _applyMood();
  }

  void _applyMood() => _buddy.mood = _override ?? _care.mood;

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
      final action = _care.action;
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
    _loggedNeed = careNeedOf(event.kind);
    if (event.kind == EntryKind.drink) _drinkLoggedAt = event.at;
    if (!_followUpPending) {
      _followUpPending = true;
      _enqueue(const [_Cue.followUp]);
    }
  });

  /// Loads today's entries.
  Future<void> _loadToday() async {
    try {
      await ref
          .read(entriesProvider.notifier)
          .loadEntries(ref.read(todayProvider));
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
      // All withdrawn (a lone „Neue Tipps" whose set was opened): the
      // greeting they replaced is still due.
      if (!_cuePlayed) _sayMoodLine();
      _cuePlayed = false;
      return;
    }
    if (!_homeFree) {
      // Goes on once Home is free again ([_resume]).
      _cueRunning = false;
      return;
    }
    _cueRunning = true;
    final cue = _playing = _cues.removeFirst();
    // Withdrawn meanwhile (the set opened, the weekly tips switched on): it
    // ends unplayed.
    if (!_stillApplies(cue)) return _nextCue();
    _cuePlayed = true;
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
        _playThen(BuddyAction.celebrate, _askForNewGoal);
        _setOverride(BuddyMood.inLove);
      case _Cue.tipsArrived:
        _buddy.play(BuddyAction.celebrate);
        _say(_tipsArrivedLine);
        _holdStage();
      case _Cue.weeklyTipsOffer:
        _playThen(BuddyAction.wave, _offerWeeklyTips);
      case _Cue.firstTipOffer:
        _playThen(BuddyAction.wave, _offerFirstTip);
      case _Cue.journeyReward:
        _playThen(BuddyAction.celebrate, _showJourneyReward);
      case _Cue.patternsUnlocked:
        _playThen(BuddyAction.celebrate, _openPatternsUnlocked);
      case _Cue.firstTipFailed:
        _say(JourneyCopy.firstTipFailed);
        _holdStage();
    }
  }

  /// Plays [action], then, once it has played, [then] (the cue's sheet or
  /// page).
  void _playThen(BuddyAction action, Future<void> Function() then) {
    _buddy.play(action);
    _cueTimer = Timer(buddyActionDuration(action), () => unawaited(then()));
  }

  /// Home is free again (visible, uncovered): the sheet that waited opens,
  /// or the queue that waited goes on.
  void _resume() {
    if (!_homeFree) return;
    _showDeferredSheet();
    if (!_cueRunning && _cues.isNotEmpty) _nextCue();
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

  /// Whether [cue]'s announcement still applies ([offerStillAppliesProvider]).
  bool _stillApplies(_Cue? cue) => switch (cue?.announcement) {
    final a? => ref.read(offerStillAppliesProvider(a)),
    null => true,
  };

  /// Shows the sheet that waited, if any (it checks again whether it may).
  /// Withdrawn while it waited, its cue ends without it.
  void _showDeferredSheet() {
    final sheet = _deferredSheet;
    if (sheet == null || !mounted) return;
    _deferredSheet = null;
    if (!_stillApplies(_playing)) return _nextCue();
    unawaited(sheet());
  }

  /// After the goal celebration: offers the next goal, then continues;
  /// waits like every cue's sheet ([_deferSheet]).
  Future<void> _askForNewGoal() async {
    if (_deferSheet(_askForNewGoal)) return;
    final streak = ref.read(buddyProvider).value?.streak ?? 0;
    int? goal;
    if (streakGoalChoices(streak).isNotEmpty) {
      goal = await showStreakGoalSheet(
        context,
        currentStreak: streak,
        title: _newGoalTitle,
      );
      if (!mounted) return;
    }
    _setOverride(null);
    if (goal != null) unawaited(saveStreakGoal(ref, goal));
    _nextCue();
  }

  /// Whether a cue's sheet or page must wait until Home is free again
  /// ([_homeFree]: the hero was hidden meanwhile, or something covers Home;
  /// sheets never stack). Then [show] is deferred.
  bool _deferSheet(Future<void> Function() show) {
    if (_homeFree) return false;
    _deferredSheet = show;
    return true;
  }

  /// After the wave: the weekly tips' offer off the journey („Zu den Tipps"
  /// opens Entdecken), then continues; waits like every cue's sheet
  /// ([_deferSheet]). On the journey or undecided by now: none.
  Future<void> _offerWeeklyTips() async {
    if (_deferSheet(_offerWeeklyTips)) return;
    if (ref.read(journeyProvider) == false) {
      final open = await showWeeklyTipsOfferSheet(context);
      if (!mounted) return;
      if (open) {
        ref.read(homeCoveredProvider.notifier).leftHome(null);
        context.go(RoutePaths.discover);
      }
    }
    _nextCue();
  }

  /// After the wave: day 3's offer of a first tip ([offerFirstTip]), then
  /// continues; waits like every cue's sheet ([_deferSheet]). „Ja, gern"
  /// started → he says it is on its way, holding the stage; the opt-in
  /// failed → a SnackBar; „Nein, danke" was answered there. A dismissal
  /// here counts as „Nein" (the offer doesn't come again), but only while
  /// the hero is still here: gone, nothing is stored and the offer comes
  /// again. Off the journey or undecided by now (another user): none.
  Future<void> _offerFirstTip() async {
    if (_deferSheet(_offerFirstTip)) return;
    if (ref.read(journeyProvider) != true) return _nextCue();
    final outcome = await offerFirstTip(context, ref);
    if (!mounted) return;
    switch (outcome) {
      case FirstTipOutcome.started:
        _say(JourneyCopy.firstTipStarted);
        _holdStage();
      case FirstTipOutcome.optInFailed:
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(WeeklyTipsSwitch.failure)),
        );
        _nextCue();
      case FirstTipOutcome.declined:
        _nextCue();
      case FirstTipOutcome.dismissed:
        unawaited(
          ref
              .read(journeyRewardsProvider.notifier)
              .answerTipOffer(accepted: false),
        );
        _nextCue();
    }
  }

  /// After the celebration: the newest earned day's reward in its sheet
  /// ([showJourneyRewardSheet]; its primary button opens it), then
  /// continues; waits like every cue's sheet ([_deferSheet]). No day to
  /// announce (any more): it ends without one.
  Future<void> _showJourneyReward() async {
    if (_deferSheet(_showJourneyReward)) return;
    final day = ref.read(journeyRewardAnnouncementProvider);
    if (day == null) return _nextCue();
    final open = await showJourneyRewardSheet(context, day: day);
    if (!mounted) return;
    if (open) {
      await openJourneyReward(context, ref, day, openUrl: widget.openUrl);
    }
    if (!mounted) return;
    _nextCue();
  }

  /// After the celebration: „Muster frei!" over Home, then continues once
  /// Home is free again (the page left it, [homeCoveredProvider]); waits
  /// like every cue's sheet ([_deferSheet]).
  Future<void> _openPatternsUnlocked() async {
    if (_deferSheet(_openPatternsUnlocked)) return;
    ref
        .read(homeCoveredProvider.notifier)
        .leftHome(context.push(RoutePaths.patternsUnlocked));
    _nextCue();
  }

  /// The StreakChip's tap: „Dein Streak", where the goal can be set or
  /// changed; it covers Home ([HomeCoverNotifier.whileOpen]), so the cues
  /// wait until it has closed. Ignored while a cue's sheet is coming
  /// ([_sheetCueOnStage]) or Home is covered (the sheet already open), so
  /// sheets never stack.
  Future<void> _openStreakSheet() async {
    final status = ref.read(buddyProvider).value;
    final cover = ref.read(homeCoveredProvider.notifier);
    if (status == null || _sheetCueOnStage || ref.read(homeCoveredProvider)) {
      return;
    }
    await cover.whileOpen(
      () => openStreakSheetAndSaveGoal(
        context,
        ref,
        status: status,
        today: _now(),
      ),
    );
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(buddyProvider).value;
    final care = ref.watch(careNowProvider);
    final action = care.action;
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
                  care: care,
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
