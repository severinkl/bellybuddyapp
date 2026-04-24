import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/recipes/widgets/recent_meal_picker_sheet.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

class _FakeEntryRepository extends Fake implements EntryRepository {
  final List<MealEntry> meals;
  _FakeEntryRepository(this.meals);

  @override
  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) async => meals;
}

void main() {
  late MockUserRecipeRepository recipeRepo;

  setUp(() {
    recipeRepo = MockUserRecipeRepository();
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required List<MealEntry> meals,
  }) async {
    when(() => recipeRepo.fetchForUser(any())).thenAnswer((_) async => []);
    when(
      () => recipeRepo.create(
        userId: any(named: 'userId'),
        title: any(named: 'title'),
        ingredients: any(named: 'ingredients'),
        imageUrl: any(named: 'imageUrl'),
      ),
    ).thenAnswer((_) async => testUserRecipe());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(
            _FakeEntryRepository(meals),
          ),
          userRecipeRepositoryProvider.overrideWithValue(recipeRepo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showRecentMealPickerSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows meal titles in the sheet', (tester) async {
    final meals = [
      testMealEntry(id: 'a', title: 'Curry'),
      testMealEntry(id: 'b', title: 'Pasta'),
    ];
    await pumpSheet(tester, meals: meals);

    expect(find.text('Curry'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
  });

  testWidgets('tapping a meal calls recipeRepo.create and shows SnackBar', (
    tester,
  ) async {
    final meal = testMealEntry(
      id: 'm1',
      title: 'Avocado Toast',
      ingredients: ['Avocado', 'Brot'],
    );
    await pumpSheet(tester, meals: [meal]);

    await tester.tap(find.text('Avocado Toast'));
    await tester.pumpAndSettle();

    verify(
      () => recipeRepo.create(
        userId: testUserId,
        title: 'Avocado Toast',
        ingredients: ['Avocado', 'Brot'],
        imageUrl: null,
      ),
    ).called(1);

    expect(find.text('Zu Meine Rezepte hinzugefügt'), findsOneWidget);
  });
}
