// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/dislike_category.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_feedback_view.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/riverpod_helpers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Recommendation rec,
  required List<Override> overrides,
}) async {
  await tester.pumpWithProviders(
    Scaffold(body: RecommendationFeedbackView(recommendation: rec)),
    overrides: overrides,
  );
  await tester.pumpAndSettle();
}

/// Pumps the feedback view inside a container whose notifier has already been
/// seeded with the supplied recommendation via `fetchRecommendations`. Returns
/// the mock repository so the caller can `verify(...)` on it.
Future<MockRecommendationRepository> _pumpWithSeededNotifier(
  WidgetTester tester, {
  required Recommendation rec,
  bool throwOnUpdate = false,
}) async {
  final repo = MockRecommendationRepository();
  when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
  when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
  if (throwOnUpdate) {
    when(
      () => repo.updateFeedback(
        id: any(named: 'id'),
        state: any(named: 'state'),
        dislikeCategory: any(named: 'dislikeCategory'),
        dislikeComment: any(named: 'dislikeComment'),
      ),
    ).thenThrow(Exception('boom'));
  } else {
    when(
      () => repo.updateFeedback(
        id: any(named: 'id'),
        state: any(named: 'state'),
        dislikeCategory: any(named: 'dislikeCategory'),
        dislikeComment: any(named: 'dislikeComment'),
      ),
    ).thenAnswer((_) async {});
  }

  final container = createContainer(
    overrides: [
      recommendationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('test-user'),
    ],
  );
  addTearDown(container.dispose);

  await container.read(recommendationProvider.notifier).fetchRecommendations();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: RecommendationFeedbackView(
            recommendation: container.read(recommendationProvider).value!.first,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return repo;
}

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
    registerFallbackValue(DislikeCategory.notRelevant);
  });

  group('RecommendationFeedbackView', () {
    testWidgets('unrated shows heading + thumbs, no category chips', (
      tester,
    ) async {
      final rec = testRecommendation(id: 'r1');
      await _pump(
        tester,
        rec: rec,
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(
            MockRecommendationRepository(),
          ),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );

      expect(find.text('War diese Empfehlung hilfreich?'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.text('Nicht relevant'), findsNothing);
      expect(find.text('Diese Empfehlung ausblenden'), findsNothing);
    });

    testWidgets('tapping thumbs-up on unrated calls setRecommendationState('
        'liked)', (tester) async {
      final rec = testRecommendation(id: 'r1');
      final repo = await _pumpWithSeededNotifier(tester, rec: rec);

      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pumpAndSettle();

      verify(
        () => repo.updateFeedback(
          id: 'r1',
          state: RecommendationState.liked,
          dislikeCategory: null,
          dislikeComment: null,
        ),
      ).called(1);
    });

    testWidgets('disliked shows categories + Ausblenden button', (
      tester,
    ) async {
      final rec = testRecommendation(
        id: 'r1',
      ).copyWith(state: RecommendationState.disliked);
      await _pump(
        tester,
        rec: rec,
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(
            MockRecommendationRepository(),
          ),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );

      expect(find.text('Schade! Warum nicht?'), findsOneWidget);
      for (final c in DislikeCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.text('Diese Empfehlung ausblenden'), findsOneWidget);
    });

    testWidgets(
      'tapping a category chip in disliked state calls setRecommendationState '
      'with the category',
      (tester) async {
        final rec = testRecommendation(
          id: 'r1',
        ).copyWith(state: RecommendationState.disliked);
        final repo = await _pumpWithSeededNotifier(tester, rec: rec);

        await tester.tap(find.text('Nicht relevant'));
        await tester.pumpAndSettle();

        verify(
          () => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.disliked,
            dislikeCategory: DislikeCategory.notRelevant,
            dislikeComment: null,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping "Diese Empfehlung ausblenden" calls setRecommendationState('
      'hidden)',
      (tester) async {
        final rec = testRecommendation(
          id: 'r1',
        ).copyWith(state: RecommendationState.disliked);
        final repo = await _pumpWithSeededNotifier(tester, rec: rec);

        await tester.tap(find.text('Diese Empfehlung ausblenden'));
        await tester.pumpAndSettle();

        verify(
          () => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.hidden,
            dislikeCategory: null,
            dislikeComment: null,
          ),
        ).called(1);
      },
    );

    testWidgets('liked shows filled thumb-up + Danke!', (tester) async {
      final rec = testRecommendation(
        id: 'r1',
      ).copyWith(state: RecommendationState.liked);
      await _pump(
        tester,
        rec: rec,
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(
            MockRecommendationRepository(),
          ),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );

      expect(find.byIcon(Icons.thumb_up), findsOneWidget); // filled
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.text('Danke!'), findsOneWidget);
    });

    testWidgets('on repo error, a SnackBar with the fallback copy appears', (
      tester,
    ) async {
      final rec = testRecommendation(id: 'r1');
      await _pumpWithSeededNotifier(tester, rec: rec, throwOnUpdate: true);

      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pump(); // start SnackBar animation
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Konnte nicht gespeichert werden.'), findsOneWidget);
    });
  });
}
