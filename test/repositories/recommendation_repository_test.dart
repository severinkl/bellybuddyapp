import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/first_tip.dart';
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

  group('requestFirstTip', () {
    Future<FirstTipResult> request() =>
        repo.requestFirstTip(intolerances: ['Fruktose'], diet: null);

    void stub(Future<FirstTipResult> Function() answer) => when(
      () => recommendationService.requestFirstTip(
        intolerances: any(named: 'intolerances'),
        diet: any(named: 'diet'),
      ),
    ).thenAnswer((_) => answer());

    test('delegates to the service', () async {
      stub(() async => const FirstTipResult(id: 'set-1', tips: 2));

      final result = await request();

      expect(result.ok, isTrue);
      verify(
        () => recommendationService.requestFirstTip(
          intolerances: ['Fruktose'],
          diet: null,
        ),
      ).called(1);
    });

    test('a failure is rethrown, never retried', () async {
      stub(() => Future.error(const FirstTipException(500)));

      await expectLater(request(), throwsA(isA<FirstTipException>()));
      verify(
        () => recommendationService.requestFirstTip(
          intolerances: any(named: 'intolerances'),
          diet: any(named: 'diet'),
        ),
      ).called(1);
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
