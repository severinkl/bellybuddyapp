import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/progress_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/progress/widgets/progress_weeks.dart';
import 'package:belly_buddy/screens/progress/progress_screen.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';
import 'package:belly_buddy/services/progress/progress_engine.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';

/// Thursday of the week of 23 Nov 2026; the window starts Monday 7 Sep.
final _now = DateTime(2026, 11, 26, 10);

DateTime _day(int month, int day) => DateTime(2026, month, day, 12);

var _ids = 0;

/// A gut-feeling entry whose score is [v] (1–2 good, 3 medium, 4–5 hard).
GutFeelingEntry _gut(DateTime at, int v) => GutFeelingEntry(
  id: 'g${_ids++}',
  trackedAt: at,
  bloating: v,
  gas: v,
  cramps: v,
  fullness: v,
);

/// [n] consecutive days from [from], one good entry each.
List<GutFeelingEntry> _goodRun(DateTime from, int n) => [
  for (var i = 0; i < n; i++)
    _gut(DateTime(from.year, from.month, from.day + i, 12), 2),
];

Progress _progress({
  List<GutFeelingEntry> guts = const [],
  List<DateTime> other = const [],
}) => computeProgress(
  ProgressSource(gutFeelings: guts, toilets: const [], otherTimes: other),
  now: _now,
);

/// [p] with its longest streak replaced.
Progress _withLongest(Progress p, int longest) => Progress(
  weeks: p.weeks,
  good: p.good,
  medium: p.medium,
  hard: p.hard,
  activeDays: p.activeDays,
  elapsedDays: p.elapsedDays,
  longestStreak: longest,
  recent: p.recent,
);

/// 34 good days: 5 in the week of 16 Nov, 3 in the week before, 26 from
/// 7 Sep; one hard day (24 Nov) and a meal-only day (25 Nov) this week.
Progress _full({bool moreGoodLastWeek = true}) => _progress(
  guts: [
    ..._goodRun(_day(11, 16), moreGoodLastWeek ? 5 : 3),
    ..._goodRun(_day(11, 9), moreGoodLastWeek ? 3 : 5),
    ..._goodRun(_day(9, 7), 26),
    _gut(_day(11, 24), 5),
  ],
  other: [_day(11, 25)],
);

class _FakeProgressNotifier extends ProgressNotifier {
  _FakeProgressNotifier(this.value, {this.error});

  final Progress? value;
  final Object? error;
  int refreshes = 0;

  /// While set, a (re)build waits for it; completing it with an error fails
  /// that build.
  Completer<void>? gate;

  @override
  Future<Progress?> build() async {
    ref.watch(_userChange);
    await gate?.future;
    if (error case final e?) throw e;
    return value;
  }

  @override
  Future<void> refresh() async => refreshes++;
}

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// What the fake watches: bumping it rebuilds the notifier as a user change
/// does (a reload, with the previous value).
final _userChange = NotifierProvider<_Counter, int>(_Counter.new);

/// How the Buddy status behaves in [pump].
enum _Buddy { loaded, loading, failed }

