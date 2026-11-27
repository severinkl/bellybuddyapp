import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/pattern_stats_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/providers/today_provider.dart';
import 'package:belly_buddy/providers/tolerance_test_provider.dart';
import 'package:belly_buddy/repositories/tolerance_test_repository.dart';
import 'package:belly_buddy/services/pattern_stats_service.dart';

import '../helpers/logs.dart';
import '../helpers/riverpod_helpers.dart';

const _zwiebel = TestSubject('ingredient', 'zwiebel', 'Zwiebel');

ToleranceTestView _view({
  String id = 't1',
  String status = 'active',
  TestPhase phase = TestPhase.leaveOut,
}) => ToleranceTestView(
  id: id,
  subject: _zwiebel,
  origin: 'picked',
  status: status,
  phase: phase,
  startsOn: DateTime(2026, 12, 1),
  leaveOutDays: 5,
  reintroDays: 3,
  dayIndex: 0,
  days: const [],
);

PatternStats _stats({ToleranceTestView? test, bool restrictive = false}) =>
    PatternStats(
      windowDays: 90,
      ratedDays: 41,
      hardDays: 9,
      ready: true,
      test: test,
      restrictive: restrictive,
    );

class _FakeService implements PatternStatsService {
  int calls = 0;
  PatternStats Function(int call) answer = (_) => _stats();
  Future<void>? gate;

  @override
  Future<PatternStats> fetch() async {
    final call = ++calls;
    if (gate != null) await gate;
    return answer(call);
  }
}

class _FakeRepo implements ToleranceTestRepository {
  final starts = <({TestSubject subject, String origin, DateTime startsOn})>[];
  final stops = <String>[];
  final completes = <String>[];
  Object? startError;
  Object? completeError;
  int completeCalls = 0;

  @override
  Future<void> start(
    TestSubject s, {
    required String origin,
    required DateTime startsOn,
  }) async {
    if (startError != null) throw startError!;
    starts.add((subject: s, origin: origin, startsOn: startsOn));
  }

  @override
  Future<void> stop(String id) async => stops.add(id);

  @override
  Future<void> complete(String id) async {
    completeCalls++;
    if (completeError != null) throw completeError!;
    completes.add(id);
  }
}

class _FakeReminders implements ToleranceTestReminders {
  final scheduled = <ToleranceTestView>[];
  int cancels = 0;

  /// What [schedule] answers (false: no permission).
  bool permitted = true;

  @override
  Future<bool> schedule(ToleranceTestView test) async {
    if (!permitted) return false;
    scheduled.add(test);
    return true;
  }

  @override
  Future<void> cancel() async => cancels++;
}

class _Today extends TodayNotifier {
  _Today(this._day);
  final DateTime _day;

  @override
  DateTime build() => _day;
}

class _Revision extends EntriesRevision {
  void bump() => state++;
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeService service;
  late _FakeRepo repo;
  late _FakeReminders reminders;

  setUp(() {
    service = _FakeService();
    repo = _FakeRepo();
    reminders = _FakeReminders();
  });

  ProviderContainer make({
    bool plusLocked = false,
    DateTime? today,
    SwitchableUserId? user,
  }) => ProviderContainer.test(
    overrides: [
      patternStatsServiceProvider.overrideWithValue(service),
      toleranceTestRepositoryProvider.overrideWithValue(repo),
      toleranceTestRemindersProvider.overrideWithValue(reminders),
      entriesRevisionProvider.overrideWith(_Revision.new),
      plusLockedProvider.overrideWithValue(plusLocked),
      todayProvider.overrideWith(() => _Today(today ?? DateTime(2026, 11, 30))),
      (user ?? SwitchableUserId('u1')).override,
    ],
  );

  Future<ProviderContainer> loaded({bool plusLocked = false}) async {
    final c = make(plusLocked: plusLocked);
    c.listen(patternStatsProvider, (_, _) {});
    await c.read(patternStatsProvider.future);
    return c;
  }

  test('phase dates use the wall-clock today', () async {
    // The wall-clock date as todayProvider says it, whatever the zone: the
    // last day of a month rolls over to the next month's first day.
    final c = make(today: DateTime(2026, 11, 30));
    c.listen(patternStatsProvider, (_, _) {});
    await c.read(patternStatsProvider.future);

    await c
        .read(toleranceTestActionsProvider)
        .start(_zwiebel, origin: 'picked');

    final startsOn = repo.starts.single.startsOn;
    expect(startsOn, DateTime(2026, 12, 1));
    expect(startsOn.isUtc, isFalse);
    expect(toleranceStartsOnWire(startsOn), '2026-12-01');
  });

