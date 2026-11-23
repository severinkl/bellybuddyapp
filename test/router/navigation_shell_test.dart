import 'dart:ui' as ui;

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/router/tab_navigation.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/spotlight_painter.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tooltip_bubble.dart';
import 'package:belly_buddy/screens/diary/diary_screen.dart';
import 'package:belly_buddy/screens/discover/discover_screen.dart';
import 'package:belly_buddy/screens/me/me_screen.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';
import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

/// Monday, 23 Nov 2026, 12:40: lunch time.
final _now = DateTime(2026, 11, 23, 12, 40);

/// Signed in, consented, Buddy onboarded; today has a breakfast at 09:00.
Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size screen = const Size(400, 860),
}) async {
  tester.view
    ..physicalSize = screen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(
    overrides: [
      ...baseOverrides(
        entries: FakeEntryRepository()
          ..seedResult(
            testEntryQueryResult(
              meals: [testMealEntry(trackedAt: DateTime(2026, 11, 23, 9))],
              toiletEntries: [],
              gutFeelings: [],
              drinks: [],
            ),
          ),
      ),
      buddyTodayProvider.overrideWithValue(() => _now),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AppTestHost()),
  );
  await tester.pumpAndSettle();
  return container;
}

String _currentPath(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

/// [finder] inside the bottom bar.
Finder _inBar(Finder finder) =>
    find.descendant(of: find.byType(BbBottomNav), matching: finder);

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Only [need] is highlighted in the sheet (none for null).
void _expectSelected(WidgetTester tester, CareNeed? need) {
  for (final option in CareNeed.values) {
    expect(
      tester.getSemantics(find.byKey(LogSheet.optionKey(option))),
      isSemantics(isSelected: option == need, hasSelectedState: true),
      reason: option.name,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  group('four-tab shell', () {
    testWidgets('bar shows five slots in order', (tester) async {
      await _pumpShell(tester);

      final labels = ['Home', 'Tagebuch', 'Eintragen', 'Entdecken', 'Ich'];
      final xs = [
        for (final label in labels)
          tester.getCenter(_inBar(find.text(label))).dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(
          xs[i],
          greaterThan(xs[i - 1]),
          reason: '${labels[i]} right of ${labels[i - 1]}',
        );
      }
      expect(_inBar(find.text('Essen tracken')), findsNothing);
    });

    testWidgets('tabs switch branches', (tester) async {
      final container = await _pumpShell(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      await _tap(tester, BbBottomNav.navDiscoverKey);
      expect(_currentPath(container), RoutePaths.discover);
      expect(find.byType(DiscoverScreen), findsOneWidget);

      await _tap(tester, BbBottomNav.navMeKey);
      expect(_currentPath(container), RoutePaths.me);
      expect(find.byType(MeScreen), findsOneWidget);

      await _tap(tester, BbBottomNav.navDiaryKey);
      expect(_currentPath(container), RoutePaths.diary);
      expect(find.byType(DiaryScreen), findsOneWidget);

      await _tap(tester, BbBottomNav.navHomeKey);
      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('no swipe between tabs', (tester) async {
      final container = await _pumpShell(tester);
      // A fine touch slop: a drag from the very edge is still at the edge
      // when it is recognised, as an edge swipe would need.
      tester.view.gestureSettings = const ui.GestureSettings(
        physicalTouchSlop: 2,
      );
      addTearDown(tester.view.resetGestureSettings);
      await tester.pumpAndSettle();
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final y = tester.getCenter(find.byType(DashboardScreen)).dy;

      // From the right edge leftwards (the old swipe to the Tagebuch), and
      // from the left edge rightwards.
      for (final (from, by) in [
        (Offset(width - 1, y), const Offset(-250, 0)),
        (Offset(1, y), const Offset(250, 0)),
      ]) {
        await tester.timedDragFrom(from, by, const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(_currentPath(container), RoutePaths.dashboard, reason: '$by');
      }
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('plus on Home opens the sheet for now with the suggested '
        'need', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);

      await _tap(tester, BbBottomNav.centerButtonKey);
      expect(find.byType(LogSheet), findsOneWidget);
      expect(find.text('Heute · 12:40'), findsOneWidget);
      // Breakfast is logged; at 12:40 lunch is next.
      _expectSelected(tester, CareNeed.food);
      handle.dispose();
    });

    testWidgets('plus on the Tagebuch logs for the shown day', (tester) async {
      final handle = tester.ensureSemantics();
      final container = await _pumpShell(tester);

      await _tap(tester, BbBottomNav.navDiaryKey);
      container.read(diaryDateProvider.notifier).set(DateTime(2026, 11, 18));
      await tester.pumpAndSettle();

      await _tap(tester, BbBottomNav.centerButtonKey);
      expect(find.text('Für Mi, 18. Nov'), findsOneWidget);
      _expectSelected(tester, null);
      handle.dispose();
    });

    testWidgets('tapping Tagebuch resets to today', (tester) async {
      final container = await _pumpShell(tester);
      container.read(diaryDateProvider.notifier).set(DateTime(2026, 11, 18));

      await _tap(tester, BbBottomNav.navDiaryKey);
      expect(_currentPath(container), RoutePaths.diary);
      expect(container.read(diaryDateProvider), DateTime(2026, 11, 23));
    });

    testWidgets('openDiaryOn opens the Tagebuch on that day', (tester) async {
      final container = await _pumpShell(tester);

      // The bar is a ConsumerWidget: its element is a WidgetRef.
      final element = tester.element(find.byType(BbBottomNav));
      openDiaryOn(element, element as WidgetRef, DateTime(2026, 11, 18, 15));
      await tester.pumpAndSettle();

      expect(_currentPath(container), RoutePaths.diary);
      expect(find.byType(DiaryScreen), findsOneWidget);
      expect(container.read(diaryDateProvider), DateTime(2026, 11, 18));
    });

    testWidgets('5-slot bar fits 375×667 at text scale 1.3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpShell(tester, screen: const Size(375, 667));
      expect(tester.takeException(), isNull);

      // Each tab once, so each label is drawn active (bold) too.
      for (final key in [
        BbBottomNav.navDiaryKey,
        BbBottomNav.navDiscoverKey,
        BbBottomNav.navMeKey,
        BbBottomNav.navHomeKey,
      ]) {
        await _tap(tester, key);
        expect(tester.takeException(), isNull, reason: '$key');
      }
    });

    testWidgets('Home fits 375×667 at text scale 1.3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpShell(tester, screen: const Size(375, 667));
      expect(tester.takeException(), isNull);

      // Scrolled into view, the insight card ends above the bar.
      final card = find.byKey(InsightCard.cardKey);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(card).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(BbBottomNav)).top),
      );
    });

    testWidgets('the tour spotlights all 7 targets and keeps its bubbles on '
        'a 375×667 phone at text scale 1.3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.padding = const FakeViewPadding(top: 20);
      final container = await _pumpShell(tester, screen: const Size(375, 667));

      // „Tutorial wiederholen" in the Ich tab.
      await _tap(tester, BbBottomNav.navMeKey);
      container.read(tutorialProvider.notifier).requestReplay();
      container.read(routerProvider).go(RoutePaths.dashboard);
      await tester.pumpAndSettle();

      for (final (i, step) in dashboardTutorialSteps.indexed) {
        // No step skipped: each shows its own text, spotlit on its target
        // (the insight card scrolled into view first).
        final target = tester.getRect(find.byKey(step.targetKey));
        final spotlight = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.painter)
            .whereType<SpotlightPainter>()
            .single
            .targetRect;
        expect(
          spotlight,
          target.inflate(AppConstants.spacingXs),
          reason: 'step $i',
        );
        final bubble = find.byType(TooltipBubble);
        expect(
          tester.widget<TooltipBubble>(bubble).richText,
          step.richText,
          reason: 'step $i',
        );
        final rect = tester.getRect(bubble);
        expect(rect.top, greaterThanOrEqualTo(20), reason: 'step $i');
        expect(rect.bottom, lessThanOrEqualTo(667), reason: 'step $i');
        expect(tester.takeException(), isNull, reason: 'step $i');

        await _tap(tester, DashboardTutorialOverlay.advanceKey);
      }
      expect(find.byType(DashboardTutorialOverlay), findsNothing);
    });
  });
}
