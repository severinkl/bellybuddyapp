# Comprehensive Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ~450 new tests across all architectural layers, bringing coverage from 11% to comprehensive.

**Architecture:** Bottom-up by layer: shared test infrastructure → service tests → repository tests → provider tests → widget tests → screen tests → integration tests → CI pipeline. Each layer mocks only the layer directly below. Uses mocktail for mocking, hand-written fakes for repositories.

**Tech Stack:** Flutter, `flutter_test`, `mocktail`, `flutter_riverpod`, `integration_test`

**Spec:** `docs/superpowers/specs/2026-03-25-comprehensive-testing-design.md`

---

## File Structure

### Test Infrastructure (5 new files)

| File | Responsibility |
|---|---|
| `test/helpers/mocks.dart` | All mocktail mock class declarations |
| `test/helpers/fakes.dart` | Hand-written fake repository implementations |
| `test/helpers/fixtures.dart` | Reusable test data factories |
| `test/helpers/riverpod_helpers.dart` | `createContainer` + `pumpWithProviders` |
| `test/helpers/supabase_mocks.dart` | Supabase fluent query chain mock helpers |

### Test Files (63 new files)

| Directory | Count | Tests |
|---|---|---|
| `test/services/` | 10 | ~91 |
| `test/repositories/` | 9 | ~65 |
| `test/providers/` | 10 | ~114 |
| `test/widgets/` | 10 | ~42 |
| `test/screens/` | 17 | ~122 |
| `integration_test/` | 5 | ~15 |

### Modified Files

| File | Change |
|---|---|
| `pubspec.yaml` | Add `mocktail: ^1.0.4` + `integration_test` to dev_dependencies |
| `lib/repositories/notification_repository.dart` | Inject abstract `NotificationScheduler` for testability |
| `.github/workflows/ci.yml` | Multi-stage pipeline |

---

## Task 1: Add Dependencies + Create Mock Declarations

**Files:**
- Modify: `pubspec.yaml`
- Create: `test/helpers/mocks.dart`
- Create: `test/helpers/supabase_mocks.dart`

- [ ] **Step 1: Add mocktail and integration_test to pubspec.yaml**

Add to `dev_dependencies`:
```yaml
  mocktail: ^1.0.4
  integration_test:
    sdk: flutter
```

Run: `flutter pub get`

- [ ] **Step 2: Create `test/helpers/mocks.dart`**

```dart
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/auth_service.dart';
import 'package:belly_buddy/services/drink_service.dart';
import 'package:belly_buddy/services/edge_function_service.dart';
import 'package:belly_buddy/services/entry_crud_service.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/ingredient_service.dart';
import 'package:belly_buddy/services/profile_service.dart';
import 'package:belly_buddy/services/recipe_service.dart';
import 'package:belly_buddy/services/recommendation_service.dart';
import 'package:belly_buddy/services/storage_service.dart';

import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

// -- Supabase client mocks --
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder {}

// -- Service mocks --
class MockProfileService extends Mock implements ProfileService {}

class MockAuthService extends Mock implements AuthService {}

class MockEntryCrudService extends Mock implements EntryCrudService {}

class MockEntryQueryService extends Mock implements EntryQueryService {}

class MockDrinkService extends Mock implements DrinkService {}

class MockIngredientService extends Mock implements IngredientService {}

class MockRecipeService extends Mock implements RecipeService {}

class MockRecommendationService extends Mock implements RecommendationService {}

class MockStorageService extends Mock implements StorageService {}

class MockEdgeFunctionService extends Mock implements EdgeFunctionService {}

// -- Repository mocks --
class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockEntryRepository extends Mock implements EntryRepository {}

class MockDrinkRepository extends Mock implements DrinkRepository {}

class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockRecommendationRepository extends Mock
    implements RecommendationRepository {}

class MockMealMediaRepository extends Mock implements MealMediaRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}
```

- [ ] **Step 3: Create `test/helpers/supabase_mocks.dart`**

Helpers for mocking the Supabase fluent query builder chains.

```dart
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

/// Sets up a mock chain for `client.from(table).select(columns)`.
/// Returns the filter builder for further `.eq()`, `.gte()` etc. chaining.
MockPostgrestFilterBuilder mockSelect(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.select(any())).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).insert(data)`.
MockPostgrestFilterBuilder mockInsert(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.insert(any())).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).update(data)`.
MockPostgrestFilterBuilder mockUpdate(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.update(any())).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).delete()`.
MockPostgrestFilterBuilder mockDelete(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.delete()).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).upsert(data)`.
MockPostgrestFilterBuilder mockUpsert(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.upsert(any(), onConflict: any(named: 'onConflict')))
      .thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up `client.storage.from(bucket)` chain.
MockStorageFileApi mockStorage(
  MockSupabaseClient client, {
  required String bucket,
}) {
  final storage = MockSupabaseStorageClient();
  final fileApi = MockStorageFileApi();
  when(() => client.storage).thenReturn(storage);
  when(() => storage.from(bucket)).thenReturn(fileApi);
  return fileApi;
}

/// Sets up `client.functions` mock.
MockFunctionsClient mockFunctions(MockSupabaseClient client) {
  final functions = MockFunctionsClient();
  when(() => client.functions).thenReturn(functions);
  return functions;
}
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock test/helpers/mocks.dart test/helpers/supabase_mocks.dart
git commit -m "test: add mocktail dependency and mock declarations"
```

---

## Task 2: Create Fixtures, Fakes, and Riverpod Helpers

**Files:**
- Create: `test/helpers/fixtures.dart`
- Create: `test/helpers/fakes.dart`
- Create: `test/helpers/riverpod_helpers.dart`

- [ ] **Step 1: Create `test/helpers/fixtures.dart`**

Factories for all model types used in tests. Every factory has sensible defaults with optional overrides.

