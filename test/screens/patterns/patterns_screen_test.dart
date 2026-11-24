import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/patterns/patterns_screen.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';

/// The app's clock, pinned: the entries ([_entries]) lie before it, in the
/// insights' window on any date.
final _now = DateTime(2026, 11, 23, 14);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeEntryRepository entries, {
  Size size = const Size(390, 844),
  double textScale = 1,
  DateTime Function()? clock,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      ...baseOverrides(entries: entries),
      buddyClockProvider.overrideWithValue(clock ?? () => _now),
    ],
  );
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const PatternsScreen())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: germanRouterApp(router, textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

FakeEntryRepository _entries(int days, int gut) => FakeEntryRepository()
  ..insightSource = insightSourceFor(
    activeDays: days,
    gutFeelings: gut,
    now: _now,
  );

const _hintGut =
    'Trag abends kurz dein Bauchgefühl ein, das hilft mir am meisten.';
const _hintKeep = 'Trag weiter ein – jeder Tag mit Einträgen zählt.';

void main() {
  testWidgets('/patterns opens from a cold start and is not gated', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 860)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer.test(
      overrides: [
        ...baseOverrides(entries: _entries(2, 1)),
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
    container.read(routerProvider).go(RoutePaths.patterns);
    await tester.pumpAndSettle();
    expect(find.byType(PatternsScreen), findsOneWidget);
    expect(find.text('Ich sammle noch!'), findsOneWidget);
  });

  group('back', () {
    Future<ProviderContainer> openApp(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(400, 860)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer.test(
        overrides: [
          ...baseOverrides(entries: _entries(2, 1)),
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
      return container;
    }

    final appBar = find.descendant(
      of: find.byType(PatternsScreen),
      matching: find.byType(AppBar),
    );
    final back = find.descendant(
      of: find.byType(PatternsScreen),
      matching: find.byType(BackButton),
    );
    String location(ProviderContainer c) =>
        c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

    testWidgets('from a cold start, the back button goes Home', (tester) async {
      final container = await openApp(tester);
      container.read(routerProvider).go(RoutePaths.patterns);
      await tester.pumpAndSettle();

      expect(tester.widget<AppBar>(appBar).leading, isA<BackButton>());
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.byType(PatternsScreen), findsNothing);
      expect(location(container), RoutePaths.dashboard);
    });

    testWidgets('pushed from Home, the default back arrow pops', (
      tester,
    ) async {
      final container = await openApp(tester);
      unawaited(container.read(routerProvider).push(RoutePaths.patterns));
      await tester.pumpAndSettle();

      expect(tester.widget<AppBar>(appBar).leading, isNull);
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.byType(PatternsScreen), findsNothing);
      expect(location(container), RoutePaths.dashboard);
    });
  });

  group('locked', () {
    testWidgets('2 days, 1 gut feeling: line, both bars, gut hint, preview', (
      tester,
    ) async {
      await _pump(tester, _entries(2, 1));

      expect(find.text('Muster'), findsOneWidget);
      expect(find.text('Ich sammle noch!'), findsOneWidget);
      expect(
        find.text('Noch 5 Tage, dann zeig ich dir erste Muster.'),
        findsOneWidget,
      );
      expect(find.text('BIS ZU DEN ERSTEN MUSTERN'), findsOneWidget);
      expect(find.text('Tage mit Einträgen'), findsOneWidget);
      expect(find.text('2 von 7'), findsOneWidget);
      expect(find.text('Bauchgefühl-Einträge'), findsOneWidget);
      expect(find.text('1 von 3'), findsOneWidget);
      expect(find.text(_hintGut), findsOneWidget);
      expect(find.text(_hintKeep), findsNothing);
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(
        find.text('Das siehst du dann · Beispiel'.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(
          'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('7 days, 1 gut feeling: gut-feeling line and hint', (
      tester,
    ) async {
      await _pump(tester, _entries(7, 1));

      expect(
        find.text(
          'Noch 2 Bauchgefühl-Einträge, dann zeig ich dir erste Muster.',
        ),
        findsOneWidget,
      );
      expect(find.text('7 von 7'), findsOneWidget);
      expect(find.text(_hintGut), findsOneWidget);
    });

    testWidgets('gut feelings done, days missing: the keep-going hint', (
      tester,
    ) async {
      await _pump(tester, _entries(3, 3));

      expect(find.text(_hintKeep), findsOneWidget);
      expect(find.text(_hintGut), findsNothing);
    });

    testWidgets('preview is marked as Beispiel and excluded from semantics', (
      tester,
    ) async {
      await _pump(tester, _entries(2, 1));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Vorschau mit Beispielwerten',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ImageFiltered),
          matching: find.byType(ExcludeSemantics),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(ImageFiltered),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });
  });

  testWidgets('error shows retry, which refreshes', (tester) async {
    final entries = _entries(2, 1)..insightSourceError = Exception('down');
    await _pump(tester, entries);

    expect(find.text('Muster konnten nicht geladen werden.'), findsOneWidget);
    expect(find.text('Ich sammle noch!'), findsNothing);

    entries.insightSourceError = null;
    await tester.tap(find.text('Nochmal versuchen'));
    await tester.pumpAndSettle();

    expect(find.text('Muster konnten nicht geladen werden.'), findsNothing);
    expect(find.text('Ich sammle noch!'), findsOneWidget);
  });

  testWidgets('pull-to-refresh fetches again', (tester) async {
    final entries = _entries(2, 1);
    await _pump(tester, entries);
    final before = entries.insightSourceCalls;

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(entries.insightSourceCalls, greaterThan(before));
  });

  testWidgets('back in the foreground on a new day, the page computes the '
      'insights again, without Home', (tester) async {
    var now = DateTime(2026, 11, 23, 23, 50);
    final entries = _entries(2, 1);
    await _pump(tester, entries, clock: () => now);
    expect(entries.insightSourceCalls, 1);

    // The device slept past midnight; its timer stood still.
    now = DateTime(2026, 11, 24, 7);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(entries.insightSourceCalls, 2);
    expect(entries.insightSourceRequests.last.now, now);
  });

  testWidgets('fits 375×667 at text scale 1.3', (tester) async {
    await _pump(
      tester,
      _entries(2, 1),
      size: const Size(375, 667),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    // Scrolls to the footer.
    await tester.scrollUntilVisible(
      find.textContaining('kein medizinischer Befund'),
      200,
    );
    expect(tester.takeException(), isNull);
  });
}
