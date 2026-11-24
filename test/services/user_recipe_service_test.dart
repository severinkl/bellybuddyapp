import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/user_recipe_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

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

  group('UserRecipeService writes', () {
    late MockSupabaseClient client;
    late UserRecipeService service;
    late MockSupabaseQueryBuilder qb;
    late MockPostgrestFilterBuilder filter;
    late MockPostgrestTransformBuilder select;
    final inserts = <Map>[];
    final updates = <Map>[];

    Map<String, dynamic> row({List<String?>? amounts}) => {
      'id': 'rec-1',
      'user_id': 'u1',
      'title': 'T',
      'ingredients': ['Reis', 'Salz'],
      'ingredient_amounts': amounts,
    };

    /// Each update answers with the next of [results] (or throws it).
    void stub({required List<Object> results}) {
      inserts.clear();
      updates.clear();
      client = MockSupabaseClient();
      qb = MockSupabaseQueryBuilder();
      filter = MockPostgrestFilterBuilder();
      select = MockPostgrestTransformBuilder();
      when(() => client.from('user_recipes')).thenAnswer((_) => qb);
      var i = 0;
      when(() => qb.insert(any())).thenAnswer((inv) {
        inserts.add(inv.positionalArguments.first as Map);
        return filter;
      });
      when(() => qb.update(any())).thenAnswer((inv) {
        updates.add(inv.positionalArguments.first as Map);
        return filter;
      });
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      when(() => filter.select()).thenAnswer((_) => select);
      when(() => select.single()).thenAnswer((_) {
        final r = results[i < results.length ? i : results.length - 1];
        i++;
        if (r is Exception) {
          return SettlableMap(Future.error(r));
        }
        return settleMap(r as Map<String, dynamic>);
      });
      service = UserRecipeService(client);
    }

    const dup = PostgrestException(message: 'dup', code: '23505');

    test('create without steps sends only the old columns', () async {
      stub(results: [row()]);
      await service.create(
        userId: 'u1',
        title: 'T',
        ingredients: const ['Reis'],
        imageUrl: null,
      );
      expect(inserts.single.keys.toSet(), {
        'user_id',
        'title',
        'ingredients',
        'image_url',
      });
    });

    test('create an adapted recipe sends steps, amounts and origin', () async {
      stub(results: [row()]);
      await service.create(
        userId: 'u1',
        title: 'T',
        ingredients: const ['Reis', 'Salz'],
        instructions: const ['Kochen'],
        ingredientAmounts: const ['2 EL', null],
        adaptedFromRecipeId: 'src-1',
      );
      expect(inserts.single['instructions'], ['Kochen']);
      expect(inserts.single['ingredient_amounts'], ['2 EL', null]);
      expect(inserts.single['adapted_from_recipe_id'], 'src-1');
    });

    test('update without steps or amounts leaves them out', () async {
      stub(results: [row()]);
      await service.update(id: 'rec-1', title: 'T', ingredients: const ['A']);
      expect(updates, hasLength(1));
      expect(updates.single.containsKey('instructions'), isFalse);
      expect(updates.single.containsKey('ingredient_amounts'), isFalse);
    });

    test('update: amounts kept gives one write', () async {
      stub(
        results: [
          row(amounts: ['2 EL', null]),
        ],
      );
      final r = await service.update(
        id: 'rec-1',
        title: 'T',
        ingredients: const ['Reis', 'Salz'],
        instructions: const ['Kochen'],
        ingredientAmounts: const ['2 EL', null],
      );
      expect(updates, hasLength(1));
      expect(updates.single['instructions'], ['Kochen']);
      expect(updates.single['ingredient_amounts'], ['2 EL', null]);
      expect(r.amountOf(0), '2 EL');
    });

    test('update: amounts the trigger dropped are written again', () async {
      stub(
        results: [
          row(),
          row(amounts: ['2 EL', null]),
        ],
      );
      final r = await service.update(
        id: 'rec-1',
        title: 'T',
        ingredients: const ['Reis', 'Salz'],
        ingredientAmounts: const ['2 EL', null],
      );
      expect(updates, hasLength(2));
      expect(updates[1], {
        'ingredient_amounts': ['2 EL', null],
      });
      expect(r.amountOf(0), '2 EL');
    });

    test('a duplicate title throws on create and update', () async {
      stub(results: [dup]);
      await expectLater(
        service.create(userId: 'u1', title: 'T', ingredients: const ['A']),
        throwsA(isA<DuplicateRecipeTitleException>()),
      );
      await expectLater(
        service.update(id: 'rec-1', title: 'T', ingredients: const ['A']),
        throwsA(isA<DuplicateRecipeTitleException>()),
      );
    });
  });
}