```dart
import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/ingredient_suggestion.dart'
    as model;
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
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
}) =>
    UserProfile(
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
}) =>
    MealEntry(
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
}) =>
    ToiletEntry(
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
}) =>
    GutFeelingEntry(
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
}) =>
    DrinkEntry(
      id: id ?? 'drink-entry-1',
      trackedAt: trackedAt ?? DateTime(2026, 3, 25, 10, 0),
      drinkId: drinkId ?? 'water-id',
      drinkName: drinkName ?? 'Wasser',
      amountMl: amountMl ?? 250,
    );

Drink testDrink({
  String? id,
  String? name,
  String? addedByUserId,
}) =>
    Drink(
      id: id ?? 'water-id',
      name: name ?? 'Wasser',
      addedByUserId: addedByUserId,
    );

Recipe testRecipe({
  String? id,
  String? title,
  List<String>? tags,
  List<String>? ingredients,
}) =>
    Recipe(
      id: id ?? 'recipe-1',
      title: title ?? 'Testrezept',
      tags: tags ?? ['vegetarisch'],
      ingredients: ingredients ?? ['Reis', 'Gemüse'],
    );

Recommendation testRecommendation({
  String? id,
  String? summary,
  List<RecommendationItem>? recommendations,
}) =>
    Recommendation(
      id: id ?? 'rec-1',
      summary: summary ?? 'Tipp: Mehr Wasser trinken.',
      recommendations: recommendations ?? [],
    );

EntryQueryResult testEntryQueryResult({
  List<MealEntry>? meals,
  List<ToiletEntry>? toiletEntries,
  List<GutFeelingEntry>? gutFeelings,
  List<DrinkEntry>? drinks,
}) =>
    EntryQueryResult(
      meals: meals ?? [testMealEntry()],
      toiletEntries: toiletEntries ?? [testToiletEntry()],
      gutFeelings: gutFeelings ?? [testGutFeelingEntry()],
      drinks: drinks ?? [testDrinkEntry()],
    );

IngredientSuggestion testIngredientSuggestion({
  String? id,
  String? name,
  bool isOwn = false,
}) =>
    IngredientSuggestion(
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
}) =>
    model.IngredientSuggestion(
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
}) =>
    IngredientSuggestionGroup(
      ingredientId: ingredientId ?? 'ing-1',
      ingredientName: ingredientName ?? 'Zwiebel',
      mealCount: mealCount,
      isNew: isNew,
      suggestionIds: suggestionIds ?? ['sug-1', 'sug-2'],
    );
```

- [ ] **Step 2: Create `test/helpers/fakes.dart`**

Fake repository implementations with in-memory state. Used in widget and integration tests.

```dart
import 'dart:typed_data';

import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/ingredient_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures.dart';

// -- FakeAuthRepository --
class FakeAuthRepository implements AuthRepository {
  bool signedIn = true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  Future<AuthResponse> signInWithEmail(String email, String password) async =>
      AuthResponse(session: null, user: null);
  @override
  Future<AuthResponse> signUpWithEmail(String email, String password) async =>
      AuthResponse(session: null, user: null);
  @override
  Future<AuthResponse> signInWithGoogle() async =>
      AuthResponse(session: null, user: null);
  @override
  Future<AuthResponse> signInWithApple() async =>
      AuthResponse(session: null, user: null);
  @override
  Future<void> signOut() async => signedIn = false;
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<UserResponse> updatePassword(String newPassword) async =>
      UserResponse(user: User(
        id: testUserId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ));
  @override
  Future<void> deleteAccount() async {}
  @override
  String? detectAuthMethod() => 'email';
}

// -- FakeProfileRepository --
class FakeProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  void seedProfile(UserProfile profile) => _profile = profile;

  @override
  Future<UserProfile?> getProfile(String userId) async => _profile;
  @override
  Future<void> createProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(userId: userId);
  @override
  Future<void> updateProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(userId: userId);
}

// -- FakeEntryRepository --
class FakeEntryRepository implements EntryRepository {
  final List<Map<String, dynamic>> _inserted = [];

  List<Map<String, dynamic>> get inserted => _inserted;
  EntryQueryResult _result = testEntryQueryResult();

  void seedResult(EntryQueryResult result) => _result = result;

  @override
  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) async =>
      _result;
  @override
  Future<void> insertEntry(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) async =>
      _inserted.add(data);
  @override
  Future<void> updateEntry(
          String table, String id, Map<String, dynamic> data) async {}
  @override
  Future<void> deleteEntry(String table, String id) async {}
  @override
  Future<void> deleteByType(String type, String id) async {}
}

// -- FakeDrinkRepository --
class FakeDrinkRepository implements DrinkRepository {
  List<Drink> _drinks = [testDrink()];

  void seedDrinks(List<Drink> drinks) => _drinks = drinks;

  @override
  Future<List<Drink>> fetchAll() async => _drinks;
  @override
  Future<int> fetchTodayTotal(String userId) async => 500;
  @override
  Future<List<String>> fetchRecentDrinkIds(String userId) async =>
      _drinks.map((d) => d.id).toList();
  @override
  Future<Drink> insertDrink(String name, {required String userId}) async {
    final drink = testDrink(id: 'new-drink', name: name, addedByUserId: userId);
    _drinks = [..._drinks, drink];
    return drink;
  }

  @override
  Future<void> deleteDrink(String drinkId) async =>
      _drinks = _drinks.where((d) => d.id != drinkId).toList();
}

// -- FakeIngredientRepository --
class FakeIngredientRepository implements IngredientRepository {
  @override
  Future<List<IngredientSuggestion>> search(
    String query, {
    required String? userId,
    int limit = 10,
  }) async =>
      [testIngredientSuggestion(name: query)];
  @override
  Future<void> insertIfNew(String name, {required String? userId}) async {}
  @override
  Future<void> deleteUserIngredient(String id) async {}
  @override
  Future<List<IngredientSuggestionGroup>> fetchSuggestionGroups(
          String userId) async =>
      [testSuggestionGroup()];
  @override
  Future<void> markAllSeen(List<String> ids) async {}
  @override
  Future<void> dismissSuggestions(List<String> ids) async {}
}

// -- FakeRecipeRepository --
class FakeRecipeRepository implements RecipeRepository {
  List<Recipe> _recipes = [testRecipe()];
  Set<String> _favorites = {};

  void seedRecipes(List<Recipe> recipes) => _recipes = recipes;

  @override
  Future<List<Recipe>> fetchAll() async => _recipes;
  @override
  Future<Set<String>> fetchFavoriteIds(String userId) async => _favorites;
  @override
  Future<void> addFavorite(String userId, String recipeId) async =>
      _favorites = {..._favorites, recipeId};
  @override
  Future<void> removeFavorite(String userId, String recipeId) async =>
      _favorites = _favorites.where((id) => id != recipeId).toSet();
}

// -- FakeRecommendationRepository --
class FakeRecommendationRepository implements RecommendationRepository {
  @override
  Future<List<Recommendation>> fetchByUserId(String userId) async =>
      [testRecommendation()];
  @override
  Future<List<Recommendation>> refreshRecommendations(
    String userId,
    UserProfile? profile,
  ) async =>
      [testRecommendation(summary: 'Neuer Tipp')];
}

// -- FakeMealMediaRepository --
class FakeMealMediaRepository implements MealMediaRepository {
  @override
  Future<String> uploadMealImage({
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) async =>
      'test-user/image.jpg';
  @override
  Future<Map<String, dynamic>> analyzeMealImage(
    Uint8List bytes,
    String filename,
  ) async =>
      {'title': 'Erkanntes Gericht', 'ingredients': ['Reis', 'Gemüse']};
  @override
  void triggerSuggestionRefresh() {}
}

// -- FakeNotificationRepository --
class FakeNotificationRepository implements NotificationRepository {
  int syncCount = 0;

  @override
  Future<void> syncNotifications(UserProfile profile) async => syncCount++;
  @override
  Future<void> cancelAll() async {}
}
```

