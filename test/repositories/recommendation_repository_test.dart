import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
  });

  late MockRecommendationService recommendationService;
  late RecommendationRepository repo;

  setUp(() {
    recommendationService = MockRecommendationService();
    repo = RecommendationRepository(recommendationService);
  });

  group('fetchByUserId', () {
    test('delegates to recommendationService.fetchByUserId', () async {
      final recs = [testRecommendation()];
      when(
        () => recommendationService.fetchByUserId(any()),
      ).thenAnswer((_) async => recs);

      final result = await repo.fetchByUserId(testUserId);

      expect(result, equals(recs));
      verify(() => recommendationService.fetchByUserId(testUserId)).called(1);
    });
  });

  group('updateFeedback', () {
    setUp(() {
      when(
        () => recommendationService.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});
    });

    test('writes state and comment when both provided (disliked)', () async {
      await repo.updateFeedback(
        id: 'rec-1',
        state: RecommendationState.disliked,
        dislikeComment: 'Nein',
      );

      verify(
        () => recommendationService.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.disliked,
          dislikeComment: 'Nein',
        ),
      ).called(1);
    });

    test('omits comment when state is liked', () async {
      await repo.updateFeedback(id: 'rec-1', state: RecommendationState.liked);

      verify(
        () => recommendationService.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.liked,
          dislikeComment: null,
        ),
      ).called(1);
    });

    test('state hidden with no comment delegates with null', () async {
      await repo.updateFeedback(id: 'rec-1', state: RecommendationState.hidden);

      verify(
        () => recommendationService.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.hidden,
          dislikeComment: null,
        ),
      ).called(1);
    });
  });
}
