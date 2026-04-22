// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_index_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overridesFor(List<Recommendation> recommendations) {
  final mock = MockRecommendationRepository();
  when(
    () => mock.fetchByUserId(any()),
  ).thenAnswer((_) async => recommendations);
  when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});
  return [
    recommendationRepositoryProvider.overrideWithValue(mock),
    currentUserIdProvider.overrideWithValue('test-user'),
  ];
}

Recommendation _rec(String id, {String? summary}) =>
    testRecommendation(id: id, summary: summary ?? 'Tipp $id');

void main() {
  group('RecommendationsScreen', () {
    testWidgets('loading state renders BbLoadingState', (tester) async {
      // Pump with a provider in AsyncValue.loading. We override the
      // repository with a Completer-like never-resolving future so the
      // notifier stays in the loading state.
      final mock = MockRecommendationRepository();
      final completer = Completer<List<Recommendation>>();
      when(() => mock.fetchByUserId(any())).thenAnswer((_) => completer.future);
      when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(mock),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pump();

      expect(find.byType(BbLoadingState), findsOneWidget);
      expect(find.text('Analysiere deine Daten...'), findsOneWidget);

      completer.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('error state renders BbErrorState with retry', (tester) async {
      final mock = MockRecommendationRepository();
      when(
        () => mock.fetchByUserId(any()),
      ).thenAnswer((_) async => throw Exception('boom'));
      when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(mock),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fehler beim Laden der Empfehlungen.'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });

    testWidgets('empty state shows mascot + "Noch keine Empfehlungen"', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor(const []),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Noch keine Empfehlungen'), findsOneWidget);
      expect(
        find.byKey(RecommendationsScreen.emptyStateRefreshKey),
        findsOneWidget,
      );
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets(
      'single-recommendation list renders one page with both chevrons hidden',
      (tester) async {
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor([_rec('1')]),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byType(PageView), findsOneWidget);
        expect(
          find.byKey(RecommendationsScreen.previousRecommendationKey),
          findsNothing,
        );
        expect(
          find.byKey(RecommendationsScreen.nextRecommendationKey),
          findsNothing,
        );
        expect(find.text('1 von 1 Empfehlungen'), findsOneWidget);
      },
    );

    testWidgets('multi-recommendation initial page is the latest (rightmost)', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor([_rec('3'), _rec('2'), _rec('1')]),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('3 von 3 Empfehlungen'), findsOneWidget);
      expect(
        find.byKey(RecommendationsScreen.nextRecommendationKey),
        findsNothing,
      );
      expect(
        find.byKey(RecommendationsScreen.previousRecommendationKey),
        findsOneWidget,
      );
    });

    testWidgets(
      'swiping rightward on the PageView retreats to an older recommendation',
      (tester) async {
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor([_rec('3'), _rec('2'), _rec('1')]),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Fling rather than plain drag: a 400px drag sits on PageView's
        // commit threshold and is flaky. A 1000 px/s fling crosses cleanly.
        await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.text('2 von 3 Empfehlungen'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the previous chevron advances to the older recommendation',
      (tester) async {
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor([_rec('3'), _rec('2'), _rec('1')]),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(RecommendationsScreen.previousRecommendationKey),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 von 3 Empfehlungen'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the next chevron advances to the newer recommendation',
      (tester) async {
        final mock = MockRecommendationRepository();
        when(
          () => mock.fetchByUserId(any()),
        ).thenAnswer((_) async => [_rec('3'), _rec('2'), _rec('1')]);
        when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

        final container = createContainer(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(mock),
            currentUserIdProvider.overrideWithValue('test-user'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: RecommendationsScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Seed the index to the middle page so both chevrons are visible.
        container.read(recommendationIndexProvider.notifier).set(1);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(RecommendationsScreen.nextRecommendationKey),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 von 3 Empfehlungen'), findsOneWidget);
      },
    );

    testWidgets(
      'cold-start swipe input works before any chevron tap (regression)',
      (tester) async {
        // Regression test for the bug fixed in efc1efc: after a prior
        // refactor, at cold start the PageView's scroll physics were
        // left in a half-initialised state and the first swipe did
        // nothing until the user tapped a chevron to force a re-settle.
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor([_rec('3'), _rec('2'), _rec('1')]),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Precondition: we're on the latest, no chevron tap yet.
        expect(find.text('3 von 3 Empfehlungen'), findsOneWidget);

        // Swipe rightward (positive X) — goes to older (pageIndex - 1).
        await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
        await tester.pumpAndSettle();

        expect(
          find.text('2 von 3 Empfehlungen'),
          findsOneWidget,
          reason:
              'First swipe at cold start must advance the PageView. '
              "If this fails, we've regressed to the pre-efc1efc bug "
              'where the scroll position needed a programmatic '
              'animateToPage to become gesture-responsive.',
        );
      },
    );

    testWidgets(
      'refresh with a new latest while reading an older page keeps the user put',
      (tester) async {
        // Exercises the anchor logic's no-yank branch (_maybeAnchor with
        // wasAtPreviousLatest == false): when a fresh recommendation
        // arrives via refresh, the reader shouldn't be teleported off
        // the entry they're currently on.
        final initial = [_rec('3'), _rec('2'), _rec('1')];
        final afterRefresh = [_rec('4'), _rec('3'), _rec('2'), _rec('1')];

        final mock = MockRecommendationRepository();
        var callCount = 0;
        when(() => mock.fetchByUserId(any())).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? initial : afterRefresh;
        });
        when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

        final container = createContainer(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(mock),
            currentUserIdProvider.overrideWithValue('test-user'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: RecommendationsScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Move to the oldest (page 0, listIndex 2 = recommendation '1').
        container.read(recommendationIndexProvider.notifier).set(0);
        await tester.pumpAndSettle();
        expect(find.text('1 von 3 Empfehlungen'), findsOneWidget);

        // Trigger a refresh that returns a new latest '4' prepended.
        await container
            .read(recommendationProvider.notifier)
            .fetchRecommendations();
        await tester.pumpAndSettle();

        // User stays on the same PAGE index (0) — which in the new 4-item
        // list is still the oldest ('1'). Indicator reflects "1 von 4":
        // the page they were on is preserved, only the total grew.
        expect(
          find.text('1 von 4 Empfehlungen'),
          findsOneWidget,
          reason:
              'User was on the oldest when the refresh landed; the '
              'anchor logic must not jumpToPage and yank them away.',
        );
      },
    );
  });
}
