import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/widgets/common/bb_labeled_field.dart';

void main() {
  testWidgets('the field keeps its name with text entered, in one node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const key = Key('field');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbLabeledField(
            label: 'Name der Mahlzeit',
            child: TextField(
              key: key,
              decoration: InputDecoration(hintText: 'z.B. Pasta'),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(key), 'Pasta');
    await tester.pump();

    final node = tester.getSemantics(find.byKey(key));
    expect(node.getSemanticsData().label, contains('Name der Mahlzeit'));
    expect(
      node,
      isSemantics(isTextField: true, value: 'Pasta', hasTapAction: true),
    );
    final named = find.semantics
        .byPredicate((n) => n.label.contains('Name der Mahlzeit'))
        .evaluate();
    expect(named, hasLength(1));
    handle.dispose();
  });

  testWidgets('a button in the field\'s decoration keeps its own node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const key = Key('field');
    var cleared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BbLabeledField(
            label: 'Rezept suchen',
            child: TextField(
              key: key,
              decoration: InputDecoration(
                hintText: 'Rezept suchen…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Suche löschen',
                  icon: const Icon(Icons.clear),
                  onPressed: () => cleared++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(key), 'Curry');
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.getSemanticsData().label, 'Rezept suchen');
    expect(node, isSemantics(isTextField: true, value: 'Curry'));
    final clear = find.semantics.byPredicate(
      (n) => n.tooltip == 'Suche löschen',
    );
    expect(clear, findsOneWidget);
    // Reachable on its own, not folded into the field.
    expect(clear.evaluate().single.isMergedIntoParent, isFalse);
    expect(node.mergeAllDescendantsIntoThisNode, isFalse);
    tester.semantics.tap(clear);
    expect(cleared, 1);
    handle.dispose();
  });
}
