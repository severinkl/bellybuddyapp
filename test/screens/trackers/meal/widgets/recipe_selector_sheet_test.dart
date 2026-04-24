import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/recipe_selector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

// ---------------------------------------------------------------------------
// Stub notifier: builds with the given recipes already loaded so that
// initState's fetch() call is a no-op and the list renders immediately.
// ---------------------------------------------------------------------------
class _StubUserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>>
    implements UserRecipesNotifier {
  _StubUserRecipesNotifier(this._recipes);

  final List<UserRecipe> _recipes;

  @override
  AsyncValue<List<UserRecipe>> build() => AsyncValue.data(_recipes);

  @override
  Future<void> fetch() async {
    // already seeded — nothing to do
  }

  @override
  Future<UserRecipe> create({
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async => throw UnimplementedError();

  @override
  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async => throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();
}

/// Opens the sheet in a test [MaterialApp] wrapped in a [ProviderScope],
/// returns the [Future] that resolves to the tapped recipe (or null).
Future<Future<UserRecipe?>> _openSheet(
  WidgetTester tester,
  List<UserRecipe> recipes,
) async {
  late Future<UserRecipe?> sheetFuture;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRecipesProvider.overrideWith(
          () => _StubUserRecipesNotifier(recipes),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  sheetFuture = showRecipeSelectorSheet(ctx);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return sheetFuture;
}

void main() {
  group('showRecipeSelectorSheet', () {
    testWidgets('tapping a recipe returns it as the sheet result', (
      tester,
    ) async {
      final recipe = testUserRecipe(
        id: 'rec-42',
        title: 'Pasta Bolognese',
        ingredients: ['Nudeln', 'Hackfleisch'],
      );

      final sheetFuture = await _openSheet(tester, [recipe]);

      // Tap the recipe tile — RecipeListTile renders recipe.title as the label
      await tester.tap(find.text('Pasta Bolognese'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final result = await sheetFuture;
      expect(result, isNotNull);
      expect(result!.id, 'rec-42');
      expect(result.title, 'Pasta Bolognese');
    });

    testWidgets('shows empty state when no recipes', (tester) async {
      await _openSheet(tester, []);
      expect(find.text('Noch keine Rezepte'), findsOneWidget);
    });
  });
}
