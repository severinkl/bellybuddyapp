import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recipes/widgets/recent_meal_picker_sheet.dart';
import 'package:belly_buddy/widgets/common/bb_drag_handle.dart';
import 'package:belly_buddy/widgets/common/bb_sheet_row.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

/// Minimal 2-route GoRouter for sheet navigation tests. The sentinel route
/// reads `state.extra` so tests can assert the meal was forwarded.
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (ctx, _) => Scaffold(
          body: Builder(
            builder: (innerCtx) => ElevatedButton(
              onPressed: () => showRecentMealPickerSheet(innerCtx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.recipeNew,
        builder: (_, state) {
          final extra = state.extra as MealEntry?;
          return Scaffold(
            body: Text('recipe-new-sentinel:${extra?.title ?? "no-extra"}'),
          );
        },
      ),
    ],
  );
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required List<MealEntry> meals,
  List<UserRecipe> recipes = const [],
}) async {
  final fakeEntries = FakeEntryRepository()
    ..seedResult(testEntryQueryResult(meals: meals));
  final recipeRepo = MockUserRecipeRepository();
  when(() => recipeRepo.fetchForUser(any())).thenAnswer((_) async => recipes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entryRepositoryProvider.overrideWithValue(fakeEntries),
        userRecipeRepositoryProvider.overrideWithValue(recipeRepo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
      // The app's theme: its bottom sheets show a drag handle.
      child: MaterialApp.router(
        theme: AppTheme.theme,
        routerConfig: _buildRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('has one drag handle, its own (the theme adds none)', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      meals: [testMealEntry(id: 'a', title: 'Curry')],
    );

    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isFalse,
    );
    expect(find.byType(BbDragHandle), findsOneWidget);
  });

  testWidgets('marks meals already saved as a recipe', (tester) async {
    await pumpSheet(
      tester,
      meals: [
        testMealEntry(id: 'a', title: 'Porridge mit Banane'),
        testMealEntry(id: 'b', title: 'Pasta'),
      ],
      recipes: [testUserRecipe(title: ' porridge mit banane ')],
    );

    const saved = 'Schon als Rezept gespeichert';
    expect(find.text(saved), findsOneWidget);
    Finder row(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(BbSheetRow));
    expect(
      find.descendant(
        of: row('Porridge mit Banane'),
        matching: find.text(saved),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('Pasta'), matching: find.text(saved)),
      findsNothing,
    );
  });

  testWidgets('shows meal titles in the sheet', (tester) async {
    final meals = [
      testMealEntry(id: 'a', title: 'Curry'),
      testMealEntry(id: 'b', title: 'Pasta'),
    ];
    await pumpSheet(tester, meals: meals);

    expect(find.text('Curry'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
  });

  testWidgets('tapping a meal pops the sheet and navigates to /recipe/new', (
    tester,
  ) async {
    final meal = testMealEntry(
      id: 'm1',
      title: 'Avocado Toast',
      ingredients: ['Avocado', 'Brot'],
    );
    await pumpSheet(tester, meals: [meal]);

    // Sheet is open — meal tile is visible.
    expect(find.text('Avocado Toast'), findsOneWidget);

    await tester.tap(find.text('Avocado Toast'));
    await tester.pumpAndSettle();

    // Sheet is dismissed and router pushed /recipe/new with the meal as extra.
    expect(find.text('Avocado Toast'), findsNothing);
    expect(
      find.text('recipe-new-sentinel:Avocado Toast'),
      findsOneWidget,
      reason: 'meal must flow through state.extra to /recipe/new',
    );
  });
}
