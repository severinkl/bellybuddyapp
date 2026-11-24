import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_list_tile.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/layout_checks.dart';

void main() {
  final recipe = testRecipe(title: 'Reispfanne mit Gemüse', cookTime: '35 Min');

  group('RecipeCollectionCard', () {
    testWidgets('title, meta, badge and tag', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: RecipeCollectionCard(
                recipe: recipe,
                badge: const FitsBadge(),
                tag: RecipeCardTag.saved,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Reispfanne mit Gemüse'), findsOneWidget);
      expect(find.text('35 Min · Mittag'), findsOneWidget);
      expect(find.text('Passt zu dir'), findsOneWidget);
      expect(find.text('Gemerkt'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.byType(RecipeCollectionCard));
      expect(tapped, isTrue);
    });

    testWidgets('the adapted tag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecipeTagPill(RecipeCardTag.adapted)),
        ),
      );
      expect(find.text('Angepasst'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('a row of 3 fits 375x667 at text scale 1.3', (tester) async {
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errors = await collectFlutterErrors(() async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final badge in const [
                      KritischBadge(2),
                      SelfCheckBadge(['Histamin']),
                      FitsBadge(),
                    ])
                      SizedBox(
                        width: AppConstants.discoverRecipeCardWidth,
                        child: RecipeCollectionCard(
                          recipe: recipe,
                          badge: badge,
                          tag: RecipeCardTag.adapted,
                          onTap: () {},
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
      expect(verticalOverflows(errors), isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('RecipeListTile', () {
    RecipeFit fit(FitBadge? badge) => badge == null
        ? RecipeFit(recipe: recipe, checked: false)
        : RecipeFit(
            recipe: recipe,
            checked: true,
            judged: badge is FitsBadge,
            lines: [
              if (badge is KritischBadge)
                for (var i = 0; i < badge.count; i++)
                  LineFit(testLine('x$i'), LineMark.kritisch),
            ],
          );

    testWidgets('title, meta and badge', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeListTile(
              fit: fit(const FitsBadge()),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Reispfanne mit Gemüse'), findsOneWidget);
      expect(find.text('35 Min · Mittag'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.text('Passt zu dir'), findsOneWidget);
      await tester.tap(find.byType(RecipeListTile));
      expect(tapped, isTrue);
    });

    testWidgets('no badge while unchecked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeListTile(fit: fit(null), onTap: () {}),
          ),
        ),
      );
      expect(find.byType(FitBadge), findsNothing);
      expect(find.text('Passt zu dir'), findsNothing);
    });

    testWidgets('a list of 3 fits 375x667 at text scale 1.3', (tester) async {
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errors = await collectFlutterErrors(() async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  for (final badge in const [
                    KritischBadge(2),
                    SelfCheckBadge(['Histamin']),
                    FitsBadge(),
                  ])
                    RecipeListTile(fit: fit(badge), onTap: () {}),
                ],
              ),
            ),
          ),
        );
      });
      expect(verticalOverflows(errors), isEmpty);
    });
  });
}
