# Architecture Refactoring: Layered Architecture with Repository Pattern

## Overview

Refactor Belly Buddy from its current hybrid architecture (static services called directly by Riverpod notifiers and screens) to a clean layered architecture following the `flutter-architecting-apps` skill: **Data Layer (Services + Repositories) → UI Layer (ViewModels/Notifiers + Views)**.

### Goals

- Introduce a Repository layer as the single source of truth (SSOT) for all domain data
- Convert static services to instance-based classes with Riverpod-managed dependency injection
- Slim notifiers into pure ViewModels that only manage UI state
- Enforce unidirectional data flow: Views → ViewModels → Repositories → Services
- Eliminate direct service calls from screens — all data operations go through providers

### Non-Goals

- No Logic Layer (Use Cases) — the app is primarily CRUD; orchestration fits in repositories
- No folder restructuring — layer-based top-level structure stays, only `lib/repositories/` is added
- No model changes — Freezed models remain as-is
- No new tests (but the refactoring enables better testability)

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

View (Screen/Widget)
  → calls static Service methods directly (auth, haptics, notifications)
```

### After

```
View (Screen/Widget)
  → watches Notifier (UI state only)
    → calls Repository (SSOT, caching, transformation, retry)
      → calls Service (stateless API wrapper, instance-based)
        → calls SupabaseClient (injected via Riverpod)

View (Screen/Widget)
  → calls HapticService directly (exception — stateless utility, stays static)
```

## Step 1: Service Layer — Static to Instance-Based

### SupabaseService Replacement

Delete `lib/services/supabase_service.dart`. Replace with Riverpod providers in a new file `lib/providers/core_providers.dart`:

```dart
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final currentUserIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);

