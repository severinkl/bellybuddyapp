// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/providers/app_config_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  group('appConfigProvider', () {
    late MockSupabaseClient client;

    setUp(() {
      client = MockSupabaseClient();
    });

    test('returns AppConfig with both rows parsed', () async {
      final fb = mockSelectRows(
        client,
        table: 'app_config',
        rows: [
          {'key': 'minimum_supported_version', 'value': '1.2.0'},
          {'key': 'latest_version', 'value': '1.4.2'},
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);

      final container = createContainer(
        overrides: <Override>[supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final config = await container.read(appConfigProvider.future);
      expect(config.minimum, '1.2.0');
      expect(config.latest, '1.4.2');
      verify(
        () =>
            fb.inFilter('key', ['minimum_supported_version', 'latest_version']),
      ).called(1);
    });

    test('throws when a required row is missing', () async {
      final fb = mockSelectRows(
        client,
        table: 'app_config',
        rows: [
          {'key': 'minimum_supported_version', 'value': '1.2.0'},
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);

      final container = createContainer(
        overrides: <Override>[supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => container.read(appConfigProvider.future),
        throwsA(isA<StateError>()),
      );
    });
  });
}
