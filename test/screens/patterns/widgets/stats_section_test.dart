import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/pattern_stats_provider.dart';
import 'package:belly_buddy/screens/patterns/patterns_screen.dart';
import 'package:belly_buddy/screens/patterns/widgets/stats_section.dart';
import 'package:belly_buddy/services/insights/insight_copy.dart';
import 'package:belly_buddy/services/insights/stats_copy.dart';
import 'package:belly_buddy/services/pattern_stats_service.dart';

import '../../../helpers/app_host.dart';

class _FixedInsights extends InsightsNotifier {
  _FixedInsights(this.value);

  final Insights value;

  @override
  Future<Insights> build() async => value;
}

/// Answers [answer] (a [PatternStats], or an error to throw) and counts
/// refreshes.
class _FakeStats extends PatternStatsNotifier {
  _FakeStats(this.answer);

  final Object answer;
  int refreshes = 0;

  @override
  Future<PatternStats?> build() async {
    final a = answer;
    if (a is PatternStats) return a;
    throw a;
  }

  @override
  Future<void> refresh() async => refreshes++;
}

final _insights = Insights(
  progress: const InsightProgress(activeDays: 24, gutFeelingEntries: 25),
  calendar: [
    for (var i = 0; i < InsightRules.windowDays; i++)
      InsightDay(
        day: DateTime(2026, 10, 25 + i),
        dayClass: i.isEven ? DayClass.hard : DayClass.good,
      ),
  ],
  goodDays: const DayColumn(days: 4),
  hardDays: const DayColumn(days: 4),
  noticed: const [],
  pick: const NothingYetPick(),
);

StatItem _item(
  String kind,
  String key,
  String name, {
  StatLevel level = StatLevel.noticed,
  int e = 10,
  int he = 6,
  int u = 31,
  int hu = 3,
  List<String> groups = const [],
  String? nestedIn,
}) => StatItem(
  kind: kind,
  key: key,
  name: name,
  level: level,
  exposed: e,
  exposedHard: he,
  unexposed: u,
  unexposedHard: hu,
  groups: groups,
  nestedIn: nestedIn,
);

final _fructans = _item('group', 'fructans', 'Fruktane', e: 12, he: 8);
final _lactose = _item(
  'group',
  'lactose',
  'Laktose',
  level: StatLevel.unsure,
  e: 6,
  he: 2,
);

/// Zwiebel carries fructans and gos, nested under fructans only.
final _zwiebel = _item(
  'ingredient',
  'zwiebel',
  'Zwiebel',
  level: StatLevel.strong,
  he: 7,
  hu: 2,
  groups: const ['fructans', 'gos'],
  nestedIn: 'fructans',
);
final _milch = _item(
  'ingredient',
  'milch',
  'Milch',
  groups: const ['lactose'],
  nestedIn: 'lactose',
);
final _kaffee = _item('ingredient', 'kaffee', 'Kaffee');
final _reis = _item(
  'ingredient',
  'reis',
  'Reis',
  level: StatLevel.calm,
  e: 18,
  he: 2,
);

PatternStats _ready({
  List<StatItem>? groups,
  List<StatItem>? ingredients,
  List<StatItem>? calm,
}) => PatternStats(
  windowDays: 90,
  ratedDays: 41,
  hardDays: 9,
  ready: true,
  groups: groups ?? [_fructans, _lactose],
  ingredients: ingredients ?? [_zwiebel, _kaffee, _milch],
  calm: calm ?? [_reis],
);

Future<_FakeStats> _pump(WidgetTester tester, Object stats) async {
  tester.view
    ..physicalSize = const Size(390, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeStats(stats);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const PatternsScreen())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        insightsProvider.overrideWith(() => _FixedInsights(_insights)),
        patternStatsProvider.overrideWith(() => fake),
      ],
      child: germanRouterApp(router),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

final _title = find.text(StatsCopy.title.toUpperCase());

extension on WidgetTester {
  double top(Finder f) => getTopLeft(f).dy;
  double left(Finder f) => getTopLeft(f).dx;
}

Finder _row(StatItem i) => find.byKey(StatsSection.rowKey(i.kind, i.key));

