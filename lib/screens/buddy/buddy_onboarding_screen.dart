import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/buddy_reactions.dart';
import '../../config/constants.dart';
import '../../models/user_profile.dart';
import '../../providers/buddy_events_provider.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/buddy_welcome_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/logger.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/buddy/buddy_side_header.dart';
import '../../widgets/common/bb_button.dart';
import '../registration/steps/buddy_name_step.dart';
import 'streak_goal_picker.dart';
import 'widgets/reminder_preview.dart';
import 'widgets/streak_moment.dart';

/// Where `/buddy-onboarding` was opened from.
enum BuddyOnboardingEntry {
  /// Right after sign-up; the wizard already named the Buddy.
  afterRegistration,

  /// The router gate: a signed-in user whose Buddy onboarding isn't done.
  gate,
}

enum BuddyOnboardingStep {
  intro,
  name,
  firstMeal,
  streakMoment,
  streakGoal,
  reminder,
}

/// The steps for [entry]: the intro and naming only for a gate user without
/// a Buddy row ([hasRow]), the first meal only right after registration,
/// then the streak moment and the goal, and the reminder ask only while
/// push is off ([remindersAlreadyOn]). The last step's answer completes
/// the onboarding and opens the dashboard.
List<BuddyOnboardingStep> buddyOnboardingSteps({
  required BuddyOnboardingEntry entry,
  required bool hasRow,
  required bool remindersAlreadyOn,
}) => [
  if (entry == BuddyOnboardingEntry.gate && !hasRow) ...[
    BuddyOnboardingStep.intro,
    BuddyOnboardingStep.name,
  ],
  if (entry == BuddyOnboardingEntry.afterRegistration)
    BuddyOnboardingStep.firstMeal,
  BuddyOnboardingStep.streakMoment,
  BuddyOnboardingStep.streakGoal,
  if (!remindersAlreadyOn) BuddyOnboardingStep.reminder,
];

/// The Buddy's line on the streak moment for [streak] days.
String streakMomentLine(int streak) => switch (streak) {
  <= 0 => 'Mit deinem nächsten Eintrag startet unser Streak!',
  1 => 'Tag 1! Unser Streak ist geboren.',
  _ => 'Unser Streak: $streak Tage! Weiter so.',
};

/// The Buddy-hosted sequence after sign-up (or for existing users via the
/// gate): first meal, the streak moment („Tag 1! Unser Streak ist
/// geboren."), the streak goal and the reminder ask; the last answer
/// completes the Buddy onboarding and opens the dashboard, where the Buddy
/// welcomes the user. Right after sign-up without an entry today the streak
/// moment is skipped. One Buddy stays on top across all steps; system back
/// returns to the previous step.
class BuddyOnboardingScreen extends ConsumerStatefulWidget {
  const BuddyOnboardingScreen({
    super.key,
    this.entry = BuddyOnboardingEntry.gate,
  });

  final BuddyOnboardingEntry entry;

  static const introNextKey = Key('buddy_onboarding_intro_next');
  static const nameNextKey = Key('buddy_onboarding_name_next');
  static const reminderYesKey = Key('buddy_onboarding_reminder_yes');
  static const reminderLaterKey = Key('buddy_onboarding_reminder_later');
  static const mealLogKey = Key('buddy_onboarding_meal_log');
  static const mealLaterKey = Key('buddy_onboarding_meal_later');
  static const momentNextKey = Key('buddy_onboarding_moment_next');

  @override
  ConsumerState<BuddyOnboardingScreen> createState() =>
      _BuddyOnboardingScreenState();
}

class _BuddyOnboardingScreenState extends ConsumerState<BuddyOnboardingScreen> {
  static const _log = AppLogger('BuddyOnboarding');

  /// The steps whose bubble sits beside a small Buddy above a list
  /// (Layout 1); the others show him centred under his bubble.
  static const _sideSteps = {
    BuddyOnboardingStep.streakGoal,
    BuddyOnboardingStep.reminder,
  };

  /// Reactions stay this long (long enough to read across a step change),
  /// then the Buddy asks the step's question again
  /// ([BuddyController.sayThenRest]).
  static const _reactionHold = Duration(seconds: 4);

