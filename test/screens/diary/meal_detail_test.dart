import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart' as model;
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/meal_detail.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';

final _meal = MealEntry(
  id: 'meal-1',
  trackedAt: DateTime(2026, 11, 27, 12),
  title: 'Bowl',
  ingredients: const ['Zwiebel', 'Reis'],
);

model.IngredientSuggestionGroup _groupFor(String name, String mealId) =>
    testSuggestionGroup(
      ingredientId: 'ing-$name',
      ingredientName: name,
    ).copyWith(
      meals: [
        model.MealDetail(
          id: mealId,
          title: 'Bowl',
          trackedAt: DateTime(2026, 11, 27, 12),
        ),
      ],
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<model.IngredientSuggestionGroup> groups,
) async {
  final container = ProviderContainer.test(
    overrides: [
      ingredientRepositoryProvider.overrideWithValue(
        FakeIngredientRepository(groups: groups),
      ),
      currentUserIdProvider.overrideWithValue('user-1'),
    ],
  );
  final router = GoRouter(
    initialLocation: '/meal',
    routes: [
      GoRoute(
        path: '/meal',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(child: MealDetail(meal: _meal)),
        ),
      ),
      GoRoute(
        path: RoutePaths.ingredientSuggestions,
        builder: (_, _) => const Scaffold(body: Text('alternatives-sentinel')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: germanRouterApp(router),
    ),
  );
  await container
      .read(ingredientSuggestionProvider.notifier)
      .fetchSuggestions();
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('diary meal detail: groups for the meal → the line under '
      '„Zutaten"; tap opens Alternativen', (tester) async {
    await _pump(tester, [
      _groupFor('Zwiebel', 'meal-1'),
      _groupFor('Lauch', 'other-meal'),
    ]);

    const line = 'Zwiebel könnte deinem Bauch zu schaffen machen.';
    expect(find.text(line), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(line)).dy,
      greaterThan(tester.getTopLeft(find.text('Zutaten')).dy),
    );

    await tester.tap(find.text('Alternativen ansehen ›'));
    await tester.pumpAndSettle();
    expect(find.text('alternatives-sentinel'), findsOneWidget);
  });

  testWidgets('diary meal detail: no groups for the meal → no line', (
    tester,
  ) async {
    await _pump(tester, [_groupFor('Lauch', 'other-meal')]);

    expect(find.textContaining('zu schaffen machen'), findsNothing);
    expect(find.text('Alternativen ansehen ›'), findsNothing);
  });
}