- [ ] **Step 3: Create `test/helpers/riverpod_helpers.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/app_theme.dart';

/// Creates a [ProviderContainer] with the given overrides.
/// Automatically disposes after the test.
/// MUST be called inside a `test()` or `setUp()` block.
ProviderContainer createContainer({
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Extension on [WidgetTester] to pump a widget with ProviderScope,
/// MaterialApp, AppTheme, and German locale — matching the real app setup.
extension PumpWithProviders on WidgetTester {
  Future<void> pumpWithProviders(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.theme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de', 'DE')],
          locale: const Locale('de', 'DE'),
          home: widget,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify everything compiles**

Run: `flutter analyze`
Run: `flutter test` (existing 167 tests should still pass)

- [ ] **Step 5: Commit**

```bash
git add test/helpers/
git commit -m "test: add test infrastructure — fixtures, fakes, and riverpod helpers"
```

---

## Task 3: Service Tests — ProfileService, EntryCrudService, EntryQueryService

**Files:**
- Create: `test/services/profile_service_test.dart`
- Create: `test/services/entry_crud_service_test.dart`
- Create: `test/services/entry_query_service_test.dart`

Each test file: read the corresponding source in `lib/services/`, mock `SupabaseClient` using `supabase_mocks.dart` helpers, test every public method with success and error paths.

### profile_service_test.dart (~8 tests)

| Group | Test | Verifies |
|---|---|---|
| fetchByUserId | returns UserProfile when row exists | Parses JSON correctly |
| fetchByUserId | returns null when no row | `.maybeSingle()` returns null |
| fetchByUserId | propagates error on Supabase failure | Rethrows |
| upsert | passes data with onConflict user_id | Correct upsert call |
| update | filters by user_id | Correct `.eq('user_id', userId)` |

### entry_crud_service_test.dart (~10 tests)

| Group | Test | Verifies |
|---|---|---|
| insert | sets user_id from parameter | `data['user_id'] == userId` |
| insert | strips id and created_at | Keys removed before insert |
| update | strips id, user_id, created_at | Keys removed before update |
| update | filters by id | Correct `.eq('id', id)` |
| delete | calls delete with eq id | Correct query |
| deleteByType | resolves meal table | Maps to `meal_entries` |
| deleteByType | resolves drink table | Maps to `drink_entries` |
| deleteByType | throws on unknown type | `ArgumentError` |

### entry_query_service_test.dart (~8 tests)

| Group | Test | Verifies |
|---|---|---|
| fetchEntriesForDateRange | returns parsed models for each type | MealEntry, ToiletEntry, GutFeelingEntry, DrinkEntry |
| fetchEntriesForDateRange | applies date range filters | gte start, lt end |
| fetchEntriesForDateRange | ordered=true applies order | `.order('tracked_at', ascending: false)` |
| fetchEntriesForDateRange | ordered=false omits order | No `.order()` call |
| fetchEntriesForDateRange | propagates error | Rethrows on failure |

**Pattern for all service tests:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:belly_buddy/services/profile_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  late MockSupabaseClient client;
  late ProfileService service;

  setUp(() {
    client = MockSupabaseClient();
    service = ProfileService(client);
  });

  group('fetchByUserId', () {
    test('returns UserProfile when row exists', () async {
      final filter = mockSelect(client, table: 'profiles');
      when(() => filter.eq('user_id', 'user-123')).thenReturn(filter);
      when(() => filter.maybeSingle()).thenAnswer((_) async => {
        'user_id': 'user-123',
        'birth_year': 1990,
        'gender': 'male',
        'height': 180,
        'weight': 75,
        // ... other fields
      });

      final result = await service.fetchByUserId('user-123');
      expect(result, isNotNull);
      expect(result!.userId, 'user-123');
    });

    test('returns null when no row', () async {
      final filter = mockSelect(client, table: 'profiles');
      when(() => filter.eq('user_id', 'user-123')).thenReturn(filter);
      when(() => filter.maybeSingle()).thenAnswer((_) async => null);

      final result = await service.fetchByUserId('user-123');
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 1: Write all three test files following the pattern above**
- [ ] **Step 2: Run tests**

Run: `flutter test test/services/`

- [ ] **Step 3: Commit**

```bash
git add test/services/
git commit -m "test: add ProfileService, EntryCrudService, EntryQueryService tests"
```

---

## Task 4: Service Tests — AuthService, EdgeFunctionService, StorageService

**Files:**
- Create: `test/services/auth_service_test.dart`
- Create: `test/services/edge_function_service_test.dart`
- Create: `test/services/storage_service_test.dart`

### auth_service_test.dart (~12 tests)

Mock `GoTrueClient` + `EdgeFunctionService`. **Skip `signInWithGoogle` and `signInWithApple`** — they depend on platform plugins (`GoogleSignIn`, `SignInWithApple`) that can't be mocked without additional setup. Focus on testable methods.

| Group | Test | Verifies |
|---|---|---|
| signInWithEmail | success returns AuthResponse | Delegates to `_auth.signInWithPassword` |
| signInWithEmail | propagates error | Rethrows |
| signUpWithEmail | success fires welcome email | Calls `_edgeFunctions.invoke('send-welcome-email')` |
| signUpWithEmail | null user skips welcome email | No edge function call |
| signOut | delegates to auth.signOut | Called once |
| resetPassword | calls edge function | `invoke('send-password-reset', body: {'email': ...})` |
| updatePassword | delegates to auth.updateUser | Correct UserAttributes |
| deleteAccount | calls edge function then signOut | Both called in order |
| detectAuthMethod | returns google from session | Provider metadata parsing |
| detectAuthMethod | returns apple from session | Provider metadata |
| detectAuthMethod | returns email for default | Fallback |
| detectAuthMethod | returns null when no session | Null session |

### edge_function_service_test.dart (~5 tests)

| Test | Verifies |
|---|---|
| invoke returns Map response as-is | No wrapping |
| invoke wraps non-Map response | `{'data': response}` |
| invoke propagates error | Rethrows |

### storage_service_test.dart (~8 tests)

| Group | Test | Verifies |
|---|---|---|
| uploadImage | correct bucket, path, MIME type | UUID filename, contentType |
| uploadImage | propagates error | Rethrows |
| getSignedUrl | correct bucket, path, expiry | createSignedUrl params |
| getPublicUrl | returns public URL | getPublicUrl call |

- [ ] **Step 1: Write all three test files**
- [ ] **Step 2: Run: `flutter test test/services/`**
- [ ] **Step 3: Commit**

```bash
git add test/services/
git commit -m "test: add AuthService, EdgeFunctionService, StorageService tests"
```

---

## Task 5: Service Tests — DrinkService, IngredientService, RecipeService, RecommendationService

**Files:**
- Create: `test/services/drink_service_test.dart`
- Create: `test/services/ingredient_service_test.dart`
- Create: `test/services/recipe_service_test.dart`
- Create: `test/services/recommendation_service_test.dart`

### drink_service_test.dart (~10 tests)

| Group | Test |
|---|---|
| fetchAll | returns drinks ordered by name |
| fetchTodayTotal | sums amount_ml for today |
| fetchTodayTotal | returns 0 for empty results |
| fetchRecentDrinkIds | deduplicates and limits to 10 |
| insertDrink | sets added_by_user_id from userId param |
| insertDrink | returns created Drink from select single |
| deleteDrink | deletes entries first, then drink |

### ingredient_service_test.dart (~16 tests)

| Group | Test |
|---|---|
| search | returns IngredientSuggestion with isOwn flag |
| search | isOwn true when added_by_user_id matches userId |
| search | isOwn false for other user |
| insertIfNew | skips when name already exists |
| insertIfNew | inserts when name is new |
| insertIfNew | returns early when userId is null |
| deleteUserIngredient | deletes by id |
| fetchSuggestions | returns raw suggestion data with join |
| fetchReplacements | returns empty for empty ids |
| fetchReplacements | returns replacement data |
| fetchMealDetails | returns empty for empty ids |
| fetchMealDetails | returns meal detail data |
| markAllSeen | updates seen_at timestamp |
| dismissSuggestions | updates dismissed_at timestamp |
| fetchNewCount | counts unseen undismissed |

### recipe_service_test.dart (~8 tests)

| Group | Test |
|---|---|
| fetchAll | returns Recipe list ordered by title |
| fetchFavoriteIds | returns Set of recipe IDs |
| addFavorite | inserts user_id + recipe_id |
| removeFavorite | deletes by user_id + recipe_id |

### recommendation_service_test.dart (~6 tests)

| Group | Test |
|---|---|
| fetchByUserId | returns sorted recommendations |
| fetchRecentContext | uses 7-day window |
| fetchRecentContext | returns meals and toilet in parallel |

- [ ] **Step 1: Write all four test files**
- [ ] **Step 2: Run: `flutter test test/services/`**
- [ ] **Step 3: Commit**

```bash
git add test/services/
git commit -m "test: add DrinkService, IngredientService, RecipeService, RecommendationService tests"
```

---

## Task 6: Repository Tests — Profile, Auth, Entry, Drink

**Files:**
- Create: `test/repositories/profile_repository_test.dart`
- Create: `test/repositories/auth_repository_test.dart`
- Create: `test/repositories/entry_repository_test.dart`
- Create: `test/repositories/drink_repository_test.dart`

Mock services via mocktail. Test business logic absorbed from providers.

### profile_repository_test.dart (~10 tests)

| Group | Test | Verifies |
|---|---|---|
| getProfile | calls fetchByUserId | Delegates with userId |
| getProfile | retries on transient failure | retryAsync behavior (success on 2nd attempt) |
| createProfile | sets userId in data | `data['user_id'] == userId` |
| createProfile | sets authMethod from AuthService | detectAuthMethod called |
| createProfile | strips null values | `removeWhere` applied |
| createProfile | handles null authMethod | Still works |
| updateProfile | strips user_id key | Not in data sent to service |

### auth_repository_test.dart (~5 tests)

Thin delegation tests. Each method should call the corresponding service method once.

### entry_repository_test.dart (~6 tests)

| Test | Verifies |
|---|---|
| fetchForDate delegates to queryService | Passes userId, date, ordered |
| insertEntry delegates with userId | Passes userId to crudService |
| updateEntry delegates | Passes table, id, data |
| deleteEntry delegates | Passes table, id |
| deleteByType delegates | Passes type, id |

### drink_repository_test.dart (~5 tests)

| Test | Verifies |
|---|---|
| fetchAll delegates | Calls drinkService.fetchAll |
| insertDrink passes userId | userId forwarded |
| deleteDrink delegates | Calls drinkService.deleteDrink |

**Pattern:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockProfileService profileService;
  late MockAuthService authService;
  late ProfileRepository repo;

  setUp(() {
    profileService = MockProfileService();
    authService = MockAuthService();
    repo = ProfileRepository(profileService, authService);
  });

  group('createProfile', () {
    test('sets userId and authMethod in data', () async {
      when(() => authService.detectAuthMethod()).thenReturn('google');
      when(() => profileService.upsert(any())).thenAnswer((_) async {});

      await repo.createProfile('user-123', testUserProfile());

      final captured =
          verify(() => profileService.upsert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['user_id'], 'user-123');
      expect(captured['auth_method'], 'google');
    });
  });
}
```

