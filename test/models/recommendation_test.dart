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

  group('Recommendation.fromJson', () {
    test('defaults state to unrated when absent', () {
      final rec = Recommendation.fromJson({
        'id': 'rec-1',
        'user_id': 'user-1',
        'summary': 'test',
        'recommendations': [],
        'created_at': '2026-04-22T12:00:00Z',
      });
      expect(rec.state, RecommendationState.unrated);
      expect(rec.dislikeComment, isNull);
      expect(rec.ratedAt, isNull);
    });

    test('parses all four states from the DB string', () {
      for (final (dbValue, expected) in const [
        ('unrated', RecommendationState.unrated),
        ('liked', RecommendationState.liked),
        ('disliked', RecommendationState.disliked),
        ('hidden', RecommendationState.hidden),
      ]) {
        final rec = Recommendation.fromJson({
          'id': 'rec-1',
          'user_id': 'user-1',
          'summary': '',
          'recommendations': [],
          'state': dbValue,
        });
        expect(rec.state, expected);
      }
    });

    test('parses dislike_comment and rated_at', () {
      final rec = Recommendation.fromJson({
        'id': 'rec-1',
        'user_id': 'user-1',
        'summary': '',
        'recommendations': [],
        'state': 'disliked',
        'dislike_comment': 'Kein Kommentar',
        'rated_at': '2026-04-22T13:00:00Z',
      });
      expect(rec.dislikeComment, 'Kein Kommentar');
      expect(rec.ratedAt, DateTime.utc(2026, 4, 22, 13));
    });
  });
}
