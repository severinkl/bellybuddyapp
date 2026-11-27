import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/repositories/tolerance_test_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/patterns/tolerance_test_screen.dart';
import 'package:belly_buddy/services/insights/test_copy.dart';
import 'package:belly_buddy/services/pattern_stats_service.dart';
import 'package:belly_buddy/widgets/common/plus_locked_card.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';

const _zwiebel = TestSubject('ingredient', 'zwiebel', 'Zwiebel');
const _fructans = TestSubject('group', 'fructans', 'Fruktane');

/// Today in these tests: Friday, 27 Nov 2026.
final _now = DateTime(2026, 11, 27, 12);

StatItem _item(
  String key,
  String name, {
  List<String> groups = const [],
  StatLevel level = StatLevel.noticed,
}) => StatItem(
  kind: 'ingredient',
  key: key,
  name: name,
  level: level,
  exposed: 10,
  exposedHard: 6,
  unexposed: 30,
  unexposedHard: 3,
  groups: groups,
);

ToleranceTestView _test({
  String status = 'active',
  TestPhase phase = TestPhase.leaveOut,
  int dayIndex = 3,
  List<TestDayView> days = const [],
  TestResult? result,
}) => ToleranceTestView(
  id: 't1',
  subject: _zwiebel,
  origin: 'picked',
  status: status,
  phase: phase,
  startsOn: DateTime(2026, 11, 25),
  leaveOutDays: 5,
  reintroDays: 3,
  dayIndex: dayIndex,
  days: days,
  result: result,
);

PatternStats _stats({
  ToleranceTestView? test,
  TestSubject? proposal,
  bool restrictive = false,
  List<StatItem> ingredients = const [],
  List<StatItem> calm = const [],
}) => PatternStats(
  windowDays: 90,
  ratedDays: 41,
  hardDays: 9,
  ready: true,
  ingredients: ingredients,
  calm: calm,
  test: test,
  proposal: proposal,
  restrictive: restrictive,
);

class _FakeRepo implements ToleranceTestRepository {
  _FakeRepo(this.service);

  final FakePatternStatsService service;
  final starts = <({TestSubject subject, String origin, DateTime startsOn})>[];
  final stops = <String>[];
  Object? startError;

  /// What the stats show after a start.
  PatternStats? afterStart;

  @override
  Future<void> start(
    TestSubject s, {
    required String origin,
    required DateTime startsOn,
  }) async {
    if (afterStart != null) service.stats = afterStart!;
    if (startError != null) throw startError!;
    starts.add((subject: s, origin: origin, startsOn: startsOn));
  }

  @override
  Future<void> stop(String id) async {
    stops.add(id);
    service.stats = _stats();
  }

  @override
  Future<void> complete(String id) async {}
}

/// A stats service whose fetch waits for [gate].
class _HeldService extends FakePatternStatsService {
  final gate = Completer<void>();

  @override
  Future<PatternStats> fetch() async {
    await gate.future;
    return super.fetch();
  }
}

