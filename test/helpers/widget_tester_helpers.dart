import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';

/// Taps that work on a small screen too.
extension TapVisible on WidgetTester {
  /// Scrolls [finder] into view, taps it and lets everything settle.
  Future<void> tapVisible(Finder finder) async {
    await ensureVisible(finder);
    await pumpAndSettle();
    await tap(finder);
    await pumpAndSettle();
  }
}

/// The level Home's ring shows on [need]'s meter (null for Klo).
double? needMeterLevel(WidgetTester tester, CareNeed need) => tester
    .widget<NeedMeter>(
      find.descendant(
        of: find.byKey(CareRing.needKey(need)),
        matching: find.byType(NeedMeter),
      ),
    )
    .level;

/// Pumps [step] at a time until [done] holds, at most [max] times.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration step = const Duration(milliseconds: 50),
  int max = 200,
}) async {
  for (var i = 0; i < max && !done(); i++) {
    await tester.pump(step);
  }
}

/// Pumps until the success page's charging circle is full.
Future<void> pumpPastCharge(WidgetTester tester) => tester.pump(
  AppConstants.careChargeDuration + const Duration(milliseconds: 100),
);
