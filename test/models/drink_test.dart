import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';

Map<String, dynamic> _row({Object? synonyms, Object? categories}) => {
  'id': 'd1',
  'name': 'Limonade',
  'added_by_user_id': null,
  'drink_synonyms': ?synonyms,
  'drink_categories': ?categories,
};

Map<String, dynamic> _cat(String? icon, int position) => {
  'catalog_categories': {'drink_icon': icon, 'position': position},
};

void main() {
  group('Drink.fromDbRow', () {
    test('takes the icon of the category with the lowest position', () {
      final d = Drink.fromDbRow(
        _row(categories: [_cat('can', 7), _cat('glass', 1)]),
      );
      expect(d.categoryIcon, DrinkIcon.glass);
    });

    test('skips a category without a known icon', () {
      final d = Drink.fromDbRow(
        _row(categories: [_cat('nope', 1), _cat(null, 2), _cat('can', 7)]),
      );
      expect(d.categoryIcon, DrinkIcon.can);
    });

    test('an unknown icon string is ignored', () {
      final d = Drink.fromDbRow(_row(categories: [_cat('nope', 1)]));
      expect(d.categoryIcon, isNull);
    });

    test('without the embeds (older server): no synonyms, no icon', () {
      final d = Drink.fromDbRow(_row());
      expect(d.synonyms, isEmpty);
      expect(d.categoryIcon, isNull);
    });

    test('reads the synonym names', () {
      final d = Drink.fromDbRow(
        _row(
          synonyms: [
            {'name': 'Kracherl'},
            {'name': 'Brause'},
          ],
        ),
      );
      expect(d.synonyms, ['Kracherl', 'Brause']);
    });
  });
}
