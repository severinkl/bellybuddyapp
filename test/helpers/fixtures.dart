import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/ingredient_suggestion.dart' as model;
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/ingredient_service.dart';

const testUserId = 'test-user-id';

UserProfile testUserProfile({
  String? userId,
  int? birthYear,
  String? gender,
  int? height,
  int? weight,
  String? diet,
  List<String>? symptoms,
  List<String>? intolerances,
  String? authMethod,
  bool remindersEnabled = true,
  List<String>? reminderTimes,
  bool dailySummaryEnabled = true,
  String dailySummaryTime = '20:00',
  bool pushEnabled = false,
  String? timezone,
}) => UserProfile(
  userId: userId ?? testUserId,
  birthYear: birthYear ?? 1990,
  gender: gender ?? 'male',
  height: height ?? 180,
  weight: weight ?? 75,
  diet: diet ?? 'Keine Einschränkungen',
  symptoms: symptoms ?? ['Blähungen'],
  intolerances: intolerances ?? [],
  authMethod: authMethod ?? 'email',
  remindersEnabled: remindersEnabled,
  reminderTimes: reminderTimes ?? ['18:00'],
  dailySummaryEnabled: dailySummaryEnabled,
  dailySummaryTime: dailySummaryTime,
  pushEnabled: pushEnabled,
  timezone: timezone ?? 'Europe/Berlin',
);

MealEntry testMealEntry({
  String? id,
  DateTime? trackedAt,
  String? title,
  List<String>? ingredients,
  String? imageUrl,
}) => MealEntry(
  id: id ?? 'meal-1',
  trackedAt: trackedAt ?? DateTime(2026, 3, 25, 12, 0),
  title: title ?? 'Testmahlzeit',
  ingredients: ingredients ?? ['Reis', 'Gemüse'],
  imageUrl: imageUrl,
);

ToiletEntry testToiletEntry({
  String? id,
  DateTime? trackedAt,
  int? stoolType,
}) => ToiletEntry(
  id: id ?? 'toilet-1',
  trackedAt: trackedAt ?? DateTime(2026, 3, 25, 14, 0),
  stoolType: stoolType ?? 3,
);

GutFeelingEntry testGutFeelingEntry({
  String? id,
  DateTime? trackedAt,
  int bloating = 2,
  int gas = 1,
  int cramps = 0,
  int fullness = 2,
}) => GutFeelingEntry(
  id: id ?? 'gut-1',
  trackedAt: trackedAt ?? DateTime(2026, 3, 25, 16, 0),
  bloating: bloating,
  gas: gas,
  cramps: cramps,
  fullness: fullness,
);

DrinkEntry testDrinkEntry({
  String? id,
  DateTime? trackedAt,
  String? drinkId,
  String? drinkName,
  int? amountMl,
}) => DrinkEntry(
  id: id ?? 'drink-entry-1',
  trackedAt: trackedAt ?? DateTime(2026, 3, 25, 10, 0),
  drinkId: drinkId ?? 'water-id',
  drinkName: drinkName ?? 'Wasser',
  amountMl: amountMl ?? 250,
);

Drink testDrink({String? id, String? name, String? addedByUserId}) => Drink(
  id: id ?? 'water-id',
  name: name ?? 'Wasser',
  addedByUserId: addedByUserId,
);

Recipe testRecipe({
  String? id,
  String? title,
  List<String>? tags,
  List<String>? ingredients,
}) => Recipe(
  id: id ?? 'recipe-1',
  title: title ?? 'Testrezept',
  tags: tags ?? ['vegetarisch'],
  ingredients: ingredients ?? ['Reis', 'Gemüse'],
);

Recommendation testRecommendation({
  String? id,
  String? summary,
  List<RecommendationItem>? recommendations,
}) => Recommendation(
  id: id ?? 'rec-1',
  summary: summary ?? 'Tipp: Mehr Wasser trinken.',
  recommendations: recommendations ?? [],
);

EntryQueryResult testEntryQueryResult({
  List<MealEntry>? meals,
  List<ToiletEntry>? toiletEntries,
  List<GutFeelingEntry>? gutFeelings,
  List<DrinkEntry>? drinks,
}) => EntryQueryResult(
  meals: meals ?? [testMealEntry()],
  toiletEntries: toiletEntries ?? [testToiletEntry()],
  gutFeelings: gutFeelings ?? [testGutFeelingEntry()],
  drinks: drinks ?? [testDrinkEntry()],
);

IngredientSuggestion testIngredientSuggestion({
  String? id,
  String? name,
  bool isOwn = false,
}) => IngredientSuggestion(
  id: id ?? 'ing-1',
  name: name ?? 'Zwiebel',
  isOwn: isOwn,
);

/// Freezed model IngredientSuggestion (from lib/models/ingredient_suggestion.dart).
/// Different from the service-layer IngredientSuggestion in ingredient_service.dart.
/// Imported with `as model` prefix to avoid name collision.
model.IngredientSuggestion testIngredientSuggestionModel({
  String? id,
  String? detectedIngredientId,
  String? mealId,
  String? helptext,
  DateTime? seenAt,
  DateTime? dismissedAt,
}) => model.IngredientSuggestion(
  id: id ?? 'model-sug-1',
  detectedIngredientId: detectedIngredientId ?? 'ing-1',
  mealId: mealId ?? 'meal-1',
  helptext: helptext,
  seenAt: seenAt,
  dismissedAt: dismissedAt,
);

IngredientSuggestionGroup testSuggestionGroup({
  String? ingredientId,
  String? ingredientName,
  bool isNew = true,
  List<String>? suggestionIds,
  int mealCount = 2,
}) => IngredientSuggestionGroup(
  ingredientId: ingredientId ?? 'ing-1',
  ingredientName: ingredientName ?? 'Zwiebel',
  mealCount: mealCount,
  isNew: isNew,
  suggestionIds: suggestionIds ?? ['sug-1', 'sug-2'],
);
