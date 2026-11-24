import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/dashboard/widgets/first_tip_offer_sheet.dart';
import 'package:belly_buddy/widgets/buddy/buddy_speech_bubble.dart';

import '../../../helpers/layout_checks.dart';

const _line =
    'Ich hab genug für deinen ersten Tipp! Soll ich ihn dir machen? ✨';
const _body =
    'Dann schalte ich die wöchentlichen Tipps ein: jeden Montag 2–3 Tipps. '
    'Dafür schicke ich deine Einträge der letzten Wochen, die Muster daraus '
    'und deine Bewertungen meiner Tipps an unseren KI-Dienst. Ausschalten '
    'kannst du sie jederzeit unter Entdecken oder in den Einstellungen.';

void main() {
  /// A page whose „open" button opens the sheet; each answer goes to
  /// [results].
  Future<void> pumpOpener(WidgetTester tester, List<FirstTipAnswer?> results) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async =>
                    results.add(await showFirstTipOfferSheet(c)),
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

  /// Lets the sheet slide out.
  Future<void> close(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows the line, the KI-Dienst sentence and both buttons', (
    tester,
  ) async {
    await pumpOpener(tester, []);
    await openSheet(tester);

    expect(FirstTipOfferSheet.line, _line);
    expect(FirstTipOfferSheet.body, _body);
    expect(find.text(glueClosingSymbol(_line)), findsOneWidget);
    expect(find.text(_body), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(FirstTipOfferSheet.yesKey),
        matching: find.text('Ja, gern'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(FirstTipOfferSheet.noKey),
        matching: find.text('Nein, danke'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('yes / no / dismissed → yes / no / null', (tester) async {
    final results = <FirstTipAnswer?>[];
    await pumpOpener(tester, results);

    await openSheet(tester);
    await tester.tap(find.byKey(FirstTipOfferSheet.yesKey));
    await close(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(FirstTipOfferSheet.noKey));
    await close(tester);
    await openSheet(tester);
    await tester.tapAt(const Offset(10, 10)); // modal barrier
    await close(tester);

    expect(results, [FirstTipAnswer.yes, FirstTipAnswer.no, null]);
    expect(find.byType(FirstTipOfferSheet), findsNothing);
  });

  testWidgets('both buttons on screen at 375×667, text scale 1.3', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(375, 667)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final errors = await collectFlutterErrors(() async {
      await pumpOpener(tester, []);
      await openSheet(tester);
    });

    expect(verticalOverflows(errors), isEmpty);
    // Without scrolling: as the sheet opened.
    for (final key in [FirstTipOfferSheet.yesKey, FirstTipOfferSheet.noKey]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(667));
    }
  });
}
