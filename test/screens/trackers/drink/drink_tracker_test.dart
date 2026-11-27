// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/trackers/drink/drink_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_search.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_size_selector.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/quick_drink_grid.dart';
import 'package:belly_buddy/widgets/common/tap_target.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/widgets/buddy/log_success_hero.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/layout_checks.dart';
import '../../../helpers/riverpod_helpers.dart';
import '../../../helpers/widget_tester_helpers.dart';

List<Override> _overrides({FakeDrinkRepository? drinkRepo}) => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  drinkRepositoryProvider.overrideWithValue(drinkRepo ?? FakeDrinkRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('DrinkTrackerScreen', () {
    testWidgets('renders screen title', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      // Use pump with duration to let async loading complete
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Was hast du getrunken? 💧'), findsOneWidget);
    });

    testWidgets('renders Heute label after loading', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Heute: '), findsOneWidget);
    });

    testWidgets('renders speichern button', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('renders quick drink grid after loading', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // FakeDrinkRepository seeds with 'Wasser' drink
      expect(find.text('Wasser'), findsOneWidget);
    });

    testWidgets('initialTrackedAt seeds trackedAt verbatim', (tester) async {
      final initial = DateTime(2026, 5, 1, 12, 30);
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DrinkTrackerScreen(initialTrackedAt: initial),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final state = container.read(drinkTrackerProvider);
      expect(state.trackedAt, equals(initial));
    });

    testWidgets('without initialTrackedAt, trackedAt is "now" after reset', (
      tester,
    ) async {
      final before = DateTime.now();
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DrinkTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final after = DateTime.now();

      final trackedAt = container.read(drinkTrackerProvider).trackedAt;
      expect(
        !trackedAt.isBefore(before) && !trackedAt.isAfter(after),
        isTrue,
        reason: 'no seed → reset() default ("now") must stand',
      );
    });

    testWidgets(
      'drag inside the suggestion list does not collapse the dropdown',
      (tester) async {
        // The whole point of switching DrinkSearch from OverlayPortal to an
        // inline Column: a user scrolling through tea varieties must not
        // make the menu disappear. Pin that invariant here so a future
        // reintroduction of the overlay fails loudly.
        final repo = FakeDrinkRepository()
          ..seedDrinks([
            testDrink(id: 'tee-1', name: 'Schwarzer Tee'),
            testDrink(id: 'tee-2', name: 'Grüner Tee'),
            testDrink(id: 'tee-3', name: 'Kräutertee'),
            testDrink(id: 'tee-4', name: 'Rooibos Tee'),
            testDrink(id: 'kaffee', name: 'Kaffee'),
          ]);

        await tester.pumpWithProviders(
          const DrinkTrackerScreen(),
          overrides: _overrides(drinkRepo: repo),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Focus the search field and type a query that matches multiple
        // teas so the suggestion list renders with several items.
        await tester.tap(find.byKey(DrinkSearch.searchFieldKey));
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Tee');
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(DrinkSearch.suggestionsKey), findsOneWidget);
        final insideDropdown = find.descendant(
          of: find.byKey(DrinkSearch.suggestionsKey),
          matching: find.text('Schwarzer Tee'),
        );
        expect(insideDropdown, findsOneWidget);

        // Simulate the reported bug: the user drags inside the dropdown
        // trying to scroll. Must not collapse the list.
        await tester.drag(
          find.byKey(DrinkSearch.suggestionsKey),
          const Offset(0, -100),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(DrinkSearch.suggestionsKey), findsOneWidget);
        expect(insideDropdown, findsOneWidget);
      },
    );

    testWidgets('successful save emits a Buddy event and shows the reaction', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DrinkTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Backdated: the event carries the entry's time, not the save's.
      final lastNight = DateTime(2026, 11, 21, 20);
      container.read(drinkTrackerProvider.notifier)
        ..toggleDrink(testDrink())
        ..selectAmount(250)
        ..setTrackedAt(lastNight);
      await tester.pump();
      await tester.ensureVisible(find.text('Speichern'));
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      // The Buddy animates forever: pump past the overlay intro only.
      await tester.pump(const Duration(milliseconds: 700));

      final event = container.read(buddyEventsProvider);
      expect(event?.kind, EntryKind.drink);
      expect(event?.sentiment, LogSentiment.good);
      expect(event?.trackedAt, lastNight);
      expect(find.text('Getränk gespeichert!'), findsOneWidget);
      final view = tester.widget<BuddyReactionView>(
        find.byType(BuddyReactionView),
      );
      expect(view.kind, EntryKind.drink);
      expect(find.byType(MascotImage), findsNothing);
    });

    testWidgets('the drink success page charges Trinken to full', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 11, 23, 14);
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DrinkTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      container.read(drinkTrackerProvider.notifier)
        ..toggleDrink(testDrink())
        ..selectAmount(250)
        ..setTrackedAt(now);
      await tester.pump();
      await tester.ensureVisible(find.text('Speichern'));
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final meter = tester.widget<ChargingMeter>(find.byType(ChargingMeter));
      expect(meter.need, CareNeed.drink);
      expect(meter.to, 1.0);
      // The log event is stamped with the app's clock, as the moment is.
      expect(container.read(buddyEventsProvider)?.at, now);
      expect(
        find.descendant(
          of: find.byType(LogSuccessHero),
          matching: find.byType(BuddyReactionView),
        ),
        findsOneWidget,
      );
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('the drink page fits 375×667 at text scale $scale with its '
          'circle and ignite row', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(750, 1334);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final now = DateTime(2026, 11, 23, 14);
        final errors = await collectFlutterErrors(() async {
          final container = ProviderContainer.test(
            overrides: [
              ..._overrides(),
              buddyClockProvider.overrideWithValue(() => now),
              // Today's first entry: the ignite row too.
              buddyProvider.overrideWith(
                () => FakeBuddyNotifier(() => buddyStatus(streak: 4)),
              ),
            ],
          );
          addTearDown(container.dispose);
          await container.read(buddyProvider.future);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: DrinkTrackerScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          container.read(drinkTrackerProvider.notifier)
            ..toggleDrink(testDrink())
            ..selectAmount(250)
            ..setTrackedAt(now);
          await tester.pump();
          await tester.ensureVisible(find.text('Speichern'));
          await tester.tap(find.text('Speichern'));
          await tester.pump();
          await pumpPastCharge(tester);
        });

        expect(find.byType(ChargingMeter), findsOneWidget);
        expect(find.byKey(LogSuccessHero.igniteKey), findsOneWidget);
        expectSuccessPageFits(
          tester,
          errors,
          page: find.byType(BbSuccessOverlay),
        );
      });
    }

    testWidgets('a save that stores nothing emits no Buddy event', (
      tester,
    ) async {
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DrinkTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final notifier = container.read(drinkTrackerProvider.notifier)
        ..toggleDrink(testDrink())
        ..selectAmount(250);
      await tester.pump();
      await tester.ensureVisible(find.text('Speichern'));
      // Deselect without rebuilding: the enabled button still calls _save,
      // but save() finds no drink and stores nothing.
      notifier.clearSelection();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(drinkTrackerProvider).showSuccess, isFalse);
      expect(container.read(buddyEventsProvider), isNull);
      expect(find.byType(BuddyReactionView), findsNothing);
    });

    testWidgets("a past day's header shows that day's total", (tester) async {
      final repo = FakeDrinkRepository();
      await tester.pumpWithProviders(
        DrinkTrackerScreen(initialTrackedAt: DateTime(2026, 11, 22, 12)),
        overrides: _overrides(drinkRepo: repo),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Am 22.11.: '), findsOneWidget);
      expect(find.text('Heute: '), findsNothing);
      expect(repo.dayTotalFetches, [DateTime(2026, 11, 22)]);
    });

    testWidgets('a user without drink history sees „Häufige Getränke"', (
      tester,
    ) async {
      final repo = FakeDrinkRepository()..recentDrinkIds = [];
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(drinkRepo: repo),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Häufige Getränke'), findsOneWidget);
      expect(find.text('Wähle aus deinen letzten Getränken'), findsNothing);
    });

    testWidgets('a user with history picks from the last drinks', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Wähle aus deinen letzten Getränken'), findsOneWidget);
    });

    testWidgets('a custom amount over 3000 ml is refused with a hint', (
      tester,
    ) async {
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DrinkTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      container.read(drinkTrackerProvider.notifier).toggleDrink(testDrink());
      await tester.pump();

      final field = find.byKey(DrinkSizeSelector.customAmountKey);
      await tester.ensureVisible(field);
      await tester.enterText(field, '99999');
      await tester.pump();

      expect(find.text('Bitte gib 1 bis 3000 ml ein.'), findsOneWidget);
      final save = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Speichern'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(save.onPressed, isNull);

      await tester.enterText(field, '3000');
      await tester.pump();
      expect(find.text('Bitte gib 1 bis 3000 ml ein.'), findsNothing);
      expect(container.read(drinkTrackerProvider).selectedAmount, 3000);
    });

    testWidgets('on a 393×852 phone with the keypad open the amount hint '
        'shows in full above „Speichern"', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DrinkTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      container.read(drinkTrackerProvider.notifier).toggleDrink(testDrink());
      await tester.pumpAndSettle();

      final field = find.byKey(DrinkSizeSelector.customAmountKey);
      await tester.ensureVisible(field);
      await tester.showKeyboard(field);
      // The iOS number pad.
      tester.view.viewInsets = const FakeViewPadding(bottom: 309);
      await tester.pumpAndSettle();
      await tester.enterText(field, '99999');
      await tester.pumpAndSettle();

      const hint = 'Bitte gib 1 bis 3000 ml ein.';
      expect(find.text(hint), findsOneWidget);
      final viewport = tester.getRect(
        find.ancestor(of: field, matching: find.byType(Scrollable)).first,
      );
      final hintRect = tester.getRect(find.text(hint));
      expect(hintRect.top, greaterThanOrEqualTo(viewport.top));
      // With room to spare: the phone's font sets a taller line than the
      // test font, and a hint flush with the edge was cut off there.
      expect(
        hintRect.bottom,
        lessThanOrEqualTo(viewport.bottom - AppConstants.spacingMd),
      );
    });

    testWidgets('after a save it closes with true for its opener', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      Object? result = 'not closed';
      final router = GoRouter(
        initialLocation: '/opener',
        routes: [
          GoRoute(
            path: '/opener',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await context.push<bool>('/drink'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/drink',
            builder: (_, _) => const DrinkTrackerScreen(),
          ),
        ],
      );
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      container.read(drinkTrackerProvider.notifier)
        ..toggleDrink(testDrink())
        ..selectAmount(250);
      await tester.pump();
      await tester.ensureVisible(find.text('Speichern'));
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('Getränk gespeichert!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(result, isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    group('for assistive tech', () {
      Future<ProviderContainer> pumpWithDrink(
        WidgetTester tester, {
        FakeDrinkRepository? drinkRepo,
      }) async {
        final container = ProviderContainer.test(
          overrides: _overrides(drinkRepo: drinkRepo),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DrinkTrackerScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        return container;
      }

      testWidgets('„Heute: " and the create row\'s text use the text tokens '
          'that meet 4.5:1', (tester) async {
        await pumpWithDrink(tester);
        expect(
          tester.widget<Text>(find.text('Heute: ')).style?.color,
          AppTheme.infoText,
        );
        await tester.tap(find.byKey(DrinkSearch.searchFieldKey));
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Mate');
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('„Mate" hinzufügen')).style?.color,
          AppTheme.primaryText,
        );
      });

      testWidgets('at 200 % text the quick-drink rows keep an 8 px gap', (
        tester,
      ) async {
        final repo = FakeDrinkRepository()
          ..seedDrinks([
            for (final n in ['Wasser', 'Kaffee', 'Tee', 'Saft', 'Milch'])
              testDrink(id: n, name: n),
          ]);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpWithDrink(tester, drinkRepo: repo);

        final pills = find
            .descendant(
              of: find.byType(QuickDrinkGrid),
              matching: find.byType(AnimatedContainer),
            )
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)))
            .toList();
        final rows = <double>{for (final r in pills) r.top}.toList()..sort();
        expect(rows.length, greaterThan(1), reason: 'needs two rows');
        for (var i = 1; i < rows.length; i++) {
          final above = pills.where((r) => r.top == rows[i - 1]);
          final below = pills.where((r) => r.top == rows[i]);
          final gap =
              below.first.top - above.map((r) => r.bottom).reduce(math.max);
          expect(gap, greaterThanOrEqualTo(8), reason: 'row $i');
        }
      });

      testWidgets('the search field keeps „Getränk suchen" with text entered', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpWithDrink(tester);
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Tee');
        await tester.pump();

        final field = tester.getSemantics(
          find.byKey(DrinkSearch.searchFieldKey),
        );
        expect(field.label, contains('Getränk suchen'));
        expect(field, isSemantics(isTextField: true, value: 'Tee'));
        handle.dispose();
      });

      testWidgets('an own drink\'s delete button is „Getränk löschen"', (
        tester,
      ) async {
        final repo = FakeDrinkRepository()
          ..seedDrinks([
            testDrink(id: 'own', name: 'Eistee', addedByUserId: 'test-user'),
          ]);
        final container = await pumpWithDrink(tester, drinkRepo: repo);
        await tester.tap(find.byKey(DrinkSearch.searchFieldKey));
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Eis');
        container.read(drinkTrackerProvider.notifier).searchDrinks('Eis');
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byTooltip('Getränk löschen'), findsOneWidget);
      });

      testWidgets('the custom amount field keeps „Andere Menge in ml" with '
          '„300" entered', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await pumpWithDrink(tester);
        container.read(drinkTrackerProvider.notifier).toggleDrink(testDrink());
        await tester.pump();

        final field = find.byKey(DrinkSizeSelector.customAmountKey);
        await tester.ensureVisible(field);
        await tester.enterText(field, '300');
        await tester.pump();

        final node = tester.getSemantics(field);
        expect(node.label, contains('Andere Menge in ml'));
        expect(node, isSemantics(isTextField: true, value: '300'));
        handle.dispose();
      });

      testWidgets('the chosen quick drink and size are selected to assistive '
          'tech', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await pumpWithDrink(tester);
        container.read(drinkTrackerProvider.notifier)
          ..toggleDrink(testDrink())
          ..selectAmount(250);
        await tester.pump();

        SemanticsNode nodeOf(Type of, String text) => tester.getSemantics(
          find.descendant(of: find.byType(of), matching: find.text(text)),
        );

        expect(
          nodeOf(QuickDrinkGrid, 'Wasser'),
          isSemantics(
            label: 'Wasser',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        );
        expect(
          nodeOf(DrinkSizeSelector, '250 ml'),
          isSemantics(
            label: '250 ml',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
        expect(
          nodeOf(DrinkSizeSelector, '500 ml'),
          isSemantics(
            label: '500 ml',
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            hasTapAction: true,
          ),
        );
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.descendant(
                    of: find.byType(QuickDrinkGrid),
                    matching: find.text('Wasser'),
                  ),
                  matching: find.byType(TapTarget),
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
        );

        // White text on the selected fill needs 4.5:1: infoText, not info.
        await tester.pump(AppConstants.animFast);
        Color? fillOf(Type of, String text) =>
            (tester
                        .widget<AnimatedContainer>(
                          find.ancestor(
                            of: find.descendant(
                              of: find.byType(of),
                              matching: find.text(text),
                            ),
                            matching: find.byType(AnimatedContainer),
                          ),
                        )
                        .decoration
                    as BoxDecoration?)
                ?.color;
        expect(fillOf(QuickDrinkGrid, 'Wasser'), AppTheme.infoText);
        expect(fillOf(DrinkSizeSelector, '250 ml'), AppTheme.infoText);
        expect(
          fillOf(DrinkSizeSelector, '500 ml'),
          AppTheme.muted.withValues(alpha: 0.5),
        );
        handle.dispose();
      });

      testWidgets('the chosen drink\'s ✕ is a named 48 px button that clears '
          'the choice', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await pumpWithDrink(tester);
        container.read(drinkTrackerProvider.notifier).toggleDrink(testDrink());
        await tester.pump();

        final clear = find.bySemanticsLabel('Auswahl entfernen');
        expect(clear, findsOneWidget);
        expect(
          tester.getSemantics(clear),
          isSemantics(
            label: 'Auswahl entfernen',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        final size = tester.getSize(clear);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.text('\u{2715}'), findsNothing);

        await tester.tap(clear);
        await tester.pump();
        expect(container.read(drinkTrackerProvider).selectedDrink, isNull);
        handle.dispose();
      });
    });
  });
}
