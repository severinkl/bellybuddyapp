import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps_editor.dart';

void main() {
  late List<String> latest;

  Future<void> pump(WidgetTester tester, List<String> initial) async {
    latest = initial;
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeStepsEditor(
              initial: initial,
              onChanged: (steps) => latest = steps,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the header, optional, the initial steps and a hint', (
    tester,
  ) async {
    await pump(tester, const ['Kochen.']);

    expect(find.text('Zubereitung'), findsOneWidget);
    expect(find.text('optional'), findsOneWidget);
    expect(find.text('Kochen.'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(RecipeStepsEditor.fieldKey(0)))
          .decoration
          ?.hintText,
      'Schritt beschreiben',
    );
  });

  testWidgets('add, type and remove steps; onChanged gets the raw texts', (
    tester,
  ) async {
    await pump(tester, const []);

    await tester.tap(find.byKey(RecipeStepsEditor.addKey));
    await tester.tap(find.byKey(RecipeStepsEditor.addKey));
    await tester.pump();
    await tester.enterText(find.byKey(RecipeStepsEditor.fieldKey(0)), 'Eins ');
    await tester.enterText(find.byKey(RecipeStepsEditor.fieldKey(1)), 'Zwei');
    expect(latest, ['Eins ', 'Zwei']);

    await tester.tap(find.byKey(RecipeStepsEditor.removeKey(0)));
    await tester.pump();
    expect(latest, ['Zwei']);
    // The keys follow the step, not its place.
    expect(find.byKey(RecipeStepsEditor.fieldKey(0)), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(RecipeStepsEditor.fieldKey(1)),
        matching: find.text('Zwei'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing a step before the one being typed in keeps it '
      'focused, with its text', (tester) async {
    await pump(tester, const ['Eins', 'Zwei', 'Drei']);
    EditableText field(String text) =>
        tester.widget<EditableText>(find.text(text));

    await tester.showKeyboard(find.text('Drei'));
    await tester.pump();
    expect(field('Drei').focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(RecipeStepsEditor.removeKey(1)));
    await tester.pump();

    expect(latest, ['Eins', 'Drei']);
    expect(find.text('Zwei'), findsNothing);
    expect(field('Drei').focusNode.hasFocus, isTrue);
    expect(field('Eins').focusNode.hasFocus, isFalse);
    // Numbered by place: „Drei" is step 2 now.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('screen readers hear each field as „Schritt N"', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const ['Kochen.', 'Essen.']);

    expect(
      tester.getSemantics(find.byKey(RecipeStepsEditor.fieldKey(1))),
      isSemantics(label: 'Schritt 2', isTextField: true, value: 'Essen.'),
    );
    // The visible number isn't said apart from its field.
    expect(find.bySemanticsLabel('2'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the remove button is named for screen readers', (tester) async {
    await pump(tester, const ['a']);
    final remove = find.byKey(RecipeStepsEditor.removeKey(0));
    expect(tester.widget<IconButton>(remove).tooltip, 'Schritt entfernen');
  });

  testWidgets('add is disabled at the most steps', (tester) async {
    await pump(tester, List.filled(AppConstants.recipeStepsMax, 'x'));

    final add = find.byKey(RecipeStepsEditor.addKey);
    expect(tester.widget<TextButton>(add).onPressed, isNull);
  });
}
