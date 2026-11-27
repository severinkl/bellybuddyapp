import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/pattern_stats_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/providers/tolerance_test_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/patterns/patterns_screen.dart';
import 'package:belly_buddy/screens/patterns/tolerance_test_screen.dart';
import 'package:belly_buddy/screens/patterns/widgets/stats_section.dart';
import 'package:belly_buddy/screens/patterns/widgets/tolerance_test_card.dart';
import 'package:belly_buddy/services/insights/stats_copy.dart';
import 'package:belly_buddy/services/insights/test_copy.dart';

import '../../../helpers/app_host.dart';

class _FixedInsights extends InsightsNotifier {
  _FixedInsights(this.value);

  final Insights value;

  @override
  Future<Insights> build() async => value;
}

class _FakeStats extends PatternStatsNotifier {
  _FakeStats(this.value);

  final PatternStats value;

  @override
  Future<PatternStats?> build() async => value;

  @override
  Future<void> refresh() async {}
}

final _insights = Insights(
  progress: const InsightProgress(activeDays: 24, gutFeelingEntries: 25),
  calendar: [
    for (var i = 0; i < InsightRules.windowDays; i++)
      InsightDay(day: DateTime(2026, 10, 29 + i), dayClass: DayClass.good),
  ],
  goodDays: const DayColumn(days: 4),
  hardDays: const DayColumn(days: 0),
  noticed: const [],
  pick: const NothingYetPick(),
);

final _now = DateTime(2026, 11, 27, 12);

const _zwiebelSubject = TestSubject('ingredient', 'zwiebel', 'Zwiebel');

StatItem _item(String kind, String key, String name, {String? nestedIn}) =>
    StatItem(
      kind: kind,
      key: key,
      name: name,
      level: StatLevel.noticed,
      exposed: 10,
      exposedHard: 6,
      unexposed: 30,
      unexposedHard: 3,
      nestedIn: nestedIn,
    );

final _fructans = _item('group', 'fructans', 'Fruktane');
final _zwiebel = _item(
  'ingredient',
  'zwiebel',
  'Zwiebel',
  nestedIn: 'fructans',
);
final _kaffee = _item('ingredient', 'kaffee', 'Kaffee');

ToleranceTestView _test({
  String status = 'active',
  TestPhase phase = TestPhase.leaveOut,
  int dayIndex = 2,
  TestResult? result,
}) => ToleranceTestView(
  id: 't1',
  subject: _zwiebelSubject,
  origin: 'proposed',
  status: status,
  phase: phase,
  startsOn: DateTime(2026, 11, 26),
  leaveOutDays: 5,
  reintroDays: 3,
  dayIndex: dayIndex,
  days: const [],
  result: result,
);

PatternStats _stats({
  ToleranceTestView? test,
  List<TestedItem> tested = const [],
  TestSubject? proposal,
  bool restrictive = false,
}) => PatternStats(
  windowDays: 90,
  ratedDays: 41,
  hardDays: 9,
  ready: true,
  groups: [_fructans],
  ingredients: [_zwiebel, _kaffee],
  test: test,
  tested: tested,
  proposal: proposal,
  restrictive: restrictive,
);

/// The extra the test page was opened with, or 'none'.
Object? _openedWith;