- [ ] **Step 1: Write all four test files**
- [ ] **Step 2: Run: `flutter test test/repositories/`**
- [ ] **Step 3: Commit**

```bash
git add test/repositories/
git commit -m "test: add ProfileRepository, AuthRepository, EntryRepository, DrinkRepository tests"
```

---

## Task 7: Repository Tests — Ingredient, Recipe, Recommendation, MealMedia, Notification

**Files:**
- Create: `test/repositories/ingredient_repository_test.dart`
- Create: `test/repositories/recipe_repository_test.dart`
- Create: `test/repositories/recommendation_repository_test.dart`
- Create: `test/repositories/meal_media_repository_test.dart`
- Create: `test/repositories/notification_repository_test.dart`
- Modify: `lib/repositories/notification_repository.dart` (inject abstract scheduler)

### Prerequisite: NotificationRepository refactor

`NotificationRepository` calls `LocalNotificationService` static methods directly. To test it, introduce an abstract interface:

```dart
// Add to lib/repositories/notification_repository.dart

/// Abstract interface for notification scheduling — enables testing.
abstract class NotificationScheduler {
  Future<void> scheduleReminders({
    required List<String> reminderTimes,
    required String timezone,
  });
  Future<void> cancelReminders();
  Future<void> scheduleDailySummary({
    required String dailySummaryTime,
    required String timezone,
  });
  Future<void> cancelDailySummary();
  Future<void> cancelAll();
}
```

