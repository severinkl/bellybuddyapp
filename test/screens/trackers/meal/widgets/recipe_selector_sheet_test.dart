// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/recipe_selector_sheet.dart';

import '../../../../helpers/fakes.dart';

class _FakeUserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>>
    implements UserRecipesNotifier {
  _FakeUserRecipesNotifier(this._recipes);

  final List<UserRecipe> _recipes;
  String? _query;
  final List<String?> setQueryCalls = [];

  @override
  AsyncValue<List<UserRecipe>> build() => AsyncValue.data(_recipes);

  @override
  Future<void> fetch({bool force = false}) async {}

  @override
  void setQuery(String? q) {
    setQueryCalls.add(q);
    _query = q;
  }

  @override
  String? get activeQuery => _query;

  @override
  bool get hasActiveQuery => _query != null;

  @override
  Future<UserRecipe> create({
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) => throw UnimplementedError();

  @override
  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showRecipeSelectorSheet(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.recipeNew,
      builder: (_, _) => const Scaffold(body: Text('recipe-new-sentinel')),
    ),
  ],
);

Future<_FakeUserRecipesNotifier> _pumpSheet(
  WidgetTester tester, {
  required List<UserRecipe> recipes,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final notifier = _FakeUserRecipesNotifier(recipes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userRecipesProvider.overrideWith(() => notifier)],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets(
    'renders one card row per recipe with title and up to 3 ingredients',
    (tester) async {
      final recipes = [
        testUserRecipe(
          id: 'r1',
          title: 'Curry mit Reis',
          ingredients: ['Reis', 'Curry', 'Zwiebel', 'Knoblauch'],
        ),
        testUserRecipe(
          id: 'r2',
          title: 'Schnitzel mit Pommes',
          ingredients: ['Schwein', 'Kartoffel'],
        ),
      ];
      await _pumpSheet(tester, recipes: recipes);

      expect(find.text('Curry mit Reis'), findsOneWidget);
      expect(find.text('Schnitzel mit Pommes'), findsOneWidget);
      expect(find.text('Reis'), findsOneWidget);
      expect(find.text('Curry'), findsOneWidget);
      expect(find.text('Zwiebel'), findsOneWidget);
      expect(find.text('Knoblauch'), findsNothing);
    },
  );

  testWidgets('tapping a recipe card pops the sheet with that recipe', (
    tester,
  ) async {
    final target = testUserRecipe(id: 'r1', title: 'Curry mit Reis');
    await _pumpSheet(tester, recipes: [target]);

    expect(find.text('Curry mit Reis'), findsOneWidget);
    await tester.tap(find.text('Curry mit Reis'));
    await tester.pumpAndSettle();

    expect(find.text('Curry mit Reis'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'tapping "Neues Rezept erstellen" pops the sheet and navigates to /recipe/new',
    (tester) async {
      await _pumpSheet(tester, recipes: const []);

      expect(find.text('Neues Rezept erstellen'), findsOneWidget);
      await tester.tap(find.text('Neues Rezept erstellen'));
      await tester.pumpAndSettle();

      expect(find.text('recipe-new-sentinel'), findsOneWidget);
    },
  );

  testWidgets('empty library shows "Noch keine Rezepte" plus the create row', (
    tester,
  ) async {
    await _pumpSheet(tester, recipes: const []);

    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    expect(find.text('Neues Rezept erstellen'), findsOneWidget);
  });

  testWidgets('dismissing the sheet clears the active query', (tester) async {
    final notifier = await _pumpSheet(tester, recipes: const []);

    // Dismiss the modal sheet by tapping the barrier scrim above it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(notifier.setQueryCalls, contains(null));
  });
}
