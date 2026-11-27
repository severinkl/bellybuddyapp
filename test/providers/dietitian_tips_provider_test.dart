import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/dietitian_tips_provider.dart';
import 'package:belly_buddy/services/dietitian_tip_service.dart';

import '../helpers/app_lifecycle.dart';
import '../helpers/dietitian_tip_fakes.dart';

void main() {
  // The foreground signal's AppLifecycleListener needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDietitianTipService service;
  late ProviderContainer container;

  ProviderContainer make({String? userId = 'u1'}) => ProviderContainer.test(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      dietitianTipServiceProvider.overrideWithValue(service),
    ],
  );

  setUp(() {
    service = FakeDietitianTipService([
      testTip(id: 'a'),
      testTip(id: 'b', seenAt: DateTime.utc(2026, 11, 25)),
    ]);
    container = make();
  });

  test('loads the tips', () async {
    final tips = await container.read(dietitianTipsProvider.future);
    expect(tips.map((t) => t.id), ['a', 'b']);
  });

  test('nobody signed in: no tips, no call', () async {
    final out = make(userId: null);
    expect(await out.read(dietitianTipsProvider.future), isEmpty);
    expect(service.listCalls, 0);
  });

  test(
    'markShownSeen stamps only the new ones, once, and keeps the badge',
    () async {
      await container.read(dietitianTipsProvider.future);
      final notifier = container.read(dietitianTipsProvider.notifier);

      await notifier.markShownSeen();
      await notifier.markShownSeen();

      expect(service.seenCalls, [
        ['a'],
      ]);
      final shown = container.read(dietitianTipsProvider).requireValue;
      expect(shown.first.isNew, isTrue);
    },
  );

  test('after a reload the stamped tip is no longer new', () async {
    await container.read(dietitianTipsProvider.future);
    final notifier = container.read(dietitianTipsProvider.notifier);
    await notifier.markShownSeen();

    await notifier.refresh();

    expect(
      container.read(dietitianTipsProvider).requireValue.first.isNew,
      isFalse,
    );
  });

  test('a tip that arrives later is stamped by the next call', () async {
    await container.read(dietitianTipsProvider.future);
    final notifier = container.read(dietitianTipsProvider.notifier);
    await notifier.markShownSeen();
    service.tips = [testTip(id: 'c'), ...service.tips];
    await notifier.refresh();

    await notifier.markShownSeen();

    expect(service.seenCalls.last, ['c']);
  });

  test('a failing markShownSeen is swallowed and tried again later', () async {
    await container.read(dietitianTipsProvider.future);
    final notifier = container.read(dietitianTipsProvider.notifier);
    service.failWrite = true;
    await notifier.markShownSeen();
    service.failWrite = false;

    await notifier.markShownSeen();

    expect(service.seenCalls, [
      ['a'],
    ]);
  });

  test('toggleTrying sets and clears trying_at', () async {
    await container.read(dietitianTipsProvider.future);
    final notifier = container.read(dietitianTipsProvider.notifier);

    await notifier.toggleTrying('a');
    expect(service.tryingCalls, [('a', true)]);
    expect(
      container.read(dietitianTipsProvider).requireValue.first.tryingAt,
      isNotNull,
    );

    await notifier.toggleTrying('a');
    expect(service.tryingCalls.last, ('a', false));
    expect(
      container.read(dietitianTipsProvider).requireValue.first.tryingAt,
      isNull,
    );
  });

  test('a failing toggleTrying throws and keeps the state', () async {
    await container.read(dietitianTipsProvider.future);
    service.failWrite = true;
    final notifier = container.read(dietitianTipsProvider.notifier);

    await expectLater(notifier.toggleTrying('a'), throwsException);

    expect(
      container.read(dietitianTipsProvider).requireValue.first.tryingAt,
      isNull,
    );
  });

  test('remove deletes and drops the tip', () async {
    await container.read(dietitianTipsProvider.future);

    await container.read(dietitianTipsProvider.notifier).remove('a');

    expect(service.removed, ['a']);
    expect(
      container.read(dietitianTipsProvider).requireValue.map((t) => t.id),
      ['b'],
    );
  });

  test('back in the foreground: loads the tips again (a kept-alive '
      'Entdecken does not)', () async {
    container.listen(dietitianTipsProvider, (_, _) {});
    await container.read(dietitianTipsProvider.future);
    expect(service.listCalls, 1);

    service.tips = [testTip(id: 'c'), ...service.tips];
    returnFromBackground();
    await pumpEventQueue();

    expect(service.listCalls, 2);
    expect(
      container.read(dietitianTipsProvider).requireValue.map((t) => t.id),
      ['c', 'a', 'b'],
    );
  });

  test(
    'a second „Probiere ich" while the first is under way is dropped',
    () async {
      await container.read(dietitianTipsProvider.future);
      final notifier = container.read(dietitianTipsProvider.notifier);
      final gate = Completer<void>();
      service.gate = gate.future;

      final first = notifier.toggleTrying('a');
      final second = notifier.toggleTrying('a');
      gate.complete();
      await Future.wait([first, second]);

      expect(service.tryingCalls, [('a', true)]);
      expect(
        container.read(dietitianTipsProvider).requireValue.first.tryingAt,
        isNotNull,
      );
    },
  );

  test('a list fetched before a remove does not bring the tip back', () async {
    await container.read(dietitianTipsProvider.future);
    final notifier = container.read(dietitianTipsProvider.notifier);
    final gate = Completer<void>();
    service.gate = gate.future;

    final reload = notifier.refresh();
    service.gate = null;
    await notifier.remove('a');
    gate.complete();
    await reload;

    expect(
      container.read(dietitianTipsProvider).requireValue.map((t) => t.id),
      ['b'],
    );
  });
}
