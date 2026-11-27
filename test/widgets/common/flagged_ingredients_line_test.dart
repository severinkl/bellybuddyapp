import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/widgets/common/flagged_ingredients_line.dart';

void main() {
  test('text: 1, 2 and 4 names give the three sentences', () {
    expect(
      FlaggedIngredientsLine.text(['Zwiebel']),
      'Zwiebel könnte deinem Bauch zu schaffen machen.',
    );
    expect(
      FlaggedIngredientsLine.text(['Zwiebel', 'Knoblauch']),
      'Zwiebel und Knoblauch könnten deinem Bauch zu schaffen machen.',
    );
    expect(
      FlaggedIngredientsLine.text(['Zwiebel', 'Knoblauch', 'Lauch', 'Apfel']),
      'Zwiebel, Knoblauch und 2 weitere könnten deinem Bauch zu schaffen '
      'machen.',
    );
  });

  testWidgets('shows the sentence and the link; the link calls onOpen', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlaggedIngredientsLine(
            names: const ['Zwiebel'],
            onOpen: () => opened++,
          ),
        ),
      ),
    );

    expect(
      find.text('Zwiebel könnte deinem Bauch zu schaffen machen.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Alternativen ansehen ›'));
    expect(opened, 1);
  });
}
