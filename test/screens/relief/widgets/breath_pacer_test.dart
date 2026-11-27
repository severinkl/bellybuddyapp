import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/screens/relief/widgets/breath_pacer.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';

void main() {
  const pattern = BreathPattern(inhale: 4, exhale: 6);

  Future<Size> pumpAt(
    WidgetTester tester,
    int second, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Center(
              child: BreathPacer(
                pattern: pattern,
                secondInStep: second,
                running: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(BreathPacer.circleKey));
  }

  testWidgets('under reduced motion the circle stays still', (tester) async {
    final at0 = await pumpAt(tester, 0, disableAnimations: true);
    final at3 = await pumpAt(tester, 3, disableAnimations: true);
    expect(at3, at0);
  });

  testWidgets('shows the phase word and the seconds left in it', (
    tester,
  ) async {
    await pumpAt(tester, 1, disableAnimations: true);
    expect(find.text('Einatmen'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('the circle grows over the inhale', (tester) async {
    final at0 = await pumpAt(tester, 0);
    final at3 = await pumpAt(tester, 3);
    expect(at3.width, greaterThan(at0.width));
  });

  testWidgets('the exhale follows the inhale', (tester) async {
    await pumpAt(tester, 4);
    expect(find.text('Ausatmen'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('the phase container reads the word and the seconds left', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 1);
    expect(
      find.bySemanticsLabel(ReliefCopy.phaseSemantics('Einatmen', 3)),
      findsOneWidget,
    );
    handle.dispose();
  });
}
