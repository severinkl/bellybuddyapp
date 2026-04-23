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

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
  });

  group('RecommendationFeedbackView', () {
    testWidgets('unrated: heading + two pills, no hint', (tester) async {
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
      expect(find.text('Hilfreich'), findsOneWidget);
      expect(find.text('Nicht hilfreich'), findsOneWidget);
      expect(
        find.text('Danke für dein Feedback', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('Wird berücksichtigt', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('tapping Hilfreich calls notifier with liked', (tester) async {
      final repo = MockRecommendationRepository();
      when(
        () => repo.fetchByUserId(any()),
      ).thenAnswer((_) async => [testRecommendation(id: 'r1')]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

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
            home: Scaffold(
              body: RecommendationFeedbackView(
                recommendation: container
                    .read(recommendationProvider)
                    .value!
                    .first,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hilfreich'));
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

    testWidgets('liked: renders "Danke für dein Feedback" hint', (
      tester,
    ) async {
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

      expect(find.textContaining('Danke'), findsOneWidget);
    });

    testWidgets('tapping Nicht hilfreich opens the dislike sheet', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      final rec = testRecommendation(id: 'r1');
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenAnswer((_) async {});

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
            home: Scaffold(
              body: RecommendationFeedbackView(
                recommendation: container
                    .read(recommendationProvider)
                    .value!
                    .first,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nicht hilfreich'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationDislikeSheet), findsOneWidget);
      // Also: the notifier was called with disliked before the sheet opened.
      verify(
        () => repo.updateFeedback(
          id: 'r1',
          state: RecommendationState.disliked,
          dislikeCategory: null,
          dislikeComment: null,
        ),
      ).called(1);
    });

    testWidgets(
      'disliked: renders hint + Bearbeiten; tapping Bearbeiten re-opens the sheet',
      (tester) async {
        final rec = testRecommendation(id: 'r1').copyWith(
          state: RecommendationState.disliked,
          dislikeCategory: DislikeCategory.notRelevant.dbValue,
        );
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

        expect(find.textContaining('Wird berücksichtigt'), findsOneWidget);
        expect(find.text('Bearbeiten'), findsOneWidget);

        await tester.tap(find.text('Bearbeiten'));
        await tester.pumpAndSettle();
        expect(find.byType(RecommendationDislikeSheet), findsOneWidget);
      },
    );

    testWidgets('repo error shows SnackBar', (tester) async {
      final repo = MockRecommendationRepository();
      when(
        () => repo.fetchByUserId(any()),
      ).thenAnswer((_) async => [testRecommendation(id: 'r1')]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(
        () => repo.updateFeedback(
          id: any(named: 'id'),
          state: any(named: 'state'),
          dislikeCategory: any(named: 'dislikeCategory'),
          dislikeComment: any(named: 'dislikeComment'),
        ),
      ).thenThrow(Exception('boom'));

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
            home: Scaffold(
              body: RecommendationFeedbackView(
                recommendation: container
                    .read(recommendationProvider)
                    .value!
                    .first,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hilfreich'));
      await tester.pumpAndSettle();

      expect(find.text('Konnte nicht gespeichert werden.'), findsOneWidget);
    });
  });
}
