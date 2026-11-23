import 'dart:async';

/// Runs a task so that overlapping calls coalesce: a call while a run is
/// under way joins it and asks for exactly one more run after it, however
/// many calls came (each may bring news the running one predates). Every
/// call completes once the run it started or joined is done, that one more
/// included.
///
/// A key tells runs apart (e.g. the signed-in user): a call with another
/// key than the run under way starts a run of its own, and the earlier run
/// ends after its current task, without the one more.
class CoalescedRunner {
  _Run? _current;

  /// Runs [task] (at once, synchronously up to its first await), or joins
  /// the run under way for [key]. When [task] throws, the run ends there:
  /// every call that started or joined it completes with the error.
  Future<void> run(Future<void> Function() task, {Object? key}) {
    final current = _current;
    if (current != null && current.key == key) {
      current.again = true;
      return current.done.future;
    }
    final run = _current = _Run(key);
    unawaited(_loop(run, task));
    return run.done.future;
  }

  Future<void> _loop(_Run run, Future<void> Function() task) async {
    try {
      do {
        run.again = false;
        await task();
      } while (run.again && identical(_current, run));
      _end(run);
      run.done.complete();
    } on Object catch (e, st) {
      _end(run);
      run.done.completeError(e, st);
    }
  }

  void _end(_Run run) {
    if (identical(_current, run)) _current = null;
  }
}

/// A run of [CoalescedRunner]: its task and the one more asked for meanwhile.
class _Run {
  _Run(this.key);

  final Object? key;

  /// Whether a call joined while the task ran.
  bool again = false;

  /// Completes once no more run is asked for; there before the task starts,
  /// so a call from inside the task can join.
  final done = Completer<void>();
}
