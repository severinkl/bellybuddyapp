import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/discover/widgets/example_tip_card.dart';
import 'package:belly_buddy/widgets/common/bb_card.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProviderSeededWith(testUserProfile())],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ExampleTipCard(),
                      SizedBox(height: 12),
                      BbCard(child: WeeklyTipsSwitch()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('labelled as an example', (tester) async {
    await pump(tester);

    expect(find.text('BEISPIEL'), findsOneWidget);
    expect(find.text('So sieht ein Tipp aus'), findsOneWidget);
    expect(find.text(ExampleTipCard.title), findsOneWidget);
    expect(find.text(ExampleTipCard.footer), findsOneWidget);
  });

  testWidgets('a dashed outline', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byKey(ExampleTipCard.cardKey),
        matching: find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString().contains('DashedBorder'),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('speaks as one example', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      tester.getSemantics(find.byKey(ExampleTipCard.cardKey)).label,
      startsWith('Beispiel-Tipp: Zwiebel mal tauschen?'),
    );
    handle.dispose();
  });

  testWidgets('fits 375×667 at text scale 1.3 above the switch', (
    tester,
  ) async {
    await pump(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.byKey(WeeklyTipsSwitch.switchKey), findsOneWidget);
  });
}
