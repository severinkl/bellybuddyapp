import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
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

  group('IngredientSuggestionNotifier.fetchSuggestions', () {
    test('loading → data with groups', () async {
      final groups = [testSuggestionGroup()];
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => groups);

      final container = makeContainer();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();

      final state = container.read(ingredientSuggestionProvider);
      expect(state, isA<AsyncData>());
      expect(state.value, hasLength(1));
      expect(state.value!.first.ingredientName, equals('Zwiebel'));
    });

    test('null userId → empty list', () async {
      final container = makeContainer(userId: null);
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();

      final state = container.read(ingredientSuggestionProvider);
      expect(state, isA<AsyncData>());
      expect(state.value, isEmpty);
      verifyNever(() => mockRepo.fetchSuggestionGroups(any()));
    });

    test('repo error → AsyncError state', () async {
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenThrow(Exception('db error'));

      final container = makeContainer();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();

      final state = container.read(ingredientSuggestionProvider);
      expect(state, isA<AsyncError>());
    });
  });

  group('IngredientSuggestionNotifier.markAllNewAsSeen', () {
    test('sets isNew = false for all new groups', () async {
      final groups = [
        testSuggestionGroup(isNew: true, suggestionIds: ['sug-1']),
        testSuggestionGroup(
          ingredientId: 'ing-2',
          ingredientName: 'Knoblauch',
          isNew: false,
          suggestionIds: ['sug-2'],
        ),
      ];
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => groups);
      when(() => mockRepo.markAllSeen(any())).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .markAllNewAsSeen();

      final updatedGroups = container.read(ingredientSuggestionProvider).value!;
      expect(updatedGroups.every((g) => !g.isNew), isTrue);
    });
  });

  group('IngredientSuggestionNotifier.dismissSuggestion', () {
    test('removes group with matching suggestion ids', () async {
      final groups = [
        testSuggestionGroup(
          suggestionIds: ['sug-to-dismiss'],
          ingredientId: 'ing-1',
        ),
        testSuggestionGroup(
          ingredientId: 'ing-2',
          ingredientName: 'Knoblauch',
          suggestionIds: ['sug-keep'],
        ),
      ];
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => groups);
      when(() => mockRepo.dismissSuggestions(any())).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .dismissSuggestion(['sug-to-dismiss']);

      final remaining = container.read(ingredientSuggestionProvider).value!;
      expect(remaining, hasLength(1));
      expect(remaining.first.ingredientName, equals('Knoblauch'));
    });
  });

  group('IngredientSuggestionNotifier.newCount', () {
    test('returns count of isNew groups', () async {
      final groups = [
        testSuggestionGroup(isNew: true),
        testSuggestionGroup(
          ingredientId: 'ing-2',
          ingredientName: 'Knoblauch',
          isNew: true,
          suggestionIds: ['sug-2'],
        ),
        testSuggestionGroup(
          ingredientId: 'ing-3',
          ingredientName: 'Paprika',
          isNew: false,
          suggestionIds: ['sug-3'],
        ),
      ];
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => groups);

      final container = makeContainer();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();

      expect(
        container.read(ingredientSuggestionProvider.notifier).newCount,
        equals(2),
      );
    });

    test('returns 0 when state is loading', () {
      final container = makeContainer();
      // No fetchSuggestions called — state stays AsyncLoading
      expect(
        container.read(ingredientSuggestionProvider.notifier).newCount,
        equals(0),
      );
    });
  });
}
