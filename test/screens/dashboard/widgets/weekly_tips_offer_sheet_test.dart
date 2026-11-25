import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/weekly_tips_offer_sheet.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';

const _line =
    'Ich seh schon erste Muster! Magst du jeden Montag Tipps von mir? ✨';
const _body =
    'In den Einstellungen kannst du sie einschalten. Dafür schicke ich deine '
    'Einträge der letzten Wochen, die Muster daraus und deine Bewertungen '
    'meiner Tipps an unseren KI-Dienst.';

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
    // A tall screen: the Buddy at his full sheet height.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOpener(tester, []);
    await openSheet(tester);

    expect(WeeklyTipsOfferSheet.body, _body);
    expect(find.text(glueClosingSymbol(_line)), findsOneWidget);
    expect(
      tester.getSize(find.byType(BuddyStage)).height,
      AppConstants.streakSheetBuddyHeight,
    );
    expect(find.text(_body), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(WeeklyTipsOfferSheet.openKey),
        matching: find.text('Zu den Einstellungen'),
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

  testWidgets('true for „Zu den Einstellungen", false for „Später" or when '
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
    // The compact Buddy keeps both buttons on screen without scrolling.
    for (final key in [
      WeeklyTipsOfferSheet.openKey,
      WeeklyTipsOfferSheet.laterKey,
    ]) {
      expect(tester.getRect(find.byKey(key)).bottom, lessThanOrEqualTo(667));
    }
  });
}
