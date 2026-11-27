// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/alternative_choice.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/providers/alternative_choices_provider.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/daily_review_provider.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/daily_review_card.dart';
import 'package:belly_buddy/services/alternative_choice_service.dart';
import 'package:belly_buddy/services/daily_review/daily_review_copy.dart';
import 'package:belly_buddy/services/daily_review/daily_review_rules.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/utils/wall_clock.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/purchases_fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

final _day = DateTime(2026, 11, 27);

/// Zwiebel in 3 meals (one of them today's `m1`), with two replacements.
IngredientSuggestionGroup _zwiebel({int recent = 3}) =>
    IngredientSuggestionGroup(
      ingredientId: 'i-zwiebel',
      ingredientName: 'Zwiebel',
      mealCount: recent,
      isNew: false,
      suggestionIds: const ['s1'],
      meals: [
        for (var i = 0; i < recent; i++)
          MealDetail(
            id: i == 0 ? 'm1' : 'old-$i',
            title: 'Mahlzeit $i',
            trackedAt: wallClockFromWire(
              DateTime.utc(2026, 11, 27 - i, 12).toIso8601String(),
            ),
          ),
      ],
      replacements: const [
        ReplacementIngredient(id: 'r-lauch', name: 'Lauchgrün'),
        ReplacementIngredient(id: 'r-schnittlauch', name: 'Schnittlauch'),
      ],
    );

/// The choice service: answers [upsert] with the stored row, or fails.
class _Service implements AlternativeChoiceService {
  bool fail = false;
  final calls = <(String, String, AlternativeChoiceKind)>[];

  /// While set, [upsert] answers only once it completes.
  Completer<void>? gate;

  @override
  Future<List<Map<String, dynamic>>> fetch(String userId) async => const [];

  @override
  Future<Map<String, dynamic>> upsert({
    required String userId,
    required String ingredientId,
    required String replacementId,
    required AlternativeChoiceKind kind,
  }) async {
    calls.add((ingredientId, replacementId, kind));
    await gate?.future;
    if (fail) throw Exception('offline');
    return {
      'id': 'c-${calls.length}',
      'ingredient_id': ingredientId,
      'replacement_ingredient_id': replacementId,
      'choice': kind.db,
      'created_at': '2026-11-27T20:00:00Z',
      'ingredient': {'name': 'Zwiebel'},
      'replacement': {'name': 'Lauchgrün'},
    };
  }

  @override
  Future<void> delete(String id) async {}
}

/// Counts [fetchSuggestions]; holds no groups of its own.
class _Suggestions extends IngredientSuggestionNotifier {
  int fetches = 0;

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() =>
      const AsyncValue.data([]);

  @override
  Future<void> fetchSuggestions() async => fetches++;
}

/// Records the closed days.
class _Closed extends DailyReviewClosedNotifier {
  final closed = <DateTime>[];

  @override
  Future<DateTime?> build() async => null;

  @override
  Future<void> close(DateTime day) async => closed.add(day);
}

class _Harness {
  _Harness({
    this.yesterday = false,
    this.meals = 3,
    this.lastGut,
    List<IngredientSuggestionGroup>? groups,
    this.locked = false,
    this.upsellRoute,
    this.extras = const [],
    this.pending = false,
    this.plus,
  }) : groupsProvider =
           NotifierProvider<
             Switchable<List<IngredientSuggestionGroup>>,
             List<IngredientSuggestionGroup>
           >(() => Switchable(groups ?? [_zwiebel()]));

  final bool yesterday;
  final int meals;
  final GutFeelingRatingLevel? lastGut;
  final bool locked;
  final String? upsellRoute;
  final List<DailyReviewLine> extras;
  final bool pending;

  /// With a Plus answer, the real seams decide (Plus switch on, store
  /// available): [locked] and [upsellRoute] are not used.
  final Future<PlusStatus> Function()? plus;

  /// The suggestion groups the review picks from; switchable.
  final NotifierProvider<
    Switchable<List<IngredientSuggestionGroup>>,
    List<IngredientSuggestionGroup>
  >
  groupsProvider;

  final service = _Service();
  final suggestions = _Suggestions();
  final closed = _Closed();
  final visible = ValueNotifier(true);
  late final GoRouter router;