  test(
    'start inserts subject, origin, starts_on and refreshes the stats',
    () async {
      final c = await loaded();
      service.answer = (_) => _stats(test: _view());

      final outcome = await c
          .read(toleranceTestActionsProvider)
          .start(_zwiebel, origin: 'proposed');

      expect(outcome, StartOutcome.started);
      expect(repo.starts.single.subject, _zwiebel);
      expect(repo.starts.single.origin, 'proposed');
      expect(repo.starts.single.startsOn, DateTime(2026, 12, 1));
      expect(service.calls, 2);
      expect(c.read(patternStatsProvider).value?.test?.id, 't1');
      // The running test from the reload gets its reminders.
      expect(reminders.scheduled.single.id, 't1');
    },
  );

  test('start conflict reloads and shows the running test', () async {
    final c = await loaded();
    repo.startError = const TestConflict();
    service.answer = (_) => _stats(test: _view(id: 'other'));

    final outcome = await c
        .read(toleranceTestActionsProvider)
        .start(_zwiebel, origin: 'picked');

    expect(outcome, StartOutcome.conflict);
    expect(service.calls, 2);
    expect(c.read(patternStatsProvider).value?.test?.id, 'other');
    expect(reminders.scheduled, isEmpty);
  });

  test('start failure is failed and logged', () async {
    final logs = captureLogs();
    final c = await loaded();
    repo.startError = StateError('offline');

    final outcome = await c
        .read(toleranceTestActionsProvider)
        .start(_zwiebel, origin: 'picked');

    expect(outcome, StartOutcome.failed);
    expect(logs.where((l) => l.contains('ToleranceTest [ERROR]')), isNotEmpty);
  });

  test('start completes an active test past its end first', () async {
    service.answer = (_) => _stats(
      test: _view(id: 'old', phase: TestPhase.done),
    );
    final c = await loaded();

    final outcome = await c
        .read(toleranceTestActionsProvider)
        .start(_zwiebel, origin: 'picked');

    expect(outcome, StartOutcome.started);
    expect(repo.completes, ['old']);
    expect(repo.starts, hasLength(1));
  });

  test('start does nothing while Plus is locked or restrictive', () async {
    final locked = await loaded(plusLocked: true);
    expect(
      await locked
          .read(toleranceTestActionsProvider)
          .start(_zwiebel, origin: 'picked'),
      StartOutcome.failed,
    );

    service.answer = (_) => _stats(restrictive: true);
    final restrictive = await loaded();
    expect(
      await restrictive
          .read(toleranceTestActionsProvider)
          .start(_zwiebel, origin: 'picked'),
      StartOutcome.failed,
    );
    expect(repo.starts, isEmpty);
  });

  test('stop sets stopped and cancels the reminders', () async {
    final c = await loaded();

    await c.read(toleranceTestActionsProvider).stop('t1');

    expect(repo.stops, ['t1']);
    expect(reminders.cancels, 1);
    expect(service.calls, 2);
  });

  test('stop does nothing while Plus is locked', () async {
    final c = await loaded(plusLocked: true);
    await c.read(toleranceTestActionsProvider).stop('t1');
    expect(repo.stops, isEmpty);
    expect(reminders.cancels, 0);
  });

