# Architecture Refactoring: Layered Architecture with Repository Pattern

## Overview

Refactor Belly Buddy from its current hybrid architecture (static services called directly by Riverpod notifiers) to a clean layered architecture following the `flutter-architecting-apps` skill: **Data Layer (Services + Repositories) → UI Layer (ViewModels/Notifiers + Views)**.

### Goals

- Introduce a Repository layer as the single source of truth (SSOT) for all domain data
- Convert static services to instance-based classes with Riverpod-managed dependency injection
- Slim notifiers into pure ViewModels that only manage UI state
- Enforce unidirectional data flow: Views → ViewModels → Repositories → Services

### Non-Goals

- No Logic Layer (Use Cases) — the app is primarily CRUD; orchestration fits in repositories
- No folder restructuring — layer-based top-level structure stays, only `lib/repositories/` is added
- No model changes — Freezed models remain as-is
- No UI changes — screens and widgets are untouched

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| State management | Keep Riverpod (`Notifier`/`AsyncNotifier`) | Already fulfills ViewModel role; migration to `ChangeNotifier` would lose Riverpod benefits |
| Dependency injection | Riverpod providers | Natural fit; enables testing via `overrideWith` |
| Logic Layer | Omit | CRUD-dominant app; no multi-repository orchestration needed |
| Folder structure | Layer-based with new `repositories/` | ~40 lib files; feature-first is premature |
| Migration scope | All features at once | Consistent end state in one sweep |
| Migration strategy | Layer-by-layer (Approach C) | Each step leaves app compilable; single concern per step |

## Architecture: Before and After

### Before

```
View (Screen/Widget)
  → watches Notifier (business logic + UI state + data fetching)
    → calls static Service methods
      → calls SupabaseService.client (static)
```

### After

```
View (Screen/Widget)
  → watches Notifier (UI state only)
    → calls Repository (SSOT, caching, transformation, retry)
      → calls Service (stateless API wrapper, instance-based)
        → calls SupabaseClient (injected via Riverpod)
```

## Step 1: Service Layer — Static to Instance-Based

### SupabaseService Replacement

Delete `lib/services/supabase_service.dart`. Replace with Riverpod providers:

```dart
// In a new file or in each service's provider registration
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final currentUserIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);
```

### Service Conversion Pattern

Every service becomes an instance class with dependencies injected via constructor.

**Before:**
```dart
class ProfileService {
  static const _table = 'profiles';
  static Future<UserProfile?> fetchByUserId(String userId) async {
    final data = await SupabaseService.client.from(_table)...;
  }
}
```

**After:**
```dart
class ProfileService {
  static const _table = 'profiles';
  final SupabaseClient _client;
  ProfileService(this._client);

  Future<UserProfile?> fetchByUserId(String userId) async {
    final data = await _client.from(_table)...;
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(supabaseClientProvider)),
);
```

### Services to Convert

| Service | Constructor Dependencies |
|---|---|
| `AuthService` | `GoTrueClient` (from `SupabaseClient.auth`) |
| `ProfileService` | `SupabaseClient` |
| `EntryCrudService` | `SupabaseClient` |
| `EntryQueryService` | `SupabaseClient` |
| `DrinkService` | `SupabaseClient` |
| `IngredientService` | `SupabaseClient` |
| `RecipeService` | `SupabaseClient` |
| `RecommendationService` | `SupabaseClient` |
| `StorageService` | `SupabaseClient` |
| `EdgeFunctionService` | `SupabaseClient` |

### Services That Stay As-Is

- `NotificationService` — facade over platform plugins, not Supabase
- `LocalNotificationService` — wraps `flutter_local_notifications` plugin
- `PushNotificationService` — wraps Firebase Cloud Messaging
- `HapticService` — wraps platform haptics

## Step 2: Repository Layer

### New Directory

```
lib/repositories/
  auth_repository.dart
  profile_repository.dart
  entry_repository.dart
  drink_repository.dart
  ingredient_repository.dart
  recipe_repository.dart
  recommendation_repository.dart
  meal_media_repository.dart
  notification_repository.dart
```

### Repository Responsibilities

Each repository:
- Wraps one or more services
- Acts as SSOT for its domain data
- Handles retry logic (absorbed from providers)
- Handles JSON preparation and data transformation (absorbed from providers)
- Handles caching where applicable
- Returns clean domain models

