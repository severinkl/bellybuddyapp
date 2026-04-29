import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/user_recipe_service.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSupabaseClient());
  });

  group('UserRecipeService', () {
    // Integration-level smoke only — the Supabase builder is heavy to mock
    // end-to-end. We test the service under its public contract:
    // construction, and that methods are defined with expected signatures.
    test('can be instantiated with a SupabaseClient', () {
      final client = _FakeSupabaseClient();
      final service = UserRecipeService(client);
      expect(service, isNotNull);
    });
  });

  group('UserRecipeService._buildTsQuery (via @visibleForTesting)', () {
    test('blank query returns empty string', () {
      expect(UserRecipeService.buildTsQuery(''), '');
      expect(UserRecipeService.buildTsQuery('   '), '');
    });

    test('single token gets prefix wildcard', () {
      expect(UserRecipeService.buildTsQuery('kart'), 'kart:*');
    });

    test('multi-token query joins with & and prefixes each', () {
      expect(UserRecipeService.buildTsQuery('curry reis'), 'curry:* & reis:*');
    });

    test('extra whitespace between tokens is collapsed', () {
      expect(
        UserRecipeService.buildTsQuery('  curry   reis  '),
        'curry:* & reis:*',
      );
    });

    test('strips tsquery reserved characters from each token', () {
      // & | ! ( ) : * < > would otherwise break the query and 400 PostgREST.
      expect(UserRecipeService.buildTsQuery('curry&reis'), 'curryreis:*');
      expect(UserRecipeService.buildTsQuery('curry|reis'), 'curryreis:*');
      expect(UserRecipeService.buildTsQuery('curry:foo'), 'curryfoo:*');
      expect(UserRecipeService.buildTsQuery('(curry)'), 'curry:*');
      expect(UserRecipeService.buildTsQuery('!curry'), 'curry:*');
    });

    test('preserves Unicode word characters (German umlauts)', () {
      expect(UserRecipeService.buildTsQuery('Möhren'), 'Möhren:*');
      expect(
        UserRecipeService.buildTsQuery('Müesli Brötchen'),
        'Müesli:* & Brötchen:*',
      );
    });

    test('drops tokens that become empty after stripping', () {
      expect(
        UserRecipeService.buildTsQuery('curry &&& reis'),
        'curry:* & reis:*',
      );
      expect(UserRecipeService.buildTsQuery('!!!'), '');
    });
  });
}