Future<void> _pump(
  WidgetTester tester,
  PatternStats stats, {
  bool plusLocked = false,
}) async {
  _openedWith = 'unopened';
  tester.view
    ..physicalSize = const Size(402, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PatternsScreen()),
      GoRoute(
        path: RoutePaths.toleranceTest,
        builder: (_, s) {
          _openedWith = s.extra ?? 'none';
          return const Scaffold(body: Text('page:test'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        insightsProvider.overrideWith(() => _FixedInsights(_insights)),
        patternStatsProvider.overrideWith(() => _FakeStats(stats)),
        buddyClockProvider.overrideWithValue(() => _now),
        plusAccessProvider.overrideWithValue(
          plusLocked ? PlusAccess.locked : PlusAccess.open,
        ),
      ],
      child: germanRouterApp(router),
    ),
  );
  await tester.pumpAndSettle();
}

final _card = find.byKey(ToleranceTestCard.tapKey);
final _testen = find.text(TestCopy.testAction);
Finder _rowTest(StatItem i) =>
    find.byKey(StatsSectionWithTests.testKey(i.kind, i.key));

void main() {
  group('card', () {
    testWidgets('running test: title, day and phase, opens the page', (
      tester,
    ) async {
      await _pump(tester, _stats(test: _test()));
      expect(
        find.descendant(
          of: _card,
          matching: find.text('Verträglichkeits-Test: Zwiebel'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tag 2 von 8'), findsOneWidget);
      expect(find.text('Phase 1: ohne Zwiebel'), findsOneWidget);
      // Above „Genauer hingeschaut".
      expect(
        tester.getTopLeft(_card).dy,
        lessThan(
          tester.getTopLeft(find.text(StatsCopy.title.toUpperCase())).dy,
        ),
      );
      await tester.tap(_card);
      await tester.pumpAndSettle();
      expect(_openedWith, 'none');
    });

    testWidgets('a test that starts tomorrow says when', (tester) async {
      await _pump(tester, _stats(test: _test(dayIndex: 0)));
      expect(find.text('Los geht\'s am 26. Nov.'), findsOneWidget);
    });

    testWidgets('a result: headline, conclusion and both notes', (
      tester,
    ) async {
      const result = TestResult(
        goodWithout: 4,
        countedWithout: 5,
        goodWith: 1,
        countedWith: 3,
        outcome: TestOutcome.worse,
      );
      await _pump(
        tester,
        _stats(
          test: _test(
            status: 'completed',
            phase: TestPhase.done,
            result: result,
          ),
        ),
      );
      expect(
        find.text(TestCopy.resultHeadline(_zwiebelSubject, result)),
        findsOneWidget,
      );
      expect(
        find.text(TestCopy.conclusion(TestOutcome.worse, _zwiebelSubject)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _card, matching: find.text(TestCopy.notMedical)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _card, matching: find.text(TestCopy.doctor)),
        findsOneWidget,
      );
      await tester.tap(_card);
      await tester.pumpAndSettle();
      expect(_openedWith, 'none');
    });

    testWidgets('a proposal opens its intro', (tester) async {
      await _pump(tester, _stats(proposal: _zwiebelSubject));
      expect(find.text('Magst du Zwiebel testen?'), findsOneWidget);
      await tester.tap(_card);
      await tester.pumpAndSettle();
      expect(_openedWith, _zwiebelSubject);
    });

    testWidgets('nothing to show: no card', (tester) async {
      await _pump(tester, _stats());
      expect(_card, findsNothing);
    });
  });

  group('rows', () {
    testWidgets('a free row offers „Testen" and opens its intro; the closing '
        'line opens the picker', (tester) async {
      await _pump(tester, _stats());
      expect(
        find.descendant(
          of: find.byKey(StatsSection.rowKey('ingredient', 'kaffee')),
          matching: _testen,
        ),
        findsOneWidget,
      );
      // Groups, nested ingredients and loose ones, plus the closing line.
      expect(_testen, findsNWidgets(4));
      expect(
        tester.getSize(_rowTest(_kaffee)).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(_rowTest(_kaffee));
      await tester.pumpAndSettle();
      expect(_openedWith, const TestSubject('ingredient', 'kaffee', 'Kaffee'));
    });

    testWidgets('the closing line\'s „Testen" asks for a pick', (tester) async {
      await _pump(tester, _stats());
      await tester.tap(find.byKey(StatsSectionWithTests.closingTestKey));
      await tester.pumpAndSettle();
      expect(_openedWith, isA<ToleranceTestPick>());
    });

    testWidgets('restrictive: no „Testen" on rows, no card', (tester) async {
      await _pump(tester, _stats(restrictive: true));
      expect(_testen, findsNothing);
      expect(_card, findsNothing);
      expect(find.text(StatsCopy.closing), findsOneWidget);
    });

    testWidgets('a tested row shows „getestet: deutlich schlechter" instead '
        'of „Testen"', (tester) async {
      await _pump(
        tester,
        _stats(
          tested: [
            TestedItem(
              subject: _zwiebelSubject,
              outcome: TestOutcome.worse,
              endedOn: DateTime(2026, 11, 10),
            ),
          ],
        ),
      );
      final row = find.byKey(StatsSection.rowKey('ingredient', 'zwiebel'));
      expect(
        find.descendant(
          of: row,
          matching: find.text('getestet: deutlich schlechter'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: _testen), findsNothing);
      expect(_rowTest(_kaffee), findsOneWidget);
    });

    testWidgets('a test of more than 60 days ago gives „Testen" back', (
      tester,
    ) async {
      await _pump(
        tester,
        _stats(
          tested: [
            TestedItem(
              subject: _zwiebelSubject,
              outcome: TestOutcome.worse,
              endedOn: DateTime(2026, 9, 1),
            ),
          ],
        ),
      );
      expect(find.text('getestet: deutlich schlechter'), findsNothing);
      expect(_rowTest(_zwiebel), findsOneWidget);
    });

    testWidgets('while a test runs no row offers „Testen"', (tester) async {
      await _pump(tester, _stats(test: _test(phase: TestPhase.reintro)));
      expect(_testen, findsNothing);
    });

    testWidgets('an active test past its end still blocks „Testen"', (
      tester,
    ) async {
      await _pump(
        tester,
        _stats(test: _test(phase: TestPhase.done, dayIndex: 9)),
      );
      expect(_testen, findsNothing);
    });
  });

  group('canOfferTest', () {
    final free = _stats();
    test('only with loaded stats, Plus open, no active test, not '
        'restrictive', () {
      expect(canOfferTest(AsyncData(free), plusLocked: false), isTrue);
      expect(canOfferTest(AsyncData(free), plusLocked: true), isFalse);
      expect(
        canOfferTest(
          // What a rebuild (a user change) shows: loading over the old value.
          // ignore: invalid_use_of_internal_member
          const AsyncLoading<PatternStats?>().copyWithPrevious(AsyncData(free)),
          plusLocked: false,
        ),
        isFalse,
      );
      expect(
        canOfferTest(
          AsyncError<PatternStats?>(Exception('x'), StackTrace.empty),
          plusLocked: false,
        ),
        isFalse,
      );
      expect(canOfferTest(const AsyncData(null), plusLocked: false), isFalse);
      expect(
        canOfferTest(AsyncData(_stats(restrictive: true)), plusLocked: false),
        isFalse,
      );
      expect(
        canOfferTest(AsyncData(_stats(test: _test())), plusLocked: false),
        isFalse,
      );
      expect(
        canOfferTest(
          AsyncData(
            _stats(
              test: _test(status: 'completed', phase: TestPhase.done),
            ),
          ),
          plusLocked: false,
        ),
        isTrue,
      );
    });
  });
}
