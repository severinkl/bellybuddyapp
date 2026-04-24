import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Meine Rezepte tab', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Meine Rezepte'), findsOneWidget);
    expect(find.text('Inspiration'), findsOneWidget);
    expect(find.text('Noch keine Rezepte'), findsOneWidget); // empty-state body
  });

  testWidgets('switches to Inspiration tab on tap', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Inspiration'));
    await tester.pumpAndSettle();
    expect(find.text('Rezepte kommen bald!'), findsOneWidget);
    expect(find.text('Noch keine Rezepte'), findsNothing);
  });
}