  /// The review the provider would build: the pick skips what was chosen.
  List<Override> get overrides => [
    currentUserIdProvider.overrideWithValue(testUserId),
    alternativeChoiceServiceProvider.overrideWithValue(service),
    ingredientSuggestionProvider.overrideWith(() => suggestions),
    dailyReviewClosedProvider.overrideWith(() => closed),
    if (plus case final answer?) ...[
      paywallEnabledProvider.overrideWithValue(true),
      purchasesGatewayProvider.overrideWithValue(FakePurchasesGateway()),
      plusProvider.overrideWith(() => FakePlusNotifier(answer)),
    ] else
      dailyReviewUpsellRouteProvider.overrideWithValue(upsellRoute),
    dailyReviewProvider.overrideWith((ref) {
      final day = ReviewDay(_day, yesterday: yesterday);
      return DailyReview(
        day: day,
        meals: meals,
        lastGut: lastGut,
        alternative: pending
            ? null
            : pickAlternative(
                groups: ref.watch(groupsProvider),
                dayMealIds: const {'m1'},
                chosen: ref.watch(chosenAlternativesProvider),
                day: _day,
              ),
        alternativeLocked: plus == null
            ? locked
            : ref.watch(dailyReviewAlternativeLockedProvider),
        alternativePending: pending,
        extras: extras,
      );
    }),
  ];

  Future<void> pump(WidgetTester tester) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, on, child) =>
                    TickerMode(enabled: on, child: child!),
                child: const DailyReviewCard(),
              ),
            ),
          ),
        ),
        ...stubRoutes([
          RoutePaths.ingredientSuggestions,
          RoutePaths.gutFeelingTracker,
          RoutePaths.plus,
          '/extra',
        ]),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: germanRouterApp(router)),
    );
    await tester.pump();
    await tester.pump();
  }

  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  void setGroups(WidgetTester tester, List<IngredientSuggestionGroup> groups) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyReviewCard)),
    );
    container.read(groupsProvider.notifier).set(groups);
  }
}