final currentUserProvider = Provider<User?>(
  (ref) => Supabase.instance.client.auth.currentUser,
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => Supabase.instance.client.auth.currentUser != null,
);
```

### Service Conversion Pattern

Every Supabase-backed service becomes an instance class with dependencies injected via constructor.

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

| Service | Constructor Dependencies | Notes |
|---|---|---|
| `AuthService` | `GoTrueClient`, `EdgeFunctionService` | Also calls `EdgeFunctionService.invoke` for welcome email, password reset, account deletion. Also needs access to current session. |
| `ProfileService` | `SupabaseClient` | |
| `EntryCrudService` | `SupabaseClient` | |
| `EntryQueryService` | `SupabaseClient` | |
| `DrinkService` | `SupabaseClient` | `insertDrink` and `deleteDrink` internally read `SupabaseService.userId` — change signatures to accept `userId` as parameter. |
| `IngredientService` | `SupabaseClient` | `search` and `insertIfNew` internally read `SupabaseService.userId` — change signatures to accept `userId` as parameter. |
| `RecipeService` | `SupabaseClient` | |
| `RecommendationService` | `SupabaseClient` | |
| `StorageService` | `SupabaseClient` | |
| `EdgeFunctionService` | `SupabaseClient` | |

### Services That Stay Static

- `HapticService` — stateless platform utility with no external dependencies. Used in 21+ widget/screen files. Converting would add `ref` plumbing to every widget for no benefit.

### Notification Services — Special Handling

`NotificationService`, `LocalNotificationService`, and `PushNotificationService` wrap platform plugins (not Supabase), but they currently call `SupabaseService` and `ProfileService` statically:

- `PushNotificationService` calls `SupabaseService.userId` and `ProfileService.update()` to save the FCM token
- `app.dart` calls `PushNotificationService` and `LocalNotificationService` static methods for message handling

**Approach:** Convert `PushNotificationService` to instance-based with injected dependencies (`ProfileService` or `ProfileRepository`). `LocalNotificationService` and `NotificationService` (facade) can stay static since they don't depend on Supabase services. `app.dart` will access push notification handling through a Riverpod provider.

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
- Preserves fire-and-forget semantics (`.ignore()`) where they exist in the current code

| Repository | Services | Absorbs From |
|---|---|---|
| `AuthRepository` | `AuthService` | Screen files (`auth_screen.dart`, `registration_wizard_screen.dart`, `settings_account_screen.dart`, `password_change_section.dart`, `reset_password_screen.dart`, `delete_account_dialog.dart`) — sign-in/out, password management, account deletion. Currently this logic lives directly in screens, not in `auth_provider.dart`. |
| `ProfileRepository` | `ProfileService`, `AuthService` | `profile_provider.dart` — retry logic, JSON prep, auth method detection |
| `EntryRepository` | `EntryCrudService`, `EntryQueryService` | `entries_provider.dart`, `diary_provider.dart` — CRUD + date-range queries |
| `DrinkRepository` | `DrinkService` | `drink_tracker_provider.dart` — drink search, recent drinks |
| `IngredientRepository` | `IngredientService` | `ingredient_suggestion_provider.dart` — fetch + grouping logic |
| `RecipeRepository` | `RecipeService` | `recipes_provider.dart` — query, favorites, filtering |
| `RecommendationRepository` | `RecommendationService`, `EdgeFunctionService` | `recommendation_provider.dart` — fetch + history. Also calls `EdgeFunctionService.invoke` for AI recommendations and reads profile data (passed as parameter, not via cross-provider dependency). |
| `MealMediaRepository` | `StorageService`, `EdgeFunctionService` | `meal_tracker_provider.dart` — image upload + AI analysis. Preserve fire-and-forget calls. |
| `NotificationRepository` | `PushNotificationService`, `NotificationService` | `notification_provider.dart` — scheduling, push token management |

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

Note: `retryAsync` remains a standalone utility in `lib/utils/retry_helper.dart` — it is called from repositories instead of providers but is not reimplemented.

## Step 3: Provider (ViewModel) Slimming + Screen Cleanup

### Notifier Pattern

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

### Notifiers to Refactor

| Provider | Type | Delegates To | Notes |
|---|---|---|---|
| `ProfileNotifier` | `Notifier` | `ProfileRepository` | Standard pattern |
| `EntriesNotifier` | `Notifier` | `EntryRepository` | Standard pattern |
| `MealTrackerNotifier` | `Notifier` | `EntryRepository`, `MealMediaRepository`, `IngredientRepository` | Standard pattern |
| `DrinkTrackerNotifier` | `Notifier` | `EntryRepository`, `DrinkRepository` | Standard pattern |
| `RecipesNotifier` | `Notifier` | `RecipeRepository` | Standard pattern |
| `RecommendationNotifier` | `Notifier` | `RecommendationRepository` | Currently reads `profileProvider` cross-provider — pass profile data as parameter to repository method instead |
| `IngredientSuggestionNotifier` | `Notifier` | `IngredientRepository` | Standard pattern |
| `diaryEntriesProvider` | `FutureProvider.family` | `EntryRepository` | Not a Notifier — just replace service calls with repository calls inside the `FutureProvider.family` body |
| `notificationSyncProvider` | `Provider<void>` (reactive side-effect) | `NotificationRepository` | Not a Notifier — reactive provider that watches `profileProvider` and triggers sync. Replace service calls with repository calls. |
| `authStateProvider` | `StreamProvider` | `AuthRepository` or direct `GoTrueClient` | Currently calls `AuthService.onAuthStateChange` statically — update to use `ref.watch(authServiceProvider).onAuthStateChange` or `ref.watch(supabaseClientProvider).auth.onAuthStateChange` |

### New Auth Provider

Auth operations currently live directly in screen files (not in any provider). Create a new `AuthNotifier` to centralize auth operations:

```dart
class AuthNotifier extends Notifier<AsyncValue<void>> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<AuthResponse> signInWithEmail(String email, String password) async { ... }
  Future<AuthResponse> signUpWithEmail(String email, String password) async { ... }
  Future<AuthResponse> signInWithGoogle() async { ... }
  Future<AuthResponse> signInWithApple() async { ... }
  Future<void> signOut() async { ... }
  Future<void> resetPassword(String email) async { ... }
  Future<void> updatePassword(String newPassword) async { ... }
  Future<void> deleteAccount() async { ... }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);
