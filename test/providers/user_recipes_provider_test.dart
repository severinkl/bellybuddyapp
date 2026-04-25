import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
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

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('fetch', () {
    test('returns recipes from repo', () async {
      final recipes = [testUserRecipe(id: 'a'), testUserRecipe(id: 'b')];
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => recipes);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      expect(container.read(userRecipesProvider).value, recipes);
      verify(() => repo.fetchForUser(testUserId)).called(1);
    });

    test('returns empty list when userId is null', () async {
      final container = makeContainer(userId: null);
      await container.read(userRecipesProvider.notifier).fetch();

      expect(container.read(userRecipesProvider).value, isEmpty);
      verifyNever(() => repo.fetchForUser(any()));
    });
  });

  group('create', () {
    test('inserts then refetches', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
        ),
      ).thenAnswer((_) async => testUserRecipe());

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      await container
          .read(userRecipesProvider.notifier)
          .create(title: 'New', ingredients: const ['a'], imageUrl: null);

      verify(
        () => repo.create(
          userId: testUserId,
          title: 'New',
          ingredients: ['a'],
          imageUrl: null,
        ),
      ).called(1);
      verify(
        () => repo.fetchForUser(testUserId),
      ).called(2); // initial + refresh
    });
  });

  group('delete', () {
    test('calls repo.delete and refetches', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(() => repo.delete(any())).thenAnswer((_) async {});

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      await container.read(userRecipesProvider.notifier).delete('rec-1');

      verify(() => repo.delete('rec-1')).called(1);
      verify(() => repo.fetchForUser(testUserId)).called(2);
    });
  });

  group('setQuery + search branch', () {
    test(
      'setQuery with a non-empty value triggers searchForUser after debounce',
      () async {
        when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
        when(
          () => repo.searchForUser(any(), any()),
        ).thenAnswer((_) async => [testUserRecipe(title: 'Curry mit Reis')]);

        final container = makeContainer();
        await container.read(userRecipesProvider.notifier).fetch();

        container.read(userRecipesProvider.notifier).setQuery('curry');

        // Wait past the 300ms debounce.
        await Future<void>.delayed(const Duration(milliseconds: 350));

        verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
        expect(
          container.read(userRecipesProvider).value?.first.title,
          'Curry mit Reis',
        );
      },
    );

    test('setQuery with empty / whitespace value clears the search', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();
      reset(repo);
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

      container.read(userRecipesProvider.notifier).setQuery('curry');
      container.read(userRecipesProvider.notifier).setQuery('');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // Empty query falls back to fetchForUser, not searchForUser.
      verify(() => repo.fetchForUser(testUserId)).called(1);
      verifyNever(() => repo.searchForUser(any(), any()));
    });

    test('rapid calls only fire the last value (debounce)', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      final notifier = container.read(userRecipesProvider.notifier);
      notifier.setQuery('c');
      notifier.setQuery('cu');
      notifier.setQuery('cur');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      verify(() => repo.searchForUser(testUserId, 'cur')).called(1);
      verifyNever(() => repo.searchForUser(testUserId, 'c'));
      verifyNever(() => repo.searchForUser(testUserId, 'cu'));
    });

    test('identical query is a no-op', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      container.read(userRecipesProvider.notifier).setQuery('curry');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      reset(repo);
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      container.read(userRecipesProvider.notifier).setQuery('curry');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      verifyNever(() => repo.searchForUser(any(), any()));
    });
  });
}
