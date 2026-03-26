# Comprehensive Test Suite Design

## Overview

Add full test coverage to Belly Buddy across all architectural layers: services, repositories, providers, widgets, screens, and integration flows. Uses mocktail for mocking, hand-written fakes for repositories, and a multi-stage CI pipeline.

### Goals

- Cover every architectural layer with targeted tests
- Establish shared test infrastructure (mocks, fakes, fixtures, helpers)
- Evolve CI from a single `test` job into a multi-stage fail-fast pipeline
- Follow the `flutter-testing-apps` skill: unit tests (services/repos/providers), widget tests (screens/widgets), integration tests (critical flows)

### Non-Goals

- No golden/snapshot tests (can be added later)
- No tests for platform plugins (`LocalNotificationService`, `PushNotificationService`) — these require device/emulator
- No tests for trivial wrappers (`HapticService`, `NotificationService` facade)
- No tests for config/constant files (no logic to test)
- No real Supabase calls — everything mocked at the service layer

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Mocking library | `mocktail` | No codegen, lightweight, popular in Flutter |
| Repository test doubles | Hand-written fakes | `flutter-testing-apps` skill recommends fakes over mocks for ViewModels/Views |
| Supabase in tests | Mocked at service layer | Fast, reliable, runs in CI without Docker |
| CI pipeline | Multi-stage fail-fast | `quality` → `unit-tests` → `widget-tests` → `integration-tests` |
| Test scope | Full coverage push | Every service, repository, provider, key screens, reusable widgets, critical flows |

## Current State

**167 existing tests** across 18 files:
- Models: 6 files (drink_entry, fodmap_flags, user_profile, user_profile_migration, recommendation, recommendation_item)
- Utils: 12 files (date_format, diary_helpers, drink_helpers, gut_feeling_rating, intolerance_helpers, mime_utils, password_validator, recipe_tag_mapping, reminder_times_converter, retry_helper, signed_url_helper, suggestion_helpers)
- Widget: 1 placeholder file

**0% coverage** on: services, repositories, providers, screens, widgets.

## Test Infrastructure

### New Dependency

```yaml
# pubspec.yaml
dev_dependencies:
  mocktail: ^1.0.4
```

### Shared Test Helpers (`test/helpers/`)

| File | Purpose |
|---|---|
| `mocks.dart` | All mocktail mock class declarations. One centralized file. |
| `fakes.dart` | Hand-written fake repository implementations with in-memory state. |
| `fixtures.dart` | Reusable test data factories: `testUserProfile()`, `testMealEntry()`, `testDrinkEntry()`, `testRecipe()`, etc. |
| `riverpod_helpers.dart` | `createContainer({overrides})` helper + `pumpWithProviders` extension on `WidgetTester`. |
| `supabase_mocks.dart` | Helpers for mocking Supabase fluent query builder chains (`client.from().select().eq()...`). |

### Mock Classes (`test/helpers/mocks.dart`)

```dart
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ... service imports

// Supabase mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder {}

// Service mocks
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

// Repository mocks (for provider tests that need precise verification)
class MockProfileRepository extends Mock implements ProfileRepository {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockEntryRepository extends Mock implements EntryRepository {}
class MockDrinkRepository extends Mock implements DrinkRepository {}
class MockIngredientRepository extends Mock implements IngredientRepository {}
class MockRecipeRepository extends Mock implements RecipeRepository {}
class MockRecommendationRepository extends Mock implements RecommendationRepository {}
class MockMealMediaRepository extends Mock implements MealMediaRepository {}
class MockNotificationRepository extends Mock implements NotificationRepository {}
```

### Fake Repositories (`test/helpers/fakes.dart`)

For widget and integration tests where mocks are too brittle. Each fake holds in-memory state.

```dart
class FakeProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  void seedProfile(UserProfile profile) => _profile = profile;

  @override
  Future<UserProfile?> getProfile(String userId) async => _profile;

  @override
  Future<void> createProfile(String userId, UserProfile profile) async {
    _profile = profile.copyWith(userId: userId);
  }

  @override
  Future<void> updateProfile(String userId, UserProfile profile) async {
    _profile = profile.copyWith(userId: userId);
  }
}
```

Same pattern for: `FakeAuthRepository`, `FakeEntryRepository`, `FakeDrinkRepository`, `FakeIngredientRepository`, `FakeRecipeRepository`, `FakeRecommendationRepository`, `FakeMealMediaRepository`, `FakeNotificationRepository`.

### Test Data Fixtures (`test/helpers/fixtures.dart`)

