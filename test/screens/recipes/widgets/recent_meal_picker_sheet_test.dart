import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/recipes/widgets/recent_meal_picker_sheet.dart';

import '../../../helpers/fixtures.dart';

class _FakeEntryRepository extends Fake implements EntryRepository {
  final List<MealEntry> meals;
  _FakeEntryRepository(this.meals);

  @override
  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) async => meals;
}

/// Builds a minimal 2-route GoRouter so the sheet's context.push('/recipe/new')
/// has a destination to navigate to without needing the full app router.
GoRouter _buildRouter(List<MealEntry> meals) {
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
        path: '/recipe/new',
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entryRepositoryProvider.overrideWithValue(_FakeEntryRepository(meals)),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter(meals)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
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