void main() {
  testWidgets('groups first, members indented under their group, loose '
      'ingredients after, calm last', (tester) async {
    await _pump(tester, _ready());

    expect(_title, findsOneWidget);
    expect(find.text(StatsCopy.subtitle), findsOneWidget);
    final order = [
      find.text(StatsCopy.groupsHeading),
      _row(_fructans),
      _row(_zwiebel),
      _row(_lactose),
      _row(_milch),
      find.text(StatsCopy.looseHeading),
      _row(_kaffee),
      find.text(StatsCopy.calmHeading),
      _row(_reis),
    ];
    for (final f in order) {
      expect(f, findsOneWidget);
    }
    for (var i = 1; i < order.length; i++) {
      expect(tester.top(order[i]), greaterThan(tester.top(order[i - 1])));
    }
    expect(
      tester.left(find.text(_zwiebel.name)),
      greaterThan(tester.left(find.text(_fructans.name))),
    );
    expect(
      tester.left(find.text(_milch.name)),
      greaterThan(tester.left(find.text(_lactose.name))),
    );
    expect(
      tester.left(find.text(_kaffee.name)),
      tester.left(find.text(_fructans.name)),
    );

    expect(
      find.text(
        'nach 7 von 10 Tagen mit Zwiebel ein schwerer Tag · ohne: 2 von 31',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Reis · an 18 Tagen gegessen, nicht öfter schwere Tage'),
      findsOneWidget,
    );
    expect(find.text('deutlich auffällig'), findsOneWidget);
    expect(find.text('auffällig'), findsNWidgets(3));
    expect(find.text('noch unsicher'), findsOneWidget);
    // Each row is read as one: name, badge, counts.
    final zwiebel = tester
        .getSemantics(
          find.descendant(
            of: _row(_zwiebel),
            matching: find.byType(MergeSemantics),
          ),
        )
        .label;
    expect(zwiebel, contains('Zwiebel'));
    expect(zwiebel, contains('deutlich auffällig'));
    expect(zwiebel, contains('nach 7 von 10 Tagen'));
    expect(find.text(StatsCopy.closing), findsOneWidget);
    expect(find.text(StatsCopy.nothingShown), findsNothing);
  });

  testWidgets('the section sits after „Fällt mir auf"', (tester) async {
    await _pump(tester, _ready());
    expect(
      tester.top(_title),
      greaterThan(
        tester.top(find.text(InsightCopy.noticedTitle.toUpperCase())),
      ),
    );
  });

  testWidgets('an ingredient appears once even with two groups', (
    tester,
  ) async {
    final gos = _item('group', 'gos', 'GOS', level: StatLevel.unsure);
    await _pump(tester, _ready(groups: [_fructans, gos]));

    expect(find.text('Zwiebel'), findsOneWidget);
    expect(_row(_zwiebel), findsOneWidget);
    expect(tester.top(_row(_zwiebel)), lessThan(tester.top(_row(gos))));
  });

  testWidgets('nothing shown says so', (tester) async {
    await _pump(tester, _ready(groups: [], ingredients: [], calm: []));
    expect(find.text(StatsCopy.nothingShown), findsOneWidget);
    expect(find.text(StatsCopy.groupsHeading), findsNothing);
    expect(find.text(StatsCopy.looseHeading), findsNothing);
    expect(find.text(StatsCopy.calmHeading), findsNothing);
  });

  testWidgets('not ready shows the 14-day line with the count', (tester) async {
    await _pump(
      tester,
      const PatternStats(
        windowDays: 90,
        ratedDays: 9,
        hardDays: 2,
        ready: false,
      ),
    );
    expect(_title, findsOneWidget);
    expect(
      find.text(
        'Für diesen Vergleich brauche ich 14 Tage mit Bauchgefühl – bisher 9.',
      ),
      findsOneWidget,
    );
    expect(find.text(StatsCopy.groupsHeading), findsNothing);
    expect(find.text(StatsCopy.limitsTitle), findsNothing);
  });

  testWidgets('route failure leaves the 30-day sections intact', (
    tester,
  ) async {
    await _pump(tester, Exception('offline'));

    expect(find.bySemanticsLabel(RegExp(r'^25\. Okt: ')), findsOneWidget);
    expect(find.text('4 gute Tage'), findsOneWidget);
    expect(find.text('4 schwere Tage'), findsOneWidget);
    expect(find.text(InsightCopy.footer), findsOneWidget);
    expect(_title, findsOneWidget);
    expect(find.text(StatsCopy.error), findsOneWidget);
    expect(find.text(StatsCopy.retry), findsOneWidget);
    expect(
      tester.getSize(find.byKey(StatsSection.retryKey)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('opening the page again refetches once; the first load is not '
      'fetched twice', (tester) async {
    final fake = await _pump(tester, _ready());
    expect(fake.refreshes, 0);

    GoRouter.of(tester.element(find.byType(StatsSection))).push('/');
    await tester.pumpAndSettle();

    expect(fake.refreshes, 1);
  });

  testWidgets('retry calls refresh', (tester) async {
    final fake = await _pump(tester, Exception('offline'));
    await tester.tap(find.byKey(StatsSection.retryKey));
    await tester.pump();
    expect(fake.refreshes, 1);
  });

  testWidgets('locked by the server (402): no section, no error line', (
    tester,
  ) async {
    await _pump(tester, const PatternStatsLockedException());
    expect(_title, findsNothing);
    expect(find.text(StatsCopy.error), findsNothing);
    expect(find.text('4 gute Tage'), findsOneWidget);
  });

  testWidgets('limits are collapsed and expand on tap', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _ready());

    final toggle = find.byKey(StatsSection.limitsKey);
    expect(find.text(StatsCopy.limitsTitle), findsOneWidget);
    for (final line in StatsCopy.limits) {
      expect(find.text(line), findsNothing);
    }
    expect(
      tester.getSemantics(toggle),
      isSemantics(isButton: true, hasExpandedState: true, isExpanded: false),
    );
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    for (final line in StatsCopy.limits) {
      expect(find.text(line), findsOneWidget);
    }
    expect(
      tester.getSemantics(toggle),
      isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.limits.first), findsNothing);
    handle.dispose();
  });

  testWidgets('a row shows the trailing slot it is given', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patternStatsProvider.overrideWith(() => _FakeStats(_ready())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatsSection(
                trailing: (item) =>
                    item.key == 'kaffee' ? const Text('TRAIL') : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _row(_kaffee), matching: find.text('TRAIL')),
      findsOneWidget,
    );
    expect(find.text('TRAIL'), findsOneWidget);
  });
}
