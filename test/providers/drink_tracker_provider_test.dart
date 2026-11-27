import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/utils/wall_clock.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockDrinkRepository mockDrinkRepo;
  late MockEntryRepository mockEntryRepo;

  setUp(() {
    mockDrinkRepo = MockDrinkRepository();
    mockEntryRepo = MockEntryRepository();
    registerFallbackValue(testDrink());
    registerFallbackValue(testDrinkEntry());
    when(
      () => mockDrinkRepo.fetchLastEntry(any()),
    ).thenAnswer((_) async => null);
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          drinkRepositoryProvider.overrideWithValue(mockDrinkRepo),
          entryRepositoryProvider.overrideWithValue(mockEntryRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  void stubLoad(List<Drink> drinks, {DrinkEntry? lastEntry}) {
    when(() => mockDrinkRepo.fetchAll()).thenAnswer((_) async => drinks);
    when(
      () => mockDrinkRepo.fetchRecentDrinkIds(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockDrinkRepo.fetchLastEntry(any()),
    ).thenAnswer((_) async => lastEntry);
  }

  group('DrinkTrackerNotifier.loadDrinks', () {
    test('populates allDrinks and quickDrinks', () async {
      final drinks = [testDrink(id: 'd-1', name: 'Wasser')];
      when(() => mockDrinkRepo.fetchAll()).thenAnswer((_) async => drinks);
      when(
        () => mockDrinkRepo.fetchRecentDrinkIds(any()),
      ).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(drinkTrackerProvider.notifier).loadDrinks();

      final state = container.read(drinkTrackerProvider);
      expect(state.allDrinks, hasLength(1));
      expect(state.isLoading, isFalse);
    });

    test('resolves the last entry to its drink and amount', () async {
      final tee = testDrink(id: 'tee-id', name: 'Tee');
      stubLoad([
        tee,
      ], lastEntry: testDrinkEntry(drinkId: 'tee-id', amountMl: 400));

      final container = makeContainer();
      await container.read(drinkTrackerProvider.notifier).loadDrinks();

      expect(container.read(drinkTrackerProvider).lastDrink, (
        drink: tee,
        amountMl: 400,
      ));
    });

    test('a last entry whose drink is unknown shows no row', () async {
      stubLoad([testDrink()], lastEntry: testDrinkEntry(drinkId: 'gone'));

      final container = makeContainer();
      await container.read(drinkTrackerProvider.notifier).loadDrinks();

      expect(container.read(drinkTrackerProvider).lastDrink, isNull);
    });

    test('no last entry means no row', () async {
      stubLoad([testDrink()]);

      final container = makeContainer();
      await container.read(drinkTrackerProvider.notifier).loadDrinks();

      expect(container.read(drinkTrackerProvider).lastDrink, isNull);
    });

    test(
      'a failing last-entry fetch leaves lastDrink null and loads the rest',
      () async {
        stubLoad([testDrink()]);
        when(
          () => mockDrinkRepo.fetchLastEntry(any()),
        ).thenAnswer((_) async => throw Exception('db error'));

        final container = makeContainer();
        await container.read(drinkTrackerProvider.notifier).loadDrinks();

        final state = container.read(drinkTrackerProvider);
        expect(state.lastDrink, isNull);
        expect(state.allDrinks, hasLength(1));
        expect(state.isLoading, isFalse);
      },
    );

    test('sets isLoading false on error', () async {
      when(() => mockDrinkRepo.fetchAll()).thenThrow(Exception('db error'));

      final container = makeContainer();
      await container.read(drinkTrackerProvider.notifier).loadDrinks();

      expect(container.read(drinkTrackerProvider).isLoading, isFalse);
    });
  });

  group('DrinkTrackerNotifier.toggleDrink', () {
    test('selects drink when not selected', () {
      final container = makeContainer();
      final drink = testDrink();

      container.read(drinkTrackerProvider.notifier).toggleDrink(drink);

      expect(container.read(drinkTrackerProvider).selectedDrink, equals(drink));
    });

    test('deselects drink when already selected', () {
      final container = makeContainer();
      final drink = testDrink();
      final notifier = container.read(drinkTrackerProvider.notifier);

      notifier.toggleDrink(drink);
      notifier.toggleDrink(drink);

      expect(container.read(drinkTrackerProvider).selectedDrink, isNull);
    });
  });

  group('DrinkTrackerNotifier.selectAmount', () {
    test('sets selectedAmount and clears customAmount', () {
      final container = makeContainer();
      container.read(drinkTrackerProvider.notifier).selectAmount(250);

      final state = container.read(drinkTrackerProvider);
      expect(state.selectedAmount, equals(250));
      expect(state.customAmount, isEmpty);
    });
  });

  group('DrinkTrackerNotifier.setCustomAmount', () {
    test('sets customAmount and parses selectedAmount', () {
      final container = makeContainer();
      container.read(drinkTrackerProvider.notifier).setCustomAmount('350');

      final state = container.read(drinkTrackerProvider);
      expect(state.customAmount, equals('350'));
      expect(state.selectedAmount, equals(350));
    });

    test('an amount over the cap selects nothing', () {
      final container = makeContainer();
      container.read(drinkTrackerProvider.notifier).setCustomAmount('99999');

      final state = container.read(drinkTrackerProvider);
      expect(state.customAmount, equals('99999'));
      expect(state.selectedAmount, isNull);
    });
  });

  group('DrinkTrackerNotifier day total', () {
    test("loads the total of the entry's day", () async {
      when(
        () => mockDrinkRepo.fetchDayTotal(any(), any()),
      ).thenAnswer((_) async => 750);
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);
      notifier.setTrackedAt(DateTime(2026, 11, 22, 12));
      await pumpEventQueue();
      clearInteractions(mockDrinkRepo);

      await notifier.loadDayTotal();

      verify(
        () => mockDrinkRepo.fetchDayTotal(testUserId, DateTime(2026, 11, 22)),
      ).called(1);
      expect(container.read(drinkTrackerProvider).dayTotal, 750);
    });

    test('moving the entry to another day reloads that day', () async {
      when(
        () => mockDrinkRepo.fetchDayTotal(any(), DateTime(2026, 11, 22)),
      ).thenAnswer((_) async => 750);
      when(
        () => mockDrinkRepo.fetchDayTotal(any(), DateTime(2026, 11, 21)),
      ).thenAnswer((_) async => 200);
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);
      notifier.setTrackedAt(DateTime(2026, 11, 22, 12));
      await pumpEventQueue();
      expect(container.read(drinkTrackerProvider).dayTotal, 750);

      notifier.setTrackedAt(DateTime(2026, 11, 22, 18));
      await pumpEventQueue();
      verify(
        () => mockDrinkRepo.fetchDayTotal(any(), DateTime(2026, 11, 22)),
      ).called(1);

      notifier.setTrackedAt(DateTime(2026, 11, 21, 18));
      await pumpEventQueue();
      expect(container.read(drinkTrackerProvider).dayTotal, 200);
    });
  });

  group('DrinkTrackerNotifier.createDrink', () {
    test(
      'calls insertDrink, adds to allDrinks, and selects new drink',
      () async {
        final newDrink = testDrink(id: 'new-1', name: 'Saft');
        when(
          () => mockDrinkRepo.insertDrink(any(), userId: any(named: 'userId')),
        ).thenAnswer((_) async => newDrink);

        final container = makeContainer();
        await container.read(drinkTrackerProvider.notifier).createDrink('Saft');

        verify(
          () => mockDrinkRepo.insertDrink('Saft', userId: testUserId),
        ).called(1);

        final state = container.read(drinkTrackerProvider);
        expect(state.allDrinks, contains(newDrink));
        expect(state.selectedDrink, equals(newDrink));
      },
    );

    test('returns early when userId is null', () async {
      final container = makeContainer(userId: null);
      await container.read(drinkTrackerProvider.notifier).createDrink('Saft');

      verifyNever(
        () => mockDrinkRepo.insertDrink(any(), userId: any(named: 'userId')),
      );
    });
  });

  group('DrinkTrackerNotifier search and creating', () {
    test('openSearch and closeSearch', () {
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);

      notifier.openSearch();
      expect(container.read(drinkTrackerProvider).isSearchOpen, isTrue);
      notifier.closeSearch();
      expect(container.read(drinkTrackerProvider).isSearchOpen, isFalse);
    });

    test('picking a drink closes the search', () {
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier)
        ..openSearch();

      notifier.toggleDrink(testDrink());

      expect(container.read(drinkTrackerProvider).isSearchOpen, isFalse);
    });

    test('creating a drink closes the search', () async {
      when(
        () => mockDrinkRepo.insertDrink(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async => testDrink(id: 'new-1', name: 'Saft'));
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier)
        ..openSearch();

      await notifier.createDrink('Saft');

      expect(container.read(drinkTrackerProvider).isSearchOpen, isFalse);
    });

    test(
      'createDrink selects the new drink without reordering quickDrinks',
      () async {
        final wasser = testDrink();
        stubLoad([wasser]);
        final newDrink = testDrink(id: 'new-1', name: 'Saft');
        when(
          () => mockDrinkRepo.insertDrink(any(), userId: any(named: 'userId')),
        ).thenAnswer((_) async => newDrink);
        final container = makeContainer();
        final notifier = container.read(drinkTrackerProvider.notifier);
        await notifier.loadDrinks();
        final before = container.read(drinkTrackerProvider).quickDrinks;

        await notifier.createDrink('Saft');

        final state = container.read(drinkTrackerProvider);
        expect(state.quickDrinks, before);
        expect(state.selectedDrink, newDrink);
      },
    );
  });

  group('DrinkTrackerNotifier.saveLast', () {
    test(
      'stores the last drink at the chosen time and shows success',
      () async {
        final tee = testDrink(id: 'tee-id', name: 'Tee');
        stubLoad([
          tee,
        ], lastEntry: testDrinkEntry(drinkId: 'tee-id', amountMl: 400));
        when(
          () => mockEntryRepo.insertEntry(
            any(),
            any(),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockDrinkRepo.fetchDayTotal(any(), any()),
        ).thenAnswer((_) async => 400);
        final container = makeContainer();
        final notifier = container.read(drinkTrackerProvider.notifier);
        await notifier.loadDrinks();
        notifier.setTrackedAt(DateTime(2026, 11, 26, 20));

        await notifier.saveLast();

        final data =
            verify(
                  () => mockEntryRepo.insertEntry(
                    any(),
                    captureAny(),
                    userId: testUserId,
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(data['drink_id'], 'tee-id');
        expect(data['amount_ml'], 400);
        expect(data['tracked_at'], wallClockToWire(DateTime(2026, 11, 26, 20)));
        expect(container.read(drinkTrackerProvider).showSuccess, isTrue);
      },
    );

    test('without a last entry stores nothing', () async {
      stubLoad([testDrink()]);
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);
      await notifier.loadDrinks();

      await notifier.saveLast();

      verifyNever(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      );
      expect(container.read(drinkTrackerProvider).showSuccess, isFalse);
    });
  });

  group('DrinkTrackerNotifier.save', () {
    test('creates drink entry and sets showSuccess', () async {
      final drink = testDrink();

      when(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDrinkRepo.fetchDayTotal(any(), any()),
      ).thenAnswer((_) async => 250);

      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);

      // Select drink and amount before saving
      notifier.toggleDrink(drink);
      notifier.selectAmount(250);

      await notifier.save();

      verify(
        () => mockEntryRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);

      final state = container.read(drinkTrackerProvider);
      expect(state.showSuccess, isTrue);
      expect(state.isSaving, isFalse);
    });

    test('returns early when no drink selected', () async {
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);

      // No drink selected
      notifier.selectAmount(250);
      await notifier.save();

      verifyNever(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      );
    });

    test('returns early when no amount selected', () async {
      final container = makeContainer();
      final notifier = container.read(drinkTrackerProvider.notifier);

      // No amount selected
      notifier.toggleDrink(testDrink());
      await notifier.save();

      verifyNever(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      );
    });
  });
}
