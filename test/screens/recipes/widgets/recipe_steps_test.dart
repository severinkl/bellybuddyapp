import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps.dart';

void main() {
  Future<void> pump(WidgetTester tester, RecipeSteps steps) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: steps)),
        ),
      );

  Color? colorOf(WidgetTester tester, Finder f) =>
      (tester.widget<DecoratedBox>(f).decoration as BoxDecoration).color;

  testWidgets('numbers the steps 1..n', (tester) async {
    await pump(tester, const RecipeSteps(steps: ['Kochen.', 'Servieren.']));
    expect(find.byKey(RecipeSteps.stepKey(0)), findsOneWidget);
    expect(find.byKey(RecipeSteps.stepKey(1)), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Kochen.'), findsOneWidget);
    expect(find.text('Servieren.'), findsOneWidget);
  });

  testWidgets('a changed step is tinted and its number is primary', (
    tester,
  ) async {
    await pump(tester, const RecipeSteps(steps: ['A', 'B'], changed: {1}));
    expect(
      colorOf(tester, find.byKey(RecipeSteps.stepKey(1))),
      AppTheme.recipeChanged,
    );
    expect(
      colorOf(tester, find.byKey(RecipeSteps.numberKey(1))),
      AppTheme.primary,
    );
    expect(colorOf(tester, find.byKey(RecipeSteps.stepKey(0))), isNull);
    expect(
      colorOf(tester, find.byKey(RecipeSteps.numberKey(0))),
      isNot(AppTheme.primary),
    );
  });
}
