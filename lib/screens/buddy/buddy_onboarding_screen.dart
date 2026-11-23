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
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../services/buddy/buddy_copy.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../services/buddy/streak_engine.dart' show maxStreakSavers;
import '../../utils/logger.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/common/bb_button.dart';
import '../registration/steps/buddy_name_step.dart';
import 'streak_goal_picker.dart';
import 'widgets/gift_reveal.dart';

/// Where `/buddy-onboarding` was opened from.
enum BuddyOnboardingEntry {
  /// Right after sign-up; the wizard already named the Buddy.
  afterRegistration,

  /// The router gate: a signed-in user whose Buddy onboarding isn't done.
  gate,
}

enum BuddyOnboardingStep { intro, name, streakGoal, reminder, firstMeal, gift }

/// The steps for [entry]: the intro and naming only for a gate user without
/// a Buddy row ([hasRow]), the reminder ask only while push is off
/// ([remindersAlreadyOn]), the first meal only right after registration.
List<BuddyOnboardingStep> buddyOnboardingSteps({
  required BuddyOnboardingEntry entry,
  required bool hasRow,
  required bool remindersAlreadyOn,
}) => [
  if (entry == BuddyOnboardingEntry.gate && !hasRow) ...[
    BuddyOnboardingStep.intro,
    BuddyOnboardingStep.name,
  ],
  BuddyOnboardingStep.streakGoal,
  if (!remindersAlreadyOn) BuddyOnboardingStep.reminder,
  if (entry == BuddyOnboardingEntry.afterRegistration)
    BuddyOnboardingStep.firstMeal,
  BuddyOnboardingStep.gift,
];

/// The Buddy-hosted sequence after sign-up (or for existing users via the
/// gate): streak goal, reminder ask, first meal and a gift (one
/// Streak-Saver), which completes the Buddy onboarding. One Buddy stays on
/// top across all steps; system back returns to the previous step.
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
  static const finishKey = Key('buddy_onboarding_finish');

  @override
  ConsumerState<BuddyOnboardingScreen> createState() =>
      _BuddyOnboardingScreenState();
}

class _BuddyOnboardingScreenState extends ConsumerState<BuddyOnboardingScreen> {
  static const _log = AppLogger('BuddyOnboarding');

  static const _introLine = 'Hi! Ich bin neu hier — dein Belly Buddy.';
  static const _thanksLine = 'Mmmh! Danke!';

  /// What the Buddy asks on each step. His bubble carries it; the steps have
  /// no headline of their own.
  static const _questions = {
    BuddyOnboardingStep.intro: _introLine,
    BuddyOnboardingStep.name: 'Wie soll ich heißen?',
    BuddyOnboardingStep.streakGoal: 'Wie viele Tage schaffen wir zusammen?',
    BuddyOnboardingStep.reminder:
        'Darf ich dich erinnern, wenn ich Hunger habe?',
    BuddyOnboardingStep.firstMeal:
        'Ich hab Hunger! Was hast du zuletzt gegessen?',
    BuddyOnboardingStep.gift: 'Ein Geschenk für dich!',
  };

  static const _giftSaverText =
      'Ein Streak-Saver! Der rettet unseren Streak, falls du mal einen Tag '
      'vergisst.';
  static const _giftSaversFullText =
      'Deine Schutzschilde sind schon voll – du bist bestens gerüstet!';
  static const _giftNoSaverText = "Du bist bestens gerüstet – los geht's!";
  static const _giftSaverCard = '🛡 Streak-Saver';
  static const _giftSaversFullCard = '🛡 Schutzschilde voll';
  static const _giftNoSaverCard = '🛡 Bestens gerüstet';

  /// Reactions stay this long (long enough to read across a step change),
  /// then the Buddy asks the step's question again.
  static const _reactionHold = Duration(seconds: 4);

  /// The stage never takes more than this share of the height (small
  /// screens, open keyboard), so the step content keeps room.
  static const double _maxStageShare = 0.33;

  final BuddyController _buddy = BuddyController();
  final math.Random _rnd = math.Random();
  final ScrollController _scroll = ScrollController();

  /// The gift's text, scrolled into view once it shows.
  final GlobalKey _giftTextKey = GlobalKey();

  /// Brings the question back after a reaction.
  Timer? _reask;

  /// Fixed once the Buddy and the profile have loaded.
  List<BuddyOnboardingStep>? _steps;
  int _index = 0;
  String _name = 'Buddy';