Create a `LocalNotificationScheduler` production implementation that delegates to `LocalNotificationService` static methods, and inject it into `NotificationRepository`.

Update `notificationRepositoryProvider` to create `NotificationRepository(LocalNotificationScheduler())`.

### ingredient_repository_test.dart (~12 tests)

The most important repo to test — absorbs suggestion grouping logic.

| Group | Test | Verifies |
|---|---|---|
| fetchSuggestionGroups | calls fetchSuggestions, fetchReplacements, fetchMealDetails | 3 service calls in sequence |
| fetchSuggestionGroups | extracts suggestion IDs correctly | Correct IDs passed to fetchReplacements |
| fetchSuggestionGroups | extracts meal IDs correctly | Correct IDs passed to fetchMealDetails |
| fetchSuggestionGroups | passes data to SuggestionHelpers.buildGroups | Correct grouping |
| fetchSuggestionGroups | handles empty suggestion data | Returns empty list |
| search | passes userId and limit | Delegates correctly |
| insertIfNew | passes userId | Delegates correctly |

### recipe_repository_test.dart (~5 tests)

| Test | Verifies |
|---|---|
| fetchAll retries on failure | retryAsync behavior |
| fetchFavoriteIds delegates | Passes userId |
| addFavorite/removeFavorite delegate | Correct params |

### recommendation_repository_test.dart (~8 tests)

| Group | Test | Verifies |
|---|---|---|
| fetchByUserId | retries on failure | retryAsync |
| refreshRecommendations | fetches context, invokes edge function, re-fetches | Full orchestration |
| refreshRecommendations | includes profile data when present | symptoms, intolerances, diet in body |
| refreshRecommendations | omits profile data when null | No profile keys in body |

### meal_media_repository_test.dart (~6 tests)

| Test | Verifies |
|---|---|
| uploadMealImage uses meal-images bucket | Correct bucket passed |
| uploadMealImage passes userId and extension | Correct params |
| analyzeMealImage builds base64 | MealHelpers.buildImageBase64 called |
| analyzeMealImage calls analyze-meal | Edge function name correct |
| triggerSuggestionRefresh is fire-and-forget | .ignore() — does not throw |

### notification_repository_test.dart (~8 tests)

Uses `MockNotificationScheduler` (mock of the new abstract interface).

| Group | Test | Verifies |
|---|---|---|
| syncNotifications | schedules reminders when enabled + times not empty | scheduleReminders called |
| syncNotifications | cancels reminders when disabled | cancelReminders called |
| syncNotifications | cancels reminders when times empty | cancelReminders called |
| syncNotifications | schedules daily summary when enabled | scheduleDailySummary called |
| syncNotifications | cancels daily summary when disabled | cancelDailySummary called |
| syncNotifications | uses profile timezone | Passes timezone |
| syncNotifications | defaults to Europe/Berlin when timezone null | Default timezone |
| cancelAll | delegates | cancelAll called |

- [ ] **Step 1: Refactor NotificationRepository with abstract NotificationScheduler**
- [ ] **Step 2: Verify existing tests and analyze pass**
- [ ] **Step 3: Write all five test files**
- [ ] **Step 4: Run: `flutter test test/repositories/`**
- [ ] **Step 5: Commit**

```bash
git add lib/repositories/notification_repository.dart test/repositories/
git commit -m "test: add remaining repository tests + NotificationScheduler abstraction"
```

---

## Task 8: Provider Tests — Auth, Profile

**Files:**
- Create: `test/providers/auth_provider_test.dart`
- Create: `test/providers/profile_provider_test.dart`

Use `createContainer` from `riverpod_helpers.dart` with `overrideWithValue` for repository providers.

### auth_provider_test.dart (~18 tests)

| Group | Test | Verifies |
|---|---|---|
| AuthNotifier.signInWithEmail | sets loading then data on success | State transitions |
| AuthNotifier.signInWithEmail | sets error and rethrows on failure | Error handling |
| AuthNotifier.signUpWithEmail | sets loading then data | State transitions |
| AuthNotifier.signInWithGoogle | sets loading then data | State transitions |
| AuthNotifier.signInWithApple | sets loading then data | State transitions |
| AuthNotifier.signOut | sets loading then data | State transitions |
| AuthNotifier.signOut | sets error on failure | Error handling |
| AuthNotifier.resetPassword | delegates to repo | No state change |
| AuthNotifier.updatePassword | delegates to repo | Returns UserResponse |
| AuthNotifier.deleteAccount | sets loading then data | State transitions |
| AuthNotifier.detectAuthMethod | delegates to repo | Returns string |
| authStateProvider | emits auth state changes | Stream subscription |
| isAuthenticatedProvider | true when session present | Reactive |
| isAuthenticatedProvider | false on error | Error state |

