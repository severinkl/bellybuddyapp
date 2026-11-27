import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/ingredient_suggestion.dart' as model;
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/intolerance_rules.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/models/ingredient_search_result.dart';

const testUserId = 'test-user-id';

/// Default `tutorialSeenAt` for test fixtures — a non-null timestamp so tests
/// that seed a profile don't accidentally trigger the dashboard onboarding
/// tour. Tests covering the tour explicitly pass `alreadySeenTutorial: false`.
final DateTime testTutorialAlreadySeenAt = DateTime.utc(2026, 1, 1);

/// Default `healthConsentAt` for test fixtures — a non-null timestamp with
/// the current policy version so tests that seed a profile aren't sent
/// through the health-consent gate. Consent tests pass
/// `hasHealthConsent: false` or an outdated `privacyPolicyVersion`.
final DateTime testHealthConsentAt = DateTime.utc(2026, 11, 22);

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
  List<String>? mealReminderTimes,
  bool dailySummaryEnabled = true,
  List<String>? moodReminderTimes,
  bool pushEnabled = false,
  String? timezone,
  DateTime? tutorialSeenAt,
  bool alreadySeenTutorial = true,
  DateTime? healthConsentAt,
  String? privacyPolicyVersion,
  bool hasHealthConsent = true,
  bool weeklyTipsEnabled = false,
  String dailyReviewTime = '19:30',
  bool dailyReviewReminder = false,
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
  mealReminderTimes: mealReminderTimes ?? ['18:00'],
  dailySummaryEnabled: dailySummaryEnabled,
  moodReminderTimes: moodReminderTimes ?? ['20:00'],
  pushEnabled: pushEnabled,
  timezone: timezone ?? 'Europe/Berlin',
  tutorialSeenAt:
      tutorialSeenAt ??
      (alreadySeenTutorial ? testTutorialAlreadySeenAt : null),
  healthConsentAt:
      healthConsentAt ?? (hasHealthConsent ? testHealthConsentAt : null),
  privacyPolicyVersion:
      privacyPolicyVersion ??
      (hasHealthConsent ? AppConstants.privacyPolicyVersion : null),
  weeklyTipsEnabled: weeklyTipsEnabled,
  dailyReviewTime: dailyReviewTime,
  dailyReviewReminder: dailyReviewReminder,
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

/// A collection recipe line. A mapped line has `catalogId: 'ing-$name'` and
/// `catalogName: name`.
RecipeIngredient testLine(
  String name, {
  int position = 0,
  String? amount,
  FodmapFlags fodmaps = const FodmapFlags(),
  Set<String> allergens = const {},
  bool lowAtAmount = false,
  bool mapped = true,
}) => RecipeIngredient(
  position: position,
  amount: amount,
  name: name,
  catalogId: mapped ? 'ing-$name' : null,
  catalogName: mapped ? name : null,
  fodmaps: mapped ? fodmaps : null,
  allergens: allergens,
  lowAtAmount: lowAtAmount,
);

Recipe testRecipe({
  String id = 'recipe-1',
  String title = 'Testrezept',
  List<RecipeIngredient>? ingredients,
  List<MealType> mealTypes = const [MealType.lunch],
  Set<String> dietTags = const {'vegan', 'vegetarisch'},
  String? cookTime = '20 Min',
  int? servings = 2,
  List<String> instructions = const ['Alles kochen.'],
  String? sourceName,
  String? sourceUrl,
  DateTime? createdAt,
}) => Recipe(
  id: id,
  title: title,
  ingredients: ingredients ?? [testLine('Reis')],
  mealTypes: mealTypes,
  dietTags: dietTags,
  cookTime: cookTime,
  servings: servings,
  instructions: instructions,
  sourceName: sourceName,
  sourceUrl: sourceUrl,
  createdAt: createdAt,
);

