import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/user_recipe_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/mocks.dart';

void main() {
  late MockUserRecipeService service;
  late UserRecipeRepository repo;

  setUp(() {
    service = MockUserRecipeService();
    repo = UserRecipeRepository(service);
  });

  group('fetchForUser', () {
    test('delegates to service', () async {
      final recipes = [testUserRecipe()];
      when(() => service.fetchForUser(any())).thenAnswer((_) async => recipes);

      final result = await repo.fetchForUser('user-1');

      expect(result, recipes);
      verify(() => service.fetchForUser('user-1')).called(1);
    });
  });

  group('create', () {
    test('forwards all arguments', () async {
      final recipe = testUserRecipe();
      when(
        () => service.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
        ),
      ).thenAnswer((_) async => recipe);

      final result = await repo.create(
        userId: 'user-1',
        title: 'Title',
        ingredients: const ['a', 'b'],
        imageUrl: 'url',
      );

      expect(result, recipe);
      verify(
        () => service.create(
          userId: 'user-1',
          title: 'Title',
          ingredients: ['a', 'b'],
          imageUrl: 'url',
        ),
      ).called(1);
    });
  });

  group('update', () {
    test('forwards all arguments', () async {
      final recipe = testUserRecipe();
      when(
        () => service.update(
          id: any(named: 'id'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
        ),
      ).thenAnswer((_) async => recipe);

      final result = await repo.update(
        id: 'rec-1',
        title: 'New',
        ingredients: const ['x'],
        imageUrl: null,
      );

      expect(result, recipe);
      verify(
        () => service.update(
          id: 'rec-1',
          title: 'New',
          ingredients: ['x'],
          imageUrl: null,
        ),
      ).called(1);
    });
  });

  group('delete', () {
    test('delegates to service', () async {
      when(() => service.delete(any())).thenAnswer((_) async {});
      await repo.delete('rec-1');
      verify(() => service.delete('rec-1')).called(1);
    });
  });
}