| Repository | Services | Absorbs From |
|---|---|---|
| `AuthRepository` | `AuthService` | `auth_provider.dart` — sign-in/out orchestration |
| `ProfileRepository` | `ProfileService`, `AuthService` | `profile_provider.dart` — retry logic, JSON prep, auth method detection |
| `EntryRepository` | `EntryCrudService`, `EntryQueryService` | `entries_provider.dart`, `diary_provider.dart` — CRUD + date-range queries |
| `DrinkRepository` | `DrinkService` | `drink_tracker_provider.dart` — drink search, recent drinks |
| `IngredientRepository` | `IngredientService` | `ingredient_suggestion_provider.dart` — fetch + grouping logic |
| `RecipeRepository` | `RecipeService` | `recipes_provider.dart` — query, favorites, filtering |
| `RecommendationRepository` | `RecommendationService` | `recommendation_provider.dart` — fetch + history |
| `MealMediaRepository` | `StorageService`, `EdgeFunctionService` | `meal_tracker_provider.dart` — image upload + AI analysis |
| `NotificationRepository` | `NotificationService` | `notification_provider.dart` — scheduling, push token management |

### Example: ProfileRepository

```dart
class ProfileRepository {
  final ProfileService _profileService;
  final AuthService _authService;
  static const _log = AppLogger('ProfileRepository');

  ProfileRepository(this._profileService, this._authService);

  Future<UserProfile?> getProfile(String userId) async {
    return retryAsync(
      () => _profileService.fetchByUserId(userId),
      log: _log,
      label: 'fetchProfile',
    );
  }

  Future<void> createProfile(String userId, UserProfile profile) async {
    final authMethod = _authService.detectAuthMethod();
    final data = profile
        .copyWith(userId: userId, authMethod: authMethod)
        .toJson();
    data['user_id'] = userId;
    data.removeWhere((key, value) => value == null);
    await _profileService.upsert(data);
  }

  Future<void> updateProfile(String userId, UserProfile profile) async {
    final data = profile.toJson();
    data.remove('user_id');
    await _profileService.update(userId, data);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(profileServiceProvider),
    ref.watch(authServiceProvider),
  ),
);
```

## Step 3: Provider (ViewModel) Slimming

### Pattern

Every notifier becomes a pure ViewModel:
- Reads repositories via `ref.read()`
- Manages `AsyncValue` / UI state
- Handles optimistic updates (state management is a UI concern)
- Contains zero data-layer logic (no retry, no JSON prep, no service imports)

**Before:**
```dart
class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  Future<void> createProfile(UserProfile profile) async {
    final userId = SupabaseService.userId;
    final authMethod = AuthService.detectAuthMethod();
    final data = profile.copyWith(...).toJson();
    data['user_id'] = userId;
    data.removeWhere((k, v) => v == null);
    await ProfileService.upsert(data);
    await fetchProfile();
  }
}
```

**After:**
```dart
class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  Future<void> createProfile(UserProfile profile) async {
    try {
      final userId = ref.read(currentUserIdProvider)!;
      await _repo.createProfile(userId, profile);
      await fetchProfile();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
```

### All Notifiers to Refactor

| Notifier | Delegates To |
|---|---|
| `ProfileNotifier` | `ProfileRepository` |
| `AuthProvider` (in `auth_provider.dart`) | `AuthRepository` |
| `EntriesNotifier` | `EntryRepository` |
| `MealTrackerNotifier` | `EntryRepository`, `MealMediaRepository`, `IngredientRepository` |
| `DrinkTrackerNotifier` | `EntryRepository`, `DrinkRepository` |
| `DiaryProvider` | `EntryRepository` |
| `RecipesNotifier` | `RecipeRepository` |
| `RecommendationNotifier` | `RecommendationRepository` |
| `IngredientSuggestionNotifier` | `IngredientRepository` |
| `NotificationProvider` | `NotificationRepository` |

### Derived Providers (Unchanged)

These stay as-is — they're pure derivations:
- `hasProfileProvider`
- `hasCompletedRegistrationProvider`
- `isAuthenticatedProvider`
- `currentUserProvider`
- `authStateProvider` (StreamProvider)

## File Impact Summary

| Action | Files |
|---|---|
| **Delete** | `lib/services/supabase_service.dart` |
| **Create** | `lib/repositories/` (9 files) |
| **Modify** | `lib/services/` (10 files — static → instance) |
| **Modify** | `lib/providers/` (10 files — slim to ViewModels) |
| **Unchanged** | `lib/models/`, `lib/config/`, `lib/screens/`, `lib/widgets/`, `lib/router/`, `lib/utils/` |

## Migration Order

Each step leaves the app compilable and functional:

1. **Step 1 — Services:** Convert static → instance-based, register as providers, replace `SupabaseService` with `supabaseClientProvider`. Update all call sites in providers to use `ref.read(xxxServiceProvider)`.
2. **Step 2 — Repositories:** Create 9 repository classes wrapping services. Register as providers. No consumers yet — app still works via Step 1 wiring.
3. **Step 3 — ViewModels:** Rewire all notifiers to consume repositories. Remove service imports from providers. Strip data-layer concerns.

## Testing Considerations

The refactoring enables better testability but does not include writing tests:
- Services can be mocked by overriding their providers
- Repositories can be tested in isolation with mocked services
- ViewModels can be tested with mocked repositories
- Integration tests can override at any layer
