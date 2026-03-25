import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../services/ingredient_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import '../utils/suggestion_helpers.dart';

class IngredientRepository {
  final IngredientService _ingredientService;
  static const _log = AppLogger('IngredientRepository');

  IngredientRepository(this._ingredientService);

  Future<List<IngredientSearchResult>> search(
    String query, {
    int limit = 10,
    required String? userId,
  }) => _ingredientService.search(query, limit: limit, userId: userId);

  Future<void> insertIfNew(String name, {required String? userId}) =>
      _ingredientService.insertIfNew(name, userId: userId);

  Future<void> deleteUserIngredient(String id) =>
      _ingredientService.deleteUserIngredient(id);

  Future<List<IngredientSuggestionGroup>> fetchSuggestionGroups(
    String userId,
  ) async {
    final data = await retryAsync(
      () => _ingredientService.fetchSuggestions(userId),
      log: _log,
      label: 'fetchSuggestions',
    );

    final allSuggestionIds = <String>[];
    final allMealIds = <String>{};
    for (final row in data) {
      final id = row['id'] as String?;
      if (id != null) allSuggestionIds.add(id);
      final mealId = row['meal_id'] as String?;
      if (mealId != null) allMealIds.add(mealId);
    }

    final results = await Future.wait([
      _ingredientService.fetchReplacements(allSuggestionIds),
      _ingredientService.fetchMealDetails(allMealIds.toList()),
    ]);

    return SuggestionHelpers.buildGroups(
      suggestionData: data,
      replacementsData: results[0],
      mealsData: results[1],
    );
  }

  Future<void> markAllSeen(List<String> ids) =>
      _ingredientService.markAllSeen(ids);

  Future<void> dismissSuggestions(List<String> ids) =>
      _ingredientService.dismissSuggestions(ids);

  Future<int> fetchNewCount(String userId) =>
      _ingredientService.fetchNewCount(userId);
}

final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => IngredientRepository(ref.watch(ingredientServiceProvider)),
);
