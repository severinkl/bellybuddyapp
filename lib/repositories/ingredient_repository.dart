import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../services/alternatives/alternative_ranking.dart';
import '../services/ingredient_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import '../utils/suggestion_helpers.dart';
import '../utils/wall_clock.dart';

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

  /// The user's suggestion groups, each with its replacements ranked by
  /// the meals of the last [rankingMealDays] days; without verdicts (the
  /// notifier ranks them with the choices, which change on their own).
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

    final now = DateTime.now();
    final results = await Future.wait([
      _ingredientService.fetchReplacements(allSuggestionIds),
      _ingredientService.fetchMealDetails(allMealIds.toList()),
      if (data.isNotEmpty)
        _recentMeals(
          userId,
          DateTime(now.year, now.month, now.day - rankingMealDays),
        ),
    ]);

    return SuggestionHelpers.buildGroups(
      suggestionData: data,
      replacementsData: results[0],
      mealsData: results[1],
      recentMeals: [
        if (results.length > 2)
          for (final row in results[2])
            (
              trackedAt: wallClockFromWire(row['tracked_at'] as String),
              ingredients: [
                for (final name in row['ingredients'] as List? ?? const [])
                  if (name is String) name,
              ],
            ),
      ],
    );
  }

  /// The meals for „eaten afterwards". The ranking is a nicety: on failure
  /// the groups rank without them (logged).
  Future<List<Map<String, dynamic>>> _recentMeals(
    String userId,
    DateTime since,
  ) async {
    try {
      return await _ingredientService.fetchMealsSince(userId, since);
    } catch (e, st) {
      _log.error('fetchMealsSince failed; ranking without meals', e, st);
      return const [];
    }
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