  /// The steps with little content below the Buddy: he gets a bigger
  /// stage ([AppConstants.buddyOnboardingHeroStageHeight]).
  static const _heroSteps = {
    BuddyOnboardingStep.intro,
    BuddyOnboardingStep.firstMeal,
    BuddyOnboardingStep.streakMoment,
  };

  /// The stage never takes more than this share of the height (small
  /// screens, open keyboard), so the step content keeps room; the bigger
  /// stage of [_heroSteps] at most [_maxHeroStageShare].
  static const double _maxStageShare = 0.33;
  static const double _maxHeroStageShare = 0.45;

  /// The stage's height on [step] in a [height] tall screen.
  static double _stageHeight(BuddyOnboardingStep step, double height) =>
      _heroSteps.contains(step)
      ? math.min(
          AppConstants.buddyOnboardingHeroStageHeight,
          height * _maxHeroStageShare,
        )
      : math.min(
          AppConstants.buddyOnboardingStageHeight,
          height * _maxStageShare,
        );

  final BuddyController _buddy = BuddyController();
  final math.Random _rnd = math.Random();
  final ScrollController _scroll = ScrollController();

  /// Fixed once the Buddy and the profile have loaded.
  List<BuddyOnboardingStep>? _steps;
  int _index = 0;
  String _name = 'Buddy';

  /// A meal was logged while the meal tracker was open from the first-meal
  /// step.
  bool _mealLogged = false;

  /// Something was logged for today (by the entry's date) during the
  /// onboarding: today counts, even before the Buddy's streak has refreshed.
  bool _loggedToday = false;

  /// A step action is running (saving, permission dialog, meal tracker).
  bool _busy = false;
  bool _calm = false;

  BuddyOnboardingStep get _step => _steps![_index];

  DateTime _today() => ref.read(buddyTodayProvider)();

  /// The streak the moment shows: a log made during the onboarding counts
  /// at once, before the Buddy's refresh lands.
  int _momentStreak(BuddyStatus? status) =>
      math.max(status?.streak ?? 0, _loggedToday ? 1 : 0);

  /// This week's counted days, with today once something was logged.
  Set<DateTime> _momentWeek(BuddyStatus? status) => {
    ...?status?.weekDays,
    if (_loggedToday) startOfDay(_today()),
  };

  /// Right after sign-up, the streak moment waits for a first entry.
  bool _skips(BuddyOnboardingStep step) =>
      step == BuddyOnboardingStep.streakMoment &&
      widget.entry == BuddyOnboardingEntry.afterRegistration &&
      _momentStreak(ref.read(buddyProvider).value) == 0;

  /// The steps shown, in order (the progress dots).
  List<BuddyOnboardingStep> get _shownSteps =>
      _steps!.where((s) => !_skips(s)).toList();

