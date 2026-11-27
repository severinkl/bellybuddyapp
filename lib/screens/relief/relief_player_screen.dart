import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/relief_player_provider.dart';
import '../../providers/relief_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../services/relief/relief_content.dart';
import '../../services/relief/screen_awake.dart';
import 'widgets/relief_done_view.dart';
import 'widgets/relief_running_view.dart';
import 'widgets/relief_safety.dart';

/// Plays one exercise (`/relief/:id`): ready with its caution, running step
/// by step, then done. Keeps the screen awake while a non-quiet step runs,
/// ticks at each step and breath phase and announces both to screen
/// readers. The router only opens it for a known [exerciseId].
class ReliefPlayerScreen extends ConsumerStatefulWidget {
  const ReliefPlayerScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ReliefPlayerScreen> createState() => _ReliefPlayerScreenState();
}

class _ReliefPlayerScreenState extends ConsumerState<ReliefPlayerScreen> {
  late final ScreenAwake _screenAwake;
  late final AppLifecycleListener _lifecycle;

  /// Whether the screen is kept awake; it starts off.
  bool _awake = false;

  /// The breath phase last announced in the current step.
  BreathPhase? _phase;

  NotifierProvider<ReliefPlayer, ReliefPlayerState> get _provider =>
      reliefPlayerProvider(widget.exerciseId);

  ReliefPlayer get _player => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    _screenAwake = ref.read(screenAwakeProvider);
    _lifecycle = AppLifecycleListener(
      onHide: () => _player.appHidden(),
      onShow: () => _player.appShown(),
    );
    ref.listenManual(_provider, _react);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_screenAwake.set(false));
    super.dispose();
  }

  void _react(ReliefPlayerState? prev, ReliefPlayerState next) {
    final step = _player.exercise.steps[next.stepIndex];
    final running = next.status == ReliefPlayerStatus.running;
    _setAwake(running && !step.quiet);

    if (next.status == ReliefPlayerStatus.ready ||
        next.status == ReliefPlayerStatus.done) {
      _phase = null;
      return;
    }

    final stepChanged =
        prev == null ||
        prev.status == ReliefPlayerStatus.ready ||
        prev.stepIndex != next.stepIndex ||
        next.secondInStep < prev.secondInStep;
    final phase = step.breath?.phaseAt(next.secondInStep);
    if (stepChanged) {
      // Only the step text: a phase word right after it would cut it off
      // (VoiceOver interrupts a running announcement).
      _phase = phase;
      _announce(step.text);
      if (running) HapticService.light();
    }

    if (phase != null && phase != _phase) {
      _phase = phase;
      _announce(breathPhaseLabel(phase));
      if (running) HapticService.selection();
    }
  }

  void _setAwake(bool on) {
    if (on == _awake) return;
    _awake = on;
    unawaited(_screenAwake.set(on));
  }

  void _announce(String message) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );

  /// Leaves the player; after a deep-link start with nothing below, goes to
  /// the list instead.
  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      context.go(RoutePaths.relief);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final player = ref.read(_provider.notifier);
    final exercise = player.exercise;
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: ReliefCopy.close,
          onPressed: _close,
        ),
        actions: [
          if (state.isActive)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: ReliefCopy.safetySheetTitle,
              onPressed: () => showReliefSafetySheet(context),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (state.status) {
          ReliefPlayerStatus.ready => _ReadyView(
            exercise: exercise,
            showDraft:
                ref.watch(reliefReviewMarkersProvider) && !exercise.reviewed,
            onStart: player.start,
          ),
          ReliefPlayerStatus.running ||
          ReliefPlayerStatus.paused => ReliefRunningView(
            exercise: exercise,
            state: state,
            secondsLeftInStep: player.secondsLeftInStep,
            secondsDone: player.secondsDone,
            onBack: player.back,
            onToggle: state.status == ReliefPlayerStatus.running
                ? player.pause
                : player.resume,
            onNext: player.next,
          ),
          ReliefPlayerStatus.done => ReliefDoneView(
            exerciseId: exercise.id,
            onFinish: _close,
          ),
        },
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.exercise,
    required this.showDraft,
    required this.onStart,
  });

  final ReliefExercise exercise;
  final bool showDraft;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final caution = exercise.caution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppConstants.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  exercise.subtitle,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitleLG,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap4,
                Text(
                  ReliefCopy.minutesLabel(exercise.minutes),
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                if (showDraft) ...[
                  AppConstants.gap8,
                  const Text(
                    ReliefCopy.draftMarker,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
                if (caution != null) ...[
                  AppConstants.gap20,
                  Container(
                    padding: AppConstants.paddingMd,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                    child: Text(
                      caution,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        height: AppTheme.lineHeightBody,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
          ),
          child: FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(minimumSize: AppConstants.minTapSize),
            child: const Text(ReliefCopy.start),
          ),
        ),
        AppConstants.gap8,
        const ReliefSafetyLine(),
      ],
    );
  }
}