/// The vertical position of [text]'s top.
double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  group('DailyReviewCard', () {
    testWidgets('today with a pick: title, meals line, gut line, '
        'alternative, recent caption, both buttons', (tester) async {
      final h = _Harness(lastGut: GutFeelingRatingLevel.gut);
      await h.pump(tester);

      expect(find.byKey(DailyReviewCard.cardKey), findsOneWidget);
      const title = 'Dein Tagesrückblick 🌙';
      const meals = 'Heute hast du 3 Mahlzeiten eingetragen.';
      const gut = 'Dein Bauchgefühl zuletzt: Gut.';
      const alt = 'Statt Zwiebel könntest du morgen Lauchgrün probieren.';
      const recent =
          'Zwiebel war in 3 deiner Mahlzeiten der letzten zwei Wochen.';
      for (final t in [title, meals, gut, alt, recent]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(_top(tester, title), lessThan(_top(tester, meals)));
      expect(_top(tester, meals), lessThan(_top(tester, gut)));
      expect(_top(tester, gut), lessThan(_top(tester, alt)));
      expect(_top(tester, alt), lessThan(_top(tester, recent)));
      expect(find.byKey(DailyReviewCard.tryKey), findsOneWidget);
      expect(find.byKey(DailyReviewCard.skipKey), findsOneWidget);
      expect(find.text('Probiere ich'), findsOneWidget);
      expect(find.text('Passt nicht für mich'), findsOneWidget);
      expect(find.byKey(DailyReviewCard.gutAskKey), findsNothing);
      expect(find.byTooltip('Schließen'), findsOneWidget);
    });

    testWidgets('yesterday: its title and „heute"; one recent meal, no '
        'caption', (tester) async {
      final h = _Harness(
        yesterday: true,
        meals: 1,
        groups: [_zwiebel(recent: 1)],
      );
      await h.pump(tester);

      expect(find.text('Dein Rückblick auf gestern 🌙'), findsOneWidget);
      expect(
        find.text('Gestern hast du 1 Mahlzeit eingetragen.'),
        findsOneWidget,
      );
      expect(
        find.text('Statt Zwiebel könntest du heute Lauchgrün probieren.'),
        findsOneWidget,
      );
      expect(find.textContaining('der letzten zwei Wochen'), findsNothing);
    });

    testWidgets('Schlecht as last gut feeling: „Ich bin für dich da. 💛" '
        'follows the level line', (tester) async {
      final h = _Harness(lastGut: GutFeelingRatingLevel.schlecht);
      await h.pump(tester);

      const gut = 'Dein Bauchgefühl zuletzt: Schlecht.';
      const hard = 'Ich bin für dich da. 💛';
      expect(find.text(gut), findsOneWidget);
      expect(find.text(hard), findsOneWidget);
      expect(_top(tester, gut), lessThan(_top(tester, hard)));
    });

    testWidgets('no gut feeling today: „Bauchgefühl eintragen" opens the '
        'tracker; yesterday: no ask', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      expect(
        find.text('Magst du noch dein Bauchgefühl eintragen?'),
        findsOneWidget,
      );
      expect(find.text('Bauchgefühl eintragen'), findsOneWidget);
      await tester.tap(find.byKey(DailyReviewCard.gutAskKey));
      await tester.pumpAndSettle();
      expect(h.location, RoutePaths.gutFeelingTracker);
    });

    testWidgets('yesterday without a gut feeling: no ask', (tester) async {
      final h = _Harness(yesterday: true);
      await h.pump(tester);

      expect(find.byKey(DailyReviewCard.gutAskKey), findsNothing);
      expect(find.textContaining('Bauchgefühl'), findsNothing);
    });

    testWidgets('no pick: the neutral line, no buttons', (tester) async {
      final h = _Harness(groups: const []);
      await h.pump(tester);

      expect(
        find.text(
          'Für morgen hab ich keine Alternative für dich. Genieß deinen Abend!',
        ),
        findsOneWidget,
      );
      expect(find.byKey(DailyReviewCard.tryKey), findsNothing);
      expect(find.byKey(DailyReviewCard.skipKey), findsNothing);
    });

    testWidgets('no pick yesterday: its neutral line', (tester) async {
      final h = _Harness(yesterday: true, groups: const []);
      await h.pump(tester);

      expect(
        find.text('Für heute hab ich keine Alternative für dich.'),
        findsOneWidget,
      );
    });

    testWidgets('Probiere ich: choose(tryIt) once; then „Gemerkt! …" and '
        '„Ansehen" opens Alternativen', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(DailyReviewCard.tryKey));
      await tester.pump();
      await tester.pump();

      expect(h.service.calls, [
        ('i-zwiebel', 'r-lauch', AlternativeChoiceKind.tryIt),
      ]);
      expect(
        find.text('Gemerkt! Du findest es unter Entdecken › Alternativen.'),
        findsOneWidget,
      );
      // The provider moved on to the next pick; the card keeps its line.
      expect(find.textContaining('Schnittlauch'), findsNothing);
      expect(find.byKey(DailyReviewCard.tryKey), findsNothing);
      expect(find.byKey(DailyReviewCard.skipKey), findsNothing);

      await tester.tap(find.byKey(DailyReviewCard.savedOpenKey));
      await tester.pumpAndSettle();
      expect(h.location, RoutePaths.ingredientSuggestions);
    });

    testWidgets('Probiere ich fails: SnackBar „Das hat nicht geklappt. '
        'Versuch es später noch einmal.", buttons stay', (tester) async {
      final h = _Harness()..service.fail = true;
      await h.pump(tester);

      await tester.tap(find.byKey(DailyReviewCard.tryKey));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Das hat nicht geklappt. Versuch es später noch einmal.'),
        findsOneWidget,
      );
      expect(
        find.text('Statt Zwiebel könntest du morgen Lauchgrün probieren.'),
        findsOneWidget,
      );
      expect(find.byKey(DailyReviewCard.tryKey), findsOneWidget);
      expect(find.byKey(DailyReviewCard.skipKey), findsOneWidget);
      expect(find.byKey(DailyReviewCard.savedOpenKey), findsNothing);
    });

    testWidgets('Passt nicht für mich: choose(skip); the next pick from the '
        'provider shows', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(DailyReviewCard.skipKey));
      await tester.pump();
      await tester.pump();

      expect(h.service.calls, [
        ('i-zwiebel', 'r-lauch', AlternativeChoiceKind.skip),
      ]);
      expect(
        find.text('Statt Zwiebel könntest du morgen Schnittlauch probieren.'),
        findsOneWidget,
      );
      expect(find.byKey(DailyReviewCard.tryKey), findsOneWidget);

      // The last one skipped too: the neutral line.
      await tester.tap(find.byKey(DailyReviewCard.skipKey));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'Für morgen hab ich keine Alternative für dich. Genieß deinen Abend!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Passt nicht für mich fails: SnackBar, the line as before', (
      tester,
    ) async {
      final h = _Harness()..service.fail = true;
      await h.pump(tester);

      await tester.tap(find.byKey(DailyReviewCard.skipKey));
      await tester.pump();
      await tester.pump();

      expect(find.text(DailyReviewCopy.failed), findsOneWidget);
      expect(
        find.text('Statt Zwiebel könntest du morgen Lauchgrün probieren.'),
        findsOneWidget,
      );
    });

    testWidgets('locked: „Für morgen hätte ich eine Alternative für dich.", '
        'ingredient not shown; „Mehr erfahren" only with a route', (
      tester,
    ) async {
      final h = _Harness(locked: true);
      await h.pump(tester);

      expect(
        find.text('Für morgen hätte ich eine Alternative für dich.'),
        findsOneWidget,
      );
      expect(find.textContaining('Zwiebel'), findsNothing);
      expect(find.textContaining('Lauchgrün'), findsNothing);
      expect(find.byKey(DailyReviewCard.tryKey), findsNothing);
      expect(find.byKey(DailyReviewCard.skipKey), findsNothing);
      expect(find.byKey(DailyReviewCard.upsellKey), findsNothing);
    });

    testWidgets('locked with an upsell route: „Mehr erfahren" opens it', (
      tester,
    ) async {
      final h = _Harness(locked: true, upsellRoute: RoutePaths.plus);
      await h.pump(tester);

      expect(find.text('Mehr erfahren'), findsOneWidget);
      await tester.tap(find.byKey(DailyReviewCard.upsellKey));
      await tester.pumpAndSettle();
      expect(h.location, RoutePaths.plus);
    });

    testWidgets('locked, yesterday: „Für heute hätte ich eine Alternative für '
        'dich."', (tester) async {
      final h = _Harness(yesterday: true, locked: true);
      await h.pump(tester);

      expect(
        find.text('Für heute hätte ich eine Alternative für dich.'),
        findsOneWidget,
      );
      expect(find.textContaining('Für morgen'), findsNothing);
    });

    testWidgets('locked without a pick (no analysis without Plus): the Plus '
        'line, „Mehr erfahren" opens the upsell', (tester) async {
      final h = _Harness(
        groups: const [],
        locked: true,
        upsellRoute: RoutePaths.plus,
      );
      await h.pump(tester);

      expect(
        find.text(
          'Mit Belly Buddy Plus schaue ich jeden Abend nach einer '
          'Alternative für dich.',
        ),
        findsOneWidget,
      );
      expect(find.text(DailyReviewCopy.none(yesterday: false)), findsNothing);
      expect(find.byKey(DailyReviewCard.tryKey), findsNothing);
      await tester.tap(find.byKey(DailyReviewCard.upsellKey));
      await tester.pumpAndSettle();
      expect(h.location, RoutePaths.plus);
    });

    testWidgets('locked without a pick and no upsell route: the Plus line, no '
        'button', (tester) async {
      final h = _Harness(groups: const [], locked: true);
      await h.pump(tester);

      expect(find.text(DailyReviewCopy.lockedNoPick), findsOneWidget);
      expect(find.byKey(DailyReviewCard.upsellKey), findsNothing);
    });

    testWidgets('the alternative still loading: no alternative block at all', (
      tester,
    ) async {
      for (final locked in [false, true]) {
        final h = _Harness(pending: true, locked: locked);
        await h.pump(tester);

        expect(find.byKey(DailyReviewCard.cardKey), findsOneWidget);
        expect(find.textContaining('Alternative'), findsNothing);
        expect(find.textContaining('Statt'), findsNothing);
        expect(find.byKey(DailyReviewCard.tryKey), findsNothing);
        expect(find.byKey(DailyReviewCard.upsellKey), findsNothing);
      }
    });

    testWidgets('the neutral line switches to the alternative once groups '
        'arrive', (tester) async {
      final h = _Harness(groups: const []);
      await h.pump(tester);
      expect(find.text(DailyReviewCopy.none(yesterday: false)), findsOneWidget);

      h.setGroups(tester, [_zwiebel()]);
      await tester.pump();

      expect(find.text(DailyReviewCopy.none(yesterday: false)), findsNothing);
      expect(
        find.text('Statt Zwiebel könntest du morgen Lauchgrün probieren.'),
        findsOneWidget,
      );
      expect(find.byKey(DailyReviewCard.tryKey), findsOneWidget);
    });

    testWidgets('while a choice saves: both buttons off, a second tap stores '
        'nothing more', (tester) async {
      final h = _Harness()..service.gate = Completer<void>();
      await h.pump(tester);

      await tester.tap(find.byKey(DailyReviewCard.tryKey));
      await tester.pump();
      expect(h.service.calls, hasLength(1));
      expect(
        tester
            .widget<TextButton>(find.byKey(DailyReviewCard.skipKey))
            .onPressed,
        isNull,
      );
      // The line being saved stays while the provider moved on.
      expect(
        find.text('Statt Zwiebel könntest du morgen Lauchgrün probieren.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(DailyReviewCard.tryKey), warnIfMissed: false);
      await tester.tap(
        find.byKey(DailyReviewCard.skipKey),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(h.service.calls, hasLength(1));

      h.service.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text(DailyReviewCopy.saved), findsOneWidget);
      expect(h.service.calls, hasLength(1));
    });

    testWidgets('real seams: Plus switch on, status none → locked, no names, '
        '„Mehr erfahren" → /plus', (tester) async {
      final h = _Harness(plus: () async => PlusStatus.none);
      await h.pump(tester);
      await tester.pump();

      expect(
        find.text(DailyReviewCopy.locked(yesterday: false)),
        findsOneWidget,
      );
      expect(find.textContaining('Zwiebel'), findsNothing);
      expect(find.textContaining('Lauchgrün'), findsNothing);
      await tester.tap(find.byKey(DailyReviewCard.upsellKey));
      await tester.pumpAndSettle();
      expect(h.location, RoutePaths.plus);
    });

    testWidgets('real seams: Plus status still loading → open (names, buttons, '
        'no upsell)', (tester) async {
      final h = _Harness(plus: () => Completer<PlusStatus>().future);
      await h.pump(tester);
      await tester.pump();

      expect(
        find.text('Statt Zwiebel könntest du morgen Lauchgrün probieren.'),
        findsOneWidget,
      );
      expect(find.byKey(DailyReviewCard.tryKey), findsOneWidget);
      expect(find.byKey(DailyReviewCard.upsellKey), findsNothing);
    });

    testWidgets('× closes for that day', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(DailyReviewCard.closeKey));
      await tester.pump();

      expect(h.closed.closed, [_day]);
    });

    testWidgets('extras lines render between the day and the alternative', (
      tester,
    ) async {
      final h = _Harness(
        lastGut: GutFeelingRatingLevel.gut,
        extras: const [
          DailyReviewLine('Eine Zeile'),
          DailyReviewLine('Eine Zeile mit Ziel', route: '/extra'),
        ],
      );
      await h.pump(tester);

      const gut = 'Dein Bauchgefühl zuletzt: Gut.';
      const alt = 'Statt Zwiebel könntest du morgen Lauchgrün probieren.';
      expect(_top(tester, gut), lessThan(_top(tester, 'Eine Zeile')));
      expect(
        _top(tester, 'Eine Zeile'),
        lessThan(_top(tester, 'Eine Zeile mit Ziel')),
      );
      expect(_top(tester, 'Eine Zeile mit Ziel'), lessThan(_top(tester, alt)));

      await tester.tap(find.text('Eine Zeile mit Ziel'));
      await tester.pumpAndSettle();
      expect(h.location, '/extra');
    });

    testWidgets('the card asks fetchSuggestions once per Home visit', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      expect(h.suggestions.fetches, 1);

      // Rebuilds within the visit ask nothing more.
      await tester.tap(find.byKey(DailyReviewCard.skipKey));
      await tester.pump();
      await tester.pump();
      expect(h.suggestions.fetches, 1);

      // Home hidden (another tab), then back: a new visit.
      h.visible.value = false;
      await tester.pump();
      expect(h.suggestions.fetches, 1);
      h.visible.value = true;
      await tester.pump();
      await tester.pump();
      expect(h.suggestions.fetches, 2);
    });
  });
}
