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

    String labelFor(DateTime createdAt) =>
        TipsRow.label(testRecommendation(createdAt: createdAt));

    test('the ISO week across the year boundaries', () {
      expect(labelFor(DateTime(2025, 12, 28)), '✨ Neue Tipps · Woche 52');
      expect(labelFor(DateTime(2025, 12, 29)), '✨ Neue Tipps · Woche 1');
      expect(labelFor(DateTime(2026, 12, 31)), '✨ Neue Tipps · Woche 53');
      expect(labelFor(DateTime(2027, 1, 3)), '✨ Neue Tipps · Woche 53');
      expect(labelFor(DateTime(2027, 1, 4)), '✨ Neue Tipps · Woche 1');
    });

    test('the week of the local day, though stored in UTC', () {
      // Sunday night and Monday just after midnight, local.
      expect(
        labelFor(DateTime(2026, 11, 22, 23, 30).toUtc()),
        '✨ Neue Tipps · Woche 47',
      );
      expect(
        labelFor(DateTime(2026, 11, 23, 0, 30).toUtc()),
        '✨ Neue Tipps · Woche 48',
      );
    });

    test('no createdAt: the week is left out', () {
      final set = testRecommendation(recommendations: _items(3));
      expect(TipsRow.label(set), '✨ Neue Tipps · 3 Tipps');
    });
  });
}
