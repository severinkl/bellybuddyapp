// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/models/app_config.dart';
import 'package:belly_buddy/providers/app_config_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../helpers/riverpod_helpers.dart';

ProviderContainer _containerWith({
  required AppConfig config,
  required String version,
}) {
  return createContainer(
    overrides: <Override>[
      appConfigProvider.overrideWith((_) async => config),
      currentVersionProvider.overrideWith((_) async => version),
    ],
  );
}

void main() {
  group('upgradeDecisionProvider', () {
    test('below minimum → hardGate', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.1.9',
      );
      addTearDown(c.dispose);
      expect(
        await c.read(upgradeDecisionProvider.future),
        UpgradeDecision.hardGate,
      );
    });

    test('at minimum, below latest → softNudge', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.2.0',
      );
      addTearDown(c.dispose);
      expect(
        await c.read(upgradeDecisionProvider.future),
        UpgradeDecision.softNudge,
      );
    });

    test('between minimum and latest → softNudge', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.4.0',
      );
      addTearDown(c.dispose);
      expect(
        await c.read(upgradeDecisionProvider.future),
        UpgradeDecision.softNudge,
      );
    });

    test('at latest → ok', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.5.0',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future), UpgradeDecision.ok);
    });

    test('above latest → ok', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.6.0',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future), UpgradeDecision.ok);
    });

    test('config fetch failure → ok (fail open)', () async {
      final c = createContainer(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            AsyncError<AppConfig>('boom', StackTrace.current),
          ),
          currentVersionProvider.overrideWith((_) async => '1.0.0'),
        ],
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future), UpgradeDecision.ok);
    });
  });
}
