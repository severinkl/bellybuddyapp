import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/meal_detail.dart';
import 'package:belly_buddy/screens/recipes/recipe_detail_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

/// The color [text] is painted in.
Color? _paintedColor(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.text.style?.color;
}

void main() {
  testWidgets('meal detail: ingredient chips have dark text', (tester) async {
    await tester.pumpWithProviders(
      Scaffold(
        body: MealDetail(
          meal: MealEntry(
            id: 'meal-1',
            trackedAt: DateTime(2026, 11, 22, 12),
            title: 'Bowl',
            ingredients: const ['Tofu', 'Edamame'],
          ),
        ),
      ),
    );

    expect(_paintedColor(tester, 'Tofu'), AppTheme.foreground);
  });

  testWidgets('recipe detail: ingredient chips have dark text', (tester) async {
    final repo = MockUserRecipeRepository();
    when(() => repo.fetchForUser(any())).thenAnswer(
      (_) async => [
        testUserRecipe(id: 'rec-1', ingredients: const ['Linsen']),
      ],
    );
    await tester.pumpWithProviders(
      const RecipeDetailScreen(recipeId: 'rec-1'),
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    await tester.pumpAndSettle();

    expect(_paintedColor(tester, 'Linsen'), AppTheme.foreground);
  });
}
