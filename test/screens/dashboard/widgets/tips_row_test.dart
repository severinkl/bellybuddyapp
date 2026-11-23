import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tips_row.dart';

import '../../../helpers/fixtures.dart';

List<RecommendationItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    RecommendationItem(type: 'try', ingredient: 'Zutat $i', reason: 'Grund'),
];

void main() {
  group('TipsRow.label', () {
    final monday = DateTime(2026, 11, 16);

    test('week and count', () {
      final set = testRecommendation(
        createdAt: monday,
        recommendations: _items(3),
      );
      expect(TipsRow.label(set), '✨ Neue Tipps · Woche 47 · 3 Tipps');
    });

    test('one Tipp', () {
      final set = testRecommendation(
        createdAt: monday,
        recommendations: _items(1),
      );
      expect(TipsRow.label(set), '✨ Neue Tipps · Woche 47 · 1 Tipp');
    });

    test('no items: the count is left out', () {
      expect(
        TipsRow.label(testRecommendation(createdAt: monday)),
        '✨ Neue Tipps · Woche 47',
      );
    });

    test('no createdAt: the week is left out', () {
      final set = testRecommendation(recommendations: _items(3));
      expect(TipsRow.label(set), '✨ Neue Tipps · 3 Tipps');
    });
  });
}
