import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/relief/relief_content.dart';
import 'relief_provider.dart';

enum ReliefPlayerStatus { ready, running, paused, done }

@immutable
class ReliefPlayerState {
  const ReliefPlayerState({
    required this.status,
    required this.stepIndex,
    required this.secondInStep,
  });

  final ReliefPlayerStatus status;
  final int stepIndex;
  final int secondInStep;

  @override
  bool operator ==(Object other) =>
      other is ReliefPlayerState &&
      other.status == status &&
      other.stepIndex == stepIndex &&
      other.secondInStep == secondInStep;

  @override
  int get hashCode => Object.hash(status, stepIndex, secondInStep);

  @override
  String toString() =>
      'ReliefPlayerState($status, step $stepIndex, second $secondInStep)';
}

/// The wall clock the player counts with; tests override it.
final reliefClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Plays the exercise [exerciseId] step by step.
///
/// Time is wall clock: while running, the second in the step is the seconds
/// counted before the last (re)start plus the time since then. The timer only
/// triggers the recompute, so a late or suspended timer loses nothing.
class ReliefPlayer extends Notifier<ReliefPlayerState> {
  ReliefPlayer(this.exerciseId);

  final String exerciseId;

  ReliefExercise? _exercise;
  Timer? _timer;

  /// Seconds in the step counted before [_resumedAt].
  int _baseSeconds = 0;
  DateTime? _resumedAt;

  @override
  ReliefPlayerState build() {
    _exercise = null;
    for (final e in ref.watch(reliefContentProvider)) {
      if (e.id == exerciseId) _exercise = e;
    }
    ref.onDispose(_stopTimer);
    return const ReliefPlayerState(
      status: ReliefPlayerStatus.ready,
      stepIndex: 0,
      secondInStep: 0,
    );
  }

  /// Throws a [StateError] for an unknown id; the screen redirects first.
  ReliefExercise get exercise =>
      _exercise ?? (throw StateError('Unknown relief exercise'));

  ReliefStep get step => exercise.steps[state.stepIndex];

  int get secondsLeftInStep {
    final left = step.seconds - state.secondInStep;
    return left < 0 ? 0 : left;
  }

  /// Seconds across all steps, for the progress bar.
  int get secondsDone {
    if (state.status == ReliefPlayerStatus.done) return exercise.totalSeconds;
    var done = 0;
    for (var i = 0; i < state.stepIndex; i++) {
      done += exercise.steps[i].seconds;
    }
    return done + state.secondInStep;
  }

  DateTime _now() => ref.read(reliefClockProvider)();

  /// Ready → running at step 0, second 0.
  void start() {
    if (state.status != ReliefPlayerStatus.ready) return;
    _runStep(0);
  }

  void pause() {
    if (state.status != ReliefPlayerStatus.running) return;
    _recompute();
    if (state.status != ReliefPlayerStatus.running) return;
    _stopTimer();
    _baseSeconds = state.secondInStep;
    state = ReliefPlayerState(
      status: ReliefPlayerStatus.paused,
      stepIndex: state.stepIndex,
      secondInStep: _baseSeconds,
    );
  }

  void resume() {
    if (state.status != ReliefPlayerStatus.paused) return;
    _baseSeconds = state.secondInStep;
    _resumedAt = _now();
    state = ReliefPlayerState(
      status: ReliefPlayerStatus.running,
      stepIndex: state.stepIndex,
      secondInStep: _baseSeconds,
    );
    _startTimer();
  }

  /// The next step at its start; on the last step finishes.
  void next() {
    if (!_active) return;
    _goTo(state.stepIndex + 1);
  }

  /// The previous step at its start; on step 0 restarts it.
  void back() {
    if (!_active) return;
    _goTo(state.stepIndex > 0 ? state.stepIndex - 1 : 0);
  }

  /// Leaving the app pauses a running step, except a quiet one, which keeps
  /// counting by wall clock.
  void appHidden() {
    if (state.status != ReliefPlayerStatus.running) return;
    if (step.quiet) return;
    pause();
  }

  /// Back in the app: catch up with the wall clock.
  void appShown() {
    if (state.status == ReliefPlayerStatus.running) _recompute();
  }

  bool get _active =>
      state.status == ReliefPlayerStatus.running ||
      state.status == ReliefPlayerStatus.paused;

  /// Moves to [index] at second 0 keeping running/paused; past the end → done.
  void _goTo(int index) {
    if (index >= exercise.steps.length) {
      _finish();
      return;
    }
    if (state.status == ReliefPlayerStatus.paused) {
      _baseSeconds = 0;
      state = ReliefPlayerState(
        status: ReliefPlayerStatus.paused,
        stepIndex: index,
        secondInStep: 0,
      );
    } else {
      _runStep(index);
    }
  }

  void _runStep(int index) {
    _baseSeconds = 0;
    _resumedAt = _now();
    state = ReliefPlayerState(
      status: ReliefPlayerStatus.running,
      stepIndex: index,
      secondInStep: 0,
    );
    _startTimer();
  }

  void _finish() {
    _stopTimer();
    state = ReliefPlayerState(
      status: ReliefPlayerStatus.done,
      stepIndex: exercise.steps.length - 1,
      secondInStep: exercise.steps.last.seconds,
    );
  }

  /// Recomputes the second from the clock; a step whose time is up moves on
  /// to the next step at second 0 (overrun is not carried).
  void _recompute() {
    final resumedAt = _resumedAt;
    if (state.status != ReliefPlayerStatus.running || resumedAt == null) {
      return;
    }
    var elapsed = _now().difference(resumedAt).inSeconds;
    if (elapsed < 0) elapsed = 0; // the clock went back
    final second = _baseSeconds + elapsed;
    if (second >= step.seconds) {
      _goTo(state.stepIndex + 1);
      return;
    }
    state = ReliefPlayerState(
      status: ReliefPlayerStatus.running,
      stepIndex: state.stepIndex,
      secondInStep: second,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final reliefPlayerProvider = NotifierProvider.autoDispose
    .family<ReliefPlayer, ReliefPlayerState, String>((id) => ReliefPlayer(id));
