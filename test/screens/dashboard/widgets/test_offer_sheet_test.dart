import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/screens/dashboard/widgets/test_offer_sheet.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';

const _zwiebel = TestSubject('ingredient', 'zwiebel', 'Zwiebel');

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
                    results.add(await showTestOfferSheet(c, subject: _zwiebel)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapAndClose(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the copy of spec §5.5: title, body, „Ansehen" and „Später"', (
    tester,
  ) async {
    await pumpOpener(tester, []);
    await openSheet(tester);

    expect(
      find.text(glueClosingSymbol('Magst du was ausprobieren?')),
      findsOneWidget,
    );
    expect(
      find.text(
        'An schweren Tagen war oft Zwiebel dabei. Wollen wir testen, ob dein '
        'Bauch ohne besser klarkommt? 5 Tage ohne, dann 3 Tage mit.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(TestOfferSheet.openKey),
        matching: find.text('Ansehen'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(TestOfferSheet.laterKey),
        matching: find.text('Später'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('true for „Ansehen", false for „Später" or when dismissed', (
    tester,
  ) async {
    final results = <bool>[];
    await pumpOpener(tester, results);

    await openSheet(tester);
    await tapAndClose(tester, find.byKey(TestOfferSheet.openKey));
    await openSheet(tester);
    await tapAndClose(tester, find.byKey(TestOfferSheet.laterKey));
    await openSheet(tester);
    await tester.tapAt(const Offset(10, 10)); // modal barrier
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [true, false, false]);
    expect(find.byType(TestOfferSheet), findsNothing);
  });

  testWidgets('48 px tap targets, labelled, readable contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOpener(tester, []);
    await openSheet(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
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
    for (final key in [TestOfferSheet.openKey, TestOfferSheet.laterKey]) {
      expect(tester.getRect(find.byKey(key)).bottom, lessThanOrEqualTo(667));
    }
  });
}
