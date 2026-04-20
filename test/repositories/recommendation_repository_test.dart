import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
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
}
