import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/adapted_recipe.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/services/user_recipe_service.dart';

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
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
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

  group('create with steps', () {
    test('passes steps and amounts to the repository and refetches', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).thenAnswer((_) async => testUserRecipe());

      final container = makeContainer();
      await container
          .read(userRecipesProvider.notifier)
          .create(
            title: 'New',
            ingredients: const ['a'],
            instructions: const ['A'],
            ingredientAmounts: const ['1 EL'],
          );

      verify(
        () => repo.create(
          userId: testUserId,
          title: 'New',
          ingredients: ['a'],
          imageUrl: null,
          instructions: ['A'],
          ingredientAmounts: ['1 EL'],
          adaptedFromRecipeId: null,
        ),
      ).called(1);
      verify(() => repo.fetchForUser(testUserId)).called(1);
    });
  });

  group('createAdapted', () {
    /// Titles the user already has: `create` throws
    /// [DuplicateRecipeTitleException] for them (case-insensitive, trimmed).
    late Set<String> taken;

    /// The named arguments of every `create` that saved.
    late List<Map<Symbol, dynamic>> saved;

    setUp(() {
      taken = {};
      saved = [];
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).thenAnswer((inv) async {
        final title = inv.namedArguments[#title] as String;
        if (taken.contains(title.trim().toLowerCase())) {
          throw const DuplicateRecipeTitleException();
        }
        saved.add(inv.namedArguments);
        return testUserRecipe(title: title);
      });
    });

    /// The named arguments of the last successful `create`.
    Map<Symbol, dynamic> sent() => saved.last;

    AdaptedRecipe adapted({
      String title = 'Risotto',
      List<AdaptedIngredient> ingredients = const [
        AdaptedIngredient(amount: '200 g', name: 'Risottoreis'),
        AdaptedIngredient(name: 'Salz'),
        AdaptedIngredient(
          amount: '2 EL',
          name: 'Knoblauchöl',
          replaces: 'Knoblauch',
        ),
      ],
      List<AdaptedStep> steps = const [
        AdaptedStep('Erhitze das Knoblauchöl.', changed: true),
        AdaptedStep('Gib den Reis dazu.'),
      ],
    }) => AdaptedRecipe(
      recipeId: 'recipe-1',
      title: title,
      ingredients: ingredients,
      removed: const ['Zwiebel'],
      steps: steps,
      note: 'Ich hab Knoblauch gegen Knoblauchöl getauscht.',
    );

    group("over core's limits: refused before sending", () {
      Future<void> expectRefused(AdaptedRecipe recipe) async {
        final container = makeContainer();
        await expectLater(
          container.read(userRecipesProvider.notifier).createAdapted(recipe),
          throwsA(isA<RecipeTooLongException>()),
        );
        expect(saved, isEmpty);
      }

      test('the steps', () async {
        final half = 'x' * (AppConstants.recipeStepsMaxChars ~/ 2);
        await expectRefused(
          adapted(steps: [AdaptedStep(half), AdaptedStep('$half!')]),
        );
      });

      test('the amounts', () async {
        final half = 'x' * (AppConstants.recipeAmountsMaxChars ~/ 2);
        await expectRefused(
          adapted(
            ingredients: [
              AdaptedIngredient(amount: half, name: 'Reis'),
              AdaptedIngredient(amount: '$half!', name: 'Salz'),
            ],
          ),
        );
      });

      test('at the limits: saved', () async {
        final container = makeContainer();
        await container
            .read(userRecipesProvider.notifier)
            .createAdapted(
              adapted(
                ingredients: [
                  AdaptedIngredient(
                    amount: 'x' * AppConstants.recipeAmountsMaxChars,
                    name: 'Reis',
                  ),
                ],
                steps: [AdaptedStep('x' * AppConstants.recipeStepsMaxChars)],
              ),
            );
        expect(saved, hasLength(1));
      });
    });

    test('duplicate title', () async {
      final container = makeContainer();
      final notifier = container.read(userRecipesProvider.notifier);

      taken = {'risotto'};
      final first = await notifier.createAdapted(adapted());
      expect(first.title, 'Risotto (angepasst)');
      expect(sent()[#title], 'Risotto (angepasst)');

      taken = {'risotto', 'risotto (angepasst)'};
      final second = await notifier.createAdapted(adapted());
      expect(second.title, 'Risotto (angepasst 2)');
    });

    test('every title taken: the duplicate is rethrown', () async {
      taken = {
        'risotto',
        'risotto (angepasst)',
        for (var n = 2; n <= 9; n++) 'risotto (angepasst $n)',
      };
      final container = makeContainer();

      await expectLater(
        container.read(userRecipesProvider.notifier).createAdapted(adapted()),
        throwsA(isA<DuplicateRecipeTitleException>()),
      );
      verify(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).called(10);
      verifyNever(() => repo.fetchForUser(any()));
    });

    test('another failure is not retried under a new title', () async {
      when(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).thenThrow(Exception('offline'));
      final container = makeContainer();

      await expectLater(
        container.read(userRecipesProvider.notifier).createAdapted(adapted()),
        throwsException,
      );
      verify(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).called(1);
    });

    test('amounts aligned with nulls', () async {
      final container = makeContainer();

      await container
          .read(userRecipesProvider.notifier)
          .createAdapted(adapted());

      final args = sent();
      expect(args[#ingredients], ['Risottoreis', 'Salz', 'Knoblauchöl']);
      expect(args[#ingredientAmounts], ['200 g', null, '2 EL']);
    });

    test('all amounts null → none sent', () async {
      final container = makeContainer();

      await container
          .read(userRecipesProvider.notifier)
          .createAdapted(
            adapted(
              ingredients: const [
                AdaptedIngredient(name: 'Risottoreis'),
                AdaptedIngredient(name: 'Salz'),
              ],
            ),
          );

      final args = sent();
      expect(args[#ingredients], ['Risottoreis', 'Salz']);
      expect(args[#ingredientAmounts], isNull);
    });

    test('steps and origin sent', () async {
      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      await container
          .read(userRecipesProvider.notifier)
          .createAdapted(
            adapted(
              // fromJson drops blank steps and trims the rest.
              steps: [
                const AdaptedStep('Erhitze das Knoblauchöl.', changed: true),
                for (var i = 1; i <= AppConstants.recipeStepsMax; i++)
                  AdaptedStep('Schritt $i'),
              ],
            ),
          );

      final args = sent();
      expect(args[#userId], testUserId);
      expect(args[#title], 'Risotto');
      expect(args[#adaptedFromRecipeId], 'recipe-1');
      expect(args[#imageUrl], isNull);
      final steps = args[#instructions] as List<String>;
      expect(steps, hasLength(AppConstants.recipeStepsMax));
      expect(steps.first, 'Erhitze das Knoblauchöl.');
      expect(steps[1], 'Schritt 1');
      expect(steps.last, 'Schritt ${AppConstants.recipeStepsMax - 1}');
      // Refetches like create: the initial fetch and the refresh.
      verify(() => repo.fetchForUser(testUserId)).called(2);
    });

    test('duplicate names keep the first', () async {
      final container = makeContainer();

      await container
          .read(userRecipesProvider.notifier)
          .createAdapted(
            adapted(
              ingredients: const [
                AdaptedIngredient(amount: '200 g', name: 'Reis'),
                AdaptedIngredient(name: 'Salz'),
                AdaptedIngredient(amount: '1 Tasse', name: 'reis'),
                AdaptedIngredient(amount: '1 Prise', name: 'SALZ'),
              ],
            ),
          );

      final args = sent();
      expect(args[#ingredients], ['Reis', 'Salz']);
      expect(args[#ingredientAmounts], ['200 g', null]);
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
