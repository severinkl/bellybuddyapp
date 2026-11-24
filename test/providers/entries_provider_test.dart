import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/entry_query_service.dart';

import '../helpers/fakes.dart';
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
    when(
      () => mockRepo.fetchLatestBefore(
        userId: any(named: 'userId'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async => const LatestEntries());
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

  group('EntriesNotifier.loadEntries latest before the day', () {
    void stubDay(Future<EntryQueryResult> Function() answer) => when(
      () => mockRepo.fetchForDate(
        userId: any(named: 'userId'),
        date: any(named: 'date'),
        ordered: any(named: 'ordered'),
      ),
    ).thenAnswer((_) => answer());

    test('loadEntries brings the latest entries before the day', () async {
      stubDay(() async => testEntryQueryResult());
      final yesterdayDrink = DateTime(2026, 11, 22, 21);
      when(
        () => mockRepo.fetchLatestBefore(
          userId: any(named: 'userId'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => LatestEntries(drink: yesterdayDrink));
      final container = makeContainer();

      await container
          .read(entriesProvider.notifier)
          .loadEntries(DateTime(2026, 11, 23, 14));

      verify(
        () => mockRepo.fetchLatestBefore(
          userId: testUserId,
          before: DateTime(2026, 11, 23),
        ),
      ).called(1);
      expect(
        container.read(entriesProvider).latestBefore.drink,
        yesterdayDrink,
      );
    });

    test('a failing latest-before query still loads the day', () async {
      stubDay(() async => testEntryQueryResult());
      when(
        () => mockRepo.fetchLatestBefore(
          userId: any(named: 'userId'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => throw Exception('db error'));
      final container = makeContainer();

      await container
          .read(entriesProvider.notifier)
          .loadEntries(DateTime(2026, 11, 23));

      final state = container.read(entriesProvider);
      expect(state.meals, hasLength(1));
      expect(state.latestBefore, const LatestEntries());
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
    });

    test('a superseded load publishes neither', () async {
      final slowDay = Completer<EntryQueryResult>();
      final slowLatest = Completer<LatestEntries>();
      var calls = 0;
      stubDay(
        () => ++calls == 1
            ? slowDay.future
            : Future.value(testEntryQueryResult(meals: [])),
      );
      var latestCalls = 0;
      when(
        () => mockRepo.fetchLatestBefore(
          userId: any(named: 'userId'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) => ++latestCalls == 1
            ? slowLatest.future
            : Future.value(LatestEntries(meal: DateTime(2026, 11, 22, 19))),
      );
      final container = makeContainer();
      final notifier = container.read(entriesProvider.notifier);

      final first = notifier.loadEntries(DateTime(2026, 11, 23));
      await notifier.loadEntries(DateTime(2026, 11, 23));
      slowDay.complete(testEntryQueryResult());
      slowLatest.complete(LatestEntries(drink: DateTime(2026, 11, 20, 8)));
      await first;

      final state = container.read(entriesProvider);
      expect(state.meals, isEmpty);
      expect(state.latestBefore.meal, DateTime(2026, 11, 22, 19));
      expect(state.latestBefore.drink, isNull);
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

  group('EntriesNotifier keeps the loaded day current', () {
    final day = DateTime(2026, 3, 25);

    /// The backend: [fetchForDate] serves [rows]; a write changes them.
    late EntryQueryResult rows;
    late List<DateTime> fetched;

    setUp(() {
      rows = testEntryQueryResult();
      fetched = [];
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((invocation) async {
        fetched.add(invocation.namedArguments[#date] as DateTime);
        return rows;
      });
    });

    EntryQueryResult without({bool meals = false, bool drinks = false}) =>
        testEntryQueryResult(
          meals: meals ? const [] : null,
          drinks: drinks ? const [] : null,
        );

    test('loadEntries remembers the local day it loaded', () async {
      final container = makeContainer();
      await container
          .read(entriesProvider.notifier)
          .loadEntries(DateTime(2026, 3, 25, 21, 30));

      expect(container.read(entriesProvider).day, day);
    });

    test('a diary delete reloads the loaded day: the entry is gone', () async {
      when(() => mockRepo.deleteByType(any(), any())).thenAnswer((_) async {
        rows = without(meals: true);
      });
      final container = makeContainer();
      final notifier = container.read(entriesProvider.notifier);
      await notifier.loadEntries(day);
      expect(container.read(entriesProvider).meals, hasLength(1));

      await notifier.deleteByType('meal', 'meal-1');
      await pumpEventQueue();

      expect(container.read(entriesProvider).meals, isEmpty);
      expect(fetched, [day, day]);
    });

    test('a diary edit reloads the loaded day', () async {
      when(() => mockRepo.updateEntry(any(), any(), any())).thenAnswer((
        _,
      ) async {
        rows = testEntryQueryResult(drinks: [testDrinkEntry(amountMl: 500)]);
      });
      final container = makeContainer();
      final notifier = container.read(entriesProvider.notifier);
      await notifier.loadEntries(day);

      await notifier.updateDrinkById('drink-entry-1', amountMl: 500);
      await pumpEventQueue();

      expect(container.read(entriesProvider).drinks.single.amountMl, 500);
    });

    test("a tracker's log reloads the loaded day, with or without a Buddy "
        'event', () async {
      rows = without(drinks: true);
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {
        rows = testEntryQueryResult();
      });
      final container = makeContainer();
      final notifier = container.read(entriesProvider.notifier);
      await notifier.loadEntries(day);
      expect(container.read(entriesProvider).drinks, isEmpty);

      await notifier.addDrinkEntry(testDrinkEntry());
      await pumpEventQueue();

      expect(container.read(entriesProvider).drinks, hasLength(1));
    });

    test('a write before anything was loaded loads nothing', () async {
      when(() => mockRepo.deleteByType(any(), any())).thenAnswer((_) async {});
      final container = makeContainer();

      await container
          .read(entriesProvider.notifier)
          .deleteByType('meal', 'meal-1');
      await pumpEventQueue();

      expect(fetched, isEmpty);
      expect(container.read(entriesProvider).day, isNull);
    });

    test(
      'an older load finishing last does not overwrite a newer one',
      () async {
        final slow = Completer<EntryQueryResult>();
        var calls = 0;
        when(
          () => mockRepo.fetchForDate(
            userId: any(named: 'userId'),
            date: any(named: 'date'),
            ordered: any(named: 'ordered'),
          ),
        ).thenAnswer((_) => ++calls == 1 ? slow.future : Future.value(rows));
        final container = makeContainer();
        final notifier = container.read(entriesProvider.notifier);

        final first = notifier.loadEntries(day);
        rows = without(meals: true);
        await notifier.loadEntries(day);
        slow.complete(testEntryQueryResult());
        await first;

        expect(container.read(entriesProvider).meals, isEmpty);
        expect(container.read(entriesProvider).isLoading, isFalse);
      },
    );
  });

  group('entriesRevisionProvider', () {
    setUp(() {
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => testEntryQueryResult());
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});
      when(
        () => mockRepo.updateEntry(any(), any(), any()),
      ).thenAnswer((_) async {});
      when(() => mockRepo.deleteEntry(any(), any())).thenAnswer((_) async {});
      when(() => mockRepo.deleteByType(any(), any())).thenAnswer((_) async {});
    });

    test('rises once per entry write: log, edit, moved date, delete', () async {
      final container = makeContainer();
      final revisions = <int>[];
      container.listen(
        entriesRevisionProvider,
        (_, next) => revisions.add(next),
      );
      final notifier = container.read(entriesProvider.notifier);

      await notifier.addMeal(testMealEntry());
      // A meal edit, also when it moves the meal to another day.
      await notifier.updateMeal(testMealEntry());
      await notifier.updateGutFeelingById(
        'gut-1',
        bloating: 1,
        gas: 1,
        cramps: 1,
        fullness: 1,
      );
      await notifier.deleteByType('meal', 'meal-1');
      await notifier.deleteToiletEntry('toilet-1');

      expect(revisions, [1, 2, 3, 4, 5]);
    });

    test('loads and failed writes leave it alone', () async {
      when(
        () => mockRepo.deleteByType(any(), any()),
      ).thenThrow(Exception('offline'));
      final container = makeContainer();
      final notifier = container.read(entriesProvider.notifier);

      await notifier.loadEntries(DateTime(2026, 3, 25));
      await expectLater(
        notifier.deleteByType('meal', 'meal-1'),
        throwsA(isA<Exception>()),
      );

      expect(container.read(entriesRevisionProvider), 0);
    });
  });

  group('EntriesNotifier refreshes a loaded Buddy', () {
    late _CountingBuddy buddy;

    setUp(() {
      buddy = _CountingBuddy();
      when(
        () => mockRepo.insertEntry(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});
      when(
        () => mockRepo.updateEntry(any(), any(), any()),
      ).thenAnswer((_) async {});
      when(() => mockRepo.deleteByType(any(), any())).thenAnswer((_) async {});
    });

    ProviderContainer withBuddy() => createContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(mockRepo),
        currentUserIdProvider.overrideWithValue(testUserId),
        buddyProvider.overrideWith(() => buddy),
      ],
    );

    test('a delete or a move reloads a loaded Buddy', () async {
      final container = withBuddy();
      container.read(buddyProvider);
      final notifier = container.read(entriesProvider.notifier);

      await notifier.deleteByType('meal', 'm1');
      expect(buddy.reloads, 1);

      await notifier.updateDrinkById(
        'drink-1',
        amountMl: 250,
        trackedAt: DateTime(2026, 11, 22, 18),
      );
      expect(buddy.reloads, 2);
    });

    test('an insert does not', () async {
      final container = withBuddy();
      container.read(buddyProvider);

      await container
          .read(entriesProvider.notifier)
          .addDrinkEntry(testDrinkEntry());

      expect(buddy.reloads, 0);
    });

    test('no Buddy loaded: nothing reloads', () async {
      final container = withBuddy();

      await container.read(entriesProvider.notifier).deleteByType('meal', 'm1');

      expect(buddy.builds, 0);
      expect(buddy.reloads, 0);
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

/// A Buddy that counts its builds and reloads.
class _CountingBuddy extends FakeBuddyNotifier {
  int builds = 0;
  int reloads = 0;

  @override
  Future<BuddyStatus?> build() {
    builds++;
    return super.build();
  }

  @override
  Future<void> reload() async => reloads++;
}
