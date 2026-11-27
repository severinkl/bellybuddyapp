import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/relief_player_provider.dart';
import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';

void main() {
  /// Runs [body] in fake time with a clock that follows fake time plus
  /// [Harness.jump] (time that passes without timers firing, as while the
  /// app is in the background).
  void run(String id, void Function(Harness h) body) {
    fakeAsync((async) {
      final h = Harness(async);
      final container = ProviderContainer.test(
        overrides: [reliefClockProvider.overrideWithValue(h.now)],
      );
      final provider = reliefPlayerProvider(id);
      final sub = container.listen(provider, (_, _) {});
      h.player = () => container.read(provider.notifier);
      h.state = () => container.read(provider);
      body(h);
      sub.close();
      container.dispose();
      async.flushMicrotasks();
    });
  }

  test('start runs step 1', () {
    run('bauchatmung', (h) {
      expect(h.state().status, ReliefPlayerStatus.ready);
      h.player().start();
      h.elapse(5);
      expect(h.state().status, ReliefPlayerStatus.running);
      expect(h.state().stepIndex, 0);
      expect(h.state().secondInStep, 5);
    });
  });

  test('steps advance by themselves', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.elapse(20);
      expect(h.state().stepIndex, 1);
      expect(h.state().secondInStep, 0);
      expect(h.player().secondsLeftInStep, 20);
    });
  });

  test('pause freezes time', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.elapse(7);
      h.player().pause();
      expect(h.state().status, ReliefPlayerStatus.paused);
      h.elapse(60);
      expect(h.state().secondInStep, 7);
      h.player().resume();
      h.elapse(1);
      expect(h.state().status, ReliefPlayerStatus.running);
      expect(h.state().secondInStep, 8);
    });
  });

  test('next on the last step finishes', () {
    run('bauchatmung', (h) {
      h.player().start();
      for (var i = 0; i < 3; i++) {
        h.player().next();
      }
      expect(h.state().stepIndex, 3);
      h.player().next();
      expect(h.state().status, ReliefPlayerStatus.done);
      expect(h.async.pendingTimers, isEmpty);
      expect(h.player().secondsDone, h.player().exercise.totalSeconds);
    });
  });

  test('back on step 0 restarts it', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.elapse(5);
      h.player().back();
      expect(h.state().stepIndex, 0);
      expect(h.state().secondInStep, 0);
      h.elapse(3);
      expect(h.state().secondInStep, 3);
    });
  });

  test('back on step 2 goes to step 1 at 0', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.player().next();
      h.player().next();
      h.elapse(10);
      expect(h.state().stepIndex, 2);
      h.player().back();
      expect(h.state().stepIndex, 1);
      expect(h.state().secondInStep, 0);
      expect(h.state().status, ReliefPlayerStatus.running);
    });
  });

  test('appHidden pauses a breathing step', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.player().next();
      h.player().next();
      h.elapse(30);
      expect(h.player().step.breath, isNotNull);
      h.player().appHidden();
      h.jump(const Duration(minutes: 20));
      h.player().appShown();
      expect(h.state().status, ReliefPlayerStatus.paused);
      expect(h.state().stepIndex, 2);
      expect(h.state().secondInStep, 30);
    });
  });

  test('appHidden keeps the quiet step running', () {
    run('waerme', (h) {
      h.player().start();
      for (var i = 0; i < 3; i++) {
        h.player().next();
      }
      h.elapse(100);
      expect(h.player().step.quiet, isTrue);
      expect(h.state().secondInStep, 100);
      h.player().appHidden();
      h.jump(const Duration(minutes: 5));
      h.player().appShown();
      expect(h.state().status, ReliefPlayerStatus.running);
      expect(h.state().stepIndex, 3);
      expect(h.state().secondInStep, 400);
      h.player().appHidden();
      h.jump(const Duration(minutes: 20));
      h.player().appShown();
      expect(h.state().status, ReliefPlayerStatus.running);
      expect(h.state().stepIndex, 4);
      expect(h.state().secondInStep, 0);
      expect(h.player().secondsLeftInStep, 20);
    });
  });

  test('a quiet step that ends while hidden is held until appShown', () {
    run('waerme', (h) {
      h.player().start();
      for (var i = 0; i < 3; i++) {
        h.player().next();
      }
      h.elapse(590);
      h.player().appHidden();
      // Android: the timer keeps firing in the background.
      h.elapse(30);
      expect(h.state().status, ReliefPlayerStatus.running);
      expect(h.state().stepIndex, 3);
      expect(h.player().secondsLeftInStep, 0);
      h.elapse(60);
      expect(h.state().stepIndex, 3);
      h.player().appShown();
      expect(h.state().status, ReliefPlayerStatus.running);
      expect(h.state().stepIndex, 4);
      expect(h.state().secondInStep, 0);
      h.elapse(5);
      expect(h.state().stepIndex, 4);
      expect(h.state().secondInStep, 5);
    });
  });

  test('appShown while paused does nothing', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.elapse(5);
      h.player().pause();
      h.jump(const Duration(minutes: 1));
      h.player().appShown();
      expect(h.state().status, ReliefPlayerStatus.paused);
      expect(h.state().secondInStep, 5);
      h.elapse(3);
      expect(h.state().secondInStep, 5);
    });
  });

  test('a clock set back keeps counting', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.elapse(5);
      h.jump(const Duration(hours: -1));
      h.elapse(1);
      expect(h.state().secondInStep, 5);
      h.elapse(2);
      expect(h.state().stepIndex, 0);
      expect(h.state().secondInStep, 7);
    });
  });

  test('secondsDone', () {
    run('bauchatmung', (h) {
      h.player().start();
      h.player().next();
      h.player().next();
      h.elapse(10);
      expect(h.state().stepIndex, 2);
      expect(h.state().secondInStep, 10);
      expect(h.player().secondsDone, 50);
    });
  });

  test('unknown id', () {
    run('gibt_es_nicht', (h) {
      expect(h.state().status, ReliefPlayerStatus.ready);
      expect(() => h.player().exercise, throwsStateError);
    });
  });

  test('uses the content provider', () {
    fakeAsync((async) {
      const custom = ReliefExercise(
        id: 'eigen',
        title: 'T',
        subtitle: 'S',
        steps: [ReliefStep(text: 'a', seconds: 2)],
      );
      final container = ProviderContainer.test(
        overrides: [
          reliefContentProvider.overrideWithValue(const [custom]),
          reliefClockProvider.overrideWithValue(
            () => DateTime(2026).add(async.elapsed),
          ),
        ],
      );
      final provider = reliefPlayerProvider('eigen');
      final sub = container.listen(provider, (_, _) {});
      container.read(provider.notifier).start();
      async.elapse(const Duration(seconds: 2));
      expect(container.read(provider).status, ReliefPlayerStatus.done);
      expect(async.pendingTimers, isEmpty);
      sub.close();
    });
  });
}

class Harness {
  Harness(this.async);

  final FakeAsync async;
  final DateTime _start = DateTime(2026, 11, 27, 10);
  Duration _jumped = Duration.zero;
  late ReliefPlayer Function() player;
  late ReliefPlayerState Function() state;

  DateTime now() => _start.add(async.elapsed).add(_jumped);

  void elapse(int seconds) => async.elapse(Duration(seconds: seconds));

  void jump(Duration d) => _jumped += d;
}
