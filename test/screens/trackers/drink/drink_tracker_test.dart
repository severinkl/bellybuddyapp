// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph, SemanticsNode;
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
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_time_line.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_today_card.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/glass_meter.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/last_drink_row.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/quick_drink_grid.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';
import 'package:belly_buddy/utils/wall_clock.dart';
import 'package:belly_buddy/widgets/common/date_time_chips.dart';
import '../../../helpers/app_host.dart'
    show germanLocalizations, germanLocale, germanRouterApp;
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
import '../../../helpers/semantics_checks.dart';

List<Override> _overrides({
  FakeDrinkRepository? drinkRepo,
  FakeEntryRepository? entryRepo,
}) => [
  entryRepositoryProvider.overrideWithValue(entryRepo ?? FakeEntryRepository()),
  drinkRepositoryProvider.overrideWithValue(drinkRepo ?? FakeDrinkRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

/// Holds every insert until [gate] completes: a save stays pending.
class _GatedEntryRepository extends FakeEntryRepository {
  final gate = Completer<void>();

  @override
  Future<void> insertEntry(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) async {
    await gate.future;
    return super.insertEntry(table, data, userId: userId);
  }
}

final _tea = testDrink(id: 'tea-id', name: 'Pfefferminztee');

/// Wasser (the last entry) and Pfefferminztee.
FakeDrinkRepository _teaRepo() =>
    FakeDrinkRepository()..seedDrinks([testDrink(), _tea]);

void main() {
  group('DrinkTrackerScreen', () {
    testWidgets('title „Was hast du getrunken?" without emoji', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      // Use pump with duration to let async loading complete
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Was hast du getrunken?'), findsOneWidget);
      expect(find.textContaining('\u{1F4A7}'), findsNothing);
    });

    testWidgets('opened: card „Heute getrunken" with the day total, „Wie '
        'zuletzt" „Wasser, 250 ml", no save button', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.descendant(
          of: find.byType(DrinkTodayCard),
          matching: find.text('Heute getrunken'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(DrinkTodayCard.totalKey)).data,
        '500 ml',
      );
      expect(find.text('Wie zuletzt'), findsOneWidget);
      expect(find.text('Wasser, 250 ml'), findsOneWidget);
      expect(find.text('Eintragen'), findsOneWidget);
      expect(find.byKey(DrinkTrackerScreen.saveKey), findsNothing);
      // The tiles are there (FakeDrinkRepository seeds „Wasser").
      expect(find.byKey(QuickDrinkGrid.tileKey('water-id')), findsOneWidget);
    });

    testWidgets('a past day reads „Am 22.11. getrunken" and loads that day', (
      tester,
    ) async {
      final repo = FakeDrinkRepository();
      await tester.pumpWithProviders(
        DrinkTrackerScreen(initialTrackedAt: DateTime(2026, 11, 22, 12)),
        overrides: _overrides(drinkRepo: repo),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Am 22.11. getrunken'), findsOneWidget);
      expect(find.text('Heute getrunken'), findsNothing);
      expect(repo.dayTotalFetches, [DateTime(2026, 11, 22)]);
    });

    testWidgets('choosing Pfefferminztee and typing 400: „+ 400 ml", total '
        '900 ml, button „400 ml Pfefferminztee eintragen"', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(drinkRepo: _teaRepo()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea-id')));
      await tester.pump();
      await tester.enterText(
        find.byKey(DrinkSizeSelector.customAmountKey),
        '400',
      );
      await tester.pump();

      expect(find.text('+ 400 ml'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(DrinkTodayCard.totalKey)).data,
        '900 ml',
      );
      expect(
        find.descendant(
          of: find.byKey(DrinkTrackerScreen.saveKey),
          matching: find.text('400 ml Pfefferminztee eintragen'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(DrinkTrackerScreen.saveKey))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('with a drink but no valid amount the button reads '
        '„Pfefferminztee eintragen" and is disabled', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(drinkRepo: _teaRepo()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea-id')));
      await tester.pump();

      expect(find.text('Pfefferminztee eintragen'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(DrinkTrackerScreen.saveKey))
            .onPressed,
        isNull,
      );
      // Without an amount nothing is pending.
      expect(find.textContaining('+ '), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(DrinkTodayCard.totalKey)).data,
        '500 ml',
      );
    });

    testWidgets('selecting a drink hides „Wie zuletzt"; deselecting brings it '
        'back', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(drinkRepo: _teaRepo()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(LastDrinkRow), findsOneWidget);
      expect(find.text('Oder wähle aus'), findsOneWidget);

      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea-id')));
      await tester.pump();
      expect(find.byType(LastDrinkRow), findsNothing);
      expect(find.text('Was?'), findsOneWidget);

      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea-id')));
      await tester.pump();
      expect(find.byType(LastDrinkRow), findsOneWidget);
      expect(find.text('Wie zuletzt'), findsOneWidget);
      expect(find.byKey(DrinkTrackerScreen.saveKey), findsNothing);
    });

    testWidgets('no last entry: no row, heading „Was?"', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(
          drinkRepo: FakeDrinkRepository()..lastEntry = null,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(LastDrinkRow), findsNothing);
      expect(find.text('Wie zuletzt'), findsNothing);
      expect(find.text('Was?'), findsOneWidget);
    });

    testWidgets('„Eintragen" on the row saves the last drink at the chosen '
        'time, shows success and the Buddy reacts', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final entries = FakeEntryRepository();
      final container = ProviderContainer.test(
        overrides: _overrides(entryRepo: entries),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.theme,
            home: const DrinkTrackerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final lastNight = DateTime(2026, 11, 21, 20);
      container.read(drinkTrackerProvider.notifier).setTrackedAt(lastNight);
      await tester.pump();
      await tester.ensureVisible(find.byKey(LastDrinkRow.saveKey));
      await tester.tap(find.byKey(LastDrinkRow.saveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final event = container.read(buddyEventsProvider);
      expect(event?.kind, EntryKind.drink);
      expect(event?.trackedAt, lastNight);
      expect(find.text('Getränk gespeichert!'), findsOneWidget);
      expect(
        tester.widget<BuddyReactionView>(find.byType(BuddyReactionView)).kind,
        EntryKind.drink,
      );
      expect(entries.inserted, hasLength(1));
      expect(entries.inserted.single['drink_id'], 'water-id');
      expect(entries.inserted.single['amount_ml'], 250);
      // The chosen wall-clock time, verbatim.
      expect(entries.inserted.single['tracked_at'], wallClockToWire(lastNight));
    });

    testWidgets('the row\'s button is named „Wasser, 250 ml eintragen"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester.getSemantics(find.byKey(LastDrinkRow.saveKey)),
        isSemantics(
          label: 'Wasser, 250 ml eintragen',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      expect(find.text('Eintragen'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Wie zuletzt, Wasser, 250 ml'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(LastDrinkRow.saveKey)).height,
        greaterThanOrEqualTo(AppConstants.minTapTarget),
      );
      handle.dispose();
    });

    testWidgets('the time line reads „Heute, <HH:mm> · ändern", opens the '
        'date and time chips and reads as expanded', (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.theme,
            localizationsDelegates: germanLocalizations,
            supportedLocales: const [germanLocale],
            locale: germanLocale,
            home: const DrinkTrackerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final at = container.read(drinkTrackerProvider).trackedAt;

      expect(find.text('Heute, ${formatTime(at)} · ändern'), findsOneWidget);
      expect(find.byType(DateTimeChips), findsNothing);
      final line = find.byKey(DrinkTimeLine.toggleKey);
      Matcher reads({required bool expanded}) => isSemantics(
        label: 'Zeitpunkt',
        value: '${formatDateWeekdayLong(at)}, ${formatTime(at)}',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasExpandedState: true,
        isExpanded: expanded,
        hasTapAction: true,
      );
      expect(tester.getSemantics(line), reads(expanded: false));

      await tester.ensureVisible(line);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(find.byType(DateTimeChips), findsOneWidget);
      expect(tester.getSemantics(line), reads(expanded: true));

      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(find.byType(DateTimeChips), findsNothing);
      handle.dispose();
    });

    testWidgets('the card is one header node and one image', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final header = find.bySemanticsLabel('Heute getrunken');
      expect(header, findsOneWidget);
      expect(
        tester.getSemantics(header),
        isSemantics(label: 'Heute getrunken', value: '500 ml', isHeader: true),
      );
      expect(find.bySemanticsLabel('500 ml'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(GlassMeter.glassesKey)),
        isSemantics(label: DrinkHelpers.glassesLabel(500, 0), isImage: true),
      );
      handle.dispose();
    });

    testWidgets('D2 state meets the tap-target, label and contrast '
        'guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer.test(
        overrides: _overrides(drinkRepo: _teaRepo()),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.theme,
            localizationsDelegates: germanLocalizations,
            supportedLocales: const [germanLocale],
            locale: germanLocale,
            home: const DrinkTrackerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final notifier = container.read(drinkTrackerProvider.notifier);
      notifier.toggleDrink(_tea);
      notifier
        ..setCustomAmount('400')
        ..openSearch();
      await tester.pumpAndSettle();
      expect(find.byKey(DrinkSearch.searchFieldKey), findsOneWidget);
      expect(find.text('400 ml Pfefferminztee eintragen'), findsOneWidget);
      expect(find.text('+ 400 ml'), findsOneWidget);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('the card and the row lay out at text scale $scale', (
        tester,
      ) async {
        // At 1.0 a wider view: the test font is wider than the phone's, so
        // label and total would wrap onto two runs at 375 px.
        tester.view
          ..physicalSize = Size(scale == 1.0 ? 600 : 375, 667)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final errors = await collectFlutterErrors(() async {
          await tester.pumpWithProviders(
            const DrinkTrackerScreen(),
            overrides: _overrides(),
          );
          await tester.pump(const Duration(milliseconds: 200));
        });
        expect(verticalOverflows(errors), isEmpty);

        final label = tester.getRect(find.text('Heute getrunken'));
        final total = tester.getRect(find.byKey(DrinkTodayCard.totalKey));
        final text = tester.getRect(find.text('Wasser, 250 ml'));
        final button = tester.getRect(find.byKey(LastDrinkRow.saveKey));
        if (scale >= AppConstants.drinkGridLargeTextScale) {
          // Stacked: the total under the label, the button under the text
          // across the row.
          expect(total.top, greaterThanOrEqualTo(label.bottom));
          expect(button.top, greaterThanOrEqualTo(text.bottom));
          final row = tester.getRect(find.byType(LastDrinkRow));
          expect(button.width, greaterThan(row.width * 0.8));
        } else {
          expect(total.left, greaterThan(label.right));
          expect(button.left, greaterThan(text.right));
        }
      });
    }

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

        // Open the search and type a query that matches multiple
        // teas so the suggestion list renders with several items.
        await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
        await tester.pump();
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
      await tester.ensureVisible(find.byKey(DrinkTrackerScreen.saveKey));
      await tester.tap(find.byKey(DrinkTrackerScreen.saveKey));
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
      await tester.ensureVisible(find.byKey(DrinkTrackerScreen.saveKey));
      await tester.tap(find.byKey(DrinkTrackerScreen.saveKey));
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
          await tester.ensureVisible(find.byKey(DrinkTrackerScreen.saveKey));
          await tester.tap(find.byKey(DrinkTrackerScreen.saveKey));
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
      await tester.ensureVisible(find.byKey(DrinkTrackerScreen.saveKey));
      // Deselect without rebuilding: the enabled button still calls _save,
      // but save() finds no drink and stores nothing.
      notifier.clearSelection();
      await tester.tap(find.byKey(DrinkTrackerScreen.saveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(drinkTrackerProvider).showSuccess, isFalse);
      expect(container.read(buddyEventsProvider), isNull);
      expect(find.byType(BuddyReactionView), findsNothing);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'on a 393×852 phone at text scale $scale with the keypad open '
        'the amount hint shows in full above the save button',
        (tester) async {
          tester.view
            ..physicalSize = const Size(393, 852)
            ..devicePixelRatio = 1
            ..padding = const FakeViewPadding(top: 59, bottom: 34);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final container = ProviderContainer.test(overrides: _overrides());
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: DrinkTrackerScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          container
              .read(drinkTrackerProvider.notifier)
              .toggleDrink(testDrink());
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
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(hint))
                .didExceedMaxLines,
            isFalse,
          );
        },
      );
    }

    testWidgets('375×667 at 200 % text with a 41-character drink, 400 ml and '
        'the search open: no overflow, the tile name ellipsised, the button '
        'label wrapped', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const name = 'Hausgemachter Ingwer-Zitronen-Kurkuma-Tee';
      expect(name.length, 41);
      final long = testDrink(id: 'long-id', name: name);
      final container = ProviderContainer.test(
        overrides: _overrides(
          drinkRepo: FakeDrinkRepository()..seedDrinks([testDrink(), long]),
        ),
      );
      addTearDown(container.dispose);
      final errors = await collectFlutterErrors(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DrinkTrackerScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        container.read(drinkTrackerProvider.notifier)
          ..toggleDrink(long)
          ..setCustomAmount('400')
          ..openSearch();
        await tester.pumpAndSettle();
      });
      expect(verticalOverflows(errors), isEmpty);
      expect(find.byKey(DrinkSearch.searchFieldKey), findsOneWidget);

      // The tile shows two lines of the name and an ellipsis, and reads the
      // whole name.
      final tile = find.byKey(QuickDrinkGrid.tileKey('long-id'));
      final tileName = tester.renderObject<RenderParagraph>(
        find.descendant(of: tile, matching: find.text(name)),
      );
      expect(tileName.maxLines, 2);
      expect(tileName.didExceedMaxLines, isTrue);
      expect(tester.getSemantics(tile).label, name);

      // The button's label wraps onto more than one line, inside it.
      final saveLabel = DrinkHelpers.saveLabel(long, 400);
      final button = find.byKey(DrinkTrackerScreen.saveKey);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final labelFinder = find.descendant(
        of: button,
        matching: find.text(saveLabel),
      );
      final label = tester.renderObject<RenderParagraph>(labelFinder);
      final oneLine = TextPainter(
        text: label.text,
        textDirection: TextDirection.ltr,
        textScaler: label.textScaler,
      )..layout();
      expect(label.size.height, greaterThan(oneLine.height));
      expect(label.didExceedMaxLines, isFalse);
      final buttonRect = tester.getRect(button);
      final labelRect = tester.getRect(labelFinder);
      expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
      expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
      oneLine.dispose();
      handle.dispose();
    });

    /// The screen pushed from an opener page; `result()` is what the push
    /// returned ('not closed' until the screen closes).
    Future<({ProviderContainer container, Object? Function() result})>
    pumpFromOpener(WidgetTester tester) async {
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
          child: germanRouterApp(router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (container: container, result: () => result);
    }

    testWidgets('after a save it closes with true for its opener', (
      tester,
    ) async {
      final (:container, :result) = await pumpFromOpener(tester);

      container.read(drinkTrackerProvider.notifier)
        ..toggleDrink(testDrink())
        ..selectAmount(250);
      await tester.pump();
      await tester.ensureVisible(find.byKey(DrinkTrackerScreen.saveKey));
      await tester.tap(find.byKey(DrinkTrackerScreen.saveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('Getränk gespeichert!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(result(), isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('after a one-tap save it closes with true for its opener', (
      tester,
    ) async {
      final (container: _, :result) = await pumpFromOpener(tester);

      await tester.ensureVisible(find.byKey(LastDrinkRow.saveKey));
      await tester.tap(find.byKey(LastDrinkRow.saveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('Getränk gespeichert!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(result(), isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a search left open does not show (or take focus) on the '
        'next visit, not even in its first frame', (tester) async {
      final (:container, result: _) = await pumpFromOpener(tester);
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();
      expect(find.byType(DrinkSearch), findsOneWidget);
      expect(container.read(drinkTrackerProvider).isSearchOpen, isTrue);

      GoRouter.of(tester.element(find.byType(DrinkTrackerScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);

      await tester.tap(find.text('open'));
      // Up to the first frame that builds the next visit (the pushed route's
      // first frame is built offstage).
      final screen = find.byType(DrinkTrackerScreen, skipOffstage: false);
      for (var i = 0; i < 10 && screen.evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(screen, findsOneWidget);
      expect(find.byType(DrinkSearch, skipOffstage: false), findsNothing);
      expect(
        tester.binding.focusManager.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DrinkSearch), findsNothing);
      expect(find.byKey(QuickDrinkGrid.searchTileKey), findsOneWidget);
    });

    group('while a save is pending', () {
      Future<({ProviderContainer container, Completer<void> gate})> pumpGated(
        WidgetTester tester,
      ) async {
        final entryRepo = _GatedEntryRepository();
        final container = ProviderContainer.test(
          overrides: _overrides(drinkRepo: _teaRepo(), entryRepo: entryRepo),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.theme,
              localizationsDelegates: germanLocalizations,
              supportedLocales: const [germanLocale],
              locale: germanLocale,
              home: const DrinkTrackerScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        return (container: container, gate: entryRepo.gate);
      }

      Future<void> finish(WidgetTester tester, Completer<void> gate) async {
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }

      testWidgets('„Eintragen" on the row: a drink tile selects nothing', (
        tester,
      ) async {
        final (:container, :gate) = await pumpGated(tester);
        await tester.tap(find.byKey(LastDrinkRow.saveKey));
        await tester.pump();
        expect(container.read(drinkTrackerProvider).isSaving, isTrue);

        await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea-id')));
        await tester.pump();
        expect(container.read(drinkTrackerProvider).selectedDrink, isNull);
        expect(find.byKey(DrinkTrackerScreen.saveKey), findsNothing);

        await finish(tester, gate);
      });

      testWidgets('the bottom button: drink and vessel tiles change nothing '
          'and keep their look', (tester) async {
        final (:container, :gate) = await pumpGated(tester);
        container.read(drinkTrackerProvider.notifier)
          ..toggleDrink(_tea)
          ..selectAmount(250);
        await tester.pump();
        await tester.ensureVisible(find.byKey(DrinkTrackerScreen.saveKey));
        await tester.tap(find.byKey(DrinkTrackerScreen.saveKey));
        await tester.pump();
        expect(container.read(drinkTrackerProvider).isSaving, isTrue);

        final water = find.byKey(QuickDrinkGrid.tileKey('water-id'));
        await tester.ensureVisible(water);
        await tester.tap(water);
        await tester.pump();
        final vessel = find.byKey(DrinkSizeSelector.vesselKey(500));
        await tester.ensureVisible(vessel);
        await tester.tap(vessel);
        await tester.pump();

        final state = container.read(drinkTrackerProvider);
        expect(state.selectedDrink, _tea);
        expect(state.selectedAmount, 250);
        // No dimming: the vessel's amount keeps the enabled text colour.
        expect(
          tester
              .widget<Text>(
                find.descendant(of: vessel, matching: find.text('500 ml')),
              )
              .style
              ?.color,
          AppTheme.foreground,
        );
        await finish(tester, gate);
      });
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

      testWidgets('„+ 250 ml" and the create row\'s text use the text tokens '
          'that meet 4.5:1', (tester) async {
        final container = await pumpWithDrink(tester);
        container.read(drinkTrackerProvider.notifier)
          ..toggleDrink(testDrink())
          ..selectAmount(250);
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('+ 250 ml')).style?.color,
          AppTheme.infoText,
        );
        container.read(drinkTrackerProvider.notifier).clearSelection();
        await tester.pump();
        await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
        await tester.pump();
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Mate');
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('„Mate" hinzufügen')).style?.color,
          AppTheme.primaryText,
        );
      });

      testWidgets('while empty, „Getränk suchen" is read once, with an '
          'example', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWithDrink(tester);
        await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
        await tester.pump();

        expectSearchFieldReadOnce(
          tester,
          name: 'Getränk suchen',
          example: 'z. B. Pfefferminztee',
          field: find.byKey(DrinkSearch.searchFieldKey),
        );
        handle.dispose();
      });

      testWidgets('the search field keeps „Getränk suchen" with text entered', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpWithDrink(tester);
        await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
        await tester.pump();
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
        await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
        await tester.pump();
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Eis');
        container.read(drinkTrackerProvider.notifier).searchDrinks('Eis');
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byTooltip('Getränk löschen'), findsOneWidget);
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
          tester.getSemantics(find.byKey(DrinkSizeSelector.vesselKey(250))),
          isSemantics(
            label: 'Glas, 250 ml',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.byKey(DrinkSizeSelector.vesselKey(500))),
          isSemantics(
            label: 'Flasche, 500 ml',
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSize(find.byKey(QuickDrinkGrid.tileKey('water-id'))).height,
          greaterThanOrEqualTo(48),
        );

        // Selected size fill: white text on infoText (4.5:1), not info.
        await tester.pump(AppConstants.animFast);
        Color? fillOf(Finder of) =>
            (tester
                        .widget<AnimatedContainer>(
                          find.descendant(
                            of: of,
                            matching: find.byType(AnimatedContainer),
                          ),
                        )
                        .decoration
                    as BoxDecoration?)
                ?.color;
        // The selected drink tile is white with an infoText border.
        expect(
          fillOf(find.byKey(QuickDrinkGrid.tileKey('water-id'))),
          AppTheme.background,
        );
        expect(
          fillOf(find.byKey(DrinkSizeSelector.vesselKey(250))),
          AppTheme.background,
        );
        expect(
          fillOf(find.byKey(DrinkSizeSelector.vesselKey(500))),
          AppTheme.card,
        );
        handle.dispose();
      });
    });
  });
}
