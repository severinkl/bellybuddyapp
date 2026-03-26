import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/drink_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockDrinkService drinkService;
  late DrinkRepository repo;

  setUp(() {
    drinkService = MockDrinkService();
    repo = DrinkRepository(drinkService);
  });

  group('fetchAll', () {
    test('delegates to drinkService.fetchAll and returns list', () async {
      final drinks = [testDrink(), testDrink(id: 'juice-id', name: 'Saft')];
      when(() => drinkService.fetchAll()).thenAnswer((_) async => drinks);

      final result = await repo.fetchAll();

      expect(result, equals(drinks));
      verify(() => drinkService.fetchAll()).called(1);
    });
  });

  group('fetchTodayTotal', () {
    test('delegates to drinkService.fetchTodayTotal', () async {
      when(
        () => drinkService.fetchTodayTotal(any()),
      ).thenAnswer((_) async => 750);

      final result = await repo.fetchTodayTotal('user-123');

      expect(result, equals(750));
      verify(() => drinkService.fetchTodayTotal('user-123')).called(1);
    });
  });

  group('insertDrink', () {
    test('delegates to drinkService.insertDrink with userId', () async {
      final drink = testDrink(name: 'Tee', addedByUserId: 'user-123');
      when(
        () => drinkService.insertDrink(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async => drink);

      final result = await repo.insertDrink('Tee', userId: 'user-123');

      expect(result, equals(drink));
      verify(
        () => drinkService.insertDrink('Tee', userId: 'user-123'),
      ).called(1);
    });
  });

  group('deleteDrink', () {
    test('delegates to drinkService.deleteDrink', () async {
      when(() => drinkService.deleteDrink(any())).thenAnswer((_) async {});

      await repo.deleteDrink('water-id');

      verify(() => drinkService.deleteDrink('water-id')).called(1);
    });
  });

  group('fetchRecentDrinkIds', () {
    test('delegates to drinkService.fetchRecentDrinkIds', () async {
      final ids = ['water-id', 'juice-id'];
      when(
        () => drinkService.fetchRecentDrinkIds(any()),
      ).thenAnswer((_) async => ids);

      final result = await repo.fetchRecentDrinkIds('user-123');

      expect(result, equals(ids));
      verify(() => drinkService.fetchRecentDrinkIds('user-123')).called(1);
    });
  });
}
