import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockRecommendationService recommendationService;
  late MockEdgeFunctionService edgeFunctionService;
  late RecommendationRepository repo;

  setUp(() {
    recommendationService = MockRecommendationService();
    edgeFunctionService = MockEdgeFunctionService();
    repo = RecommendationRepository(recommendationService, edgeFunctionService);
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

  group('refreshRecommendations', () {
    test(
      'calls fetchRecentContext, invokes edge function, then re-fetches',
      () async {
        final context = {
          'recentMeals': <dynamic>[],
          'recentToilet': <dynamic>[],
        };
        final recs = [testRecommendation(summary: 'Neuer Tipp')];

        when(
          () => recommendationService.fetchRecentContext(any()),
        ).thenAnswer((_) async => context);
        when(
          () => edgeFunctionService.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => <String, dynamic>{});
        when(
          () => recommendationService.fetchByUserId(any()),
        ).thenAnswer((_) async => recs);

        final result = await repo.refreshRecommendations(testUserId, null);

        expect(result, equals(recs));
        verifyInOrder([
          () => recommendationService.fetchRecentContext(testUserId),
          () => edgeFunctionService.invoke(
            'diet-recommendations',
            body: any(named: 'body'),
          ),
          () => recommendationService.fetchByUserId(testUserId),
        ]);
      },
    );

    test(
      'includes profile data in edge function body when profile is not null',
      () async {
        final profile = testUserProfile(
          symptoms: ['Blähungen'],
          intolerances: ['Laktose'],
          diet: 'vegetarisch',
        );
        final context = {
          'recentMeals': <dynamic>[],
          'recentToilet': <dynamic>[],
        };

        when(
          () => recommendationService.fetchRecentContext(any()),
        ).thenAnswer((_) async => context);
        when(
          () => edgeFunctionService.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => <String, dynamic>{});
        when(
          () => recommendationService.fetchByUserId(any()),
        ).thenAnswer((_) async => []);

        await repo.refreshRecommendations(testUserId, profile);

        final captured =
            verify(
                  () => edgeFunctionService.invoke(
                    'diet-recommendations',
                    body: captureAny(named: 'body'),
                  ),
                ).captured.single
                as Map<String, dynamic>;

        expect(captured['symptoms'], equals(['Blähungen']));
        expect(captured['intolerances'], equals(['Laktose']));
        expect(captured['diet'], equals('vegetarisch'));
      },
    );

    test(
      'omits profile data from edge function body when profile is null',
      () async {
        final context = {
          'recentMeals': <dynamic>[],
          'recentToilet': <dynamic>[],
        };

        when(
          () => recommendationService.fetchRecentContext(any()),
        ).thenAnswer((_) async => context);
        when(
          () => edgeFunctionService.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => <String, dynamic>{});
        when(
          () => recommendationService.fetchByUserId(any()),
        ).thenAnswer((_) async => []);

        await repo.refreshRecommendations(testUserId, null);

        final captured =
            verify(
                  () => edgeFunctionService.invoke(
                    'diet-recommendations',
                    body: captureAny(named: 'body'),
                  ),
                ).captured.single
                as Map<String, dynamic>;

        expect(captured.containsKey('symptoms'), isFalse);
        expect(captured.containsKey('intolerances'), isFalse);
        expect(captured.containsKey('diet'), isFalse);
      },
    );
  });
}
