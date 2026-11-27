import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/ingredient_search_result.dart';

IngredientSearchResult _r(String id, String name, String matched) =>
    IngredientSearchResult(
      id: id,
      name: name,
      matchedName: matched,
      isOwn: false,
    );

void main() {
  group('IngredientSearchResult.rank', () {
    test('ranks by matchedName, keeping the canonical name', () {
      final result = IngredientSearchResult.rank(
        [
          _r('1', 'Tomate', 'Strauchtomate'),
          _r('2', 'Tomate', 'Paradeiser'),
          _r('3', 'Paprika', 'Paradeiserpaprika'),
        ],
        query: 'parad',
        limit: 10,
      );

      expect(result.map((r) => r.matchedName), [
        'Paradeiser',
        'Paradeiserpaprika',
      ]);
      expect(result.first.name, 'Tomate');
    });

    test('dedupes by id', () {
      final result = IngredientSearchResult.rank(
        [_r('1', 'Tomate', 'Paradeiser'), _r('1', 'Tomate', 'Tomate')],
        query: 'tom',
        limit: 10,
      );
      expect(result, hasLength(1));
    });

    test('the own row wins over a shared row with the same matched word', () {
      final result = IngredientSearchResult.rank(
        [
          _r('1', 'Tomate', 'Paradeiser'),
          const IngredientSearchResult(
            id: '2',
            name: 'Paradeiser',
            matchedName: ' paradeiser ',
            isOwn: true,
          ),
        ],
        query: 'parad',
        limit: 10,
      );
      expect(result.map((r) => r.id), ['2']);
    });

    test('a word after a comma or dot is a word start', () {
      final result = IngredientSearchResult.rank(
        [_r('1', 'a', 'Xraps'), _r('2', 'b', 'Öl, Raps')],
        query: 'raps',
        limit: 10,
      );
      expect(result.map((r) => r.id), ['2', '1']);
    });

    test('exact, then prefix, then word start, then contains', () {
      final result = IngredientSearchResult.rank(
        [
          _r('1', 'a', 'Schafermilch'),
          _r('2', 'b', 'glutenfreie Hafer'),
          _r('3', 'c', 'Haferkleie'),
          _r('4', 'd', 'Hafer'),
        ],
        query: 'hafer',
        limit: 10,
      );
      expect(result.map((r) => r.id), ['4', '3', '2', '1']);
    });

    test('shows a second line only when the word differs from the name', () {
      expect(_r('1', 'Tomate', 'Paradeiser').showsCanonicalName, isTrue);
      expect(_r('1', 'Tomate', ' tomate ').showsCanonicalName, isFalse);
      expect(_r('1', 'Tomate', 'Tomate').showsCanonicalName, isFalse);
    });
  });
}
