import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

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
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          drinkRepositoryProvider.overrideWithValue(mockDrinkRepo),
          entryRepositoryProvider.overrideWithValue(mockEntryRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

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
      expect(state.hasRecentDrinks, isFalse);
    });

    test('knows when the user has logged drinks before', () async {
      final drinks = [testDrink(id: 'd-1', name: 'Wasser')];
      when(() => mockDrinkRepo.fetchAll()).thenAnswer((_) async => drinks);
      when(
        () => mockDrinkRepo.fetchRecentDrinkIds(any()),
      ).thenAnswer((_) async => ['d-1']);

      final container = makeContainer();
      await container.read(drinkTrackerProvider.notifier).loadDrinks();

      expect(container.read(drinkTrackerProvider).hasRecentDrinks, isTrue);
    });

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
