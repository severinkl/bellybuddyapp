import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/discover/widgets/example_tip_card.dart';
import 'package:belly_buddy/widgets/common/bb_card.dart';
import 'package:belly_buddy/widgets/common/dashed_border_painter.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

/// The page around the card: Entdecken scrolls, so [scroll] is the default.
class _Wrap extends StatelessWidget {
  const _Wrap({required this.scroll, required this.child});
  final bool scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(padding: const EdgeInsets.all(16), child: child);
    return scroll ? SingleChildScrollView(child: padded) : padded;
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    bool scroll = true,
  }) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProviderSeededWith(testUserProfile())],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: _Wrap(
              scroll: true,
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

  testWidgets('a dashed outline, painted over the fill', (tester) async {
    await pump(tester);

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(ExampleTipCard.cardKey),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is DashedBorderPainter,
        ),
      ),
    );
    expect(paint.painter, isNull);
  });

  testWidgets('speaks as one example', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      tester.getSemantics(find.byKey(ExampleTipCard.cardKey)).label,
      startsWith('Beispiel-Tipp: Zwiebel mal tauschen? Diese Woche'),
    );
    handle.dispose();
  });

  testWidgets('fits 375×667 at text scale 1.3 above the switch', (
    tester,
  ) async {
    await pump(tester, textScale: 1.3);
    // As on Entdecken (a scroll view): nothing overflows sideways, and the
    // card sits above the switch.

    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byKey(ExampleTipCard.cardKey));
    final sw = tester.getRect(find.byKey(WeeklyTipsSwitch.switchKey));
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(375));
    expect(card.bottom, lessThan(sw.top));
    expect(sw.right, lessThanOrEqualTo(375));
  });
}
