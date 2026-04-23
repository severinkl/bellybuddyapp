// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_index_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
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

Recommendation _rec(String id, {String? summary, DateTime? createdAt}) =>
    testRecommendation(
      id: id,
      summary: summary ?? 'Tipp $id',
      createdAt: createdAt,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
  });

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
      'single-recommendation list renders one page with both chevrons disabled',
      (tester) async {
        // Single rec with no createdAt → title falls back to 'Empfehlungen'.
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor([_rec('1')]),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byType(PageView), findsOneWidget);
        // With a single recommendation both AppBar IconButtons are present
        // but disabled (onPressed: null) — they are rendered, not hidden.
        final appBar = find.byType(AppBar);
        final prevBtn = tester.widget<IconButton>(
          find.descendant(
            of: appBar,
            matching: find.byKey(
              RecommendationsScreen.previousRecommendationKey,
            ),
          ),
        );
        expect(prevBtn.onPressed, isNull);
        final nextBtn = tester.widget<IconButton>(
          find.descendant(
            of: appBar,
            matching: find.byKey(RecommendationsScreen.nextRecommendationKey),
          ),
        );
        expect(nextBtn.onPressed, isNull);
        // No createdAt → AppBar falls back to 'Empfehlungen'.
        expect(
          find.descendant(of: appBar, matching: find.text('Empfehlungen')),
          findsOneWidget,
        );
        expect(find.textContaining('Empfehlungen ('), findsNothing);
      },
    );

    testWidgets('multi-recommendation initial page is the latest (rightmost)', (
      tester,
    ) async {
      final recs = [
        _rec('3', createdAt: DateTime(2026, 4, 22)), // newest-first (latest)
        _rec('2', createdAt: DateTime(2026, 4, 21)),
        _rec('1', createdAt: DateTime(2026, 4, 20)), // oldest
      ];
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor(recs),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Initial page is the latest (pageIndex = total-1 = 2, listIndex = 0 → recs[0]).
      // Date appears in AppBar title only (inline row removed in Task 5).
      expect(find.text(formatDateWeekday(recs[0].createdAt!)), findsAtLeast(1));
      // At the latest page, the next button is present but disabled.
      final appBar = find.byType(AppBar);
      final nextBtn = tester.widget<IconButton>(
        find.descendant(
          of: appBar,
          matching: find.byKey(RecommendationsScreen.nextRecommendationKey),
        ),
      );
      expect(nextBtn.onPressed, isNull);
      // Prev button is enabled (there are older pages).
      final prevBtn = tester.widget<IconButton>(
        find.descendant(
          of: appBar,
          matching: find.byKey(RecommendationsScreen.previousRecommendationKey),
        ),
      );
      expect(prevBtn.onPressed, isNotNull);
    });

    testWidgets(
      'swiping rightward on the PageView retreats to an older recommendation',
      (tester) async {
        final recs = [
          _rec('3', createdAt: DateTime(2026, 4, 22)),
          _rec('2', createdAt: DateTime(2026, 4, 21)),
          _rec('1', createdAt: DateTime(2026, 4, 20)),
        ];
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor(recs),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Fling rather than plain drag: a 400px drag sits on PageView's
        // commit threshold and is flaky. A 1000 px/s fling crosses cleanly.
        await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
        await tester.pumpAndSettle();

        // After fling: pageIndex=1, listIndex=(3-1)-1=1 → recs[1].
        // Date appears in AppBar title and inline _SwipeLayout row (Task 5 removes it).
        expect(
          find.text(formatDateWeekday(recs[1].createdAt!)),
          findsAtLeast(1),
        );
      },
    );

    testWidgets(
      'tapping the previous chevron advances to the older recommendation',
      (tester) async {
        final recs = [
          _rec('3', createdAt: DateTime(2026, 4, 22)),
          _rec('2', createdAt: DateTime(2026, 4, 21)),
          _rec('1', createdAt: DateTime(2026, 4, 20)),
        ];
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor(recs),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(RecommendationsScreen.previousRecommendationKey),
        );
        await tester.pumpAndSettle();

        // After tap previous: pageIndex=1, listIndex=1 → recs[1].
        // Date appears in AppBar title and inline _SwipeLayout row (Task 5 removes it).
        expect(
          find.text(formatDateWeekday(recs[1].createdAt!)),
          findsAtLeast(1),
        );
      },
    );

    testWidgets('tapping the next chevron advances to the newer recommendation', (
      tester,
    ) async {
      final recs = [
        _rec('3', createdAt: DateTime(2026, 4, 22)),
        _rec('2', createdAt: DateTime(2026, 4, 21)),
        _rec('1', createdAt: DateTime(2026, 4, 20)),
      ];
      final mock = MockRecommendationRepository();
      when(() => mock.fetchByUserId(any())).thenAnswer((_) async => recs);
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

      await tester.tap(find.byKey(RecommendationsScreen.nextRecommendationKey));
      await tester.pumpAndSettle();

      // After tap next from pageIndex=1: pageIndex=2, listIndex=0 → recs[0] (latest).
      // Date appears in AppBar title and inline _SwipeLayout row (Task 5 removes it).
      expect(find.text(formatDateWeekday(recs[0].createdAt!)), findsAtLeast(1));
    });

    testWidgets(
      'cold-start swipe input works before any chevron tap (regression)',
      (tester) async {
        // Regression test for the bug fixed in efc1efc: after a prior
        // refactor, at cold start the PageView's scroll physics were
        // left in a half-initialised state and the first swipe did
        // nothing until the user tapped a chevron to force a re-settle.
        final recs = [
          _rec('3', createdAt: DateTime(2026, 4, 22)),
          _rec('2', createdAt: DateTime(2026, 4, 21)),
          _rec('1', createdAt: DateTime(2026, 4, 20)),
        ];
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor(recs),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Precondition: we're on the latest (pageIndex=2, listIndex=0 → recs[0]).
        // Date appears in AppBar title and inline _SwipeLayout row (Task 5 removes it).
        expect(
          find.text(formatDateWeekday(recs[0].createdAt!)),
          findsAtLeast(1),
        );

        // Swipe rightward (positive X) — goes to older (pageIndex - 1).
        await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
        await tester.pumpAndSettle();

        expect(
          find.text(formatDateWeekday(recs[1].createdAt!)),
          findsAtLeast(1),
          reason:
              'First swipe at cold start must advance the PageView. '
              "If this fails, we've regressed to the pre-efc1efc bug "
              'where the scroll position needed a programmatic '
              'animateToPage to become gesture-responsive.',
        );
      },
    );

    testWidgets(
      'every entry lands on the latest — cached data does not force a loading flicker',
      (tester) async {
        // Regression: fetchRecommendations used to flip state to loading even
        // when cached data was present. That dismounted the PageView, so the
        // anchor scheduled in the parent's first build lost its target, and
        // the user ended up on page 0 (oldest) instead of the latest. With
        // the provider keeping cached data visible during re-fetch, the
        // PageView stays mounted throughout and the anchor lands.
        final recs = [
          _rec('3', createdAt: DateTime(2026, 4, 22)),
          _rec('2', createdAt: DateTime(2026, 4, 21)),
          _rec('1', createdAt: DateTime(2026, 4, 20)),
        ];
        final mock = MockRecommendationRepository();
        when(() => mock.fetchByUserId(any())).thenAnswer((_) async => recs);
        when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

        final container = createContainer(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(mock),
            currentUserIdProvider.overrideWithValue('test-user'),
          ],
        );
        addTearDown(container.dispose);

        // Warm the cache as if the screen had been entered before.
        await container
            .read(recommendationProvider.notifier)
            .fetchRecommendations();
        // Leave the global index where a previous session left it — oldest.
        container.read(recommendationIndexProvider.notifier).set(0);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: RecommendationsScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(
          find.text(formatDateWeekday(recs[0].createdAt!)),
          findsAtLeast(1),
          reason:
              'Every screen entry must land on the newest recommendation. '
              'If this fails, the provider is flipping to loading during a '
              're-fetch and dismounting the PageView, breaking the anchor.',
        );
      },
    );

    testWidgets('each page renders RecommendationFeedbackView', (tester) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor([_rec('1')]),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('War diese Empfehlung hilfreich?'), findsOneWidget);
      expect(find.text('Hilfreich'), findsOneWidget);
      expect(find.text('Nicht hilfreich'), findsOneWidget);
    });

    testWidgets(
      'refresh with a new latest while reading an older page keeps the user put',
      (tester) async {
        // Exercises the anchor logic's no-yank branch (_maybeAnchor with
        // wasAtPreviousLatest == false): when a fresh recommendation
        // arrives via refresh, the reader shouldn't be teleported off
        // the entry they're currently on.
        final initial = [
          _rec('3', createdAt: DateTime(2026, 4, 22)),
          _rec('2', createdAt: DateTime(2026, 4, 21)),
          _rec('1', createdAt: DateTime(2026, 4, 20)),
        ];
        final afterRefresh = [
          _rec('4', createdAt: DateTime(2026, 4, 23)),
          _rec('3', createdAt: DateTime(2026, 4, 22)),
          _rec('2', createdAt: DateTime(2026, 4, 21)),
          _rec('1', createdAt: DateTime(2026, 4, 20)),
        ];

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

        // Move to the oldest (page 0, listIndex 2 → initial[2] = rec '1').
        container.read(recommendationIndexProvider.notifier).set(0);
        await tester.pumpAndSettle();
        // On oldest in initial list: pageIndex=0, listIndex=(3-1)-0=2 → initial[2].
        // Date appears in AppBar title and inline _SwipeLayout row (Task 5 removes it).
        expect(
          find.text(formatDateWeekday(initial[2].createdAt!)),
          findsAtLeast(1),
        );

        // Trigger a refresh that returns a new latest '4' prepended.
        await container
            .read(recommendationProvider.notifier)
            .fetchRecommendations();
        await tester.pumpAndSettle();

        // User stays on the same PAGE index (0) — which in the new 4-item
        // list is still the oldest ('1'). Title shows that same rec's date.
        // pageIndex=0, listIndex=(4-1)-0=3 → afterRefresh[3] = rec '1'.
        expect(
          find.text(formatDateWeekday(afterRefresh[3].createdAt!)),
          findsAtLeast(1),
          reason:
              'User was on the oldest when the refresh landed; the '
              'anchor logic must not jumpToPage and yank them away.',
        );
      },
    );

    testWidgets('AppBar leading renders "Dashboard" button that pops', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(
        () => repo.fetchByUserId(any()),
      ).thenAnswer((_) async => [testRecommendation(id: '1')]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      // Build a 2-route GoRouter so context.pop() has a real navigator stack
      // to pop back to. The sentinel home screen lets us assert that the pop
      // actually happened.
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home-sentinel')),
          ),
          GoRoute(
            path: '/recommendations',
            builder: (_, _) => const RecommendationsScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(repo),
            currentUserIdProvider.overrideWithValue('u'),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.theme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to the recommendations screen so there is something to pop.
      router.push('/recommendations');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Dashboard'), findsOneWidget);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      // After the pop the sentinel home screen is visible again.
      expect(find.text('home-sentinel'), findsOneWidget);
    });

    testWidgets(
      'hiding the currently-viewed recommendation clamps the header to a valid position',
      (tester) async {
        // Regression: after `setRecommendationState(hidden)` removed the
        // currently-viewed rec from the list, the AppBar briefly rendered
        // "Empfehlungen (3 von 2)" because the index notifier still pointed
        // at the old rightmost page. The fix clamps the display index
        // against the live list length.
        final repo = MockRecommendationRepository();
        when(
          () => repo.fetchByUserId(any()),
        ).thenAnswer((_) async => [_rec('3'), _rec('2'), _rec('1')]);
        when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
        when(
          () => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
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

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: RecommendationsScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Index provider confirms we're at 2 (the latest).
        expect(container.read(recommendationIndexProvider), 2);

        // Simulate the user tapping "Empfehlung ausblenden" in the sheet.
        // This is what the sheet's `_hide()` method calls.
        await container
            .read(recommendationProvider.notifier)
            .setRecommendationState(id: '3', state: RecommendationState.hidden);
        await tester.pumpAndSettle();

        // Index must have been clamped from 2 to the new max (1).
        // (The post-frame callback in _SwipeLayout writes back the clamped value.)
        expect(container.read(recommendationIndexProvider), 1);
      },
    );

    testWidgets('AppBar title shows the current recommendation\'s date', (
      tester,
    ) async {
      final rec = testRecommendation(
        id: '1',
        createdAt: DateTime(2026, 4, 22, 10, 30),
      );
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('u'),
        ],
      );
      await tester.pumpAndSettle();

      final appBar = find.byType(AppBar);
      expect(
        find.descendant(
          of: appBar,
          matching: find.text(formatDateWeekday(rec.createdAt!)),
        ),
        findsOneWidget,
      );
      // The old "Empfehlungen (X von Y)" counter text is gone.
      expect(find.textContaining('Empfehlungen ('), findsNothing);
    });

    testWidgets('chevron actions live in the AppBar, not the body', (
      tester,
    ) async {
      final recs = [
        _rec('1', createdAt: DateTime(2026, 4, 20)),
        _rec('2', createdAt: DateTime(2026, 4, 21)),
        _rec('3', createdAt: DateTime(2026, 4, 22)),
      ];
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => recs);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('u'),
        ],
      );
      await tester.pumpAndSettle();

      // Both prev/next buttons render inside the AppBar.
      final appBar = find.byType(AppBar);
      expect(
        find.descendant(
          of: appBar,
          matching: find.byKey(RecommendationsScreen.previousRecommendationKey),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: appBar,
          matching: find.byKey(RecommendationsScreen.nextRecommendationKey),
        ),
        findsOneWidget,
      );
      // The body no longer has an inline chevron row — the only chevron_right
      // icon in the tree is the AppBar action.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('AppBar title falls back to "Empfehlungen" on empty list', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('u'),
        ],
      );
      await tester.pumpAndSettle();

      final appBar = find.byType(AppBar);
      expect(
        find.descendant(of: appBar, matching: find.text('Empfehlungen')),
        findsOneWidget,
      );
    });
  });
}
