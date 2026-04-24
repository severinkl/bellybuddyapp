import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/recipes/widgets/add_recipe_chooser_sheet.dart';

import '../../../helpers/mocks.dart';

class _FakeEntryRepository extends Fake implements EntryRepository {
  @override
  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) async => [];
}

void main() {
  late MockUserRecipeRepository recipeRepo;

  setUp(() {
    recipeRepo = MockUserRecipeRepository();
    when(() => recipeRepo.fetchForUser(any())).thenAnswer((_) async => []);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(_FakeEntryRepository()),
          userRecipeRepositoryProvider.overrideWithValue(recipeRepo),
          currentUserIdProvider.overrideWithValue('user-1'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showAddRecipeChooserSheet(ctx),
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

  testWidgets('shows both options when sheet is opened', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Aus kürzlicher Mahlzeit'), findsOneWidget);
    expect(find.text('Neu erstellen'), findsOneWidget);
  });

  testWidgets('shows history and add icons', (tester) async {
    await pumpSheet(tester);

    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
