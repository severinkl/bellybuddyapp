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
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_dislike_sheet.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/riverpod_helpers.dart';

// Helper: pump a host widget that opens the sheet on a button tap.
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
    testWidgets('renders all 5 chips + textarea + buttons', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
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
      for (final c in DislikeCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.text('Empfehlung ausblenden'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
    });

    testWidgets(
      'tapping a chip calls setRecommendationState with that category',
      (tester) async {
        final repo = MockRecommendationRepository();
        when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
        when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
        when(
          () => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
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
        // Seed the provider with this rec so setRecommendationState has a target.
        await container
            .read(recommendationProvider.notifier)
            .fetchRecommendations();
        // Stub fetch to return the rec once we re-run.
        when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
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

        await tester.tap(find.text('Nicht relevant'));
        await tester.pumpAndSettle();

        verify(
          () => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.disliked,
            dislikeCategory: DislikeCategory.notRelevant.dbValue,
            dislikeComment: null,
          ),
        ).called(1);
      },
    );

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
          dislikeCategory: any(named: 'dislikeCategory'),
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
          dislikeCategory: any(named: 'dislikeCategory'),
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
          dislikeCategory: null,
          dislikeComment: null,
        ),
      ).called(1);
    });

    testWidgets('pre-fills selected chip when rec has a category', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
        dislikeCategory: DislikeCategory.tooComplicated.dbValue,
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

      // The textarea should be pre-filled.
      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.controller?.text, 'zu lang');
      // The selected ChoiceChip should be the one labelled "Zu kompliziert".
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(
        chips
            .firstWhere((c) => (c.label as Text).data == 'Zu kompliziert')
            .selected,
        isTrue,
      );
    });
  });
}