**Pattern:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  group('AuthNotifier', () {
    test('signInWithEmail transitions loading → data', () async {
      when(() => mockRepo.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResponse(session: null, user: null));

      final container = createContainer(overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ]);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signInWithEmail('test@test.com', 'password');

      expect(container.read(authNotifierProvider), isA<AsyncData>());
    });

    test('signInWithEmail sets error on failure', () async {
      when(() => mockRepo.signInWithEmail(any(), any()))
          .thenThrow(Exception('Invalid credentials'));

      final container = createContainer(overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ]);

      final notifier = container.read(authNotifierProvider.notifier);
      expect(
        () => notifier.signInWithEmail('test@test.com', 'wrong'),
        throwsException,
      );
    });
  });
}
```

### profile_provider_test.dart (~14 tests)

| Group | Test | Verifies |
|---|---|---|
| ProfileNotifier.fetchProfile | loading → data with profile | State transition |
| ProfileNotifier.fetchProfile | null userId → data(null) | Early return |
| ProfileNotifier.createProfile | calls repo.createProfile then refetches | Two repo calls |
| ProfileNotifier.updateProfile | optimistic update | State changes before await |
| ProfileNotifier.updateProfile | reverts on error | Previous state restored |
| ProfileNotifier.reset | sets data(null) | State cleared |
| hasProfileProvider | true when profile exists | Derived |
| hasProfileProvider | false when null | Derived |
| hasCompletedRegistrationProvider | true when complete | Checks isComplete |
| hasCompletedRegistrationProvider | false when incomplete | Missing fields |

- [ ] **Step 1: Write both test files**
- [ ] **Step 2: Run: `flutter test test/providers/`**
- [ ] **Step 3: Commit**

```bash
git add test/providers/
git commit -m "test: add AuthProvider and ProfileProvider tests"
```

---

## Task 9: Provider Tests — Entries, Diary, Notification

**Files:**
- Create: `test/providers/entries_provider_test.dart`
- Create: `test/providers/diary_provider_test.dart`
- Create: `test/providers/notification_provider_test.dart`

### entries_provider_test.dart (~16 tests)

**Note:** `EntriesNotifier` uses custom `EntriesState` (NOT `AsyncNotifier`). Check `state.isLoading` and `state.error`, not `AsyncValue`.

| Group | Test |
|---|---|
| loadEntries | sets isLoading true, then populates entries |
| loadEntries | null userId returns early |
| loadEntries | error sets state.error |
| addMeal | calls repo.insertEntry with meal table |
| updateMeal | calls repo.updateEntry |
| deleteMeal | calls repo.deleteEntry |
| addToiletEntry | calls repo.insertEntry with toilet table |
| addGutFeeling | calls repo.insertEntry with gutFeeling table |
| addDrinkEntry | calls repo.insertEntry with drink table |
| updateGutFeelingById | calls repo.updateEntry with correct data |
| updateToiletById | calls repo.updateEntry with stool_type |
| updateDrinkById | calls repo.updateEntry with amount_ml |
| deleteByType | delegates to repo |
| reset | clears all entries |

### diary_provider_test.dart (~6 tests)

**Note:** `diaryEntriesProvider` is `FutureProvider.family` — test with `container.read(diaryEntriesProvider(date))`.

| Group | Test |
|---|---|
| diaryEntriesProvider | returns entries for date |
| diaryEntriesProvider | null userId returns empty |
| diaryDateProvider | defaults to today |
| diaryDateProvider | set changes date |

### notification_provider_test.dart (~4 tests)

| Test | Verifies |
|---|---|
| calls repo.syncNotifications when profile changes | Reactive sync |
| ignores null profile | No repo call |
| handles sync error gracefully | Catches error |

- [ ] **Step 1: Write all three test files**
- [ ] **Step 2: Run: `flutter test test/providers/`**
- [ ] **Step 3: Commit**

```bash
git add test/providers/
git commit -m "test: add EntriesProvider, DiaryProvider, NotificationProvider tests"
```

---

## Task 10: Provider Tests — MealTracker, DrinkTracker

**Files:**
- Create: `test/providers/meal_tracker_provider_test.dart`
- Create: `test/providers/drink_tracker_provider_test.dart`

### meal_tracker_provider_test.dart (~16 tests)

| Group | Test |
|---|---|
| setTitle | updates state.title |
| setNotes | updates state.notes |
| setTrackedAt | updates state.trackedAt |
| setImage | sets imageBytes and imageFileName |
| clearImage | resets to default preserving trackedAt/notes |
| analyzeImage | sets isAnalyzing then updates title/ingredients |
| analyzeImage | clears isAnalyzing on error |
| searchIngredients | returns empty for query < 3 chars |
| searchIngredients | calls repo.search for query >= 3 chars |
| searchIngredients | sets ingredientSearchError on failure |
| addIngredient | adds to ingredients list |
| addIngredient | skips duplicates |
| addIngredient | fires insertIfNew (fire-and-forget) |
| removeIngredient | removes from list |
| save | with image uploads then creates entry |
| save | without image skips upload |

### drink_tracker_provider_test.dart (~14 tests)

| Group | Test |
|---|---|
| loadDrinks | populates allDrinks and quickDrinks |
| loadDrinks | no userId uses first 11 |
| loadTodayTotal | updates todayTotal |
| searchDrinks | filters allDrinks |
| toggleDrink | selects drink |
| toggleDrink | deselects same drink |
| clearSelection | clears drink and amount |
| selectAmount | sets selectedAmount |
| setCustomAmount | parses and sets |
| createDrink | adds to allDrinks sorted |
| deleteDrink | removes from all lists |
| deleteDrink | clears if selected |
| save | creates entry and refreshes total |
| save | guards null drink/amount |

- [ ] **Step 1: Write both test files**
- [ ] **Step 2: Run: `flutter test test/providers/`**
- [ ] **Step 3: Commit**

```bash
git add test/providers/
git commit -m "test: add MealTrackerProvider and DrinkTrackerProvider tests"
```

---

## Task 11: Provider Tests — IngredientSuggestion, Recipes, Recommendation

**Files:**
- Create: `test/providers/ingredient_suggestion_provider_test.dart`
- Create: `test/providers/recipes_provider_test.dart`
- Create: `test/providers/recommendation_provider_test.dart`

### ingredient_suggestion_provider_test.dart (~8 tests)

| Test | Verifies |
|---|---|
| fetchSuggestions loading → groups | State transition |
| fetchSuggestions null userId → empty | Early return |
| markAllNewAsSeen updates isNew flags | Local state update |
| markAllNewAsSeen skips when no unseen | No repo call |
| dismissSuggestion removes from list | Filtered by ID |
| newCount returns count of isNew groups | Getter |

### recipes_provider_test.dart (~10 tests)

**Note:** `RecipesNotifier.build()` triggers `_loadAll()` immediately. Must set up mock repo before reading provider.

| Test | Verifies |
|---|---|
| build triggers loadAll | Recipes loaded on first read |
| search filtering works | Case-insensitive title match |
| tag filtering works | All selected tags must match |
| combined search + tag | Both filters apply |
| toggleFavorite adds | Calls repo.addFavorite |
| toggleFavorite removes | Calls repo.removeFavorite |
| toggleFavorite null userId is no-op | Guard |

### recommendation_provider_test.dart (~8 tests)

| Test | Verifies |
|---|---|
| fetchRecommendations loading → data | State transition |
| fetchRecommendations null userId → empty | Early return |
| fetchRecommendations error → error state | Error handling |
| refreshRecommendations passes profile | Profile forwarded to repo |
| refreshRecommendations null profile | Still works |

- [ ] **Step 1: Write all three test files**
- [ ] **Step 2: Run: `flutter test test/providers/`**
- [ ] **Step 3: Commit**

```bash
git add test/providers/
git commit -m "test: add IngredientSuggestionProvider, RecipesProvider, RecommendationProvider tests"
```

---

## Task 12: Widget Tests — Core Reusable Widgets

**Files:**
- Create: `test/widgets/bb_button_test.dart`
- Create: `test/widgets/bb_card_test.dart`
- Create: `test/widgets/bb_chip_selector_test.dart`
- Create: `test/widgets/bb_password_field_test.dart`
- Create: `test/widgets/bb_async_state_test.dart`
- Create: `test/widgets/bb_slider_test.dart`
- Create: `test/widgets/bb_bottom_nav_test.dart`
- Create: `test/widgets/date_time_chips_test.dart`
- Create: `test/widgets/tracker_card_test.dart`
- Create: `test/widgets/mood_slider_row_test.dart`

Use `pumpWithProviders` from `riverpod_helpers.dart`. Read each widget source first to understand its constructor and behavior.

### bb_button_test.dart (~6 tests)

| Test | Verifies |
|---|---|
| renders label text | `find.text('Label')` |
| onPressed fires callback | Tap triggers |
| disabled state ignores tap | No callback |
| loading shows CircularProgressIndicator | Spinner visible |
| uses AppTheme colors | Correct styling |

### bb_async_state_test.dart (~4 tests)

**Note:** Tests both `BbLoadingState` and `BbErrorState` (two separate classes in `bb_async_state.dart`).

| Test | Verifies |
|---|---|
| BbLoadingState shows spinner | CircularProgressIndicator visible |
| BbErrorState shows error message | Error text rendered |
| BbErrorState retry button fires callback | onRetry called |
| BbErrorState hides retry when no callback | No button |

### Pattern:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWithProviders(
        BbButton(label: 'Speichern', onPressed: () {}),
      );
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('onPressed fires callback', (tester) async {
      var pressed = false;
      await tester.pumpWithProviders(
        BbButton(label: 'Tap', onPressed: () => pressed = true),
      );
      await tester.tap(find.text('Tap'));
      expect(pressed, isTrue);
    });
  });
}
```