Future<_FakeRepo> _pump(
  WidgetTester tester,
  PatternStats stats, {
  Object? extra,
  bool plusLocked = false,
  FakePatternStatsService? service,
}) async {
  tester.view
    ..physicalSize = const Size(402, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final svc = service ?? FakePatternStatsService(stats: stats);
  svc.stats = stats;
  final repo = _FakeRepo(svc);
  final router = GoRouter(
    initialLocation: RoutePaths.toleranceTest,
    initialExtra: extra,
    routes: [
      GoRoute(
        path: RoutePaths.toleranceTest,
        builder: (_, s) => ToleranceTestScreen(extra: s.extra),
      ),
      ...stubRoutes([RoutePaths.patterns, RoutePaths.plus]),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        buddyClockProvider.overrideWithValue(() => _now),
        plusAccessProvider.overrideWithValue(
          plusLocked ? PlusAccess.locked : PlusAccess.open,
        ),
        patternStatsServiceProvider.overrideWithValue(svc),
        toleranceTestRepositoryProvider.overrideWithValue(repo),
      ],
      child: germanRouterApp(router),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

final _start = find.byKey(ToleranceTestScreen.startKey);

void main() {
  testWidgets('opening the page within 30 s of a fetch does not refetch; '
      'the first load is not fetched twice', (tester) async {
    final svc = FakePatternStatsService();
    await _pump(tester, _stats(), service: svc);
    expect(svc.calls, 1);

    GoRouter.of(
      tester.element(find.byType(ToleranceTestScreen)),
    ).push(RoutePaths.toleranceTest);
    await tester.pumpAndSettle();

    expect(svc.calls, 1);
  });

  testWidgets('intro shows both phases with dates starting tomorrow and '
      'starts the test', (tester) async {
    final repo = await _pump(tester, _stats(), extra: _zwiebel);

    expect(find.text(TestCopy.title(_zwiebel)), findsOneWidget);
    expect(find.text(TestCopy.introBody(_zwiebel, 5, 3)), findsOneWidget);
    expect(
      find.text('Ohne: 28. Nov – 2. Dez · Mit: 3. Dez – 5. Dez'),
      findsOneWidget,
    );
    expect(find.text(TestCopy.doctor), findsOneWidget);
    expect(tester.getSize(_start).height, greaterThanOrEqualTo(48));

    repo.afterStart = _stats(test: _test(dayIndex: 0));
    await tester.tap(_start);
    await tester.pumpAndSettle();

    expect(repo.starts, hasLength(1));
    expect(repo.starts.single.subject, _zwiebel);
    expect(repo.starts.single.origin, 'picked');
    expect(repo.starts.single.startsOn, DateTime(2026, 11, 28));
    // The running test, no intro any more.
    expect(_start, findsNothing);
    expect(find.byKey(ToleranceTestScreen.stopKey), findsOneWidget);
  });

  testWidgets('without a subject the proposal is the intro, started as '
      '„proposed"', (tester) async {
    final repo = await _pump(tester, _stats(proposal: _zwiebel));
    expect(find.text(TestCopy.title(_zwiebel)), findsOneWidget);
    await tester.tap(_start);
    await tester.pumpAndSettle();
    expect(repo.starts.single.origin, 'proposed');
  });

  testWidgets('the origin follows the entry point, not the value', (
    tester,
  ) async {
    // From a stats row: picked, even though it is the proposal too.
    var repo = await _pump(tester, _stats(proposal: _zwiebel), extra: _zwiebel);
    await tester.tap(_start);
    await tester.pumpAndSettle();
    expect(repo.starts.single.origin, 'picked');

    // From the card's proposal.
    repo = await _pump(
      tester,
      _stats(),
      extra: const ToleranceTestProposed(_zwiebel),
    );
    expect(find.text(TestCopy.title(_zwiebel)), findsOneWidget);
    await tester.tap(_start);
    await tester.pumpAndSettle();
    expect(repo.starts.single.origin, 'proposed');
  });

  testWidgets('group intro lists up to five eaten foods of that group', (
    tester,
  ) async {
    await _pump(
      tester,
      _stats(
        ingredients: [
          _item('zwiebel', 'Zwiebel', groups: ['fructans', 'gos']),
          _item('milch', 'Milch', groups: ['lactose']),
          _item('knoblauch', 'Knoblauch', groups: ['fructans']),
          _item('lauch', 'Lauch', groups: ['fructans']),
          _item('roggenbrot', 'Roggenbrot', groups: ['fructans']),
        ],
        calm: [
          _item(
            'weizenbrot',
            'Weizenbrot',
            groups: ['fructans'],
            level: StatLevel.calm,
          ),
          _item(
            'nudeln',
            'Nudeln',
            groups: ['fructans'],
            level: StatLevel.calm,
          ),
        ],
      ),
      extra: _fructans,
    );
    expect(
      find.text(
        'Lebensmittel mit Fruktanen sind bei dir zum Beispiel: Zwiebel, '
        'Knoblauch, Lauch, Roggenbrot, Weizenbrot.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a group nobody ate has no foods line', (tester) async {
    await _pump(tester, _stats(), extra: _fructans);
    expect(find.textContaining('sind bei dir zum Beispiel'), findsNothing);
    expect(_start, findsOneWidget);
  });

  testWidgets('running test: one dot per day, a marker on a not-kept day, '
      '„kein Eintrag" grey', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _stats(
        test: _test(
          days: [
            TestDayView(
              day: DateTime(2026, 11, 25),
              phase: TestPhase.leaveOut,
              dayClass: DayClass.good,
              exposed: false,
            ),
            TestDayView(
              day: DateTime(2026, 11, 26),
              phase: TestPhase.leaveOut,
              dayClass: DayClass.hard,
              exposed: true,
            ),
            TestDayView(
              day: DateTime(2026, 11, 27),
              phase: TestPhase.leaveOut,
              dayClass: DayClass.none,
              exposed: false,
            ),
          ],
        ),
      ),
    );

    expect(find.text(TestCopy.title(_zwiebel)), findsOneWidget);
    expect(find.text('Tag 3 von 8'), findsOneWidget);
    expect(find.text('Phase 1: ohne Zwiebel'), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      expect(find.byKey(ToleranceTestScreen.dotKey(i)), findsOneWidget);
    }
    expect(find.byKey(ToleranceTestScreen.dotKey(8)), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(ToleranceTestScreen.dotKey(1)),
        matching: find.byKey(ToleranceTestScreen.markerKey),
      ),
      findsOneWidget,
    );
    expect(find.byKey(ToleranceTestScreen.markerKey), findsOneWidget);
    expect(
      find.bySemanticsLabel('26. Nov: schwer, nicht eingehalten'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('27. Nov: kein Eintrag'), findsOneWidget);
    expect(find.bySemanticsLabel('28. Nov: noch offen'), findsOneWidget);
    final none = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(ToleranceTestScreen.dotKey(2)),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((none.decoration! as BoxDecoration).color, AppTheme.muted);
    expect(find.text(TestCopy.notKept(1, _zwiebel)), findsOneWidget);
    expect(_start, findsNothing);
    handle.dispose();
  });

  testWidgets('stop: dialog, „Beenden" stops, „Weitermachen" keeps', (
    tester,
  ) async {
    final repo = await _pump(tester, _stats(test: _test()));
    final stop = find.byKey(ToleranceTestScreen.stopKey);
    expect(tester.getSize(stop).height, greaterThanOrEqualTo(48));

    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(find.text(TestCopy.stopTitle), findsOneWidget);
    expect(find.text(TestCopy.stopBody), findsOneWidget);
    expect(find.text(TestCopy.doctor), findsOneWidget);
    await tester.tap(find.text(TestCopy.stopKeep));
    await tester.pumpAndSettle();
    expect(repo.stops, isEmpty);
    expect(find.text(TestCopy.stopTitle), findsNothing);
    expect(stop, findsOneWidget);

    await tester.tap(stop);
    await tester.pumpAndSettle();
    await tester.tap(find.text(TestCopy.stopConfirm));
    await tester.pumpAndSettle();
    expect(repo.stops, ['t1']);
    // Stopped: no partial result, back to choosing.
    expect(stop, findsNothing);
    expect(find.text(TestCopy.pickerTitle), findsOneWidget);
  });

  testWidgets('restrictive: the page shows the restrictive text and no start '
      'button', (tester) async {
    await _pump(tester, _stats(restrictive: true));
    expect(find.text(TestCopy.restrictive), findsOneWidget);
    expect(_start, findsNothing);
    expect(find.text(TestCopy.pickerTitle), findsNothing);
  });

  testWidgets('restrictive with a subject: no intro, no start button', (
    tester,
  ) async {
    await _pump(tester, _stats(restrictive: true), extra: _zwiebel);
    expect(find.text(TestCopy.restrictive), findsOneWidget);
    expect(_start, findsNothing);
  });

  testWidgets('a start conflict reloads and shows the running test', (
    tester,
  ) async {
    final repo = await _pump(tester, _stats(), extra: _zwiebel);
    repo
      ..startError = const TestConflict()
      ..afterStart = _stats(test: _test());
    await tester.tap(_start);
    await tester.pumpAndSettle();
    expect(find.text('Tag 3 von 8'), findsOneWidget);
    expect(find.byKey(ToleranceTestScreen.stopKey), findsOneWidget);
    expect(find.text(TestCopy.startFailed), findsNothing);
  });

  testWidgets('a failed start says so and keeps the intro', (tester) async {
    final repo = await _pump(tester, _stats(), extra: _zwiebel);
    repo.startError = Exception('offline');
    await tester.tap(_start);
    await tester.pumpAndSettle();
    expect(find.text(TestCopy.startFailed), findsOneWidget);
    expect(_start, findsOneWidget);
  });

  testWidgets('no start before the stats have loaded', (tester) async {
    final held = _HeldService();
    await _pump(tester, _stats(), extra: _zwiebel, service: held);
    expect(_start, findsNothing);
    held.gate.complete();
    await tester.pumpAndSettle();
    expect(_start, findsOneWidget);
  });

  testWidgets('Plus locked: the Plus card, no test content', (tester) async {
    await _pump(tester, _stats(proposal: _zwiebel), plusLocked: true);
    expect(find.byType(PlusLockedCard), findsOneWidget);
    expect(_start, findsNothing);
    expect(find.text(TestCopy.title(_zwiebel)), findsNothing);
  });

  testWidgets('without proposal: the six groups; a group opens its intro', (
    tester,
  ) async {
    await _pump(tester, _stats());
    expect(find.text(TestCopy.pickerTitle), findsOneWidget);
    for (final g in TestCopy.groups) {
      final row = find.byKey(ToleranceTestScreen.groupKey(g.key));
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.byKey(ToleranceTestScreen.groupKey('lactose')));
    await tester.pumpAndSettle();
    expect(find.text('Verträglichkeits-Test: Laktose'), findsOneWidget);
    expect(_start, findsOneWidget);
    // Replaced, not stacked.
    expect(
      find.byType(ToleranceTestScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a finished test shows its result with both notes; unclear '
      'offers „Nochmal testen"', (tester) async {
    const result = TestResult(
      goodWithout: 1,
      countedWithout: 2,
      goodWith: 1,
      countedWith: 1,
      outcome: TestOutcome.unclear,
    );
    await _pump(
      tester,
      _stats(
        test: _test(status: 'completed', phase: TestPhase.done, result: result),
      ),
    );
    for (final line in TestCopy.resultLines(_zwiebel, result)) {
      expect(find.text(line), findsOneWidget);
    }
    await tester.tap(find.byKey(ToleranceTestScreen.retestKey));
    await tester.pumpAndSettle();
    expect(find.text(TestCopy.introBody(_zwiebel, 5, 3)), findsOneWidget);
    expect(_start, findsOneWidget);
    // Replaced, not stacked.
    expect(
      find.byType(ToleranceTestScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('active past its end: the result, no start, no stop', (
    tester,
  ) async {
    const result = TestResult(
      goodWithout: 1,
      countedWithout: 1,
      goodWith: 0,
      countedWith: 0,
      outcome: TestOutcome.unclear,
    );
    await _pump(
      tester,
      _stats(
        test: _test(phase: TestPhase.done, dayIndex: 9, result: result),
      ),
      extra: _fructans,
    );
    expect(
      find.text(TestCopy.resultHeadline(_zwiebel, result)),
      findsOneWidget,
    );
    expect(find.byKey(ToleranceTestScreen.retestKey), findsNothing);
    expect(find.byKey(ToleranceTestScreen.stopKey), findsNothing);
    expect(_start, findsNothing);
  });

  testWidgets('„Testen" from the closing line skips the last result', (
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
        test: _test(status: 'completed', phase: TestPhase.done, result: result),
      ),
      extra: const ToleranceTestPick(),
    );
    expect(find.text(TestCopy.pickerTitle), findsOneWidget);
    expect(find.text(TestCopy.resultHeadline(_zwiebel, result)), findsNothing);
  });
}
