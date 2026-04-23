// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_dislike_sheet.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/riverpod_helpers.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required Recommendation rec,
  required List<Override> overrides,
}) async {
  await tester.pumpWithProviders(
    Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showRecommendationDislikeSheet(ctx, rec),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: overrides,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
  });

  group('RecommendationDislikeSheet', () {
    testWidgets('renders heading + textarea + buttons (no chips)', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

      final rec = testRecommendation(
        id: 'r1',
      ).copyWith(state: RecommendationState.disliked);

      await _openSheet(
        tester,
        rec: rec,
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );

      expect(find.text('Was hat dir nicht gefallen?'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Empfehlung ausblenden'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
    });

    testWidgets('Fertig pops without calling the repo', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      final rec = testRecommendation(
        id: 'r1',
      ).copyWith(state: RecommendationState.disliked);

      await _openSheet(
        tester,
        rec: rec,
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );

      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationDislikeSheet), findsNothing);
      verifyNever(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      );
    });

    testWidgets('Ausblenden calls setRecommendationState(hidden) and pops', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer(
        (_) async => [
          testRecommendation(
            id: 'r1',
          ).copyWith(state: RecommendationState.disliked),
        ],
      );
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

      final rec = testRecommendation(
        id: 'r1',
      ).copyWith(state: RecommendationState.disliked);
      final container = createContainer(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showRecommendationDislikeSheet(ctx, rec),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empfehlung ausblenden'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationDislikeSheet), findsNothing);
      verify(
        () => repo.updateFeedback(
          id: 'r1',
          state: RecommendationState.hidden,
          dislikeComment: null,
        ),
      ).called(1);
    });

    testWidgets('pre-fills the textarea with any existing comment', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
        dislikeComment: 'zu lang',
      );

      await _openSheet(
        tester,
        rec: rec,
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );

      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.controller?.text, 'zu lang');
    });
  });
}