/// Core's intolerance table as core #11 publishes it in
/// `app_config.intolerance_rules` (`json.dumps(INTOLERANCE_RULES,
/// ensure_ascii=False)`), „Milch" and „Erdnuss" among the allergens.
const kTestIntoleranceRulesJson =
    '{"Laktose": {"fodmaps": ["lactose"], "allergens": [], "judgeable": true}, '
    '"Gluten": {"fodmaps": [], "allergens": ["gluten"], "judgeable": true}, '
    '"Weizen": {"fodmaps": ["fructans"], "allergens": ["weizen"], "judgeable": true}, '
    '"Nüsse": {"fodmaps": [], "allergens": ["nuesse"], "judgeable": true}, '
    '"Eier": {"fodmaps": [], "allergens": ["eier"], "judgeable": true}, '
    '"Soja": {"fodmaps": [], "allergens": ["soja"], "judgeable": true}, '
    '"Milch": {"fodmaps": [], "allergens": ["milch"], "judgeable": true}, '
    '"Erdnuss": {"fodmaps": [], "allergens": ["erdnuss"], "judgeable": true}, '
    '"Fruktose": {"fodmaps": ["fructose"], "allergens": [], "judgeable": true}, '
    '"Sorbit": {"fodmaps": ["sorbitol"], "allergens": [], "judgeable": true}, '
    '"Histamin": {"fodmaps": [], "allergens": [], "judgeable": false}, '
    '"Mannit": {"fodmaps": ["mannitol"], "allergens": [], "judgeable": true}, '
    '"Fructane": {"fodmaps": ["fructans"], "allergens": [], "judgeable": true}, '
    '"GOS": {"fodmaps": ["gos"], "allergens": [], "judgeable": true}, '
    '"FODMAPs": {"fodmaps": ["fructans", "gos", "lactose", "fructose", "sorbitol", "mannitol"], '
    '"allergens": [], "judgeable": true}}';

IntoleranceRules testIntoleranceRules() =>
    IntoleranceRules.parse(kTestIntoleranceRulesJson)!;

/// A tip set: by default with one tip ([testRecommendationItem]), since a
/// set without tips is never new; pass `recommendations: []` for one.
Recommendation testRecommendation({
  String? id,
  String? summary,
  List<RecommendationItem>? recommendations,
  DateTime? createdAt,
  DateTime? seenAt,
}) => Recommendation(
  id: id ?? 'rec-1',
  summary: summary ?? 'Tipp: Mehr Wasser trinken.',
  recommendations: recommendations ?? [testRecommendationItem()],
  createdAt: createdAt,
  seenAt: seenAt,
);

/// A tip: by default a Tausch-Tipp, Zwiebel → Schnittlauch, without focus
/// or a recipe (an older set's shape).
RecommendationItem testRecommendationItem({
  String type = 'substitute',
  String ingredient = 'Zwiebel',
  String reason = 'Grund',
  String? alternative = 'Schnittlauch',
  bool focus = false,
  String? recipeId,
  String? recipeTitle,
}) => RecommendationItem(
  type: type,
  ingredient: ingredient,
  reason: reason,
  alternative: alternative,
  focus: focus,
  recipeId: recipeId,
  recipeTitle: recipeTitle,
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

IngredientSearchResult testIngredientSearchResult({
  String? id,
  String? name,
  bool isOwn = false,
}) => IngredientSearchResult(
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

/// Four blog articles without images, newest first: two „Gesund verdauen",
/// one „Rezepte", one „Persönliches".
List<KnowledgeArticle> testKnowledgeArticles() => [
  KnowledgeArticle(
    title: 'Was ist FODMAP?',
    link: Uri.parse('https://www.myfodmap.at/was-ist-fodmap'),
    category: 'Gesund verdauen',
    publishedAt: DateTime.utc(2026, 11, 20, 8),
  ),
  KnowledgeArticle(
    title: 'Suppe für kalte Tage',
    link: Uri.parse('https://www.myfodmap.at/suppe'),
    category: 'Rezepte',
    publishedAt: DateTime.utc(2026, 11, 10, 8),
  ),
  KnowledgeArticle(
    title: 'Mein Weg zum Bauchgefühl',
    link: Uri.parse('https://www.myfodmap.at/mein-weg'),
    category: 'Persönliches',
    publishedAt: DateTime.utc(2026, 10, 28, 8),
  ),
  KnowledgeArticle(
    title: 'Ballaststoffe verstehen',
    link: Uri.parse('https://www.myfodmap.at/ballaststoffe'),
    category: 'Gesund verdauen',
    publishedAt: DateTime.utc(2026, 10, 15, 8),
  ),
];

/// Insights from the first days: [activeDays] days with entries and
/// [gutFeelings] Bauchgefühl entries (locked below InsightRules'
/// thresholds), the [journey]'s dots, nothing noticed yet.
Insights lockedInsights({
  int activeDays = 2,
  int gutFeelings = 1,
  List<JourneyDay> journey = const [],
}) => Insights(
  progress: InsightProgress(
    activeDays: activeDays,
    gutFeelingEntries: gutFeelings,
  ),
  calendar: const [],
  goodDays: const DayColumn(days: 0),
  hardDays: const DayColumn(days: 0),
  noticed: const [],
  pick: const NothingYetPick(),
  journey: journey,
);