  @override
  void initState() {
    super.initState();
    // Listen rather than read the single event slot after the tracker pops:
    // a drink logged from the meal's success screen replaces the meal there.
    ref.listenManual(buddyEventsProvider, (_, event) {
      if (event == null) return;
      // The entry's own date: a meal backdated to yesterday is no log for
      // today, however recently it was saved.
      if (isSameDay(event.trackedAt.toLocal(), _today())) _loggedToday = true;
      if (event.kind == EntryKind.meal &&
          _steps != null &&
          _step == BuddyOnboardingStep.firstMeal) {
        _mealLogged = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _buddy.dispose();
    super.dispose();
  }

  /// The step list once both providers have settled (data or error); null
  /// while loading.
  List<BuddyOnboardingStep>? _resolveSteps(
    AsyncValue<BuddyStatus?> buddy,
    AsyncValue<UserProfile?> profile,
  ) {
    bool settled(AsyncValue<Object?> v) => v.hasValue || v.hasError;
    if (!settled(buddy) || !settled(profile)) return null;

    final status = buddy.value;
    _name = status?.state.name ?? _name;
    final steps = buddyOnboardingSteps(
      entry: widget.entry,
      // Unknown (load error): don't ask for a name that may already exist.
      hasRow: status?.hasRow ?? buddy.hasError,
      remindersAlreadyOn: profile.value?.pushEnabled ?? false,
    );
    if (streakGoalChoices(status?.streak ?? 0).isEmpty) {
      steps.remove(BuddyOnboardingStep.streakGoal);
    }
    // The controller's setters never notify, so entering here is build-safe.
    _enter(steps.first);
    return steps;
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _goTo(int index) {
    setState(() => _index = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _enter(_steps![index]);
  }

  /// The next shown step, or — after the last one — completes the
  /// onboarding.
  void _advance() {
    var next = _index + 1;
    while (next < _steps!.length && _skips(_steps![next])) {
      next++;
    }
    if (next < _steps!.length) {
      _goTo(next);
    } else {
      unawaited(_finish());
    }
  }

  /// System back: the previous shown step; nothing on the first one or
  /// while busy.
  void _back() {
    if (_steps == null || _busy) return;
    var prev = _index - 1;
    while (prev >= 0 && _skips(_steps![prev])) {
      prev--;
    }
    if (prev >= 0) _goTo(prev);
  }

  /// Sets the Buddy up for [step]: his mood, and he asks its question.
  void _enter(BuddyOnboardingStep step) {
    _ask(step);
    switch (step) {
      case BuddyOnboardingStep.intro:
        _buddy
          ..mood = BuddyMood.happy
          ..play(BuddyAction.wakeUp);
      case BuddyOnboardingStep.firstMeal:
        _buddy.mood = BuddyMood.hungry;
      case BuddyOnboardingStep.streakMoment:
        _buddy.mood = BuddyMood.happy;
        if (_momentStreak(ref.read(buddyProvider).value) > 0) {
          _buddy.play(BuddyAction.celebrate);
        }
      case BuddyOnboardingStep.name:
      case BuddyOnboardingStep.streakGoal:
      case BuddyOnboardingStep.reminder:
        _buddy.mood = BuddyMood.happy;
    }
  }

  /// What the Buddy asks on [step]. His bubble carries it; the steps have
  /// no headline of their own.
  String _question(BuddyOnboardingStep step) => switch (step) {
    BuddyOnboardingStep.intro => 'Hi! Ich bin neu hier — dein Belly Buddy.',
    BuddyOnboardingStep.name => 'Wie soll ich heißen?',
    BuddyOnboardingStep.firstMeal =>
      'Ich hab Hunger! Was hast du zuletzt gegessen?',
    BuddyOnboardingStep.streakMoment => streakMomentLine(
      _momentStreak(ref.read(buddyProvider).value),
    ),
    BuddyOnboardingStep.streakGoal => 'Wie viele Tage schaffen wir zusammen?',
    BuddyOnboardingStep.reminder =>
      'Darf ich mich melden, wenn ich Hunger hab?',
  };

  /// The Buddy asks [step]'s question. It stays until the next step's
  /// replaces it and comes back after a reaction.
  void _ask(BuddyOnboardingStep step) => _buddy.rest(_question(step));

  /// Whether [step] is showing and free for a new action. The outgoing step
  /// stays tappable while it fades out, so every handler checks this.
  bool _ready(BuddyOnboardingStep step) =>
      mounted && _steps != null && _step == step && !_busy;

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }

  /// Runs [action]; failures are logged, the onboarding goes on.
  Future<void> _logErrors(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      _log.error('$what failed', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // Step actions
  // ---------------------------------------------------------------------------

  void _introNext() {
    if (_ready(BuddyOnboardingStep.intro)) _advance();
  }

  bool get _nameValid => AppConstants.isValidBuddyName(_name);

  Future<void> _confirmName() async {
    if (!_ready(BuddyOnboardingStep.name) || !_nameValid) return;
    final name = _name.trim();
    final messenger = ScaffoldMessenger.of(context);
    final buddy = ref.read(buddyProvider.notifier);
    _setBusy(true);
    var saved = true;
    try {
      await buddy.setName(name);
    } catch (e, st) {
      // Not blocking: the Buddy keeps its current name.
      saved = false;
      _log.error('Saving the Buddy name failed', e, st);
    }
    if (!mounted) return;
    _setBusy(false);
    if (!saved) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Der Name konnte nicht gespeichert werden.'),
        ),
      );
    }
    _advance();
    final reaction = wizardReaction('name:confirmed');
    if (reaction != null) {
      _buddy.react(reaction, name: name, rnd: _rnd, hold: _reactionHold);
    }
  }

  void _pickGoal(int goal) {
    if (!_ready(BuddyOnboardingStep.streakGoal)) return;
    final buddy = ref.read(buddyProvider.notifier);
    unawaited(
      _logErrors('Saving the streak goal', () => buddy.setStreakGoal(goal)),
    );
    _buddy.play(BuddyAction.celebrate);
    _advance();
  }

  Future<void> _remindersYes() async {
    if (!_ready(BuddyOnboardingStep.reminder)) return;
    _setBusy(true);
    var granted = false;
    await _logErrors('Enabling reminders', () async {
      granted = await enableReminders(ref);
    });
    // enableReminders already marks the opt-in as offered, but not when it
    // stopped early (no profile) or failed.
    await _markRemindersAsked();
    if (!mounted) return;
    _setBusy(false);
    if (granted) _buddy.play(BuddyAction.nodYes);
    _advance();
  }

  Future<void> _remindersLater() async {
    if (!_ready(BuddyOnboardingStep.reminder)) return;
    _setBusy(true);
    await _markRemindersAsked();
    if (!mounted) return;
    _setBusy(false);
    _advance();
  }

  /// The dashboard's opt-in dialog must not ask again.
  Future<void> _markRemindersAsked() => _logErrors(
    'Storing the reminder opt-in flag',
    markNotificationOptInOffered,
  );

  Future<void> _logMeal() async {
    if (!_ready(BuddyOnboardingStep.firstMeal)) return;
    _mealLogged = false;
    _setBusy(true);
    await context.push<void>(RoutePaths.mealTracker);
    if (!mounted) return;
    _setBusy(false);
    if (!_mealLogged || _step != BuddyOnboardingStep.firstMeal) return;
    // The tracker's success screen already showed him eating; the streak
    // moment celebrates.
    _advance();
  }

  void _mealLater() {
    if (_ready(BuddyOnboardingStep.firstMeal)) _advance();
  }

  void _momentNext() {
    if (_ready(BuddyOnboardingStep.streakMoment)) _advance();
  }

  /// Completes the onboarding; false on failure.
  Future<bool> _complete() async {
    final buddy = ref.read(buddyProvider.notifier);
    // Push was already on, so the reminder ask was skipped: the dashboard's
    // opt-in dialog must not ask either.
    if (!_steps!.contains(BuddyOnboardingStep.reminder)) {
      await _markRemindersAsked();
    }
    try {
      await buddy.completeOnboarding();
      return true;
    } catch (e, st) {
      _log.error('Completing the Buddy onboarding failed', e, st);
      return false;
    }
  }

  /// After the last step: completes the onboarding and opens the
  /// dashboard, where the Buddy welcomes the user. On failure the step
  /// stays and its answer can be tapped again (completing is idempotent).
  Future<void> _finish() async {
    if (!mounted || _busy) return;
    _setBusy(true);
    final ok = await _complete();
    if (!mounted) return;
    if (ok) {
      ref.read(buddyWelcomeProvider.notifier).set(BuddyWelcomeNotifier.line);
      context.go(RoutePaths.dashboard);
      return;
    }
    _setBusy(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Das hat nicht geklappt. Bitte versuch es noch einmal.'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final buddy = ref.watch(buddyProvider);
    final profile = ref.watch(profileProvider);
    final steps = _steps ??= _resolveSteps(buddy, profile);
    final status = buddy.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: steps == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) =>
                      _buildFlow(steps, status, constraints.maxHeight),
                ),
        ),
      ),
    );
  }

  Widget _buildFlow(
    List<BuddyOnboardingStep> steps,
    BuddyStatus? status,
    double height,
  ) {
    final step = _step;
    final shown = _shownSteps;
    final switchDuration = _calm ? Duration.zero : AppConstants.animMedium;
    final actions = _buildActions(step);
    final name = status?.state.name ?? _name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppConstants.gap16,
        _ProgressDots(
          count: shown.length,
          index: math.max(0, shown.indexOf(step)),
          calm: _calm,
        ),
        // One Buddy at a time (his widget ticks the controller): beside his
        // bubble above a list, else centred under it.
        if (_sideSteps.contains(step)) ...[
          AppConstants.gap8,
          BuddySideHeader(
            controller: _buddy,
            name: name,
            buddySize: BuddySideHeader.defaultBuddySize,
          ),
        ] else
          SizedBox(
            height: _stageHeight(step, height),
            child: BuddyStage(controller: _buddy, name: name),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: AppConstants.wizardStepPadding,
            child: AnimatedSwitcher(
              duration: switchDuration,
              child: KeyedSubtree(
                key: ValueKey(step),
                child: _buildContent(step, status, name),
              ),
            ),
          ),
        ),
        // The step's actions never scroll away; the Scaffold keeps them
        // above the keyboard.
        AnimatedSwitcher(
          duration: switchDuration,
          child: KeyedSubtree(
            key: ValueKey(step),
            child: actions.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingLg,
                      AppConstants.spacingSm,
                      AppConstants.spacingLg,
                      AppConstants.spacingMd,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// What the step shows below the Buddy (scrolls when tight).
  Widget _buildContent(
    BuddyOnboardingStep step,
    BuddyStatus? status,
    String name,
  ) {
    return switch (step) {
      // The Buddy's line is the whole content; the buttons below answer.
      BuddyOnboardingStep.intro ||
      BuddyOnboardingStep.firstMeal => const SizedBox.shrink(),
      BuddyOnboardingStep.name => BuddyNameStep(
        value: _name,
        onChanged: (v) => setState(() => _name = v),
        onSubmitted: _confirmName,
      ),
      BuddyOnboardingStep.streakMoment => StreakMoment(
        streak: _momentStreak(status),
        weekDays: _momentWeek(status),
        today: _today(),
      ),
      BuddyOnboardingStep.streakGoal => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StreakGoalWhyCard(),
          AppConstants.gap16,
          StreakGoalPicker(
            currentStreak: status?.streak ?? 0,
            onSelected: _pickGoal,
          ),
        ],
      ),
      BuddyOnboardingStep.reminder => ReminderPreview(
        buddyName: name,
        profile: ref.watch(profileProvider).value,
      ),
    };
  }

  /// The step's buttons for the fixed bottom slot; empty when the content
  /// itself is the action (the goal cards).
  List<Widget> _buildActions(BuddyOnboardingStep step) {
    return switch (step) {
      BuddyOnboardingStep.intro => [
        BbButton(
          key: BuddyOnboardingScreen.introNextKey,
          label: 'Weiter',
          icon: Icons.arrow_forward,
          onPressed: _introNext,
        ),
      ],
      BuddyOnboardingStep.name => [
        BbButton(
          key: BuddyOnboardingScreen.nameNextKey,
          label: 'Weiter',
          icon: Icons.arrow_forward,
          isLoading: _busy,
          onPressed: _nameValid ? _confirmName : null,
        ),
      ],
      BuddyOnboardingStep.firstMeal => [
        BbButton(
          key: BuddyOnboardingScreen.mealLogKey,
          label: 'Mahlzeit eintragen',
          onPressed: _busy ? null : _logMeal,
        ),
        AppConstants.gap8,
        _LaterButton(
          key: BuddyOnboardingScreen.mealLaterKey,
          onPressed: _busy ? null : _mealLater,
        ),
      ],
      BuddyOnboardingStep.streakMoment => [
        BbButton(
          key: BuddyOnboardingScreen.momentNextKey,
          label: 'Weiter',
          icon: Icons.arrow_forward,
          isLoading: _busy,
          onPressed: _momentNext,
        ),
      ],
      BuddyOnboardingStep.streakGoal => const [],
      BuddyOnboardingStep.reminder => [
        BbButton(
          key: BuddyOnboardingScreen.reminderYesKey,
          label: 'Erinnerungen aktivieren',
          isLoading: _busy,
          onPressed: _remindersYes,
        ),
        AppConstants.gap8,
        _LaterButton(
          key: BuddyOnboardingScreen.reminderLaterKey,
          onPressed: _busy ? null : _remindersLater,
        ),
      ],
    };
  }
}

class _LaterButton extends StatelessWidget {
  const _LaterButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: AppTheme.mutedForeground),
    child: const Text('Später'),
  );
}

/// One dot per step; the current one is a wider pill, done ones filled.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.index,
    required this.calm,
  });

  final int count;
  final int index;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Schritt ${index + 1} von $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: calm ? Duration.zero : AppConstants.animNormal,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacing2,
                ),
                width: i == index
                    ? AppConstants.progressDotActiveWidth
                    : AppConstants.progressDotSize,
                height: AppConstants.progressDotSize,
                decoration: BoxDecoration(
                  color: i <= index ? AppTheme.primary : AppTheme.muted,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
