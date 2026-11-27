import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/feedback_context_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';

void main() {
  test('context carries version and OS', () async {
    final container = ProviderContainer(
      overrides: [
        currentVersionProvider.overrideWith((ref) async => '1.3.0'),
        osVersionReaderProvider.overrideWithValue(() async => '18.1'),
      ],
    );
    addTearDown(container.dispose);

    final context = await container.read(feedbackContextProvider.future);

    expect(context.appVersion, '1.3.0');
    expect(context.osVersion, '18.1');
    expect(['ios', 'android'], contains(context.platform));
  });

  test('context falls back to unbekannt when the OS reader throws', () async {
    final container = ProviderContainer(
      overrides: [
        currentVersionProvider.overrideWith((ref) async => '1.3.0'),
        osVersionReaderProvider.overrideWithValue(
          () async => throw Exception('no device info'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final context = await container.read(feedbackContextProvider.future);

    expect(context.osVersion, 'unbekannt');
    expect(context.appVersion, '1.3.0');
  });

  test(
    'context falls back to unbekannt when the version lookup fails',
    () async {
      final container = ProviderContainer(
        // Riverpod retries a failed provider; the test wants the first error.
        retry: (_, _) => null,
        overrides: [
          currentVersionProvider.overrideWith((ref) async => throw 'boom'),
          osVersionReaderProvider.overrideWithValue(() async => '14'),
        ],
      );
      addTearDown(container.dispose);

      final context = await container.read(feedbackContextProvider.future);

      expect(context.appVersion, 'unbekannt');
      expect(context.osVersion, '14');
    },
  );
}
