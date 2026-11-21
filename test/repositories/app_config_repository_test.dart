import 'package:belly_buddy/repositories/app_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  group('AppConfigRepository', () {
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

      final config = await AppConfigRepository(client).fetch();
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

      await expectLater(
        () => AppConfigRepository(client).fetch(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
