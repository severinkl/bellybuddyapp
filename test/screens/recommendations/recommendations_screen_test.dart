// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recipe_collection_provider.dart';
import 'package:belly_buddy/providers/recommendation_index_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_card.dart';
import 'package:belly_buddy/screens/recommendations/widgets/tip_recipe_link.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';
import 'package:belly_buddy/widgets/common/bb_card.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/layout_checks.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overridesFor(List<Recommendation> recommendations) {
  final mock = MockRecommendationRepository();
  when(
    () => mock.fetchByUserId(any()),
  ).thenAnswer((_) async => recommendations);
  when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});
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
      when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});

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
      when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(mock),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fehler beim Laden der Tipps.'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });

    testWidgets('a failed reload (offline resume) keeps the open set: title '
        'and page', (tester) async {
      final recs = [
        _rec('2', createdAt: DateTime(2026, 4, 22)),
        _rec('1', createdAt: DateTime(2026, 4, 20)),
      ];
      final mock = MockRecommendationRepository();
      when(() => mock.fetchByUserId(any())).thenAnswer((_) async => recs);
      when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(mock),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(formatDateWeekdayShort(recs[0].createdAt!)),
      );
      expect(title, findsOneWidget);

      // The resume refresh reloads them, offline.
      when(
        () => mock.fetchByUserId(any()),
      ).thenAnswer((_) async => throw Exception('offline'));
      await ProviderScope.containerOf(
        tester.element(find.byType(RecommendationsScreen)),
      ).read(recommendationProvider.notifier).fetchRecommendations();
      await tester.pumpAndSettle();

      expect(find.text('Fehler beim Laden der Tipps.'), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(title, findsOneWidget);
      final prevBtn = tester.widget<IconButton>(
        find.byKey(RecommendationsScreen.previousRecommendationKey),
      );
      expect(prevBtn.onPressed, isNotNull);
    });

    testWidgets('opening marks the shown set seen; a failed mark leaves it '
        'new, quietly', (tester) async {
      final repo = FakeRecommendationRepository(sets: [_rec('1')])
        ..markError = Exception('offline');
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pumpAndSettle();

      expect(repo.marked, [
        ['1'],
      ]);
      expect(tester.takeException(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RecommendationsScreen)),
      );
      expect(container.read(unseenTipSetProvider)?.id, '1');
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('a set that arrives while the Tipps are open is marked '
        'seen', (tester) async {
      final repo = FakeRecommendationRepository(sets: [_rec('1')]);
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RecommendationsScreen)),
      );
      expect(repo.marked, [
        ['1'],
      ]);

      // A push brings this week's set while they are open.
      repo.sets = [_rec('2'), ...repo.sets];
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();
      await tester.pumpAndSettle();

      expect(repo.marked, [
        ['1'],
        ['2'],
      ]);
      expect(container.read(unseenTipSetProvider), isNull);
    });

    testWidgets('a mark that fails is not retried while they stay open', (
      tester,
    ) async {
      final repo = FakeRecommendationRepository(sets: [_rec('1')])
        ..markError = Exception('offline');
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RecommendationsScreen)),
      );
      await container
          .read(recommendationProvider.notifier)
          .fetchRecommendations();
      await tester.pumpAndSettle();

      expect(repo.marked, [
        ['1'],
      ]);
    });

    testWidgets('empty state shows mascot + "Noch keine Tipps"', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor(const []),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Noch keine Tipps'), findsOneWidget);
      expect(
        find.byKey(RecommendationsScreen.emptyStateRefreshKey),
        findsOneWidget,
      );
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets(
      'single-recommendation list renders one page with both chevrons disabled',
      (tester) async {
        // Single rec with no createdAt → title falls back to 'Tipps'.
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
        // No createdAt → AppBar falls back to 'Tipps'.
        expect(
          find.descendant(of: appBar, matching: find.text('Tipps')),
          findsOneWidget,
        );
        expect(find.textContaining('Tipps ('), findsNothing);
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
      expect(
        find.text(formatDateWeekdayShort(recs[0].createdAt!)),
        findsAtLeast(1),
      );
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
        // Date appears in AppBar title only.
        expect(
          find.text(formatDateWeekdayShort(recs[1].createdAt!)),
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
        // Date appears in AppBar title only.
        expect(
          find.text(formatDateWeekdayShort(recs[1].createdAt!)),
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
      when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});

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
      // Date appears in AppBar title only.
      expect(
        find.text(formatDateWeekdayShort(recs[0].createdAt!)),
        findsAtLeast(1),
      );
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
        // Date appears in AppBar title only.
        expect(
          find.text(formatDateWeekdayShort(recs[0].createdAt!)),
          findsAtLeast(1),
        );

        // Swipe rightward (positive X) — goes to older (pageIndex - 1).
        await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
        await tester.pumpAndSettle();

        expect(
          find.text(formatDateWeekdayShort(recs[1].createdAt!)),
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
        when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});

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
          find.text(formatDateWeekdayShort(recs[0].createdAt!)),
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

      expect(find.text('War dieser Tipp hilfreich?'), findsOneWidget);
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
        when(() => mock.markSeen(any(), any())).thenAnswer((_) async {});

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
        // Date appears in AppBar title only.
        expect(
          find.text(formatDateWeekdayShort(initial[2].createdAt!)),
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
          find.text(formatDateWeekdayShort(afterRefresh[3].createdAt!)),
          findsAtLeast(1),
          reason:
              'User was on the oldest when the refresh landed; the '
              'anchor logic must not jumpToPage and yank them away.',
        );
      },
    );

    testWidgets('AppBar leading is a tonal back-icon button that pops', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(
        () => repo.fetchByUserId(any()),
      ).thenAnswer((_) async => [testRecommendation(id: '1')]);
      when(() => repo.markSeen(any(), any())).thenAnswer((_) async {});

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

      // The leading widget is a back-icon IconButton (no text).
      final appBar = find.byType(AppBar);
      final backIcon = find.descendant(
        of: appBar,
        matching: find.byIcon(Icons.arrow_back_ios_new),
      );
      expect(backIcon, findsOneWidget);
      // The old "Dashboard" label is gone.
      expect(find.text('Dashboard'), findsNothing);

      await tester.tap(backIcon);
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
        when(() => repo.markSeen(any(), any())).thenAnswer((_) async {});
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

        // Simulate the user tapping "Tipp ausblenden" in the sheet.
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
      when(() => repo.markSeen(any(), any())).thenAnswer((_) async {});

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
          matching: find.text(formatDateWeekdayShort(rec.createdAt!)),
        ),
        findsOneWidget,
      );
      // The old "(X von Y)" counter text is gone.
      expect(find.textContaining('Tipps ('), findsNothing);
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
      when(() => repo.markSeen(any(), any())).thenAnswer((_) async {});

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
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AppBar title falls back to "Tipps" on empty list', (
      tester,
    ) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markSeen(any(), any())).thenAnswer((_) async {});

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
        find.descendant(of: appBar, matching: find.text('Tipps')),
        findsOneWidget,
      );
    });

    testWidgets('no pause dialog', (tester) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor([_rec('1')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Danke, dass du dabei bist! 💛'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets("the page's list is headed „Tipps\"", (tester) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overridesFor([
          _rec('1', createdAt: DateTime.utc(2026, 11, 16, 10)),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Tipps'),
        ),
        findsOneWidget,
      );
      expect(find.text('Empfehlungen'), findsNothing);
    });
  });

  group('a letter, a focus and a recipe link (core #12)', () {
    const letter =
        'Mir ist aufgefallen, dass an deinen schweren Tagen oft Zwiebel '
        'dabei war. Lass uns diese Woche etwas Neues ausprobieren.';
    // „Dein Wochenbrief", drawn in capitals (StepFieldLabel.style).
    const letterLabel = 'DEIN WOCHENBRIEF';
    final anyLetterLabel = find.textContaining(
      RegExp('wochenbrief', caseSensitive: false),
    );
    const link = 'Passendes Rezept: Hirse-Bowl';

    late FakeRecipeRepository collection;
    late GoRouter router;

    setUp(() {
      collection = FakeRecipeRepository()
        ..collection = [testRecipe(id: 'r-1', title: 'Hirse-Bowl')];
    });

    Future<void> pumpTips(
      WidgetTester tester,
      Recommendation set, {
      double textScale = 1,
    }) async {
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const RecommendationsScreen()),
          ...stubRoutes([RoutePaths.collectionRecipe]),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(
              FakeRecommendationRepository(sets: [set]),
            ),
            recipeRepositoryProvider.overrideWithValue(collection),
            currentUserIdProvider.overrideWithValue(testUserId),
          ],
          child: germanRouterApp(router, textScale: textScale),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The cards' ingredients, top to bottom.
    List<String> ingredients(WidgetTester tester) => [
      for (final card in tester.widgetList<RecommendationCard>(
        find.byType(RecommendationCard),
      ))
        card.item.ingredient,
    ];

    /// The outer card of each tip, top to bottom.
    List<BbCard> tipCards(WidgetTester tester) => [
      for (final card in find.byType(RecommendationCard).evaluate())
        tester.widget<BbCard>(
          find
              .descendant(
                of: find.byWidget(card.widget),
                matching: find.byType(BbCard),
              )
              .first,
        ),
    ];

    /// Core's new shape, the focus item stored second.
    Recommendation letterSet({String? recipeTitle = 'Hirse-Bowl'}) =>
        testRecommendation(
          id: 'new',
          summary: letter,
          recommendations: [
            testRecommendationItem(
              type: 'try',
              ingredient: 'Haferflocken',
              alternative: null,
            ),
            testRecommendationItem(
              focus: true,
              recipeId: 'r-1',
              recipeTitle: recipeTitle,
            ),
          ],
        );

    testWidgets('a new set: the letter, then the focus item first', (
      tester,
    ) async {
      await pumpTips(tester, letterSet());

      expect(find.text(letterLabel), findsOneWidget);
      expect(find.text(letter), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(letterLabel)).dy,
        lessThan(tester.getTopLeft(find.text(letter)).dy),
      );
      expect(
        tester.widget<Text>(find.text(letter)).style?.fontWeight,
        FontWeight.w400,
      );

      expect(ingredients(tester), ['Zwiebel', 'Haferflocken']);
      expect(
        find.descendant(
          of: find.byType(RecommendationCard).first,
          matching: find.text('Fokus der Woche'),
        ),
        findsOneWidget,
      );
      expect(find.text('Fokus der Woche'), findsOneWidget);
      expect(find.byKey(RecommendationCard.focusLabelKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Fokus der Woche')).dy,
        lessThan(tester.getTopLeft(find.text('Zwiebel')).dy),
      );
      final [focus, other] = tipCards(tester);
      expect(focus.showBorder, isTrue);
      expect(focus.borderColor, AppTheme.primary);
      expect(focus.borderWidth, AppConstants.borderWidthLg);
      expect(other.showBorder, isFalse);
    });

    testWidgets('an old set renders as today', (tester) async {
      final old = Recommendation.fromJson({
        'id': 'old',
        'summary': 'Weniger Zwiebel, mehr Haferflocken.',
        'recommendations': [
          {'type': 'try', 'ingredient': 'Haferflocken', 'reason': 'r'},
          {
            'type': 'substitute',
            'ingredient': 'Zwiebel',
            'reason': 'r',
            'alternative': 'Schnittlauch',
          },
        ],
      });
      await pumpTips(tester, old);

      expect(anyLetterLabel, findsNothing);
      expect(find.text('Fokus der Woche'), findsNothing);
      expect(find.byKey(RecommendationCard.focusLabelKey), findsNothing);
      expect(find.byType(TipRecipeLink), findsNothing);
      expect(find.textContaining('Passendes Rezept'), findsNothing);
      expect(ingredients(tester), ['Haferflocken', 'Zwiebel']);
      expect(tipCards(tester).map((c) => c.showBorder), [false, false]);
      expect(
        tester
            .widget<Text>(find.text('Weniger Zwiebel, mehr Haferflocken.'))
            .style
            ?.fontWeight,
        FontWeight.w600,
      );
      // Nothing to link: the collection isn't even loaded.
      expect(collection.collectionFetches, 0);
    });

    testWidgets('the recipe link opens the recipe', (tester) async {
      await pumpTips(tester, letterSet());

      final zwiebel = find.byType(RecommendationCard).first;
      expect(
        find.descendant(of: zwiebel, matching: find.text(link)),
        findsOneWidget,
      );
      // Under the reason and the alternative.
      expect(
        tester.getTopLeft(find.text(link)).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.descendant(
                  of: zwiebel,
                  matching: find.text('→ Alternative: Schnittlauch'),
                ),
              )
              .dy,
        ),
      );

      await tester.tap(find.text(link));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/collection/r-1',
      );
      expect(find.text('page:${RoutePaths.collectionRecipe}'), findsOneWidget);
      // Pushed over the Tipps.
      expect(router.canPop(), isTrue);
    });

    testWidgets('a recipe no longer in the collection: no link', (
      tester,
    ) async {
      collection.collection = [testRecipe(id: 'r-2', title: 'Hirse-Bowl')];
      await pumpTips(tester, letterSet());

      expect(find.text('Fokus der Woche'), findsOneWidget);
      expect(find.byKey(TipRecipeLink.keyFor('r-1')), findsNothing);
      expect(find.textContaining('Passendes Rezept'), findsNothing);
    });

    testWidgets('the collection loading or failed: no link', (tester) async {
      final gate = Completer<void>();
      collection = _GatedRecipeRepository(gate.future)
        ..collection = [testRecipe(id: 'r-1', title: 'Hirse-Bowl')]
        ..collectionError = Exception('offline');
      await pumpTips(tester, letterSet());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RecommendationsScreen)),
      );

      expect(container.read(recipeCollectionProvider).isLoading, isTrue);
      expect(find.text('Fokus der Woche'), findsOneWidget);
      expect(find.byKey(TipRecipeLink.keyFor('r-1')), findsNothing);
      expect(find.textContaining('Passendes Rezept'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(container.read(recipeCollectionProvider).hasError, isTrue);
      expect(find.byKey(TipRecipeLink.keyFor('r-1')), findsNothing);
      expect(find.textContaining('Passendes Rezept'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("recipe_title missing: the collection's title", (tester) async {
      await pumpTips(tester, letterSet(recipeTitle: null));

      expect(find.text(link), findsOneWidget);
    });

    testWidgets('fits 375×667 at 1.3', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      collection.collection = [
        testRecipe(
          id: 'r-1',
          title: 'Hirse-Bowl mit Ofengemüse und Tahini-Dressing',
        ),
      ];
      const reason =
          'An deinen schweren Tagen war oft Zwiebel dabei, an deinen guten '
          'Tagen seltener.';
      final set = testRecommendation(
        summary: letter,
        recommendations: [
          testRecommendationItem(
            reason: reason,
            alternative: 'Frühlingszwiebelgrün',
            focus: true,
            recipeId: 'r-1',
            recipeTitle: 'Hirse-Bowl mit Ofengemüse und Tahini-Dressing',
          ),
          testRecommendationItem(
            type: 'try',
            ingredient: 'Haferflocken',
            reason: reason,
            alternative: null,
          ),
          testRecommendationItem(
            ingredient: 'Knoblauch',
            reason: reason,
            alternative: 'Knoblauchöl',
          ),
        ],
      );

      final errors = await collectFlutterErrors(() async {
        await pumpTips(tester, set, textScale: 1.3);
        expect(find.byKey(TipRecipeLink.keyFor('r-1')), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
      });

      expect(find.text('Knoblauch'), findsOneWidget);
      expect(verticalOverflows(errors), isEmpty);
    });
  });
}

/// A collection whose fetch waits for [_gate].
class _GatedRecipeRepository extends FakeRecipeRepository {
  _GatedRecipeRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<Recipe>> fetchCollection() async {
    await _gate;
    return super.fetchCollection();
  }
}
