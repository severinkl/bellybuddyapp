import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('leading sits before the label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Los',
              leading: const SizedBox(key: Key('lead'), width: 24, height: 24),
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('lead'))).right,
      lessThanOrEqualTo(tester.getRect(find.text('Los')).left),
    );
    await tester.tap(find.byType(BbButton));
    expect(taps, 1);
  });

  testWidgets('semanticLabel names the button for assistive tech, the '
      'visible text stays', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Eintragen',
              semanticLabel: 'Wasser, 250 ml eintragen',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Eintragen'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ElevatedButton)),
      isSemantics(
        label: 'Wasser, 250 ml eintragen',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    expect(find.bySemanticsLabel('Eintragen'), findsNothing);
    handle.dispose();
  });

  testWidgets('semanticLabel also names it while loading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Eintragen',
              semanticLabel: 'Wasser, 250 ml eintragen',
              isLoading: true,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(ElevatedButton)).label,
      'Wasser, 250 ml eintragen',
    );
    handle.dispose();
  });
}
