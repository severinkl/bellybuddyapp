import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/ingredient_search_result.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_autocomplete_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockIngredientRepository mockRepo;

  setUp(() {
    mockRepo = MockIngredientRepository();
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('IngredientAutocompleteNotifier.searchIngredients', () {
    test('returns empty list when query is shorter than 3 chars', () async {
      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .searchIngredients('ab');

      expect(
        container.read(ingredientAutocompleteProvider).suggestions,
        isEmpty,
      );
      verifyNever(() => mockRepo.search(any(), userId: any(named: 'userId')));
    });

    test('populates suggestions for 3+ char query', () async {
      when(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const [
          IngredientSearchResult(id: 'i-1', name: 'Zwiebel', isOwn: false),
        ],
      );

      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .searchIngredients('Zwi');

      final state = container.read(ingredientAutocompleteProvider);
      expect(state.suggestions, hasLength(1));
      expect(state.suggestions.first.name, equals('Zwiebel'));
    });

    test('captures error in state instead of throwing', () async {
      when(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      ).thenThrow(Exception('boom'));

      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .searchIngredients('Zwi');

      expect(
        container.read(ingredientAutocompleteProvider).searchError,
        isNotNull,
      );
    });
  });

  group('IngredientAutocompleteNotifier.addIngredient', () {
    test('clears suggestions and calls insertIfNew', () async {
      when(
        () => mockRepo.insertIfNew(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .addIngredient('  Tomate  ');

      expect(
        container.read(ingredientAutocompleteProvider).suggestions,
        isEmpty,
      );
      verify(
        () => mockRepo.insertIfNew('Tomate', userId: testUserId),
      ).called(1);
    });

    test('skips DB write when name is empty after trim', () async {
      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .addIngredient('   ');

      verifyNever(
        () => mockRepo.insertIfNew(any(), userId: any(named: 'userId')),
      );
    });
  });

  group('IngredientAutocompleteNotifier.deleteUserIngredient', () {
    test('removes the entry from state and calls the repo', () async {
      when(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const [
          IngredientSearchResult(id: 'i-1', name: 'A', isOwn: true),
          IngredientSearchResult(id: 'i-2', name: 'B', isOwn: false),
        ],
      );
      when(() => mockRepo.deleteUserIngredient('i-1')).thenAnswer((_) async {});

      final container = makeContainer();
      final notifier = container.read(ingredientAutocompleteProvider.notifier);
      await notifier.searchIngredients('abc');
      await notifier.deleteUserIngredient('i-1');

      expect(
        container
            .read(ingredientAutocompleteProvider)
            .suggestions
            .map((s) => s.id),
        ['i-2'],
      );
      verify(() => mockRepo.deleteUserIngredient('i-1')).called(1);
    });
  });
}
