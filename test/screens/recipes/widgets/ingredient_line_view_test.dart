import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/recipes/widgets/ingredient_line_view.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';

void main() {
  Future<void> pump(WidgetTester tester, IngredientLineView view) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: view)),
        ),
      );

  Finder decorated(Color color) => find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == color,
  );

  Finder struck(String text) => find.byWidgetPredicate((w) {
    if (w is! Text) return false;
    var found = false;
    w.textSpan?.visitChildren((s) {
      if (s is TextSpan &&
          s.text == text &&
          s.style?.decoration == TextDecoration.lineThrough) {
        found = true;
      }
      return true;
    });
    return found;
  });

  testWidgets('fits: check mark, amount and name', (tester) async {
    await pump(
      tester,
      const IngredientLineView(
        amount: '200 g',
        name: 'Reis',
        mark: LineMark.fits,
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(decorated(AppTheme.gutFeelingGoodSoft), findsOneWidget);
    expect(find.text('200 g'), findsOneWidget);
    expect(find.text('Reis'), findsOneWidget);
  });

  testWidgets('kritisch: suffix and the reason', (tester) async {
    await pump(
      tester,
      const IngredientLineView(
        name: 'Honig',
        mark: LineMark.kritisch,
        because: ['Fruktose'],
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('Honig — für dich kritisch'), findsOneWidget);
    expect(find.text('wegen Fruktose'), findsOneWidget);
  });

  testWidgets('unknown: not in the catalog', (tester) async {
    await pump(
      tester,
      const IngredientLineView(name: 'Zimt', mark: LineMark.unknown),
    );
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.text('nicht im Katalog'), findsOneWidget);
  });

  testWidgets('neutral: a dot, no verdict', (tester) async {
    await pump(
      tester,
      const IngredientLineView(
        amount: '200 g',
        name: 'Reis',
        mark: LineMark.neutral,
      ),
    );
    expect(find.byType(Icon), findsNothing);
    expect(find.byKey(IngredientLineView.neutralKey), findsOneWidget);
    expect(find.text('Reis'), findsOneWidget);
    expect(find.text('200 g'), findsOneWidget);
  });

  testWidgets('neutral lines line up with marked ones', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IngredientLineView(name: 'Reis', mark: LineMark.neutral),
              IngredientLineView(
                name: 'Quark',
                mark: LineMark.kritisch,
                because: ['Laktose'],
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Reis')).dx,
      tester.getTopLeft(find.text('Quark — für dich kritisch')).dx,
    );
  });

  testWidgets('without the amount column, the name starts at the left', (
    tester,
  ) async {
    await pump(
      tester,
      const IngredientLineView(name: '2 Karotten', amountColumn: false),
    );
    expect(
      tester.getTopLeft(find.text('2 Karotten')).dx,
      tester.getTopLeft(find.byType(IngredientLineView)).dx,
    );

    // With the column (the default), the name sits right of it.
    await pump(tester, const IngredientLineView(name: '2 Karotten'));
    expect(
      tester.getTopLeft(find.text('2 Karotten')).dx -
          tester.getTopLeft(find.byType(IngredientLineView)).dx,
      AppConstants.recipeAmountWidth,
    );
  });

  testWidgets('no mark: no mark icon', (tester) async {
    await pump(tester, const IngredientLineView(amount: '1 EL', name: 'Öl'));
    expect(find.byType(Icon), findsNothing);
    expect(find.text('1 EL'), findsOneWidget);
  });

  testWidgets('swap: struck original, new name, getauscht, tinted row', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const IngredientLineView(
        amount: '100 ml',
        name: 'Hafermilch',
        mark: LineMark.fits,
        replaces: 'Milch',
      ),
    );
    expect(struck('Milch'), findsOneWidget);
    expect(find.textContaining('Hafermilch'), findsOneWidget);
    expect(find.textContaining('getauscht'), findsOneWidget);
    expect(decorated(AppTheme.primarySoft), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(IngredientLineView)).label,
      'Milch getauscht gegen Hafermilch',
    );
    handle.dispose();
  });

  testWidgets('removed: struck name and weggelassen', (tester) async {
    await pump(
      tester,
      const IngredientLineView(name: 'Zwiebel', removed: true),
    );
    expect(struck('Zwiebel'), findsOneWidget);
    expect(find.textContaining('weggelassen'), findsOneWidget);
  });

  testWidgets('note is a muted caption', (tester) async {
    await pump(
      tester,
      const IngredientLineView(name: 'Zimt', note: 'unbekannt'),
    );
    expect(find.text('unbekannt'), findsOneWidget);
  });

  testWidgets('semantics: one merged node per verdict', (tester) async {
    final handle = tester.ensureSemantics();
    Future<String> label(IngredientLineView v) async {
      await pump(tester, v);
      return tester.getSemantics(find.byType(IngredientLineView)).label;
    }

    expect(
      await label(
        const IngredientLineView(
          amount: '2 EL',
          name: 'Honig',
          mark: LineMark.kritisch,
          because: ['Fruktose', 'Laktose'],
        ),
      ),
      '2 EL Honig, für dich kritisch, wegen Fruktose und Laktose',
    );
    expect(
      await label(
        const IngredientLineView(
          amount: '200 g',
          name: 'Reis',
          mark: LineMark.fits,
        ),
      ),
      '200 g Reis, passt',
    );
    expect(
      await label(
        const IngredientLineView(name: 'Zimt', mark: LineMark.unknown),
      ),
      'Zimt, nicht im Katalog',
    );
    expect(
      await label(
        const IngredientLineView(
          amount: '200 g',
          name: 'Reis',
          mark: LineMark.neutral,
        ),
      ),
      '200 g Reis',
    );
    handle.dispose();
  });
}
