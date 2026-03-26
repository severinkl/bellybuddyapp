import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drink.dart';
import '../services/drink_service.dart';

class DrinkRepository {
  final DrinkService _drinkService;
  DrinkRepository(this._drinkService);

  Future<List<Drink>> fetchAll() => _drinkService.fetchAll();

  Future<int> fetchTodayTotal(String userId) =>
      _drinkService.fetchTodayTotal(userId);

  Future<List<String>> fetchRecentDrinkIds(String userId) =>
      _drinkService.fetchRecentDrinkIds(userId);

  Future<Drink> insertDrink(String name, {required String userId}) =>
      _drinkService.insertDrink(name, userId: userId);

  Future<void> deleteDrink(String drinkId) =>
      _drinkService.deleteDrink(drinkId);
}

final drinkRepositoryProvider = Provider<DrinkRepository>(
  (ref) => DrinkRepository(ref.watch(drinkServiceProvider)),
);