  test(
    'a done test is completed once, not again on the next refresh',
    () async {
      // The server still says active/done on the reload (e.g. a lagging
      // replica): the completer must not write again.
      service.answer = (_) => _stats(test: _view(phase: TestPhase.done));
      final c = make();
      c.listen(toleranceTestCompleterProvider, (_, _) {});
      await settle();

      expect(repo.completes, ['t1']);

      (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
      await settle();

      expect(service.calls, greaterThanOrEqualTo(3));
      expect(repo.completes, ['t1']);
    },
  );

  test('the completer leaves running and finished tests alone', () async {
    service.answer = (c) => c == 1
        ? _stats(test: _view(phase: TestPhase.reintro))
        : _stats(
            test: _view(status: 'completed', phase: TestPhase.done),
          );
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();

    expect(repo.completes, isEmpty);
  });

  test('the completer does nothing while Plus is locked', () async {
    service.answer = (_) => _stats(test: _view(phase: TestPhase.done));
    final c = make(plusLocked: true);
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();

    expect(repo.completes, isEmpty);
    expect(service.calls, 0);
  });

  test('the completer does nothing while the stats are locked', () async {
    service.answer = (_) => throw const PatternStatsLockedException();
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();

    expect(c.read(patternStatsProvider).isLocked, isTrue);
    expect(repo.completes, isEmpty);
  });

  test(
    'the completer ignores loading stats (the previous user\'s value)',
    () async {
      final logs = captureLogs();
      final user = SwitchableUserId('u1');
      service.answer = (call) => call == 1
          ? _stats(
              test: _view(id: 'a', phase: TestPhase.done),
            )
          : _stats();
      // u1's completion fails, so 'a' would be tried again on a later arrival.
      repo.completeError = StateError('offline');
      final c = make(user: user);
      c.listen(toleranceTestCompleterProvider, (_, _) {});
      await settle();
      expect(repo.completeCalls, 1);
      expect(logs, isNotEmpty);

      // Another user signs in; while their stats load, the state still holds
      // u1's done test.
      final release = Completer<void>();
      service.gate = release.future;
      user.set(c, 'u2');
      await settle();
      expect(c.read(patternStatsProvider).isLoading, isTrue);
      expect(c.read(patternStatsProvider).value?.test?.id, 'a');
      expect(repo.completeCalls, 1);

      release.complete();
      await settle();
      expect(repo.completeCalls, 1);
    },
  );

  test('completing a test cancels its reminders', () async {
    service.answer = (_) => _stats(test: _view(phase: TestPhase.done));
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();

    expect(repo.completes, ['t1']);
    expect(reminders.cancels, 1);
    expect(reminders.scheduled, isEmpty);
  });

  test('a running test found at app start gets its reminders once; another '
      'user\'s test again', () async {
    final user = SwitchableUserId('u1');
    service.answer = (_) => _stats(test: _view(phase: TestPhase.reintro));
    final c = make(user: user);
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect([for (final t in reminders.scheduled) t.id], ['t1']);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect(reminders.scheduled, hasLength(1));

    service.answer = (_) => _stats(test: _view(id: 't2'));
    user.set(c, 'u2');
    await settle();
    expect([for (final t in reminders.scheduled) t.id], ['t1', 't2']);
  });

  test('no reminders rescheduled for a finished test or while Plus is '
      'locked', () async {
    service.answer = (_) => _stats(
      test: _view(status: 'completed', phase: TestPhase.done),
    );
    var c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.scheduled, isEmpty);

    service.answer = (_) => _stats(test: _view());
    c = make(plusLocked: true);
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.scheduled, isEmpty);
  });

  test('Plus known locked: pending test reminders are cancelled; open: '
      'not', () async {
    var c = make(plusLocked: true);
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.cancels, 1);

    // Open with a running test: nothing cancelled.
    service.answer = (_) => _stats(test: _view(phase: TestPhase.reintro));
    c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.cancels, 1);
  });

  test('loaded stats without an active test (stopped or completed '
      'elsewhere) cancel the reminders once', () async {
    service.answer = (call) =>
        call == 1 ? _stats(test: _view(phase: TestPhase.reintro)) : _stats();
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.cancels, 0);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect(reminders.cancels, 1);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect(reminders.cancels, 1);
  });

  test('a test this build cannot read cancels no reminders', () async {
    service.answer = (_) => const PatternStats(
      windowDays: 90,
      ratedDays: 41,
      hardDays: 9,
      ready: true,
      hasUnreadableTest: true,
    );
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.cancels, 0);
  });

  test('reminders not scheduled (no permission) are tried again on the '
      'next sight', () async {
    reminders.permitted = false;
    service.answer = (_) => _stats(test: _view(phase: TestPhase.reintro));
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.scheduled, isEmpty);

    reminders.permitted = true;
    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect([for (final t in reminders.scheduled) t.id], ['t1']);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect(reminders.scheduled, hasLength(1));
  });

  test('a start schedules its reminders once, though the completer sees '
      'the new test too', () async {
    service.answer = (call) => call == 1 ? _stats() : _stats(test: _view());
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();

    await c
        .read(toleranceTestActionsProvider)
        .start(_zwiebel, origin: 'picked');
    await settle();

    expect([for (final t in reminders.scheduled) t.id], ['t1']);
  });

  test('a stale answer without the test, after a start, cancels its '
      'reminders; the next sight of the test schedules them again', () async {
    // 1: before the start; 2: after it; 3: stale, from before the start;
    // 4: fresh again.
    service.answer = (call) =>
        call == 2 || call == 4 ? _stats(test: _view()) : _stats();
    final c = make();
    c.listen(toleranceTestCompleterProvider, (_, _) {});
    await settle();
    expect(reminders.cancels, 1);

    await c
        .read(toleranceTestActionsProvider)
        .start(_zwiebel, origin: 'picked');
    await settle();
    expect([for (final t in reminders.scheduled) t.id], ['t1']);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect(reminders.cancels, 2);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();
    expect([for (final t in reminders.scheduled) t.id], ['t1', 't1']);
  });
}