  /// A meal was logged while the first-meal step showed.
  bool _mealLogged = false;

  /// A step action is running (saving, permission dialog, meal tracker).
  bool _busy = false;
  bool _giftOpened = false;
  Future<bool>? _completion;

  /// Whether completing the onboarding added the gift saver; null until it
  /// has completed. The gift's text waits for it.
  bool? _saverGranted;
  bool _calm = false;

  BuddyOnboardingStep get _step => _steps![_index];

  @override
  void initState() {
    super.initState();
    // Listen rather than read the single event slot after the tracker pops:
    // a drink logged from the meal's success screen replaces the meal there.
    ref.listenManual(buddyEventsProvider, (_, event) {
      if (event?.kind == EntryKind.meal &&
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
    _reask?.cancel();
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

  void _advance() {
    if (_index < _steps!.length - 1) _goTo(_index + 1);
  }

  /// System back: the previous step; nothing on the first one, while busy
  /// or once the gift is open.
  void _back() {
    if (_steps == null || _index == 0 || _busy || _giftOpened) return;
    _goTo(_index - 1);
  }

  /// Sets the Buddy up for [step]: his mood, and he asks its question.
  void _enter(BuddyOnboardingStep step) {
    _mealLogged = false;
    _ask(step);
    switch (step) {
      case BuddyOnboardingStep.intro:
        _buddy
          ..mood = BuddyMood.happy
          ..play(BuddyAction.wakeUp);
      case BuddyOnboardingStep.firstMeal:
        _buddy.mood = BuddyMood.hungry;
      case BuddyOnboardingStep.name:
      case BuddyOnboardingStep.streakGoal:
      case BuddyOnboardingStep.reminder:
      case BuddyOnboardingStep.gift:
        _buddy.mood = BuddyMood.happy;
    }
  }

  /// The Buddy asks [step]'s question, up until the next line replaces it.
  void _ask(BuddyOnboardingStep step) {
    _reask?.cancel();
    final question = _questions[step];
    if (question != null) _buddy.say(question, duration: null);
  }

  /// Shows [line] (a reaction) for [_reactionHold], then asks the current
  /// step's question again.
  void _sayBriefly(String line) {
    _buddy.say(line, duration: null);
    _reask?.cancel();
    final step = _step;
    _reask = Timer(_reactionHold, () {
      if (mounted && _step == step) _ask(step);
    });
  }

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
      final mood = reaction.mood;
      final action = reaction.action;
      if (mood != null) _buddy.mood = mood;
      if (action != null) _buddy.play(action);
      _sayBriefly(BuddyCopy.fill(reaction.pick(_rnd), name: name));
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
    _setBusy(true);
    await context.push<void>(RoutePaths.mealTracker);
    if (!mounted) return;
    _setBusy(false);
    if (!_mealLogged || _step != BuddyOnboardingStep.firstMeal) return;
    _advance();
    _buddy
      ..mood = BuddyMood.happy
      ..play(BuddyAction.eat);
    _sayBriefly(_thanksLine);
  }

  void _mealLater() {
    if (_ready(BuddyOnboardingStep.firstMeal)) _advance();
  }

  void _onGiftOpened() {
    if (_giftOpened) return;
    setState(() => _giftOpened = true);
    _buddy
      ..mood = BuddyMood.inLove
      ..play(BuddyAction.celebrate);
    _completion = _complete();
  }

  /// Small screens: brings the gift's text into view once it shows.
  void _revealGiftText() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final text = _giftTextKey.currentContext;
      if (!mounted || text == null) return;
      Scrollable.ensureVisible(
        text,
        duration: _calm ? Duration.zero : AppConstants.animMedium,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  /// Completes the onboarding and grants the gift saver; false on failure.
  Future<bool> _complete() async {
    final buddy = ref.read(buddyProvider.notifier);
    // Push was already on, so the reminder ask was skipped: the dashboard's
    // opt-in dialog must not ask either.
    if (!_steps!.contains(BuddyOnboardingStep.reminder)) {
      await _markRemindersAsked();
    }
    try {
      final granted = await buddy.completeOnboarding(grantGiftSaver: true);
      if (mounted) {
        setState(() => _saverGranted = granted);
        _revealGiftText();
      }
      return true;
    } catch (e, st) {
      _log.error('Completing the Buddy onboarding failed', e, st);
      return false;
    }
  }

  Future<void> _finish() async {
    if (!_ready(BuddyOnboardingStep.gift) || !_giftOpened) return;
    _setBusy(true);
    final ok = await (_completion ??= _complete());
    if (!mounted) return;
    if (ok) {
      context.go(RoutePaths.dashboard);
      return;
    }
    // Try again on the next tap (completeOnboarding is idempotent).
    _completion = null;
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
    final stageHeight = math.min(
      AppConstants.buddyOnboardingStageHeight,
      height * _maxStageShare,
    );
    final switchDuration = _calm ? Duration.zero : AppConstants.animMedium;
    final actions = _buildActions(_step);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppConstants.gap16,
        _ProgressDots(count: steps.length, index: _index, calm: _calm),
        SizedBox(
          height: stageHeight,
          child: BuddyStage(
            controller: _buddy,
            name: status?.state.name ?? _name,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingSm,
              AppConstants.spacingLg,
              AppConstants.spacingMd,
            ),
            child: AnimatedSwitcher(
              duration: switchDuration,
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: _buildContent(_step, status),
              ),
            ),
          ),
        ),
        // The step's actions never scroll away; the Scaffold keeps them
        // above the keyboard.
        AnimatedSwitcher(
          duration: switchDuration,
          child: KeyedSubtree(
            key: ValueKey((_step, _giftOpened)),
            child: actions.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingLg,
                      AppConstants.spacingSm,
                      AppConstants.spacingLg,
                      AppConstants.spacingMd,
                    ),
                    child: _StepColumn(children: actions),
                  ),
          ),
        ),
      ],
    );
  }

  /// What the step shows below the Buddy (scrolls when tight).
  Widget _buildContent(BuddyOnboardingStep step, BuddyStatus? status) {
    return switch (step) {
      // The Buddy's greeting is the whole content.
      BuddyOnboardingStep.intro => const SizedBox.shrink(),
      BuddyOnboardingStep.name => BuddyNameStep(
        value: _name,
        onChanged: (v) => setState(() => _name = v),
        onSubmitted: _confirmName,
      ),
      BuddyOnboardingStep.streakGoal => StreakGoalPicker(
        currentStreak: status?.streak ?? 0,
        onSelected: _pickGoal,
      ),
      // The Buddy's question is the whole content; the buttons below answer.
      BuddyOnboardingStep.reminder ||
      BuddyOnboardingStep.firstMeal => const SizedBox.shrink(),
      BuddyOnboardingStep.gift => _StepColumn(
        children: [
          Center(
            child: GiftReveal(
              onOpened: _onGiftOpened,
              cardLabel: _saverGranted == null ? null : _giftCopy(status).card,
            ),
          ),
          if (_giftOpened && _saverGranted != null) ...[
            AppConstants.gap16,
            Text(
              key: _giftTextKey,
              _giftCopy(status).text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBodyLG,
                color: AppTheme.foreground,
              ),
            ),
          ],
        ],
      ),
    };
  }

  /// What the opened gift's card and text say: the Streak-Saver only when
  /// one was added.
  ({String card, String text}) _giftCopy(BuddyStatus? status) {
    if (_saverGranted ?? false) {
      return (card: _giftSaverCard, text: _giftSaverText);
    }
    final full = (status?.state.savers ?? 0) >= maxStreakSavers;
    return full
        ? (card: _giftSaversFullCard, text: _giftSaversFullText)
        : (card: _giftNoSaverCard, text: _giftNoSaverText);
  }

  /// The step's buttons for the fixed bottom slot; empty when the content
  /// itself is the action (goal cards, the closed gift).
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
      BuddyOnboardingStep.streakGoal => const [],
      BuddyOnboardingStep.reminder => [
        BbButton(
          key: BuddyOnboardingScreen.reminderYesKey,
          label: 'Ja, gerne',
          isLoading: _busy,
          onPressed: _remindersYes,
        ),
        AppConstants.gap8,
        _LaterButton(
          key: BuddyOnboardingScreen.reminderLaterKey,
          onPressed: _busy ? null : _remindersLater,
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
      BuddyOnboardingStep.gift => [
        if (_giftOpened)
          BbButton(
            key: BuddyOnboardingScreen.finishKey,
            label: "Los geht's",
            isLoading: _busy,
            onPressed: _finish,
          ),
      ],
    };
  }
}

class _StepColumn extends StatelessWidget {
  const _StepColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
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
