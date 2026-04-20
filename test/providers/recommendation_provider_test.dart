import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockRecommendationRepository mockRepo;

  setUp(() {
    mockRepo = MockRecommendationRepository();
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('RecommendationNotifier.fetchRecommendations', () {
    test('loading → data with recommendations', () async {
      final recs = [testRecommendation()];
      when(() => mockRepo.fetchByUserId(any())).thenAnswer((_) async => recs);

      final container = makeContainer();
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();

      final state = container.read(recommendationProvider);
      expect(state, isA<AsyncData>());
      expect(state.value, hasLength(1));
    });

    test('null userId → empty list', () async {
      final container = makeContainer(userId: null);
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();

      final state = container.read(recommendationProvider);
      expect(state, isA<AsyncData>());
      expect(state.value, isEmpty);
      verifyNever(() => mockRepo.fetchByUserId(any()));
    });

    test('repo error → AsyncError state', () async {
      when(
        () => mockRepo.fetchByUserId(any()),
      ).thenThrow(Exception('fetch failed'));

      final container = makeContainer();
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();

      final state = container.read(recommendationProvider);
      expect(state, isA<AsyncError>());
    });
  });
}
