import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
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

    test('fetchSuggestions keeps the groups while reloading', () async {
      final first = [testSuggestionGroup()];
      final held = Completer<List<IngredientSuggestionGroup>>();
      var fetches = 0;
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) => ++fetches == 1 ? Future.value(first) : held.future);

      final container = makeContainer();
      final notifier = container.read(ingredientSuggestionProvider.notifier);
      await notifier.fetchSuggestions();

      final reload = notifier.fetchSuggestions();
      final during = container.read(ingredientSuggestionProvider);
      expect(during.isLoading, isFalse);
      expect(during.value, same(first));

      final second = [
        testSuggestionGroup(ingredientId: 'ing-2', ingredientName: 'Lauch'),
      ];
      held.complete(second);
      await reload;
      expect(container.read(ingredientSuggestionProvider).value, same(second));
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
    test('marks seen in DB but keeps isNew in local state', () async {
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

      verify(() => mockRepo.markAllSeen(['sug-1'])).called(1);
      final updatedGroups = container.read(ingredientSuggestionProvider).value!;
      expect(updatedGroups[0].isNew, isTrue);
      expect(updatedGroups[1].isNew, isFalse);
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

  group('newIngredientSuggestionCountProvider', () {
    List<IngredientSuggestionGroup> threeGroupsTwoNew() => [
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

    test('counts the new groups', () async {
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => threeGroupsTwoNew());

      final container = makeContainer();
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();

      expect(container.read(newIngredientSuggestionCountProvider), 2);
    });

    test('is 0 while loading', () {
      final container = makeContainer();
      // No fetchSuggestions called — state stays AsyncLoading
      expect(container.read(newIngredientSuggestionCountProvider), 0);
    });

    test('drops to 0 for its listeners once they are marked seen, while the '
        'groups stay new', () async {
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => threeGroupsTwoNew());
      when(() => mockRepo.markAllSeen(any())).thenAnswer((_) async {});

      final container = makeContainer();
      final counts = <int>[];
      container.listen(
        newIngredientSuggestionCountProvider,
        (_, next) => counts.add(next),
        fireImmediately: true,
      );
      final notifier = container.read(ingredientSuggestionProvider.notifier);
      await notifier.fetchSuggestions();
      await container.pump();
      await notifier.markAllNewAsSeen();
      await container.pump();

      expect(counts, [0, 2, 0]);
      final groups = container.read(ingredientSuggestionProvider).value!;
      expect(groups.where((g) => g.isNew), hasLength(2));
    });

    test('new groups arriving after a mark count again (the „n neu" badge '
        'returns)', () async {
      var groups = threeGroupsTwoNew();
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => groups);
      when(() => mockRepo.markAllSeen(any())).thenAnswer((_) async {});

      final container = makeContainer();
      container.listen(newIngredientSuggestionCountProvider, (_, _) {});
      final notifier = container.read(ingredientSuggestionProvider.notifier);
      // Alternativen opened: fetched, marked seen.
      await notifier.fetchSuggestions();
      await notifier.markAllNewAsSeen();
      expect(container.read(newIngredientSuggestionCountProvider), 0);

      // Later a new group arrives; the server no longer marks the seen ones
      // new.
      groups = [
        testSuggestionGroup(
          ingredientId: 'ing-4',
          ingredientName: 'Lauch',
          isNew: true,
          suggestionIds: ['sug-4'],
        ),
        for (final g in threeGroupsTwoNew()) g.copyWith(isNew: false),
      ];
      await notifier.fetchSuggestions();

      expect(container.read(newIngredientSuggestionCountProvider), 1);
    });

    test(
      'an earlier fetch landing after the mark keeps the count at 0',
      () async {
        final held = Completer<List<IngredientSuggestionGroup>>();
        var fetches = 0;
        when(() => mockRepo.fetchSuggestionGroups(any())).thenAnswer(
          (_) =>
              ++fetches == 1 ? Future.value(threeGroupsTwoNew()) : held.future,
        );
        when(() => mockRepo.markAllSeen(any())).thenAnswer((_) async {});

        final container = makeContainer();
        container.listen(newIngredientSuggestionCountProvider, (_, _) {});
        final notifier = container.read(ingredientSuggestionProvider.notifier);
        await notifier.fetchSuggestions();
        expect(container.read(newIngredientSuggestionCountProvider), 2);

        // A refresh (Entdecken, a push) starts before the Alternativen are
        // marked seen …
        final refresh = notifier.fetchSuggestions();
        await notifier.markAllNewAsSeen();
        expect(container.read(newIngredientSuggestionCountProvider), 0);
        // … and lands after, from a server that still had them new.
        held.complete(threeGroupsTwoNew());
        await refresh;

        expect(container.read(newIngredientSuggestionCountProvider), 0);
      },
    );

    test('a failed mark keeps the count', () async {
      when(
        () => mockRepo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => threeGroupsTwoNew());
      when(() => mockRepo.markAllSeen(any())).thenThrow(Exception('offline'));

      final container = makeContainer();
      final notifier = container.read(ingredientSuggestionProvider.notifier);
      await notifier.fetchSuggestions();
      await notifier.markAllNewAsSeen();

      expect(container.read(newIngredientSuggestionCountProvider), 2);
    });
  });
}
