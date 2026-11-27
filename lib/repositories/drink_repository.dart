import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drink.dart';
import '../models/drink_entry.dart';
import '../services/drink_service.dart';

class DrinkRepository {
  final DrinkService _drinkService;
  DrinkRepository(this._drinkService);

  Future<List<Drink>> fetchAll() => _drinkService.fetchAll();

  Future<int> fetchDayTotal(String userId, DateTime day) =>
      _drinkService.fetchDayTotal(userId, day);

  Future<List<String>> fetchRecentDrinkIds(String userId) =>
      _drinkService.fetchRecentDrinkIds(userId);

  Future<DrinkEntry?> fetchLastEntry(String userId) =>
      _drinkService.fetchLastEntry(userId);

  Future<Drink> insertDrink(String name, {required String userId}) =>
      _drinkService.insertDrink(name, userId: userId);

  Future<void> deleteDrink(String drinkId) =>
      _drinkService.deleteDrink(drinkId);
}

final drinkRepositoryProvider = Provider<DrinkRepository>(
  (ref) => DrinkRepository(ref.watch(drinkServiceProvider)),
);
