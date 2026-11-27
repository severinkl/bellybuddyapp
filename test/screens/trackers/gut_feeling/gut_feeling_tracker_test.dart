// ignore_for_file: invalid_use_of_internal_member
import 'dart:ui' show SemanticsFlag;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/widgets/mood_tab_selector.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/care_log_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:belly_buddy/widgets/common/mood_slider_row.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/widgets/buddy/log_success_hero.dart';
import 'package:belly_buddy/widgets/buddy/need_icon.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';
import 'package:belly_buddy/config/constants.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/layout_checks.dart';
import '../../../helpers/riverpod_helpers.dart';
import '../../../helpers/widget_tester_helpers.dart';
import '../../../helpers/reduce_motion.dart';

List<Override> _overrides([FakeEntryRepository? entries]) => [
  entryRepositoryProvider.overrideWithValue(entries ?? FakeEntryRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('GutFeelingTrackerScreen', () {
    testWidgets('renders screen appBar title', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      // Use pump with duration to let entry animations start
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Wie geht es dir?'), findsOneWidget);
    });

    testWidgets('renders two tab options', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // MoodTabSelector has "Bauchgefühl" and "Stimmung" tabs
      expect(find.text('Bauchgefühl'), findsOneWidget);
      expect(find.text('Stimmung'), findsOneWidget);
    });

    testWidgets('the symptom sliders start at „gar nicht"', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('gar nicht'), findsWidgets);
      expect(find.text('garnicht'), findsNothing);
    });

    testWidgets('VoiceOver reads each symptom slider by its name and as '
        '„N von 5", not in percent', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      // Past the entry fade-in (hidden from screen readers until shown).
      await tester.pump(const Duration(seconds: 1));

      final sliders = find.semantics
          .byFlag(SemanticsFlag.isSlider)
          .evaluate()
          .toList();
      expect(sliders, hasLength(4));
      for (var i = 0; i < 4; i++) {
        final node = sliders[i];
        expect(node.label, AppConstants.gutFeelingSymptoms[i]);
        expect(node.value, '1 von 5');
        expect(node.increasedValue, '2 von 5');
        expect(node.value, isNot(contains('%')));
      }
      semantics.dispose();
    });

    testWidgets('renders weiter button on first tab', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Weiter'), findsOneWidget);
    });

    testWidgets('renders PageView with two pages', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('successful save emits a Buddy event and shows the reaction', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GutFeelingTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Weiter'));
      // Page slide (350 ms): start, finish, rebuild with the new label.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      // The Buddy animates forever: pump past the overlay intro only.
      await tester.pump(const Duration(milliseconds: 700));

      final event = container.read(buddyEventsProvider);
      expect(event?.kind, EntryKind.gutFeeling);
      // All sliders at their default 1 → spiGut → good.
      expect(event?.sentiment, LogSentiment.good);
      expect(find.text('Eintrag gespeichert!'), findsOneWidget);
      final view = tester.widget<BuddyReactionView>(
        find.byType(BuddyReactionView),
      );
      expect(view.kind, EntryKind.gutFeeling);
      expect(view.sentiment, LogSentiment.good);
      expect(find.byType(MascotImage), findsNothing);
    });

    testWidgets('the Bauchgefühl page charges Bauchgefühl', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // A past day's entry is logged at 12:00; the clock reads 12:00 too.
      await tester.pumpWithProviders(
        GutFeelingTrackerScreen(initialDate: DateTime(2026, 11, 23)),
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 12),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final meter = tester.widget<ChargingMeter>(find.byType(ChargingMeter));
      expect(meter.need, CareNeed.gutFeeling);
      expect(meter.from, AppConstants.careMeterFloor);
      expect(meter.to, 1.0);
      expect(
        find.descendant(
          of: find.byType(LogSuccessHero),
          matching: find.byType(BuddyReactionView),
        ),
        findsOneWidget,
      );
    });

    Future<ProviderContainer> saveWithLine(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 12),
          ),
          insightsProviderSeededWith(lockedInsights()),
          careLogProvider.overrideWithValue(const CareLog()),
          buddyProvider.overrideWith(
            () => FakeBuddyNotifier(() => buddyStatus(streak: 4)),
          ),
        ],
      );
      await container.read(insightsProvider.future);
      await container.read(buddyProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GutFeelingTrackerScreen(initialDate: DateTime(2026, 11, 23)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await pumpPastCharge(tester);
      return container;
    }

    testWidgets("the day's first Bauchgefühl, locked: the Buddy says how far "
        'it is', (tester) async {
      await saveWithLine(tester);

      const line = 'Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.';
      expect(find.text(line), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('fits 375×667 at text scale $scale with the line and the '
          'ignite row', (tester) async {
        tester.view.physicalSize = const Size(750, 1334);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final errors = await collectFlutterErrors(() => saveWithLine(tester));

        expect(find.byKey(LogSuccessHero.igniteKey), findsOneWidget);
        expect(
          tester
              .widget<LogSuccessHero>(find.byType(LogSuccessHero))
              .moment
              .buddyLine,
          isNotNull,
        );
        expectSuccessPageFits(
          tester,
          errors,
          page: find.byType(BbSuccessOverlay),
        );
      });
    }

    Future<ProviderContainer> pumpTracker(
      WidgetTester tester,
      FakeEntryRepository entries,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides(entries));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GutFeelingTrackerScreen()),
        ),
      );
      // Past the entry animation, so the mascots take taps.
      await tester.pump(const Duration(milliseconds: 700));
      return container;
    }

    Future<void> tapMascot(WidgetTester tester, String asset) async {
      final mascot = find.byWidgetPredicate(
        (w) => w is MascotImage && w.assetPath == asset,
      );
      await tester.ensureVisible(mascot);
      await tester.pump();
      await tester.tap(mascot);
      await tester.pump();
    }

    Future<void> goToStimmungAndSave(WidgetTester tester) async {
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('an untouched Stimmung tab saves no mood values', (
      tester,
    ) async {
      final entries = FakeEntryRepository();
      await pumpTracker(tester, entries);

      await goToStimmungAndSave(tester);

      final saved = entries.inserted.single;
      for (final key in ['stress', 'happiness', 'energy', 'focus']) {
        expect(saved[key], isNull, reason: key);
      }
      expect(saved['body_feel'], isNull);
      expect(saved['bloating'], 1);
    });

    testWidgets('a mood slider the user set is saved', (tester) async {
      final entries = FakeEntryRepository();
      await pumpTracker(tester, entries);
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      await tapMascot(tester, AppConstants.mascotStressed);
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final saved = entries.inserted.single;
      expect(saved['stress'], 5);
      expect(saved['happiness'], isNull);
    });

    testWidgets('Krämpfe 5 and Völlegefühl 5 make a hard day for the Buddy', (
      tester,
    ) async {
      final entries = FakeEntryRepository();
      final container = await pumpTracker(tester, entries);

      await tapMascot(tester, AppConstants.mascotCramp);
      await tapMascot(tester, AppConstants.mascotFullness);
      await goToStimmungAndSave(tester);

      expect(entries.inserted.single['cramps'], 5);
      expect(entries.inserted.single['fullness'], 5);
      final event = container.read(buddyEventsProvider);
      expect(event?.sentiment, LogSentiment.bad);
      final view = tester.widget<BuddyReactionView>(
        find.byType(BuddyReactionView),
      );
      expect(view.sentiment, LogSentiment.bad);
      // No celebration after a hard day: the calm success screen.
      final overlay = tester.widget<BbSuccessOverlay>(
        find.byType(BbSuccessOverlay),
      );
      expect(overlay.calm, isTrue);
      expect(overlay.message, isNot(contains('!')));
    });

    testWidgets('after a hard day the calm page lights no „Tag n", even on '
        "today's first entry", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 14),
          ),
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
          child: MaterialApp(
            home: GutFeelingTrackerScreen(initialDate: DateTime(2026, 11, 23)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      await tapMascot(tester, AppConstants.mascotCramp);
      await tapMascot(tester, AppConstants.mascotFullness);
      await goToStimmungAndSave(tester);

      expect(
        tester.widget<BbSuccessOverlay>(find.byType(BbSuccessOverlay)).calm,
        isTrue,
      );
      // Today's first entry: it does make day 5 …
      expect(
        tester
            .widget<LogSuccessHero>(find.byType(LogSuccessHero))
            .moment
            .ignitesDay,
        5,
      );
      // … but the calm page cheers no progress.
      expect(find.byKey(LogSuccessHero.igniteKey), findsNothing);
      expect(find.text('Tag 5'), findsNothing);
    });

    testWidgets('a good day gets the cheerful success screen', (tester) async {
      final entries = FakeEntryRepository();
      await pumpTracker(tester, entries);

      await goToStimmungAndSave(tester);

      final overlay = tester.widget<BbSuccessOverlay>(
        find.byType(BbSuccessOverlay),
      );
      expect(overlay.calm, isFalse);
    });

    /// The asset the charging circle's belly draws.
    String chargingBelly(WidgetTester tester) {
      final icon = tester.widget<NeedIcon>(
        find.descendant(
          of: find.byType(ChargingMeter),
          matching: find.byType(NeedIcon),
        ),
      );
      return NeedIcon.assetFor(icon.need, gutFeeling: icon.gutFeeling);
    }

    testWidgets('„Schlecht": the calm page\'s charging belly has its mouth', (
      tester,
    ) async {
      await pumpTracker(tester, FakeEntryRepository());

      await tapMascot(tester, AppConstants.mascotCramp);
      await goToStimmungAndSave(tester);

      expect(
        tester.widget<BbSuccessOverlay>(find.byType(BbSuccessOverlay)).calm,
        isTrue,
      );
      expect(
        chargingBelly(tester),
        NeedIcon.assetFor(
          CareNeed.gutFeeling,
          gutFeeling: GutFeelingRatingLevel.schlecht,
        ),
      );
    });

    testWidgets('„Sehr gut": the charging belly smiles wide open', (
      tester,
    ) async {
      await pumpTracker(tester, FakeEntryRepository());

      // All symptoms at „gar nicht".
      await goToStimmungAndSave(tester);

      expect(
        chargingBelly(tester),
        NeedIcon.assetFor(
          CareNeed.gutFeeling,
          gutFeeling: GutFeelingRatingLevel.spiGut,
        ),
      );
      expect(
        chargingBelly(tester),
        isNot(NeedIcon.assetFor(CareNeed.gutFeeling)),
      );
    });

    testWidgets('on a phone, the Stimmung rows end above Speichern', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622); // iPhone 17
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpTracker(tester, FakeEntryRepository());

      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final button = find.ancestor(
        of: find.text('Speichern'),
        matching: find.byType(BbButton),
      );
      expect(button, findsOneWidget);
      final buttonTop = tester.getRect(button).top;
      expect(
        tester.getRect(find.byType(PageView)).bottom,
        lessThanOrEqualTo(buttonTop),
        reason: 'the content ends above the pinned button, not under it',
      );
      await tester.ensureVisible(find.text('unwohl'));
      await tester.pump();
      expect(tester.getRect(find.text('unwohl')).bottom, lessThan(buttonTop));
    });

    testWidgets('with disableAnimations the screen enters without animating', (
      tester,
    ) async {
      reduceMotion(tester);
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      for (final content in [
        find.byType(MoodTabSelector),
        find.byType(PageView),
      ]) {
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(of: content, matching: find.byType(FadeTransition))
              .first,
        );
        final slide = tester.widget<SlideTransition>(
          find
              .ancestor(of: content, matching: find.byType(SlideTransition))
              .first,
        );
        expect(fade.opacity.value, 1);
        expect(slide.position.value, Offset.zero);
      }

      // „Weiter" switches the page without sliding.
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      expect(find.text('Speichern'), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
    });

    testWidgets('the tabs are selected/unselected buttons, each ≥ 48 high', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(seconds: 1));

      for (final (label, selected) in [
        ('Bauchgefühl', true),
        ('Stimmung', false),
      ]) {
        final tab = find.descendant(
          of: find.byType(MoodTabSelector),
          matching: find.text(label),
        );
        final node = tester.getSemantics(tab);
        expect(
          node,
          isSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: selected,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        );
        expect(node.rect.height, greaterThanOrEqualTo(48), reason: label);
      }

      tester.semantics.tap(find.semantics.byLabel('Stimmung'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(MoodTabSelector),
            matching: find.text('Stimmung'),
          ),
        ),
        isSemantics(
          label: 'Stimmung',
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    group('Ruhe für den Bauch offer', () {
      final offer = find.text(ReliefCopy.gutFeelingOffer);

      /// The tracker pushed over `page:/from` in a router with `/relief`;
      /// the feature gate is [relief].
      Future<GoRouter> pumpRouted(
        WidgetTester tester, {
        bool relief = true,
        DateTime? initialDate,
        double textScale = 1,
      }) async {
        SharedPreferences.setMockInitialValues({});
        final router = GoRouter(
          initialLocation: '/from',
          routes: [
            ...stubRoutes(['/from', RoutePaths.relief, RoutePaths.dashboard]),
            GoRoute(
              path: '/track',
              builder: (_, _) =>
                  GutFeelingTrackerScreen(initialDate: initialDate),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._overrides(),
              reliefEnabledProvider.overrideWithValue(relief),
            ],
            child: germanRouterApp(router, textScale: textScale),
          ),
        );
        router.push('/track');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        return router;
      }

      testWidgets('Krämpfe 5: the success page offers calm; the tap opens '
          '/relief in place of the tracker', (tester) async {
        final router = await pumpRouted(tester);

        await tapMascot(tester, AppConstants.mascotCramp);
        await goToStimmungAndSave(tester);

        expect(offer, findsOneWidget);
        await tester.tap(offer);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('page:${RoutePaths.relief}'), findsOneWidget);
        // Not dismissed as well: the tracker was replaced, nothing popped.
        expect(find.text('page:/from'), findsNothing);
        expect(
          find.byType(GutFeelingTrackerScreen, skipOffstage: false),
          findsNothing,
        );
        // Back returns to where the entry was logged from.
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('page:/from'), findsOneWidget);
        expect(find.text('page:${RoutePaths.relief}'), findsNothing);
      });

      testWidgets('the whole pill is the target, edge included', (
        tester,
      ) async {
        await pumpRouted(tester);
        await tapMascot(tester, AppConstants.mascotCramp);
        await goToStimmungAndSave(tester);

        final pill = find.ancestor(of: offer, matching: find.byType(Container));
        final rect = tester.getRect(pill.first);
        expect(rect.height, greaterThanOrEqualTo(AppConstants.minTapTarget));
        await tester.tapAt(rect.topCenter + const Offset(0, 3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('page:${RoutePaths.relief}'), findsOneWidget);
      });

      testWidgets('every symptom at 2: no offer', (tester) async {
        await pumpRouted(tester);

        for (final row in tester.widgetList<MoodSliderRow>(
          find.byType(MoodSliderRow),
        )) {
          row.onChanged(2);
        }
        await tester.pump();
        await goToStimmungAndSave(tester);

        expect(find.byType(BbSuccessOverlay), findsOneWidget);
        expect(offer, findsNothing);
      });

      testWidgets('the feature off: Krämpfe 5 offers nothing', (tester) async {
        await pumpRouted(tester, relief: false);

        await tapMascot(tester, AppConstants.mascotCramp);
        await goToStimmungAndSave(tester);

        expect(find.byType(BbSuccessOverlay), findsOneWidget);
        expect(offer, findsNothing);
      });

      testWidgets('Krämpfe 5 logged for yesterday: no offer', (tester) async {
        await pumpRouted(
          tester,
          initialDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        await tapMascot(tester, AppConstants.mascotCramp);
        await goToStimmungAndSave(tester);

        expect(find.byType(BbSuccessOverlay), findsOneWidget);
        expect(offer, findsNothing);
      });

      for (final scale in [1.0, 1.3]) {
        testWidgets('fits 375×667 at text scale $scale with the offer', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(750, 1334);
          tester.view.devicePixelRatio = 2;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final errors = await collectFlutterErrors(() async {
            await pumpRouted(tester);
            await tapMascot(tester, AppConstants.mascotCramp);
            await goToStimmungAndSave(tester);
            await pumpPastCharge(tester);
          });

          expect(offer, findsOneWidget);
          expectSuccessPageFits(
            tester,
            errors,
            page: find.byType(BbSuccessOverlay),
          );
        });
      }

      // At text scale 2 the wrapped offer leaves the Buddy too little room
      // on smaller phones (iPhone 17: 12 px); the largest phone fits.
      testWidgets('fits 440×956 at text scale 2 with the offer', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1320, 2868);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final errors = await collectFlutterErrors(() async {
          await pumpRouted(tester, textScale: 2);
          await tapMascot(tester, AppConstants.mascotCramp);
          await goToStimmungAndSave(tester);
          await pumpPastCharge(tester);
        });

        expect(offer, findsOneWidget);
        expectSuccessPageFits(
          tester,
          errors,
          page: find.byType(BbSuccessOverlay),
        );
      });
    });
  });
}