```

Screens then call `ref.read(authNotifierProvider.notifier).signInWithEmail(...)` instead of `AuthService.signInWithEmail(...)`.

### Derived Providers (Unchanged)

These stay as-is — they're pure derivations with no service dependencies:
- `hasProfileProvider`
- `hasCompletedRegistrationProvider`

### Screen Modifications

Screens that currently call services directly must be updated to go through providers:

| Screen | Current Direct Calls | After |
|---|---|---|
| `auth_screen.dart` | `AuthService.signInWithEmail/Google/Apple`, `resetPassword` | Use `authNotifierProvider` |
| `registration_wizard_screen.dart` | `AuthService.signUpWithEmail/signInWithGoogle/signInWithApple` | Use `authNotifierProvider` |
| `reset_password_screen.dart` | `AuthService.updatePassword` | Use `authNotifierProvider` |
| `settings_account_screen.dart` | `AuthService.signOut/detectAuthMethod`, `SupabaseService.currentUser` | Use `authNotifierProvider` + `currentUserProvider` |
| `password_change_section.dart` | `AuthService.signInWithEmail/updatePassword/resetPassword`, `SupabaseService.currentUser` | Use `authNotifierProvider` + `currentUserProvider` |
| `delete_account_dialog.dart` | `AuthService.deleteAccount` | Use `authNotifierProvider` |
| `settings_notifications_screen.dart` | `PushNotificationService.requestPermission`, `SupabaseService.userId` | Use `notificationRepository` provider + `currentUserIdProvider` |
| `drink_search.dart` | `SupabaseService.userId` | Use `currentUserIdProvider` |

### app.dart and main.dart Modifications

`app.dart` currently calls `SupabaseService` and notification services directly:
- `SupabaseService.isAuthenticated` / `.userId` → Use `isAuthenticatedProvider` / `currentUserIdProvider` (already a `ConsumerStatefulWidget`)
- `PushNotificationService.*` message handling → Create a `pushNotificationProvider` that exposes message streams and route extraction
- `LocalNotificationService.cancelAll()` → Call through `NotificationRepository`

`main.dart` calls `NotificationService.initialize()` — this stays as-is (one-time platform initialization before Riverpod is available).

### Utility File Modifications

- `lib/utils/signed_url_helper.dart` — calls `StorageService.getSignedUrl()` statically. Update to accept `StorageService` as a parameter, or convert to a provider-aware helper.

## File Impact Summary

| Action | Files |
|---|---|
| **Delete** | `lib/services/supabase_service.dart` |
| **Create** | `lib/repositories/` (9 files) |
| **Create** | `lib/providers/core_providers.dart` (supabase, currentUser, isAuthenticated providers) |
| **Modify** | `lib/services/` (10 Supabase-backed services — static → instance + `PushNotificationService`) |
| **Modify** | `lib/providers/` (all provider files — slim to ViewModels + new `AuthNotifier`) |
| **Modify** | `lib/screens/` (8 screen/widget files — replace direct service calls with provider calls) |
| **Modify** | `lib/app.dart` (replace `SupabaseService` + notification service calls with providers) |
| **Modify** | `lib/utils/signed_url_helper.dart` (replace static `StorageService` call) |
| **Unchanged** | `lib/models/`, `lib/config/`, `lib/router/`, `lib/main.dart` (except `NotificationService.initialize` stays) |
| **Unchanged** | `lib/widgets/common/` (only `HapticService` calls, which stays static) |
| **Unchanged** | `lib/utils/` (except `signed_url_helper.dart`) |

## Migration Order

Each step leaves the app compilable and functional:

1. **Step 1 — Services + Core Providers:**
   - Create `lib/providers/core_providers.dart` with `supabaseClientProvider`, `currentUserIdProvider`, `currentUserProvider`, `isAuthenticatedProvider`
   - Convert 10 Supabase-backed services from static to instance-based, register each as a Riverpod provider
   - Convert `PushNotificationService` to instance-based (inject `ProfileService`/`ProfileRepository`)
   - Update `DrinkService` and `IngredientService` method signatures to accept `userId` as parameter instead of reading `SupabaseService.userId` internally
   - Update all call sites (providers, screens, `app.dart`, `signed_url_helper.dart`) to use `ref.read(xxxServiceProvider)` or core providers instead of static calls
   - Delete `lib/services/supabase_service.dart`

2. **Step 2 — Repositories:**
   - Create 9 repository classes wrapping services
   - Register as Riverpod providers
   - Absorb retry logic, JSON prep, data transformation, and fire-and-forget patterns from providers
   - No consumers yet — app still works via Step 1 wiring

3. **Step 3 — ViewModels + Screen Cleanup:**
   - Create `AuthNotifier` to centralize auth operations
   - Rewire all notifiers/providers to consume repositories instead of services
   - Update `FutureProvider.family` and reactive `Provider<void>` to use repositories
   - Update `authStateProvider` to use injected service
   - Update 8 screen files to call providers instead of services directly
   - Update `app.dart` to use providers for notification handling
   - Remove all service imports from providers and screens (except `HapticService`)

## Testing Considerations

The refactoring enables better testability but does not include writing tests:
- Services can be mocked by overriding their providers
- Repositories can be tested in isolation with mocked services
- ViewModels can be tested with mocked repositories
- Integration tests can override at any layer
