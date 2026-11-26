import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/spotlight_painter.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tooltip_bubble.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/streak_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';

final _now = DateTime(2026, 11, 23, 12, 40);

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  for (final (phone, size, padding) in [
    ('375×667', const Size(375, 667), const FakeViewPadding(top: 20)),
    (
      '402×874',
      const Size(402, 874),
      const FakeViewPadding(top: 62, bottom: 34),
    ),
  ]) {
    testWidgets('$phone: „Überspringen" covers nothing lit in any step (the '
        'streak chip, the ring\'s needs) nor the step\'s bubble', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1
        ..padding = padding;
      addTearDown(tester.view.reset);
      final container = ProviderContainer.test(
        overrides: [
          ...baseOverrides(entries: FakeEntryRepository()),
          buddyTodayProvider.overrideWithValue(() => _now),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AppTestHost(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(tutorialProvider.notifier).requestReplay();
      container.read(routerProvider).go(RoutePaths.dashboard);
      await tester.pumpAndSettle();

      for (final (i, _) in dashboardTutorialSteps.indexed) {
        final skip = tester.getRect(
          find.byKey(DashboardTutorialOverlay.skipKey),
        );
        final spotlight = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.painter)
            .whereType<SpotlightPainter>()
            .single
            .targetRect;
        // The step's bubble, and whatever of Home is lit.
        final covered = <String, Rect>{
          'bubble': tester.getRect(find.byType(TooltipBubble)),
          for (final (what, finder) in [
            ('streak badge', find.byType(StreakBadge)),
            for (final need in CareNeed.values)
              (need.label, find.byKey(CareRing.needKey(need))),
          ])
            if (tester.getRect(finder).overlaps(spotlight))
              what: tester.getRect(finder),
        };
        for (final MapEntry(key: what, value: rect) in covered.entries) {
          expect(
            skip.overlaps(rect),
            isFalse,
            reason: 'step $i: $what $rect under the pill $skip',
          );
        }
        await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
        await tester.pumpAndSettle();
      }
      expect(find.byType(DashboardTutorialOverlay), findsNothing);
    });
  }
}
