import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/coalesced_runner.dart';

/// A task whose runs wait until the test finishes them.
class _HeldTask {
  final runs = <Completer<void>>[];

  Future<void> call() {
    final run = Completer<void>();
    runs.add(run);
    return run.future;
  }
}

void main() {
  late CoalescedRunner runner;
  late _HeldTask task;

  setUp(() {
    runner = CoalescedRunner();
    task = _HeldTask();
  });

  test('a lone call runs the task once', () async {
    final done = runner.run(task.call);
    expect(task.runs, hasLength(1));

    task.runs.single.complete();
    await done;
    expect(task.runs, hasLength(1));
  });

  test('calls during a run make exactly one more after it, and every call '
      'completes once that one is done', () async {
    var completed = 0;
    for (var i = 0; i < 3; i++) {
      unawaited(runner.run(task.call).then((_) => completed++));
    }
    await pumpEventQueue();
    expect(task.runs, hasLength(1));

    task.runs.first.complete();
    await pumpEventQueue();
    expect(task.runs, hasLength(2));
    expect(completed, 0);

    task.runs.last.complete();
    await pumpEventQueue();
    expect(task.runs, hasLength(2));
    expect(completed, 3);
  });

  test('a call after a run finished starts a new one', () async {
    final first = runner.run(task.call);
    task.runs.single.complete();
    await first;

    final second = runner.run(task.call);
    expect(task.runs, hasLength(2));
    task.runs.last.complete();
    await second;
    expect(task.runs, hasLength(2));
  });

  test('a call from inside the task, before its first await, joins the run '
      'as the one more', () async {
    var calls = 0;
    Future<void>? joined;
    Future<void> reentrant() {
      if (++calls == 1) joined = runner.run(reentrant);
      return Future.value();
    }

    await runner.run(reentrant);
    await joined;
    expect(calls, 2);
  });

  test('a call with another key runs on its own; the earlier run finishes '
      'without the one more it was asked for', () async {
    final previous = <Completer<void>>[];
    final earlier = runner.run(() {
      final run = Completer<void>();
      previous.add(run);
      return run.future;
    }, key: 'u1');
    final joinedEarlier = runner.run(task.call, key: 'u1');

    final other = runner.run(task.call, key: 'u2');
    expect(task.runs, hasLength(1));
    task.runs.single.complete();
    await other;

    previous.single.complete();
    await Future.wait([earlier, joinedEarlier]);
    expect(previous, hasLength(1));
    expect(task.runs, hasLength(1));
  });

  test('a task that throws ends the run with the error for every call; the '
      'next call starts afresh', () async {
    final failing = runner.run(task.call);
    final joined = runner.run(task.call);
    task.runs.single.completeError(StateError('offline'));

    await expectLater(failing, throwsStateError);
    await expectLater(joined, throwsStateError);
    expect(task.runs, hasLength(1));

    final next = runner.run(task.call);
    expect(task.runs, hasLength(2));
    task.runs.last.complete();
    await next;
  });
}