- [ ] **Step 1: Read each widget source, write test file**
- [ ] **Step 2: Run: `flutter test test/widgets/`**
- [ ] **Step 3: Commit**

```bash
git add test/widgets/
git commit -m "test: add core widget tests (BbButton, BbCard, BbChipSelector, etc.)"
```

---

## Task 13: Screen Tests — Auth + Registration + Dashboard

**Files:**
- Create: `test/screens/auth/auth_screen_test.dart`
- Create: `test/screens/auth/reset_password_screen_test.dart`
- Create: `test/screens/registration/registration_wizard_screen_test.dart`
- Create: `test/screens/dashboard/dashboard_screen_test.dart`

Override `authNotifierProvider`, `profileRepositoryProvider`, etc. with fakes/mocks. Read each screen source first to understand widgets rendered.

### auth_screen_test.dart (~10 tests)

| Test | Verifies |
|---|---|
| renders email and password fields | `find.byType(TextField)` ×2 |
| renders sign-in button | German text "Anmelden" |
| sign-in calls AuthNotifier.signInWithEmail | Mock verification |
| shows loading while signing in | CircularProgressIndicator |
| displays error message on failure | Error text visible |
| Google button visible | Social button rendered |
| navigates to register on tap | Route change |

### registration_wizard_screen_test.dart (~12 tests)

| Test | Verifies |
|---|---|
| starts at step 1 | First step content visible |
| next button advances step | Step 2 visible |
| back button goes to previous step | Step 1 visible again |
| progress indicator shows correct step | Progress bar |
| auth step renders email/password | Fields visible |
| birth year step renders picker | Picker widget |
| final step submits profile | createProfile called |

### dashboard_screen_test.dart (~6 tests)

| Test | Verifies |
|---|---|
| renders feature cards | All tracker cards visible |
| tapping meal card navigates | Route to meal tracker |

- [ ] **Step 1: Write all four test files**
- [ ] **Step 2: Run: `flutter test test/screens/`**
- [ ] **Step 3: Commit**

```bash
git add test/screens/
git commit -m "test: add auth, registration, and dashboard screen tests"
```

---

## Task 14: Screen Tests — Trackers

**Files:**
- Create: `test/screens/trackers/meal/meal_tracker_test.dart`
- Create: `test/screens/trackers/drink/drink_tracker_test.dart`
- Create: `test/screens/trackers/toilet/toilet_tracker_test.dart`
- Create: `test/screens/trackers/gut_feeling/gut_feeling_tracker_test.dart`

### meal_tracker_test.dart (~10 tests)

| Test | Verifies |
|---|---|
| renders title field with default "Neue Mahlzeit" | Default text |
| ingredient search triggers on 3+ chars | Provider call |
| add ingredient shows in list | UI update |
| save button creates meal | Entry inserted |
| success overlay shown after save | Overlay visible |

### drink_tracker_test.dart (~8 tests)

| Test | Verifies |
|---|---|
| quick drink grid renders | Grid visible |
| selecting drink highlights it | Selection state |
| size buttons render | Size options visible |
| save creates drink entry | Entry inserted |

### toilet_tracker_test.dart (~5 tests)

| Test | Verifies |
|---|---|
| renders 5 stool type options | 5 buttons |
| selecting type highlights it | Selection state |
| save creates toilet entry | Entry inserted |

### gut_feeling_tracker_test.dart (~8 tests)

| Test | Verifies |
|---|---|
| renders two tabs | Bauchgefühl + Stimmung |
| Bauchgefühl tab has 4 sliders | bloating, gas, cramps, fullness |
| Stimmung tab has mood sliders | stress, happiness, etc. |
| tab switching works | Second tab content visible |
| save creates gut feeling entry | Entry inserted |

