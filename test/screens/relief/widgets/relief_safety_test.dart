import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/screens/relief/widgets/relief_safety.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';

void main() {
  final opened = <Uri>[];
  var openResult = true;

  Future<bool> fakeOpen(
    Uri url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    opened.add(url);
    return openResult;
  }

  setUp(() {
    opened.clear();
    openResult = true;
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReliefSafetySheet(context, open: fakeOpen),
              child: const Text('öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet lists every number', (tester) async {
    await openSheet(tester);
    expect(find.text(ReliefCopy.safetySheetTitle), findsOneWidget);
    for (final number in ['144', '112', '1450', '116 117']) {
      expect(find.text(number), findsOneWidget, reason: number);
    }
  });

  testWidgets('a number opens the dialer', (tester) async {
    await openSheet(tester);
    await tester.ensureVisible(find.text('112'));
    await tester.tap(find.text('112'));
    await tester.pumpAndSettle();
    expect(opened, [Uri(scheme: 'tel', path: '112')]);
    expect(find.text(ReliefCopy.dialFailed('112')), findsNothing);
  });

  testWidgets('116 117 dials without the space', (tester) async {
    await openSheet(tester);
    await tester.ensureVisible(find.text('116 117'));
    await tester.tap(find.text('116 117'));
    await tester.pumpAndSettle();
    expect(opened, [Uri(scheme: 'tel', path: '116117')]);
  });

  testWidgets('when the dialer cannot open, says to dial directly', (
    tester,
  ) async {
    openResult = false;
    await openSheet(tester);
    await tester.ensureVisible(find.text('112'));
    await tester.tap(find.text('112'));
    await tester.pumpAndSettle();
    expect(find.text('Wähl bitte direkt 112.'), findsOneWidget);
  });

  testWidgets('tapping the line opens the sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReliefSafetyLine())),
    );
    expect(find.text(ReliefCopy.safetyLine), findsOneWidget);
    await tester.tap(find.text(ReliefCopy.safetyLine));
    await tester.pumpAndSettle();
    expect(find.text(ReliefCopy.safetyIntro), findsOneWidget);
  });
}