```dart
UserProfile testUserProfile({
  String userId = 'test-user-id',
  String? diet,
  List<String>? intolerances,
  bool isComplete = true,
}) => UserProfile(
  userId: userId,
  birthYear: 1990,
  gender: 'male',
  heightCm: 180,
  weightKg: 75,
  diet: diet,
  intolerances: intolerances ?? [],
  symptoms: [],
  // ... other required fields with sensible defaults
);

MealEntry testMealEntry({ ... }) => MealEntry(...);
DrinkEntry testDrinkEntry({ ... }) => DrinkEntry(...);
// etc.
```

### Riverpod Helpers (`test/helpers/riverpod_helpers.dart`)

```dart
ProviderContainer createContainer({
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

extension WidgetTesterX on WidgetTester {
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

### Supabase Mock Helpers (`test/helpers/supabase_mocks.dart`)

Helper for mocking the fluent query builder chains that every service uses.

```dart
/// Sets up MockSupabaseClient.from(table).select().eq().maybeSingle() chain.
/// Returns the final mock so the test can set up when().thenAnswer().
MockPostgrestFilterBuilder setupSelectQuery(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.select(any())).thenReturn(filterBuilder);
  return filterBuilder;
}
```

## Layer 1: Service Tests

Mock `SupabaseClient` and sub-clients. Verify correct Supabase calls and response transformation.

### Test Files

| Test File | Service | Test Count | Key Scenarios |
|---|---|---|---|
| `test/services/profile_service_test.dart` | ProfileService | ~8 | fetchByUserId returns UserProfile/null, upsert passes data with onConflict, update filters by userId |
| `test/services/auth_service_test.dart` | AuthService | ~12 | signIn success/error, signUp fires welcome email, signOut, resetPassword calls edge function, updatePassword, deleteAccount calls edge function then signOut, detectAuthMethod from session metadata (google/apple/email/null) |
| `test/services/entry_crud_service_test.dart` | EntryCrudService | ~10 | insert sets user_id + strips id/created_at, update strips id/user_id/created_at, delete by id, deleteByType resolves table, unknown type throws |
| `test/services/entry_query_service_test.dart` | EntryQueryService | ~8 | Date boundary formatting, parallel queries, ordered flag, correct model parsing for each type |
| `test/services/drink_service_test.dart` | DrinkService | ~10 | fetchAll ordered by name, fetchTodayTotal sums amounts, fetchRecentDrinkIds dedup + limit 10, insertDrink sets added_by_user_id, deleteDrink cascades entries then drink |
| `test/services/ingredient_service_test.dart` | IngredientService | ~16 | search ilike + isOwn flag, insertIfNew skips existing, deleteUserIngredient, fetchSuggestions join query, fetchReplacements empty short-circuit, fetchMealDetails empty short-circuit + inFilter, markAllSeen/dismissSuggestions timestamp update, fetchNewCount |
| `test/services/recipe_service_test.dart` | RecipeService | ~8 | fetchAll returns Recipe list, fetchFavoriteIds returns Set, addFavorite/removeFavorite |
| `test/services/recommendation_service_test.dart` | RecommendationService | ~6 | fetchByUserId ordered desc, fetchRecentContext 7-day window + parallel queries |
| `test/services/storage_service_test.dart` | StorageService | ~8 | uploadImage correct bucket/path/MIME, getSignedUrl expiry, getPublicUrl |
| `test/services/edge_function_service_test.dart` | EdgeFunctionService | ~5 | invoke Map response, invoke non-Map wraps, error propagation |

**Total: ~91 test cases**

### Note: Two `IngredientSuggestion` Types

The codebase has two distinct classes named `IngredientSuggestion`:
- **Service-layer class** in `lib/services/ingredient_service.dart`: plain Dart class `{id, name, isOwn}`, returned by `IngredientService.search()`, used in `MealTrackerState`.
- **Freezed model** in `lib/models/ingredient_suggestion.dart`: Freezed class `{id, detectedIngredientId, mealId, helptext, seenAt, dismissedAt}`, used in suggestion grouping.

Test fixtures must include factories for both types. Mock return types must match the correct class for each method.

## Layer 2: Repository Tests

Mock services. Test retry logic, JSON prep, data transformation, multi-service orchestration.

### Test Files

| Test File | Repository | Test Count | Key Scenarios |
|---|---|---|---|
| `test/repositories/profile_repository_test.dart` | ProfileRepository | ~10 | getProfile uses retryAsync, createProfile adds userId + authMethod + strips nulls, updateProfile strips user_id, createProfile with null authMethod |
| `test/repositories/auth_repository_test.dart` | AuthRepository | ~5 | Delegation tests for signIn/signOut/signUp (thin wrapper) |
| `test/repositories/entry_repository_test.dart` | EntryRepository | ~6 | fetchForDate passes ordered flag, insertEntry passes userId, delegation for update/delete/deleteByType |
| `test/repositories/drink_repository_test.dart` | DrinkRepository | ~5 | Delegation tests, insertDrink passes userId |
| `test/repositories/ingredient_repository_test.dart` | IngredientRepository | ~12 | fetchSuggestionGroups: calls 3 services sequentially/parallel, extracts IDs correctly, passes to SuggestionHelpers, handles empty data. search/insertIfNew pass userId |
| `test/repositories/recipe_repository_test.dart` | RecipeRepository | ~5 | fetchAll uses retryAsync, favorites delegation |
| `test/repositories/recommendation_repository_test.dart` | RecommendationRepository | ~8 | fetchByUserId uses retryAsync, refreshRecommendations: fetches context → calls edge function → re-fetches, null profile omits profile fields, full profile includes symptoms/intolerances/diet |
| `test/repositories/meal_media_repository_test.dart` | MealMediaRepository | ~6 | uploadMealImage uses meal-images bucket, analyzeMealImage builds base64 + calls edge function, triggerSuggestionRefresh fire-and-forget |
| `test/repositories/notification_repository_test.dart` | NotificationRepository | ~8 | syncNotifications: reminders enabled + times → schedules, disabled → cancels, dailySummary enabled → schedules, disabled → cancels, default timezone Europe/Berlin, cancelAll. **Note:** `NotificationRepository` calls static methods on `LocalNotificationService` (platform plugin). To test it, introduce an abstract `NotificationScheduler` interface that `NotificationRepository` depends on, with a `LocalNotificationScheduler` production impl and a `FakeNotificationScheduler` for tests. This is a small prerequisite refactor. |

**Total: ~65 test cases**

## Layer 3: Provider/Notifier Tests

Use `ProviderContainer` with overridden repository providers (mocks for precise verification, fakes for complex interactions).

### Test Files

| Test File | Provider | Test Count | Key Scenarios |
|---|---|---|---|
| `test/providers/auth_provider_test.dart` | AuthNotifier + derived | ~18 | AuthNotifier: signInWithEmail/signUp/Google/Apple sets loading→data, error sets error→rethrows, signOut loading→data, resetPassword delegates, updatePassword delegates, deleteAccount loading→data. Derived: authStateProvider emits, currentUserProvider reactive, isAuthenticatedProvider loading fallback |
| `test/providers/profile_provider_test.dart` | ProfileNotifier + derived | ~14 | fetchProfile loading→data, null userId→data(null), createProfile calls repo+refetches, updateProfile optimistic update, updateProfile reverts on error, reset→data(null), hasProfileProvider true/false, hasCompletedRegistrationProvider true/false |
| `test/providers/entries_provider_test.dart` | EntriesNotifier | ~16 | loadEntries loading→data, null userId early return, all CRUD methods (addMeal/updateMeal/deleteMeal + toilet + gutFeeling + drink), updateGutFeelingById/updateToiletById/updateDrinkById, deleteByType, reset |
| `test/providers/diary_provider_test.dart` | diaryEntriesProvider + date | ~6 | Returns entries for date, null userId→empty, diaryDateProvider defaults today, set changes date |
| `test/providers/meal_tracker_provider_test.dart` | MealTrackerNotifier | ~16 | setTitle/setNotes/setTrackedAt update state, setImage/clearImage, analyzeImage loading→result, analyzeImage error clears loading, searchIngredients min 3 chars, searchIngredients error sets error, addIngredient dedup + fire-and-forget, removeIngredient, deleteUserIngredient removes from suggestions, save with image + without image, save calls triggerSuggestionRefresh, save error clears saving |
| `test/providers/drink_tracker_provider_test.dart` | DrinkTrackerNotifier | ~14 | loadDrinks builds quickDrinks from recent, loadDrinks no userId fallback, loadTodayTotal, searchDrinks filters, toggleDrink select/deselect, clearSelection, selectAmount/setCustomAmount, createDrink sorts allDrinks + adds to quick, deleteDrink removes from all lists + clears if selected, save creates entry + refreshes total, save guards null drink/amount |
| `test/providers/ingredient_suggestion_provider_test.dart` | IngredientSuggestionNotifier | ~8 | fetchSuggestions loading→groups, null userId→empty, markAllNewAsSeen updates isNew flags, dismissSuggestion removes from list, newCount getter |
| `test/providers/recipes_provider_test.dart` | RecipesNotifier | ~10 | build triggers loadAll, search filtering, tag filtering, combined search+tag, toggleFavorite add/remove, favorites optimistic |
| `test/providers/recommendation_provider_test.dart` | RecommendationNotifier | ~8 | fetchRecommendations loading→data, null userId→empty, refreshRecommendations passes profile, refreshRecommendations null profile |
| `test/providers/notification_provider_test.dart` | notificationSyncProvider | ~4 | Calls repo when profile changes, ignores null profile, handles error gracefully |

**Total: ~114 test cases**

### Testing Notes

- **`EntriesNotifier`** extends `Notifier<EntriesState>` (custom state class with `isLoading`/`error` fields), NOT `AsyncNotifier`. Test assertions check `state.isLoading` and `state.error`, not `AsyncValue`.
- **`diaryEntriesProvider`** is a `FutureProvider.family<List<DiaryEntry>, DateTime>`. Test by reading with the family argument: `container.read(diaryEntriesProvider(testDate))`.
- **`RecipesNotifier.build()`** triggers `_loadAll()` immediately. Tests must have mock repository set up before reading `recipesProvider`.
- **`createContainer` helper** uses `addTearDown` which requires being called inside `test()` or `setUp()` blocks.

## Layer 4: Widget Tests

Override providers with fakes. Test rendering, interaction, and state display.

### Screen Tests

| Test File | Screen | Test Count | Key Scenarios |
|---|---|---|---|
| `test/screens/auth/auth_screen_test.dart` | AuthScreen | ~10 | Renders email/password fields, sign-in button calls AuthNotifier, shows loading indicator, displays error on failure, Google button visible, Apple button conditional on platform |
| `test/screens/auth/reset_password_screen_test.dart` | ResetPasswordScreen | ~5 | Email field, submit calls updatePassword, success feedback, validation |
| `test/screens/registration/registration_wizard_screen_test.dart` | RegistrationWizardScreen | ~12 | Step 1-7 navigation, back button, each step renders correct fields, final submit calls createProfile, progress indicator |
| `test/screens/dashboard/dashboard_screen_test.dart` | DashboardScreen | ~6 | Feature cards render, taps navigate to correct routes |
| `test/screens/diary/diary_screen_test.dart` | DiaryScreen | ~10 | Date navigation forward/back, entries render by type, empty state message, swipe between dates, tap entry opens detail |
| `test/screens/trackers/meal/meal_tracker_test.dart` | MealTrackerScreen | ~10 | Title field, ingredient add/remove/search, image section placeholder, notes field, date/time chips, save button, success overlay |
| `test/screens/trackers/drink/drink_tracker_test.dart` | DrinkTrackerScreen | ~8 | Quick drink grid, search, size selector buttons, custom amount, today total display, save |
| `test/screens/trackers/toilet/toilet_tracker_test.dart` | ToiletTrackerScreen | ~5 | Stool type selector (5 options), selection highlights, save |
| `test/screens/trackers/gut_feeling/gut_feeling_tracker_test.dart` | GutFeelingTrackerScreen | ~8 | Two tabs render, Bauchgefühl sliders (bloating/gas/cramps/fullness), Stimmung sliders, tab switching, save |
| `test/screens/recipes/recipes_screen_test.dart` | RecipesScreen | ~8 | Recipe list renders, search field filters, tag chips filter, favorite icon toggles, recipe detail sheet opens |
| `test/screens/recommendations/recommendations_screen_test.dart` | RecommendationsScreen | ~6 | Cards render, refresh button, empty state, loading state, history section |
| `test/screens/settings/settings_screen_test.dart` | SettingsScreen | ~4 | Navigation items render, taps navigate |
| `test/screens/settings/settings_account_test.dart` | SettingsAccountScreen | ~6 | Auth method display, password section visibility (email only), sign-out button, delete account dialog |
| `test/screens/settings/settings_notifications_test.dart` | SettingsNotificationsScreen | ~6 | Reminder toggle, time picker, daily summary toggle, timezone selector |
| `test/screens/settings/settings_profile_test.dart` | SettingsProfileScreen | ~6 | Profile fields render, edit + save, validation |
| `test/screens/ingredient_suggestions/ingredient_suggestions_screen_test.dart` | IngredientSuggestionsScreen | ~8 | Suggestion cards render, detail modal opens, dismiss, mark seen, badge count, empty state |
| `test/screens/welcome/welcome_screen_test.dart` | WelcomeScreen | ~4 | Renders mascot, login/register buttons, page navigation |

### Widget Tests

| Test File | Widget | Test Count | Key Scenarios |
|---|---|---|---|
| `test/widgets/bb_button_test.dart` | BbButton | ~6 | Renders label, onPressed fires, disabled state ignores tap, loading shows spinner, correct styling |
| `test/widgets/bb_card_test.dart` | BbCard | ~3 | Renders child, correct padding/radius |
| `test/widgets/bb_chip_selector_test.dart` | BbChipSelector | ~5 | Renders chips, tap toggles selection, multi-select, correct colors |
| `test/widgets/bb_password_field_test.dart` | BbPasswordField | ~5 | Obscured by default, toggle shows text, validation error display, onChanged fires |
| `test/widgets/bb_async_state_test.dart` | BbLoadingState + BbErrorState | ~4 | BbLoadingState shows spinner, BbErrorState shows message + optional retry callback, BbErrorState without retry hides button |
| `test/widgets/bb_slider_test.dart` | BbSlider | ~4 | Renders label, value change fires callback, respects min/max |
| `test/widgets/bb_bottom_nav_test.dart` | BbBottomNav | ~4 | Renders all tabs, tap fires callback, active tab highlighted |
| `test/widgets/date_time_chips_test.dart` | DateTimeChips | ~4 | Displays formatted date+time, tap fires onEdit |
| `test/widgets/tracker_card_test.dart` | TrackerCard | ~3 | Icon + title render, tap fires callback |
| `test/widgets/mood_slider_row_test.dart` | MoodSliderRow | ~4 | Label renders, slider changes value, mascot displays |

**Total: ~164 test cases**

## Layer 5: Integration Tests

Full app with faked repositories. Test critical multi-screen user flows.

### Test Files

| Test File | Flow | Test Count |
|---|---|---|
| `integration_test/auth_flow_test.dart` | Welcome → Login → Dashboard | ~3 |
| `integration_test/registration_flow_test.dart` | Welcome → Sign up → 7 wizard steps → Dashboard | ~3 |
| `integration_test/meal_tracking_flow_test.dart` | Dashboard → Meal tracker → Fill → Save → Diary shows entry | ~3 |
| `integration_test/drink_tracking_flow_test.dart` | Dashboard → Drink tracker → Select → Save → Total updates | ~3 |
| `integration_test/diary_flow_test.dart` | Diary → Navigate date → Tap entry → Detail → Edit → Save | ~3 |

**Total: ~15 test cases**

### Integration Test Setup

```dart
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

  testWidgets('meal tracking flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
          entryRepositoryProvider.overrideWithValue(fakeEntryRepo),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          // ... all repository overrides
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pumpAndSettle();
    // navigate and verify
  });
}
```

## CI Pipeline

Evolve from single `test` job to multi-stage:

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

**Stage flow:** `quality` (30s) → `unit-tests` (30s) → `widget-tests` (2min) → `integration-tests` (5min on macOS with simulator)

**Key properties:**
- `needs:` enforces sequential stages — fail fast
- `quality` and `unit-tests` on `ubuntu-latest` (cheap, fast)
- `integration-tests` on `macos-latest` (iOS simulator required)
- `flutter pub get` + `build_runner` in each job (CI jobs are isolated)
- `env.json` provided as repo secret or committed test config

## Test Count Summary

| Layer | New Test Files | Estimated Cases |
|---|---|---|
| Infrastructure | 5 helpers | — |
| Services | 10 | ~91 |
| Repositories | 9 | ~65 |
| Providers | 10 | ~114 |
| Screens | 17 | ~122 |
| Widgets | 10 | ~42 |
| Integration | 5 | ~15 |
| **New Total** | **66** | **~449** |
| Existing (models + utils) | 18 | 167 |
| **Grand Total** | **84** | **~616** |

## File Structure

```
test/
  helpers/
    mocks.dart
    fakes.dart
    fixtures.dart
    riverpod_helpers.dart
    supabase_mocks.dart
  models/         (existing — 6 files)
  utils/          (existing — 12 files)
  services/       (new — 10 files)
  repositories/   (new — 9 files)
  providers/      (new — 10 files)
  screens/        (new — 17 files)
    auth/
    registration/
    dashboard/
    diary/
    trackers/
      meal/
      drink/
      toilet/
      gut_feeling/
    recipes/
    recommendations/
    settings/
  widgets/        (new — 10 files)
integration_test/ (new — 5 files)
```
