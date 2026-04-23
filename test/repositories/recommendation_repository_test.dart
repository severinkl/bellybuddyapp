import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/dislike_category.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
    registerFallbackValue(DislikeCategory.notRelevant);
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
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});
    });

    test(
      'writes state, category, and comment when all provided (disliked)',
      () async {
        await repo.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.disliked,
          dislikeCategory: DislikeCategory.notRelevant.dbValue,
          dislikeComment: 'Nein',
        );

        verify(
          () => recommendationService.updateFeedback(
            id: 'rec-1',
            state: RecommendationState.disliked,
            dislikeCategory: DislikeCategory.notRelevant.dbValue,
            dislikeComment: 'Nein',
          ),
        ).called(1);
      },
    );

    test('omits null category and comment when state is liked', () async {
      await repo.updateFeedback(id: 'rec-1', state: RecommendationState.liked);

      verify(
        () => recommendationService.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.liked,
          dislikeCategory: null,
          dislikeComment: null,
        ),
      ).called(1);
    });

    test(
      'state hidden with no category/comment delegates with nulls',
      () async {
        await repo.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.hidden,
        );

        verify(
          () => recommendationService.updateFeedback(
            id: 'rec-1',
            state: RecommendationState.hidden,
            dislikeCategory: null,
            dislikeComment: null,
          ),
        ).called(1);
      },
    );
  });
}
