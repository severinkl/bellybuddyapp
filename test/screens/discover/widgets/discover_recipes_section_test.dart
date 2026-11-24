import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/my_recipe_item.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_recipes_section.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';

import '../../../helpers/fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    AsyncValue<List<RecipeFit>> forYou = const AsyncData([]),
    AsyncValue<List<MyRecipeItem>> mine = const AsyncData([]),
    VoidCallback? onRetrySaved,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiscoverRecipesSection(
            forYou: forYou,
            mine: mine,
            onOpenAll: () {},
            onOpenMine: () {},
            onOpenRecipe: (_) {},
            onOpenOwn: (_) {},
            onRetrySaved: onRetrySaved,
          ),
        ),
      ),
    ),
  );

  testWidgets('both parts empty: a line each, no „Alle ›" for mine', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Noch keine Rezepte.'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Alle meine Rezepte'), findsNothing);
    expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
  });

  testWidgets('each part loads and fails on its own', (tester) async {
    await pump(
      tester,
      forYou: AsyncError(Exception('x'), StackTrace.empty),
      mine: const AsyncLoading(),
    );

    expect(find.text('Rezepte konnten nicht geladen werden.'), findsOneWidget);
    expect(find.text('Laden…'), findsOneWidget);
  });

  testWidgets('Meine Rezepte shows at most six', (tester) async {
    await pump(
      tester,
      mine: AsyncData([
        for (var i = 0; i < 9; i++)
          OwnRecipe(testUserRecipe(id: 'r$i', title: 'Rezept $i')),
      ]),
    );

    expect(
      find.byType(RecipeCard),
      findsNWidgets(DiscoverRecipesSection.shown),
    );
    expect(find.byType(RecipeCollectionCard), findsNothing);
  });

  testWidgets('saved ones failed: the create offer stays, with a quiet line '
      'and its retry', (tester) async {
    var retries = 0;
    await pump(tester, onRetrySaved: () => retries++);

    expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    expect(find.text(RecipeCopy.savedFailed), findsOneWidget);
    await tester.tap(find.text(RecipeCopy.retry));
    expect(retries, 1);
  });

  testWidgets('no retry given: no quiet line', (tester) async {
    await pump(tester);

    expect(find.text(RecipeCopy.savedFailed), findsNothing);
  });
}
