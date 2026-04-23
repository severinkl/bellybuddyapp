import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/dislike_category.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockRecommendationRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
    registerFallbackValue(DislikeCategory.notRelevant);
  });

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

  group('RecommendationNotifier.setRecommendationState', () {
    final rec1 = testRecommendation(id: 'rec-1');
    final rec2 = testRecommendation(id: 'rec-2');
    final rec3 = testRecommendation(id: 'rec-3');

    Future<ProviderContainer> seeded(List<Recommendation> recs) async {
      when(() => mockRepo.fetchByUserId(any())).thenAnswer((_) async => recs);
      final container = makeContainer();
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();
      return container;
    }

    test('liked → replaces the recommendation with state=liked', () async {
      final container = await seeded([rec1, rec2, rec3]);
      when(
        () => mockRepo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

      await container
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: 'rec-1',
            state: RecommendationState.liked,
          );

      verify(
        () => mockRepo.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.liked,
          dislikeCategory: null,
          dislikeComment: null,
        ),
      ).called(1);

      final list = container.read(recommendationProvider).value!;
      expect(list, hasLength(3));
      expect(
        list.firstWhere((r) => r.id == 'rec-1').state,
        RecommendationState.liked,
      );
      expect(
        list.firstWhere((r) => r.id == 'rec-2').state,
        RecommendationState.unrated,
      );
    });

    test('disliked + category + comment → repo receives all three', () async {
      final container = await seeded([rec1, rec2]);
      when(
        () => mockRepo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

      await container
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: 'rec-1',
            state: RecommendationState.disliked,
            category: DislikeCategory.notRelevant,
            comment: 'Text',
          );

      verify(
        () => mockRepo.updateFeedback(
          id: 'rec-1',
          state: RecommendationState.disliked,
          dislikeCategory: DislikeCategory.notRelevant.dbValue,
          dislikeComment: 'Text',
        ),
      ).called(1);

      final updated = container
          .read(recommendationProvider)
          .value!
          .firstWhere((r) => r.id == 'rec-1');
      expect(updated.state, RecommendationState.disliked);
      expect(updated.dislikeCategory, 'not_relevant');
      expect(updated.dislikeComment, 'Text');
    });

    test('hidden → removes the recommendation from the list', () async {
      final container = await seeded([rec1, rec2, rec3]);
      when(
        () => mockRepo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

      await container
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: 'rec-1',
            state: RecommendationState.hidden,
          );

      final list = container.read(recommendationProvider).value!;
      expect(list, hasLength(2));
      expect(list.any((r) => r.id == 'rec-1'), isFalse);
    });

    test(
      'on repo error, the list is reverted and the exception rethrows',
      () async {
        final container = await seeded([rec1, rec2, rec3]);
        final seedSnapshot = container.read(recommendationProvider).value!;
        when(
          () => mockRepo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          ),
        ).thenThrow(Exception('boom'));

        await expectLater(
          container
              .read(recommendationProvider.notifier)
              .setRecommendationState(
                id: 'rec-1',
                state: RecommendationState.liked,
              ),
          throwsA(isA<Exception>()),
        );

        final list = container.read(recommendationProvider).value!;
        expect(list, hasLength(seedSnapshot.length));
        for (var i = 0; i < seedSnapshot.length; i++) {
          expect(list[i].id, seedSnapshot[i].id);
          expect(list[i].state, seedSnapshot[i].state);
        }
      },
    );
  });

  group('RecommendationNotifier.setDislikeComment', () {
    test(
      'updates only the comment locally and calls repo with current state + category',
      () async {
        final seeded = testRecommendation(id: 'rec-1').copyWith(
          state: RecommendationState.disliked,
          dislikeCategory: 'not_relevant',
        );
        when(
          () => mockRepo.fetchByUserId(any()),
        ).thenAnswer((_) async => [seeded]);
        when(
          () => mockRepo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          ),
        ).thenAnswer((_) async {});

        final container = makeContainer();
        await container
            .read(recommendationProvider.notifier)
            .fetchRecommendations();

        await container
            .read(recommendationProvider.notifier)
            .setDislikeComment(id: 'rec-1', comment: 'hallo');

        verify(
          () => mockRepo.updateFeedback(
            id: 'rec-1',
            state: RecommendationState.disliked,
            dislikeCategory: DislikeCategory.notRelevant.dbValue,
            dislikeComment: 'hallo',
          ),
        ).called(1);

        final updated = container
            .read(recommendationProvider)
            .value!
            .firstWhere((r) => r.id == 'rec-1');
        expect(updated.state, RecommendationState.disliked);
        expect(updated.dislikeCategory, 'not_relevant');
        expect(updated.dislikeComment, 'hallo');
      },
    );
  });
}
