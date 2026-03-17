import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/recommendation_item.dart';

void main() {
  group('Recommendation.fromJson (tests _parseItems indirectly)', () {
    test('null recommendations field produces empty list', () {
      final rec = Recommendation.fromJson({'id': '1', 'recommendations': null});
      expect(rec.recommendations, isEmpty);
    });

    test('empty recommendations list produces empty list', () {
      final rec = Recommendation.fromJson({
        'id': '1',
        'recommendations': <dynamic>[],
      });
      expect(rec.recommendations, isEmpty);
    });

    test('valid list of maps produces RecommendationItems', () {
      final rec = Recommendation.fromJson({
        'id': '1',
        'recommendations': [
          {'type': 'try', 'ingredient': 'Ingwer', 'reason': 'Gut'},
          {'type': 'substitute', 'ingredient': 'Milch', 'reason': 'Laktose'},
        ],
      });
      expect(rec.recommendations, hasLength(2));
      expect(rec.recommendations[0], isA<RecommendationItem>());
      expect(rec.recommendations[1].type, 'substitute');
    });

    test('non-map entries are filtered out', () {
      final rec = Recommendation.fromJson({
        'id': '1',
        'recommendations': [
          {'type': 'try', 'ingredient': 'A', 'reason': 'B'},
          'not a map',
          42,
          null,
        ],
      });
      expect(rec.recommendations, hasLength(1));
      expect(rec.recommendations[0].ingredient, 'A');
    });
  });
}
