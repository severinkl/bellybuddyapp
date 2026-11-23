import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/common/bb_button.dart';

enum _Phase { asleep, waking, talking, ready }

/// The first screen a new user sees: the Buddy sleeps until tapped, wakes
/// up, waves and introduces himself in three lines, then offers
/// „Los geht's" (registration). „Ich habe schon ein Konto" (sign-in) is
/// always available.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  static const registrationButtonKey = Key('welcome_registration_button');
  static const signInButtonKey = Key('welcome_sign_in_button');
  static const buddyAreaKey = Key('welcome_buddy_area');
  static const hintKey = Key('welcome_wake_hint');

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _lines = [
    'Hi! Ich bin dein Belly Buddy.',
    'Ich helfe dir herauszufinden, was deinem Bauch guttut.',
    'Lass uns uns kennenlernen!',
  ];

  /// What the Buddy does with each line.
  static const _lineActions = [
    BuddyAction.wave,
    BuddyAction.hug,
    BuddyAction.celebrate,
  ];

  /// Into wakeUp, its eyes are open and its blinks done; from here its face
  /// override covers the lids, so the mood can turn happy underneath. Doing
  /// it only with the first line would let the zzZ (and shut lids) of the
  /// fading asleep mood show through the wave.
  static const _eyesOpen = Duration(milliseconds: 1300);

  /// From the tap to the first line: the wakeUp stretch, blinks and hop
  /// have played (its last 0.4 s are just a held smile).
  static const _wakeUpLead = Duration(milliseconds: 2200);

  /// Auto-advance pacing between lines.
  static const _linePace = Duration(milliseconds: 2500);

  static const _hintPulse = Duration(milliseconds: 1400);

  final _buddy = BuddyController(mood: BuddyMood.asleep);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _hintPulse,
    lowerBound: 0.45,
  );

  _Phase _phase = _Phase.asleep;
  int _line = -1;
  Timer? _timer;
  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    _syncPulse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _buddy.dispose();
    super.dispose();
  }

  /// The hint breathes while the Buddy sleeps (steady under reduced motion).
  void _syncPulse() {
    if (_phase == _Phase.asleep && !_calm) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.value = _pulse.upperBound;
    }
  }

  void _wake() {
    if (_phase != _Phase.asleep) return;
    HapticService.light();
    if (_calm) {
      _showLine(0);
      return;
    }
    // Stay asleep while the lids open: wakeUp opens them from the mood's
    // shut lids.
    _buddy.play(BuddyAction.wakeUp);
    setState(() => _phase = _Phase.waking);
    _syncPulse();
    _timer = Timer(_eyesOpen, () {
      _buddy.mood = BuddyMood.happy;
      _timer = Timer(_wakeUpLead - _eyesOpen, () => _showLine(0));
    });
  }

  void _showLine(int i) {
    _timer?.cancel();
    _buddy
      ..mood = BuddyMood.happy
      ..play(_lineActions[i])
      // Up until the next line replaces it; the last one stays next to the
      // button.
      ..say(_lines[i], duration: null);
    final last = i == _lines.length - 1;
    setState(() {
      _line = i;
      _phase = last ? _Phase.ready : _Phase.talking;
    });
    _syncPulse();
    if (!last) _timer = Timer(_linePace, () => _showLine(i + 1));
  }

  void _onAreaTap() {
    switch (_phase) {
      case _Phase.asleep:
        _wake();
      case _Phase.talking:
        _showLine(_line + 1);
      case _Phase.ready:
        _start();
      case _Phase.waking:
        break;
    }
  }

  /// Starts the registration, from „Los geht's" or a tap on the awake Buddy.
  void _start() => context.go(RoutePaths.registration);

  /// The Buddy as large as the area allows at its natural proportions, with
  /// the bubble slot right above it, centred: a stretched stage would park
  /// the bubble far above his head (the Buddy is drawn bottom-anchored).
  /// The extra headroom keeps the `celebrate` jump clear of the bubble.
  Widget _buildStage(BuildContext context, BoxConstraints c) {
    const bubbleHeight = AppConstants.buddyBubbleHeight;
    if (c.maxHeight <= bubbleHeight) return const SizedBox.shrink();
    // kBuddyStageAspect includes the headroom `AnimatedBuddy` keeps for
    // jumps (see `BuddyLayout`).
    final buddyHeight = math.min(
      c.maxWidth / kBuddyStageAspect + AppConstants.spacingLg,
      c.maxHeight - bubbleHeight,
    );
    return Center(
      child: SizedBox(
        height: buddyHeight + bubbleHeight,
        child: BuddyStage(controller: _buddy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
          ),
          child: Column(
            children: [
              AppConstants.gap24,
              Expanded(
                child: GestureDetector(
                  key: WelcomeScreen.buddyAreaKey,
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: _onAreaTap,
                  // The area owns every tap: it wakes the Buddy, skips
                  // through the story, and once he is awake starts like
                  // „Los geht's".
                  child: IgnorePointer(
                    child: LayoutBuilder(builder: _buildStage),
                  ),
                ),
              ),
              AppConstants.gap16,
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppConstants.buttonHeight,
                ),
                child: AnimatedSwitcher(
                  duration: _calm ? Duration.zero : AppConstants.animMedium,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: switch (_phase) {
                    _Phase.asleep => _WakeHint(onTap: _wake, pulse: _pulse),
                    _Phase.ready => BbButton(
                      key: WelcomeScreen.registrationButtonKey,
                      label: "Los geht's",
                      onPressed: _start,
                    ),
                    _Phase.waking || _Phase.talking => const SizedBox.shrink(),
                  },
                ),
              ),
              AppConstants.gap12,
              TextButton(
                key: WelcomeScreen.signInButtonKey,
                onPressed: () => context.go(RoutePaths.auth),
                child: const Text('Ich habe schon ein Konto'),
              ),
              AppConstants.gap16,
            ],
          ),
        ),
      ),
    );
  }
}

class _WakeHint extends StatelessWidget {
  const _WakeHint({required this.onTap, required this.pulse});

  final VoidCallback onTap;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: WelcomeScreen.hintKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FadeTransition(
          opacity: pulse,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: AppConstants.iconSizeSm,
                color: AppTheme.mutedForeground,
              ),
              SizedBox(width: AppConstants.spacingSm),
              Flexible(
                child: Text(
                  'Tippe, um ihn zu wecken',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
