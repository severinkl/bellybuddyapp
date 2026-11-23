import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/weekly_tips_offer_sheet.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';

const _line =
    'Ich seh schon erste Muster! Magst du jeden Montag Tipps von mir? ✨';
const _body =
    'Unter Entdecken kannst du sie einschalten. Dafür schicke ich deine '
    'Mahlzeiten und dein Bauchgefühl der letzten Woche an unseren KI-Dienst.';

void main() {
  /// A page whose „open" button opens the sheet; each result goes to
  /// [results].
  Future<void> pumpOpener(WidgetTester tester, List<bool> results) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async =>
                    results.add(await showWeeklyTipsOfferSheet(c)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  /// Taps „open" and lets the sheet slide in.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Taps [finder] and lets the sheet close.
  Future<void> tapAndClose(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows the line, the sentence and both buttons', (tester) async {
    await pumpOpener(tester, []);
    await openSheet(tester);

    expect(find.text(glueClosingSymbol(_line)), findsOneWidget);
    expect(
      tester.getSize(find.byType(BuddyStage)).height,
      AppConstants.streakSheetBuddyHeight,
    );
    expect(find.text(_body), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(WeeklyTipsOfferSheet.openKey),
        matching: find.text('Zu den Tipps'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(WeeklyTipsOfferSheet.laterKey),
        matching: find.text('Später'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('true for „Zu den Tipps", false for „Später" or when '
      'dismissed', (tester) async {
    final results = <bool>[];
    await pumpOpener(tester, results);

    await openSheet(tester);
    await tapAndClose(tester, find.byKey(WeeklyTipsOfferSheet.openKey));
    await openSheet(tester);
    await tapAndClose(tester, find.byKey(WeeklyTipsOfferSheet.laterKey));
    await openSheet(tester);
    await tester.tapAt(const Offset(10, 10)); // modal barrier
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [true, false, false]);
    expect(find.byType(WeeklyTipsOfferSheet), findsNothing);
  });

  testWidgets('fits 375×667 at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpOpener(tester, []);
    await openSheet(tester);

    expect(tester.takeException(), isNull);
    // Both buttons on screen without scrolling.
    expect(
      tester.getRect(find.byKey(WeeklyTipsOfferSheet.laterKey)).bottom,
      lessThanOrEqualTo(667),
    );
  });
}