- [ ] **Step 1: Write all four test files**
- [ ] **Step 2: Run: `flutter test test/screens/`**
- [ ] **Step 3: Commit**

```bash
git add test/screens/
git commit -m "test: add tracker screen tests (meal, drink, toilet, gut feeling)"
```

---

## Task 15: Screen Tests — Diary, Recipes, Recommendations, Settings, IngredientSuggestions, Welcome

**Files:**
- Create: `test/screens/diary/diary_screen_test.dart`
- Create: `test/screens/recipes/recipes_screen_test.dart`
- Create: `test/screens/recommendations/recommendations_screen_test.dart`
- Create: `test/screens/settings/settings_screen_test.dart`
- Create: `test/screens/settings/settings_account_test.dart`
- Create: `test/screens/settings/settings_notifications_test.dart`
- Create: `test/screens/settings/settings_profile_test.dart`
- Create: `test/screens/ingredient_suggestions/ingredient_suggestions_screen_test.dart`
- Create: `test/screens/welcome/welcome_screen_test.dart`

### diary_screen_test.dart (~10 tests)

| Test | Verifies |
|---|---|
| renders entries for current date | Entry cards visible |
| date navigation forward/back | Date label changes |
| empty state shows message | German empty text |
| tap entry opens detail sheet | Bottom sheet visible |

### recipes_screen_test.dart (~8 tests)

| Test | Verifies |
|---|---|
| recipe list renders | Recipe cards visible |
| search filters recipes | Filtered list |
| tag chips toggle | Filter applied |
| favorite toggle updates icon | Heart filled/unfilled |

### recommendations_screen_test.dart (~6 tests)

| Test | Verifies |
|---|---|
| renders recommendation cards | Cards visible |
| refresh button triggers refresh | Provider called |
| empty state message | German text |

### settings screens (~20 tests total)

Settings screen, account, notifications, profile — test navigation, form fields, actions.

**IMPORTANT — Import paths:** The settings sub-screens live in `lib/screens/settings/widgets/` (not `lib/screens/settings/`). Import as:
- `package:belly_buddy/screens/settings/widgets/settings_account_screen.dart`
- `package:belly_buddy/screens/settings/widgets/settings_notifications_screen.dart`
- `package:belly_buddy/screens/settings/widgets/settings_profile_screen.dart`

### ingredient_suggestions_screen_test.dart (~8 tests)

| Test | Verifies |
|---|---|
| suggestion cards render | Cards visible |
| detail modal opens on tap | Modal visible |
| dismiss removes card | Card gone |
| empty state | German message |

### welcome_screen_test.dart (~4 tests)

| Test | Verifies |
|---|---|
| renders mascot and buttons | UI elements visible |
| login button present | German text |

- [ ] **Step 1: Write all nine test files**
- [ ] **Step 2: Run: `flutter test test/screens/`**
- [ ] **Step 3: Commit**

```bash
git add test/screens/
git commit -m "test: add remaining screen tests (diary, recipes, recommendations, settings, etc.)"
```

---

## Task 16: Integration Tests

**Files:**
- Create: `integration_test/auth_flow_test.dart`
- Create: `integration_test/registration_flow_test.dart`
- Create: `integration_test/meal_tracking_flow_test.dart`
- Create: `integration_test/drink_tracking_flow_test.dart`
- Create: `integration_test/diary_flow_test.dart`

All integration tests use `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` and wrap `BellyBuddyApp` in `ProviderScope` with all repository providers overridden with fakes.

### Setup pattern:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
// ... all repository imports

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeProfileRepository fakeProfileRepo;
  late FakeEntryRepository fakeEntryRepo;
  // ... other fakes

  setUp(() {
    fakeProfileRepo = FakeProfileRepository()
      ..seedProfile(testUserProfile());
    fakeEntryRepo = FakeEntryRepository();
    // ...
  });

  testWidgets('auth flow: login → dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(testUserId),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
          entryRepositoryProvider.overrideWithValue(fakeEntryRepo),
          // ... all other repo overrides
        ],
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dashboard is shown (authenticated + profile exists)
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
```

### auth_flow_test.dart (~3 tests)

| Test | Flow |
|---|---|
| Login with credentials → Dashboard | Email + password → sign in → dashboard visible |
| Login error shows message | Wrong credentials → error displayed |
| Sign out returns to welcome | Settings → sign out → welcome screen |

### registration_flow_test.dart (~3 tests)

| Test | Flow |
|---|---|
| Full wizard completion | Sign up → step 1-7 → dashboard |

### meal_tracking_flow_test.dart (~3 tests)

| Test | Flow |
|---|---|
| Create meal entry | Dashboard → meal tracker → fill title + ingredients → save → success |

### drink_tracking_flow_test.dart (~3 tests)

| Test | Flow |
|---|---|
| Create drink entry | Dashboard → drink tracker → select → amount → save → total updates |

### diary_flow_test.dart (~3 tests)

| Test | Flow |
|---|---|
| View and navigate diary | Diary tab → see entries → navigate dates |

- [ ] **Step 1: Write all five integration test files**
- [ ] **Step 2: Run: `flutter test integration_test/` (requires simulator or device)**
- [ ] **Step 3: Commit**

```bash
git add integration_test/
git commit -m "test: add integration tests for critical user flows"
```

---

## Task 17: CI Pipeline — Multi-Stage

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read current CI config**

Read `.github/workflows/ci.yml` to understand existing structure.

- [ ] **Step 2: Rewrite as multi-stage pipeline**

Replace with 4 sequential stages: quality → unit-tests → widget-tests → integration-tests.

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  quality:
    name: Lint & Analyze
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: dart format --set-exit-if-changed lib/ test/
      - run: flutter analyze

  unit-tests:
    name: Unit Tests
    needs: quality
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter test test/models/ test/utils/ test/services/ test/repositories/ test/providers/ --dart-define-from-file=env.json

  widget-tests:
    name: Widget Tests
    needs: unit-tests
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter test test/screens/ test/widgets/ --dart-define-from-file=env.json

  integration-tests:
    name: Integration Tests
    needs: widget-tests
    runs-on: macos-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - uses: futureware-tech/simulator-action@v3
        with:
          model: 'iPhone 15'
      - run: flutter test integration_test/ --dart-define-from-file=env.json
```

- [ ] **Step 3: Verify CI config is valid YAML**
- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: multi-stage pipeline — quality → unit → widget → integration"
```