void main() {
  late GoRouter router;
  late ProviderContainer container;

  Future<_FakeProgressNotifier> pump(
    WidgetTester tester, {
    Progress? progress,
    Object? error,
    int streak = 5,
    _Buddy buddy = _Buddy.loaded,
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notifier = _FakeProgressNotifier(progress, error: error);
    container = ProviderContainer.test(
      overrides: [
        progressProvider.overrideWith(() => notifier),
        buddyProvider.overrideWith(
          () => FakeBuddyNotifier(
            () => switch (buddy) {
              _Buddy.loaded => buddyStatus(streak: streak),
              _Buddy.loading => Completer<BuddyStatus?>().future,
              _Buddy.failed => throw Exception('buddy down'),
            },
          ),
        ),
        buddyClockProvider.overrideWithValue(() => _now),
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.progress,
      routes: [
        GoRoute(
          path: RoutePaths.progress,
          builder: (_, _) => const ProgressScreen(),
        ),
        ...stubRoutes([RoutePaths.gutFeelingTracker, RoutePaths.me]),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  String location() => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('no entries: empty state, button opens the gut-feeling tracker', (
    tester,
  ) async {
    await pump(tester, progress: _progress());

    expect(find.text('Dein Verlauf'), findsOneWidget);
    expect(find.byKey(ProgressScreen.emptyKey), findsOneWidget);
    expect(find.text('Dein Verlauf füllt sich bald'), findsOneWidget);
    expect(
      find.text(
        'Trag dein Bauchgefühl ein – dann siehst du hier Woche für Woche, '
        'wie es dir geht.',
      ),
      findsOneWidget,
    );
    expect(find.text('Die letzten 12 Wochen'), findsNothing);

    await tester.tap(find.text('Bauchgefühl eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('page:${RoutePaths.gutFeelingTracker}'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('12 week rows, newest first, labelled', (tester) async {
    await pump(tester, progress: _full(), size: const Size(400, 4000));

    final mondays = [for (final w in _full().weeks.reversed) w.monday];
    expect(mondays, hasLength(12));
    final tops = [
      for (final m in mondays)
        tester.getTopLeft(find.byKey(ProgressWeeks.weekKey(m))).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]));
    }
    Finder labelIn(DateTime monday, String text) => find.descendant(
      of: find.byKey(ProgressWeeks.weekKey(monday)),
      matching: find.text(text),
    );
    expect(labelIn(DateTime(2026, 11, 23), 'Diese Woche'), findsOneWidget);
    expect(labelIn(DateTime(2026, 11, 16), '16.–22. Nov'), findsOneWidget);
    expect(labelIn(DateTime(2026, 9, 28), '28. Sep – 4. Okt'), findsOneWidget);
    // The week's line: counts, then how many days were logged.
    expect(
      labelIn(
        DateTime(2026, 11, 16),
        '5 gute Tage · an 5 von 7 Tagen eingetragen',
      ),
      findsOneWidget,
    );
    expect(
      labelIn(
        DateTime(2026, 11, 23),
        '1 schwerer Tag · an 2 von 4 Tagen eingetragen',
      ),
      findsOneWidget,
    );
    // The legend, with the dot of a day without gut feeling.
    expect(find.text('ohne Bauchgefühl'), findsOneWidget);
    expect(find.text('kein Eintrag'), findsOneWidget);
    // The footer, as on the Muster page.
    expect(
      find.text(
        'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('active days without gut feeling', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      progress: _progress(other: [_day(11, 24), _day(11, 10)]),
      size: const Size(400, 4000),
    );

    expect(find.byKey(ProgressScreen.emptyKey), findsNothing);
    expect(find.text('Die letzten 12 Wochen'), findsOneWidget);
    expect(
      find.text('Kein Bauchgefühl eingetragen · an 1 von 4 Tagen eingetragen'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('24. Nov: eingetragen, ohne Bauchgefühl'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('23. Nov: kein Eintrag'), findsOneWidget);
    expect(find.text('Eingetragen an 2 von 81 Tagen'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('totals, streaks and the positive line', (tester) async {
    await pump(tester, progress: _withLongest(_full(), 3));

    expect(find.text('34 gute Tage'), findsOneWidget);
    expect(find.text('0 mittlere'), findsOneWidget);
    expect(find.text('1 schwerer'), findsOneWidget);
    expect(find.text('Aktueller Streak'), findsOneWidget);
    expect(find.text('Längster Streak'), findsOneWidget);
    expect(find.text('in den letzten 12 Wochen'), findsOneWidget);
    // Current = the Buddy's streak; longest = max(3, 5).
    expect(find.text('5 Tage'), findsNWidgets(2));
    expect(find.text('Eingetragen an 36 von 81 Tagen'), findsOneWidget);
    expect(
      find.text('Letzte Woche hattest du mehr gute Tage als die Woche davor.'),
      findsOneWidget,
    );

    await pump(tester, progress: _withLongest(_full(), 9), streak: 0);
    expect(find.text('Startet mit deinem nächsten Eintrag'), findsOneWidget);
    expect(find.text('9 Tage'), findsOneWidget);

    await pump(tester, progress: _full(moreGoodLastWeek: false));
    expect(_full(moreGoodLastWeek: false).moreGoodDaysLastWeek, isFalse);
    expect(
      find.text('Letzte Woche hattest du mehr gute Tage als die Woche davor.'),
      findsNothing,
    );
  });

  testWidgets('no current streak tile while the Buddy has no value', (
    tester,
  ) async {
    for (final buddy in [_Buddy.loading, _Buddy.failed]) {
      await pump(tester, progress: _withLongest(_full(), 9), buddy: buddy);
      expect(find.text('Aktueller Streak'), findsNothing);
      expect(find.text('Startet mit deinem nächsten Eintrag'), findsNothing);
      expect(find.text('Längster Streak'), findsOneWidget);
      expect(find.text('9 Tage'), findsOneWidget);
    }
  });

  testWidgets('a reload shows loading, not the previous data; an error '
      'with a previous value shows the error', (tester) async {
    final notifier = await pump(tester, progress: _full());
    expect(find.text('Die letzten 12 Wochen'), findsOneWidget);

    final gate = notifier.gate = Completer<void>();
    container.read(_userChange.notifier).bump();
    await tester.pump();
    expect(find.byType(BbLoadingState), findsOneWidget);
    expect(find.text('Die letzten 12 Wochen'), findsNothing);

    gate.completeError(Exception('down'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Dein Verlauf konnte nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Die letzten 12 Wochen'), findsNothing);
  });

  testWidgets('trend: the line below two weeks with means, the chart from 2', (
    tester,
  ) async {
    await pump(
      tester,
      progress: _progress(guts: _goodRun(_day(11, 23), 3)),
      size: const Size(400, 4000),
    );
    expect(find.text('Beschwerden pro Woche'), findsOneWidget);
    expect(find.textContaining('zeige ich dir, sobald'), findsOneWidget);
    expect(find.text('Blähbauch'), findsNothing);

    // Entries of 3 days in each of the last two weeks.
    final guts = [
      for (final d in [23, 24, 25]) _gut(_day(11, d), 2),
      for (final d in [16, 17, 18]) _gut(_day(11, d), 3),
    ];
    await pump(
      tester,
      progress: _progress(guts: guts),
      size: const Size(400, 4000),
    );
    expect(find.text('Blähbauch'), findsOneWidget);
    expect(find.textContaining('zeige ich dir, sobald'), findsNothing);
  });

  testWidgets('error shows retry, retry calls refresh', (tester) async {
    final notifier = await pump(tester, error: Exception('down'));

    expect(
      find.text('Dein Verlauf konnte nicht geladen werden.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Nochmal versuchen'));
    await tester.pump();

    expect(notifier.refreshes, 1);
  });

  testWidgets('pull to refresh calls refresh', (tester) async {
    final notifier = await pump(tester, progress: _full());

    await tester.fling(
      find.text('Die letzten 12 Wochen'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(notifier.refreshes, 1);
  });

  testWidgets('future days have no cell semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, progress: _full(), size: const Size(400, 4000));

    expect(find.bySemanticsLabel('24. Nov: schwer'), findsOneWidget);
    expect(find.bySemanticsLabel('26. Nov: kein Eintrag'), findsOneWidget);
    for (final day in [27, 28, 29]) {
      expect(find.bySemanticsLabel(RegExp('^$day\\. Nov')), findsNothing);
    }
    handle.dispose();
  });

  testWidgets('/progress opens in the app from a cold start, not gated', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer.test(
      overrides: [
        ...baseOverrides(),
        buddyClockProvider.overrideWithValue(() => _now),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppTestHost(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(RoutePaths.progress);
    await tester.pumpAndSettle();

    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.byKey(ProgressScreen.emptyKey), findsOneWidget);
  });

  group('back', () {
    testWidgets('opened without a page below, back goes to Ich', (
      tester,
    ) async {
      await pump(tester, progress: _full());

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(location(), RoutePaths.me);
    });
  });

  testWidgets('fits 375×667 at text scale 1.3', (tester) async {
    await pump(
      tester,
      progress: _withLongest(_full(), 12),
      size: const Size(375, 667),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
