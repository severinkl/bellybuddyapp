import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recipes/widgets/recent_meal_picker_sheet.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

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
}) async {
  final fakeEntries = FakeEntryRepository()
    ..seedResult(testEntryQueryResult(meals: meals));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entryRepositoryProvider.overrideWithValue(fakeEntries),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter()),
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
