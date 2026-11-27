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
      expect(config.paywallEnabled, isFalse);
      expect(config.akuthilfeEnabled, isFalse);
      verify(
        () => fb.inFilter('key', [
          'minimum_supported_version',
          'latest_version',
          'paywall_enabled',
          'akuthilfe_enabled',
        ]),
      ).called(1);
    });

    Future<bool> paywallWith(String? value) async {
      final fb = mockSelectRows(
        client,
        table: 'app_config',
        rows: [
          {'key': 'minimum_supported_version', 'value': '1.2.0'},
          {'key': 'latest_version', 'value': '1.4.2'},
          if (value != null) {'key': 'paywall_enabled', 'value': value},
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      return (await AppConfigRepository(client).fetch()).paywallEnabled;
    }

    test("paywall_enabled 'true' switches the paywall on", () async {
      expect(await paywallWith('true'), isTrue);
    });

    test("paywall_enabled other than exactly 'true' stays off", () async {
      expect(await paywallWith('false'), isFalse);
      expect(await paywallWith('TRUE '), isFalse);
      expect(await paywallWith('True'), isFalse);
      expect(await paywallWith(''), isFalse);
    });

    test('missing paywall_enabled stays off', () async {
      expect(await paywallWith(null), isFalse);
    });

    test('still throws when latest_version is missing', () async {
      final fb = mockSelectRows(
        client,
        table: 'app_config',
        rows: [
          {'key': 'minimum_supported_version', 'value': '1.2.0'},
          {'key': 'paywall_enabled', 'value': 'true'},
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);

      await expectLater(
        () => AppConfigRepository(client).fetch(),
        throwsA(isA<StateError>()),
      );
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

    Future<bool> switchFor(String? value) async {
      final fb = mockSelectRows(
        client,
        table: 'app_config',
        rows: [
          {'key': 'minimum_supported_version', 'value': '1.2.0'},
          {'key': 'latest_version', 'value': '1.4.2'},
          if (value != null) {'key': 'akuthilfe_enabled', 'value': value},
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      return (await AppConfigRepository(client).fetch()).akuthilfeEnabled;
    }

    test("akuthilfe_enabled 'true' turns the switch on", () async {
      expect(await switchFor('true'), isTrue);
    });

    test('a missing akuthilfe_enabled row means off', () async {
      expect(await switchFor(null), isFalse);
    });

    test("'TRUE' and '1' mean off", () async {
      expect(await switchFor('TRUE'), isFalse);
      expect(await switchFor('1'), isFalse);
    });
  });
}
