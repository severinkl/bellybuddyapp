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

/// The search under test (Meine Rezepte's).
final _search = recipeSearchProvider(RecipeSearchHost.myRecipes);

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
    container.listen(_search, (_, _) {});
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

    expect(container.read(_search).value, recipes);
    expect(container.read(_search.notifier).hasActiveQuery, false);
  });

  test('setQuery with a non-empty value searches after the debounce, and '
      'leaves the user\'s recipes unfiltered', () async {
    final all = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => all);
    when(
      () => repo.searchForUser(any(), any()),
    ).thenAnswer((_) async => [testUserRecipe(title: 'Curry mit Reis')]);

    final container = await makeContainer();
    container.read(_search.notifier).setQuery('curry');
    expect(container.read(_search.notifier).activeQuery, 'curry');
    await debounce();

    verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
    expect(container.read(_search).value?.single.title, 'Curry mit Reis');
    expect(container.read(userRecipesProvider).value, all);
  });

  test('setQuery with empty / whitespace value clears the search', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    reset(repo);
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

    container.read(_search.notifier).setQuery('curry');
    container.read(_search.notifier).setQuery('  ');
    await debounce();

    // An empty query reloads all recipes, not searchForUser.
    verify(() => repo.fetchForUser(testUserId)).called(1);
    verifyNever(() => repo.searchForUser(any(), any()));
    expect(container.read(_search.notifier).hasActiveQuery, false);
  });

  test('clearing a search shows all recipes again', () async {
    final all = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => all);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    final search = container.read(_search.notifier);
    search.setQuery('zzz');
    await debounce();
    expect(container.read(_search).value, isEmpty);

    search.setQuery(null);
    await debounce();

    expect(container.read(_search).value, all);
  });

  test('rapid calls only fire the last value (debounce)', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    final container = await makeContainer();
    final notifier = container.read(_search.notifier);
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
    container.read(_search.notifier).setQuery('curry');
    await debounce();
    reset(repo);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

    container.read(_search.notifier).setQuery('curry');
    await debounce();

    verifyNever(() => repo.searchForUser(any(), any()));
  });

  test('an edit to the recipes searches again', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
    when(() => repo.delete(any())).thenAnswer((_) async {});

    final container = await makeContainer();
    container.read(_search.notifier).setQuery('curry');
    await debounce();
    when(
      () => repo.searchForUser(any(), any()),
    ).thenAnswer((_) async => [testUserRecipe(title: 'Curry neu')]);

    await container.read(userRecipesProvider.notifier).delete('rec-1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(_search).value?.single.title, 'Curry neu');
  });

  test('without a screen watching it, the search is gone', () async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    final container = createContainer(
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    final sub = container.listen(_search, (_, _) {});
    container.read(_search.notifier).setQuery('curry');

    sub.close();
    await container.pump();

    expect(container.read(_search.exists), isFalse);
    expect(container.read(_search.notifier).activeQuery, isNull);
  });

  test('each host has its own search', () async {
    final all = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => all);
    when(
      () => repo.searchForUser(any(), any()),
    ).thenAnswer((_) async => [testUserRecipe(title: 'Pasta Pesto')]);
    final picker = recipeSearchProvider(RecipeSearchHost.recipePicker);
    final container = await makeContainer();
    container.listen(picker, (_, _) {});

    container.read(_search.notifier).setQuery('pasta');
    await debounce();

    expect(container.read(_search).value?.single.title, 'Pasta Pesto');
    expect(container.read(picker.notifier).activeQuery, isNull);
    expect(container.read(picker).value, all);
  });

  group('titleMatches', () {
    test('every word starts a title word, any order and case', () {
      expect(titleMatches('Curry mit Reis', 'Reis Curry'), isTrue);
      expect(titleMatches('Curry mit Reis', '  CUR  re '), isTrue);
      expect(titleMatches('Möhren-Suppe', 'suppe möh'), isTrue);
      expect(titleMatches('Curry mit Reis', 'urry'), isFalse);
      expect(titleMatches('Curry mit Reis', 'Curry Nudeln'), isFalse);
    });

    test('a blank query, or one of signs only, matches', () {
      expect(titleMatches('Curry', ''), isTrue);
      expect(titleMatches('Curry', ' !! '), isTrue);
    });
  });
}
