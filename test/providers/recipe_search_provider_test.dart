import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recipe_search_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  /// A container whose search is watched (as by a screen), with the user's
  /// recipes loaded.
  Future<ProviderContainer> makeContainer() async {
    final container = createContainer(
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    container.listen(recipeSearchProvider, (_, _) {});
    await container.read(userRecipesProvider.notifier).fetch();
    return container;
  }

  /// Past the 300 ms debounce.
  Future<void> debounce() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  test('without a query, shows the user\'s recipes as they load', () async {
    final recipes = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => recipes);

    final container = await makeContainer();

    expect(container.read(recipeSearchProvider).value, recipes);
    expect(container.read(recipeSearchProvider.notifier).hasActiveQuery, false);
  });

  test('setQuery with a non-empty value searches after the debounce, and '
      'leaves the user\'s recipes unfiltered', () async {
    final all = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => all);
    when(
      () => repo.searchForUser(any(), any()),
    ).thenAnswer((_) async => [testUserRecipe(title: 'Curry mit Reis')]);

    final container = await makeContainer();
    container.read(recipeSearchProvider.notifier).setQuery('curry');
    expect(container.read(recipeSearchProvider.notifier).activeQuery, 'curry');
    await debounce();

    verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
    expect(
      container.read(recipeSearchProvider).value?.single.title,
      'Curry mit Reis',
    );
    expect(container.read(userRecipesProvider).value, all);
  });

  test('setQuery with empty / whitespace value clears the search', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    reset(repo);
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

    container.read(recipeSearchProvider.notifier).setQuery('curry');
    container.read(recipeSearchProvider.notifier).setQuery('  ');
    await debounce();

    // An empty query reloads all recipes, not searchForUser.
    verify(() => repo.fetchForUser(testUserId)).called(1);
    verifyNever(() => repo.searchForUser(any(), any()));
    expect(container.read(recipeSearchProvider.notifier).hasActiveQuery, false);
  });

  test('clearing a search shows all recipes again', () async {
    final all = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => all);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    final search = container.read(recipeSearchProvider.notifier);
    search.setQuery('zzz');
    await debounce();
    expect(container.read(recipeSearchProvider).value, isEmpty);

    search.setQuery(null);
    await debounce();

    expect(container.read(recipeSearchProvider).value, all);
  });

  test('rapid calls only fire the last value (debounce)', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    final notifier = container.read(recipeSearchProvider.notifier);
    notifier.setQuery('c');
    notifier.setQuery('cu');
    notifier.setQuery('cur');
    await debounce();

    verify(() => repo.searchForUser(testUserId, 'cur')).called(1);
    verifyNever(() => repo.searchForUser(testUserId, 'c'));
    verifyNever(() => repo.searchForUser(testUserId, 'cu'));
  });

  test('identical query is a no-op', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    container.read(recipeSearchProvider.notifier).setQuery('curry');
    await debounce();
    reset(repo);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    container.read(recipeSearchProvider.notifier).setQuery('curry');
    await debounce();

    verifyNever(() => repo.searchForUser(any(), any()));
  });

  test('an edit to the recipes searches again', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
    when(() => repo.delete(any())).thenAnswer((_) async {});

    final container = await makeContainer();
    container.read(recipeSearchProvider.notifier).setQuery('curry');
    await debounce();
    when(
      () => repo.searchForUser(any(), any()),
    ).thenAnswer((_) async => [testUserRecipe(title: 'Curry neu')]);

    await container.read(userRecipesProvider.notifier).delete('rec-1');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(recipeSearchProvider).value?.single.title,
      'Curry neu',
    );
  });

  test('without a screen watching it, the search is gone', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    final container = createContainer(
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    final sub = container.listen(recipeSearchProvider, (_, _) {});
    container.read(recipeSearchProvider.notifier).setQuery('curry');

    sub.close();
    await container.pump();

    expect(container.read(recipeSearchProvider.exists), isFalse);
    expect(container.read(recipeSearchProvider.notifier).activeQuery, isNull);
  });
}
