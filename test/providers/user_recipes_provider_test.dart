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
}
