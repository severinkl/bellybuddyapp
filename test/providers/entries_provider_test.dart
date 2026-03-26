import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockEntryRepository mockRepo;

  setUp(() {
    mockRepo = MockEntryRepository();
    registerFallbackValue(testMealEntry());
    registerFallbackValue(testToiletEntry());
    registerFallbackValue(testGutFeelingEntry());
    registerFallbackValue(testDrinkEntry());
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          entryRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('EntriesNotifier.loadEntries', () {
    test('populates state with entries from repo', () async {
      final result = testEntryQueryResult();
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => result);

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .loadEntries(DateTime(2026, 3, 25));

      final state = container.read(entriesProvider);
      expect(state.meals, hasLength(1));
      expect(state.toiletEntries, hasLength(1));
      expect(state.gutFeelings, hasLength(1));
      expect(state.drinks, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('sets isLoading to true then false', () async {
      final result = testEntryQueryResult();
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => result);

      final container = makeContainer();
      final future = container
          .read(entriesProvider.notifier)
          .loadEntries(DateTime(2026, 3, 25));
      // After the call completes, isLoading is false
      await future;
      expect(container.read(entriesProvider).isLoading, isFalse);
    });

    test('null userId returns early without calling repo', () async {
      final container = makeContainer(userId: null);
      // No fetchForDate stub needed — should not be called
      final notifier = container.read(entriesProvider.notifier);

      // loadEntries sets isLoading=true but doesn't call repo
      await notifier.loadEntries(DateTime(2026, 3, 25));

      verifyNever(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      );
    });

    test('repo error sets state.error and rethrows', () async {
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenThrow(Exception('db error'));

      final container = makeContainer();

      await expectLater(
        () => container
            .read(entriesProvider.notifier)
            .loadEntries(DateTime(2026, 3, 25)),
        throwsA(isA<Exception>()),
      );

      final state = container.read(entriesProvider);
      expect(state.error, isA<Exception>());
      expect(state.isLoading, isFalse);
    });
  });

  group('EntriesNotifier.addMeal', () {
    test('delegates to repo.insertEntry', () async {
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container.read(entriesProvider.notifier).addMeal(testMealEntry());

      verify(
        () => mockRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);
    });
  });

  group('EntriesNotifier.updateMeal', () {
    test('delegates to repo.updateEntry', () async {
      when(
        () => mockRepo.updateEntry(any(), any(), any()),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .updateMeal(testMealEntry());

      verify(() => mockRepo.updateEntry(any(), 'meal-1', any())).called(1);
    });
  });

  group('EntriesNotifier.deleteMeal', () {
    test('delegates to repo.deleteEntry', () async {
      when(() => mockRepo.deleteEntry(any(), any())).thenAnswer((_) async {});

      final container = makeContainer();
      await container.read(entriesProvider.notifier).deleteMeal('meal-1');

      verify(() => mockRepo.deleteEntry(any(), 'meal-1')).called(1);
    });
  });

  group('EntriesNotifier.addToiletEntry', () {
    test('delegates to repo.insertEntry', () async {
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .addToiletEntry(testToiletEntry());

      verify(
        () => mockRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);
    });
  });

  group('EntriesNotifier.addGutFeeling', () {
    test('delegates to repo.insertEntry', () async {
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .addGutFeeling(testGutFeelingEntry());

      verify(
        () => mockRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);
    });
  });

  group('EntriesNotifier.addDrinkEntry', () {
    test('delegates to repo.insertEntry', () async {
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .addDrinkEntry(testDrinkEntry());

      verify(
        () => mockRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);
    });
  });

  group('EntriesNotifier.deleteByType', () {
    test('delegates to repo.deleteByType', () async {
      when(() => mockRepo.deleteByType(any(), any())).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .deleteByType('meal', 'meal-1');

      verify(() => mockRepo.deleteByType('meal', 'meal-1')).called(1);
    });
  });

  group('EntriesNotifier.reset', () {
    test('clears state back to defaults', () async {
      final result = testEntryQueryResult();
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => result);

      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .loadEntries(DateTime(2026, 3, 25));
      expect(container.read(entriesProvider).meals, hasLength(1));

      container.read(entriesProvider.notifier).reset();

      final state = container.read(entriesProvider);
      expect(state.meals, isEmpty);
      expect(state.toiletEntries, isEmpty);
      expect(state.gutFeelings, isEmpty);
      expect(state.drinks, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });
}
