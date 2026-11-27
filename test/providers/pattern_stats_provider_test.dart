import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/pattern_stats_provider.dart';
import 'package:belly_buddy/services/pattern_stats_service.dart';

import '../helpers/logs.dart';
import '../helpers/riverpod_helpers.dart';

PatternStats _stats(int rated) =>
    PatternStats(windowDays: 90, ratedDays: rated, hardDays: 0, ready: false);

class _FakeService implements PatternStatsService {
  int calls = 0;
  Future<PatternStats> Function(int call) answer = (c) async => _stats(c);

  @override
  Future<PatternStats> fetch() => answer(++calls);
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
  final user = SwitchableUserId('u1');
  late _FakeService service;

  setUp(() => service = _FakeService());

  ProviderContainer make() => ProviderContainer.test(
    overrides: [
      patternStatsServiceProvider.overrideWithValue(service),
      entriesRevisionProvider.overrideWith(_Revision.new),
      user.override,
    ],
  );

  test('signed out: null, no call', () async {
    final signedOut = SwitchableUserId(null);
    final c = ProviderContainer.test(
      overrides: [
        patternStatsServiceProvider.overrideWithValue(service),
        signedOut.override,
      ],
    );
    expect(await c.read(patternStatsProvider.future), isNull);
    expect(service.calls, 0);
  });

  test('an entry write refetches once', () async {
    final c = make();
    c.listen(patternStatsProvider, (_, _) {});
    expect((await c.read(patternStatsProvider.future))?.ratedDays, 1);

    (c.read(entriesRevisionProvider.notifier) as _Revision).bump();
    await settle();

    expect(service.calls, 2);
    expect(c.read(patternStatsProvider).value?.ratedDays, 2);
  });

  test('a failure is an AsyncError and is logged', () async {
    final logs = captureLogs();
    service.answer = (_) async => throw StateError('boom');
    final c = make();
    c.listen(patternStatsProvider, (_, _) {});
    await expectLater(c.read(patternStatsProvider.future), throwsStateError);
    await settle();

    final s = c.read(patternStatsProvider);
    expect(s.hasError, isTrue);
    expect(s.isLocked, isFalse);
    expect(logs.where((l) => l.contains('PatternStats [ERROR]')), isNotEmpty);
  });

  test(
    'a lock (402 plus_required) is an error the state reports as locked',
    () async {
      service.answer = (_) async => throw const PatternStatsLockedException();
      final c = make();
      c.listen(patternStatsProvider, (_, _) {});
      await expectLater(
        c.read(patternStatsProvider.future),
        throwsA(isA<PatternStatsLockedException>()),
      );
      await settle();
      expect(c.read(patternStatsProvider).isLocked, isTrue);
    },
  );

  test('refresh after a failure recovers', () async {
    service.answer = (c) async => c == 1 ? throw StateError('x') : _stats(c);
    final c = make();
    c.listen(patternStatsProvider, (_, _) {});
    await c.read(patternStatsProvider.future).then((_) {}, onError: (_) {});
    await c.read(patternStatsProvider.notifier).refresh();
    expect(c.read(patternStatsProvider).value?.ratedDays, 2);
  });

  test('a result for the previous user is dropped', () async {
    final c = make();
    c.listen(patternStatsProvider, (_, _) {});
    await c.read(patternStatsProvider.future);

    final slow = Completer<PatternStats>();
    service.answer = (_) => slow.future;
    final refresh = c.read(patternStatsProvider.notifier).refresh();
    user.set(c, 'u2');
    service.answer = (_) async => _stats(99);
    await settle();
    slow.complete(_stats(7));
    await refresh;
    await settle();

    expect(c.read(patternStatsProvider).value?.ratedDays, 99);
  });
}
