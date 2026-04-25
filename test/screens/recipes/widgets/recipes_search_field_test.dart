import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipes_search_field.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: Scaffold(body: RecipesSearchField())),
      ),
    );
  }

  testWidgets('typing pushes the query to the provider after debounce', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump(const Duration(milliseconds: 350));

    verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
  });

  testWidgets('clear icon appears when text is non-empty and clears on tap', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump();

    final clear = find.byIcon(Icons.clear);
    expect(clear, findsOneWidget);

    await tester.tap(clear);
    await tester.pump();
    expect(find.text('curry'), findsNothing);
  });

  testWidgets('prefills the field from the notifier active query', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    addTearDown(container.dispose);

    // Seed an active query before the widget mounts.
    await container.read(userRecipesProvider.notifier).fetch();
    // Bypass debounce: set _query directly via setQuery with a very short
    // pump to flush the debounce timer before mounting the widget.
    container.read(userRecipesProvider.notifier).setQuery('reis');
    // Advance fake time past the 300 ms debounce so the timer fires.
    await tester.pump(const Duration(milliseconds: 350));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: RecipesSearchField())),
      ),
    );
    // Single pump is enough — initState already set the controller text.
    await tester.pump();

    expect(find.text('reis'), findsOneWidget);
  });
}
