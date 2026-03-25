# Layered Architecture Refactoring Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Belly Buddy codebase to a clean layered architecture (Services + Repositories + ViewModels) with Riverpod-managed dependency injection.

**Architecture:** Static services become instance-based classes registered as Riverpod providers. A new Repository layer (SSOT) sits between services and ViewModels. Notifiers are slimmed to pure ViewModels with no data-layer logic.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), Supabase (`supabase_flutter`), Freezed models

**Spec:** `docs/superpowers/specs/2026-03-25-architecture-refactoring-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `lib/providers/core_providers.dart` | Supabase client + currentUserId providers (auth-reactive providers stay in `auth_provider.dart`) |
| `lib/repositories/notification_repository.dart` | Notification scheduling wrapper (local + push) |
| `lib/repositories/auth_repository.dart` | Sign-in/out, password management, account deletion |
| `lib/repositories/profile_repository.dart` | Profile CRUD with retry + JSON prep |
| `lib/repositories/entry_repository.dart` | All entry CRUD + date-range queries |
| `lib/repositories/drink_repository.dart` | Drink master data, recent drinks, drink CRUD |
| `lib/repositories/ingredient_repository.dart` | Ingredient search/insert, suggestions, replacements |
| `lib/repositories/recipe_repository.dart` | Recipe queries, favorites |
| `lib/repositories/recommendation_repository.dart` | AI recommendations fetch + refresh |
| `lib/repositories/meal_media_repository.dart` | Image upload + AI meal analysis |

### Deleted Files

| File | Reason |
|---|---|
| `lib/services/supabase_service.dart` | Replaced by `core_providers.dart` |

### Modified Files

| File | Changes |
|---|---|
| `lib/services/auth_service.dart` | Static → instance, inject `GoTrueClient` + `EdgeFunctionService` |
| `lib/services/profile_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/entry_crud_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/entry_query_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/drink_service.dart` | Static → instance, inject `SupabaseClient`, add `userId` param to `insertDrink` |
| `lib/services/ingredient_service.dart` | Static → instance, inject `SupabaseClient`, add `userId` param to `search`/`insertIfNew` |
| `lib/services/recipe_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/recommendation_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/storage_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/edge_function_service.dart` | Static → instance, inject `SupabaseClient` |
| `lib/services/push_notification_service.dart` | Replace `SupabaseService.userId` + `ProfileService.update` with injected deps |
| `lib/providers/auth_provider.dart` | Use injected services, add `AuthNotifier` |
| `lib/providers/notification_provider.dart` | Delegate to `NotificationRepository` |
| `lib/providers/profile_provider.dart` | Delegate to `ProfileRepository` |
| `lib/providers/entries_provider.dart` | Delegate to `EntryRepository` |
| `lib/providers/diary_provider.dart` | Delegate to `EntryRepository` |
| `lib/providers/meal_tracker_provider.dart` | Delegate to `MealMediaRepository` + `EntryRepository` + `IngredientRepository` |
| `lib/providers/drink_tracker_provider.dart` | Delegate to `DrinkRepository` + `EntryRepository` |
| `lib/providers/ingredient_suggestion_provider.dart` | Delegate to `IngredientRepository` |
| `lib/providers/recipes_provider.dart` | Delegate to `RecipeRepository` |
| `lib/providers/recommendation_provider.dart` | Delegate to `RecommendationRepository` |
| `lib/app.dart` | Replace `SupabaseService` with core providers |
| `lib/screens/auth/auth_screen.dart` | Use `AuthNotifier` instead of `AuthService` |
| `lib/screens/auth/reset_password_screen.dart` | Use `AuthNotifier` |
| `lib/screens/registration/registration_wizard_screen.dart` | Use `AuthNotifier` |
| `lib/screens/settings/widgets/settings_account_screen.dart` | Use `AuthNotifier` + core providers |
| `lib/screens/settings/widgets/password_change_section.dart` | Use `AuthNotifier` + core providers |
| `lib/screens/settings/widgets/delete_account_dialog.dart` | Use `AuthNotifier` |
| `lib/screens/settings/widgets/settings_notifications_screen.dart` | Use core providers + repository |
| `lib/screens/trackers/drink/widgets/drink_search.dart` | Use `currentUserIdProvider` |
| `lib/screens/trackers/meal/widgets/ingredient_search.dart` | Import `IngredientSuggestion` from service (type only — no service call) |
| `lib/utils/signed_url_helper.dart` | Remove `StorageService` import, use `Supabase.instance.client.storage` directly |

---

## Task 1: Create Core Providers + Convert EdgeFunctionService

**Files:**
- Create: `lib/providers/core_providers.dart`
- Modify: `lib/services/edge_function_service.dart`

- [ ] **Step 1: Create `lib/providers/core_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Core Supabase client — single source for all services
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Current authenticated user's ID (nullable).
/// For auth-reactive providers (currentUserProvider, isAuthenticatedProvider),
/// see auth_provider.dart — those watch the auth state stream.
final currentUserIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);
```

- [ ] **Step 2: Convert `EdgeFunctionService` to instance-based**

Replace contents of `lib/services/edge_function_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class EdgeFunctionService {
  static const _log = AppLogger('EdgeFunctionService');
  final SupabaseClient _client;

  EdgeFunctionService(this._client);

  Future<Map<String, dynamic>> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        body: body,
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'data': response.data};
    } catch (e, st) {
      _log.error('invoke($functionName) failed', e, st);
      rethrow;
    }
  }
}

final edgeFunctionServiceProvider = Provider<EdgeFunctionService>(
  (ref) => EdgeFunctionService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: No new issues (other services still use static `SupabaseService` — that's fine for now)

- [ ] **Step 4: Commit**

```bash
git add lib/providers/core_providers.dart lib/services/edge_function_service.dart
git commit -m "refactor: add core providers and convert EdgeFunctionService to instance-based"
```

---

## Task 2: Convert AuthService to Instance-Based

**Files:**
- Modify: `lib/services/auth_service.dart`

- [ ] **Step 1: Convert `AuthService`**

Replace static class with instance class. Inject `GoTrueClient` and `EdgeFunctionService`. Keep `_generateNonce` and `isAppleSignInAvailable` as static (they have no dependencies).

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '../config/oauth_config.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';
import 'edge_function_service.dart';

class AuthService {
  static const _log = AppLogger('AuthService');
  final GoTrueClient _auth;
  final EdgeFunctionService _edgeFunctions;

  AuthService(this._auth, this._edgeFunctions);

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithPassword(email: email, password: password);
    } catch (e, st) {
      _log.error('signInWithEmail failed', e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await _auth.signUp(email: email, password: password);
      if (response.user != null) {
        _edgeFunctions
            .invoke('send-welcome-email', body: {'email': email})
            .ignore();
      }
      return response;
    } catch (e, st) {
      _log.error('signUpWithEmail failed', e, st);
      rethrow;
    }
  }

  static String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<AuthResponse> signInWithGoogle() async {
    const webClientId = OAuthConfig.googleWebClientId;
    const iosClientId = OAuthConfig.googleIosClientId;

    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    await GoogleSignIn.instance.initialize(
      clientId: iosClientId,
      serverClientId: webClientId,
      nonce: hashedNonce,
    );

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('No ID token received from Google');
    }

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return _signInWithIdToken(
      OAuthProvider.apple,
      credential.identityToken,
      'Apple',
    );
  }

  Future<AuthResponse> _signInWithIdToken(
    OAuthProvider provider,
    String? idToken,
    String providerName,
  ) async {
    if (idToken == null) {
      throw Exception('No ID token received from $providerName');
    }
    return await _auth.signInWithIdToken(provider: provider, idToken: idToken);
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, st) {
      _log.error('signOut failed', e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _edgeFunctions.invoke(
        'send-password-reset',
        body: {'email': email},
      );
    } catch (e, st) {
      _log.error('resetPassword failed', e, st);
      rethrow;
    }
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (e, st) {
      _log.error('updatePassword failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _edgeFunctions.invoke('delete-account');
      await signOut();
    } catch (e, st) {
      _log.error('deleteAccount failed', e, st);
      rethrow;
    }
  }

  String? detectAuthMethod() {
    final session = currentSession;
    if (session == null) return null;

    final provider = session.user.appMetadata['provider'] as String?;
    switch (provider) {
      case 'google':
        return 'google';
      case 'apple':
        return 'apple';
      case 'email':
        return 'email';
      default:
        return 'email';
    }
  }

  static bool get isAppleSignInAvailable => Platform.isIOS;
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(supabaseClientProvider).auth,
    ref.watch(edgeFunctionServiceProvider),
  ),
);
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze`
Expected: Warnings about unused imports of old `AuthService` static calls in screen files — these will be fixed in later tasks.

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "refactor: convert AuthService to instance-based with DI"
```

---

## Task 3: Convert Remaining Supabase Services to Instance-Based

**Files:**
- Modify: `lib/services/profile_service.dart`
- Modify: `lib/services/entry_crud_service.dart`
- Modify: `lib/services/entry_query_service.dart`
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: Convert `ProfileService`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class ProfileService {
  static const _log = AppLogger('ProfileService');
  static const _table = 'profiles';
  final SupabaseClient _client;

  ProfileService(this._client);

  Future<UserProfile?> fetchByUserId(String userId) async {
    _log.debug('fetchByUserId: userId=$userId');
    final data = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    _log.debug('fetchByUserId: data=$data');
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> upsert(Map<String, dynamic> data) async {
    await _client.from(_table).upsert(data, onConflict: 'user_id');
  }

  Future<void> update(String userId, Map<String, dynamic> data) async {
    await _client.from(_table).update(data).eq('user_id', userId);
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 2: Convert `EntryCrudService`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

const entryTableFor = {
  'meal': 'meal_entries',
  'toilet': 'toilet_entries',
  'gutFeeling': 'gut_feeling_entries',
  'drink': 'drink_entries',
};

class EntryCrudService {
  static const _log = AppLogger('EntryCrudService');
  final SupabaseClient _client;

  EntryCrudService(this._client);

  Future<void> insert(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) async {
    data['user_id'] = userId;
    data.remove('id');
    data.remove('created_at');
    try {
      await _client.from(table).insert(data);
    } catch (e, st) {
      _log.error('insert into $table failed', e, st);
      rethrow;
    }
  }

  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at');
    try {
      await _client.from(table).update(data).eq('id', id);
    } catch (e, st) {
      _log.error('update $table/$id failed', e, st);
      rethrow;
    }
  }

  Future<void> delete(String table, String id) async {
    try {
      await _client.from(table).delete().eq('id', id);
    } catch (e, st) {
      _log.error('delete $table/$id failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteByType(String type, String id) async {
    final table = switch (type) {
      'meal' => entryTableFor['meal']!,
      'toilet' => entryTableFor['toilet']!,
      'gutFeeling' => entryTableFor['gutFeeling']!,
      'drink' => entryTableFor['drink']!,
      _ => throw ArgumentError('Unknown entry type: $type'),
    };
    await delete(table, id);
  }
}

final entryCrudServiceProvider = Provider<EntryCrudService>(
  (ref) => EntryCrudService(ref.watch(supabaseClientProvider)),
);
```

Note: `insert` now requires a `userId` parameter instead of reading `SupabaseService.userId` internally.

**IMPORTANT — Compilability:** After changing the `insert` signature, immediately update the callers in `entries_provider.dart` to pass `userId`. Replace all `EntryCrudService.insert(table, data)` calls with `EntryCrudService(ref.read(supabaseClientProvider)).insert(table, data, userId: ref.read(currentUserIdProvider)!)`. These callers will be fully rewritten in Task 10 — this is a temporary fix to keep compilation working.

- [ ] **Step 3: Convert `EntryQueryService`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

class EntryQueryResult {
  final List<MealEntry> meals;
  final List<ToiletEntry> toiletEntries;
  final List<GutFeelingEntry> gutFeelings;
  final List<DrinkEntry> drinks;

  const EntryQueryResult({
    required this.meals,
    required this.toiletEntries,
    required this.gutFeelings,
    required this.drinks,
  });
}

class EntryQueryService {
  static const _log = AppLogger('EntryQueryService');
  final SupabaseClient _client;

  EntryQueryService(this._client);

  Future<EntryQueryResult> fetchEntriesForDateRange({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) async {
    try {
      final start = startOfDay(date).toIso8601String();
      final end = endOfDay(date).toIso8601String();

      PostgrestFilterBuilder<PostgrestList> baseQuery(
        String table, [
        String columns = '*',
      ]) {
        return _client
            .from(table)
            .select(columns)
            .eq('user_id', userId)
            .gte('tracked_at', start)
            .lt('tracked_at', end);
      }

      final List<Future<List<dynamic>>> futures;
      if (ordered) {
        futures = [
          baseQuery('meal_entries').order('tracked_at', ascending: false),
          baseQuery('toilet_entries').order('tracked_at', ascending: false),
          baseQuery(
            'gut_feeling_entries',
          ).order('tracked_at', ascending: false),
          baseQuery(
            'drink_entries',
            '*, drinks(name)',
          ).order('tracked_at', ascending: false),
        ];
      } else {
        futures = [
          baseQuery('meal_entries'),
          baseQuery('toilet_entries'),
          baseQuery('gut_feeling_entries'),
          baseQuery('drink_entries', '*, drinks(name)'),
        ];
      }

      final results = await Future.wait(futures);

      return EntryQueryResult(
        meals: results[0].map((e) => MealEntry.fromJson(e)).toList(),
        toiletEntries:
            results[1].map((e) => ToiletEntry.fromJson(e)).toList(),
        gutFeelings:
            results[2].map((e) => GutFeelingEntry.fromJson(e)).toList(),
        drinks: results[3].map((e) => DrinkEntry.fromDbRow(e)).toList(),
      );
    } catch (e, st) {
      _log.error('fetchEntriesForDateRange failed for $date', e, st);
      rethrow;
    }
  }
}

final entryQueryServiceProvider = Provider<EntryQueryService>(
  (ref) => EntryQueryService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 4: Convert `StorageService`**

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';
import '../utils/mime_utils.dart';

class StorageService {
  static const _log = AppLogger('StorageService');
  static const _uuid = Uuid();
  final SupabaseClient _client;

  StorageService(this._client);

  Future<String> uploadImage({
    required String bucket,
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) async {
    try {
      final fileName = '$userId/${_uuid.v4()}.$extension';
      await _client.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(
              contentType: mimeTypeForExtension(extension),
            ),
          );
      return fileName;
    } catch (e, st) {
      _log.error('uploadImage failed for bucket=$bucket', e, st);
      rethrow;
    }
  }

  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(path, expiresIn);
    } catch (e, st) {
      _log.error('getSignedUrl failed for bucket=$bucket path=$path', e, st);
      rethrow;
    }
  }

  String getPublicUrl({required String bucket, required String path}) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze`

- [ ] **Step 6: Commit**

```bash
git add lib/services/profile_service.dart lib/services/entry_crud_service.dart lib/services/entry_query_service.dart lib/services/storage_service.dart
git commit -m "refactor: convert ProfileService, EntryCrudService, EntryQueryService, StorageService to instance-based"
```

---

## Task 4: Convert DrinkService, IngredientService, RecipeService, RecommendationService

**Files:**
- Modify: `lib/services/drink_service.dart`
- Modify: `lib/services/ingredient_service.dart`
- Modify: `lib/services/recipe_service.dart`
- Modify: `lib/services/recommendation_service.dart`

- [ ] **Step 1: Convert `DrinkService`**

Key change: `insertDrink` now takes `userId` as parameter instead of reading from `SupabaseService`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drink.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

class DrinkService {
  static const _log = AppLogger('DrinkService');
  final SupabaseClient _client;

  DrinkService(this._client);

  Future<List<Drink>> fetchAll() async {
    try {
      final data = await _client.from('drinks').select().order('name');
      return data.map((e) => Drink.fromDbRow(e)).toList();
    } catch (e, st) {
      _log.error('fetchAll failed', e, st);
      rethrow;
    }
  }

  Future<int> fetchTodayTotal(String userId) async {
    try {
      final now = DateTime.now();
      final data = await _client
          .from('drink_entries')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('tracked_at', startOfDay(now).toIso8601String())
          .lt('tracked_at', endOfDay(now).toIso8601String());
      return data.fold<int>(0, (sum, e) => sum + (e['amount_ml'] as int));
    } catch (e, st) {
      _log.error('fetchTodayTotal failed', e, st);
      rethrow;
    }
  }

  Future<List<String>> fetchRecentDrinkIds(String userId) async {
    try {
      final data = await _client
          .from('drink_entries')
          .select('drink_id')
          .eq('user_id', userId)
          .order('tracked_at', ascending: false)
          .limit(20);
      final seen = <String>{};
      return data
          .map((e) => e['drink_id'] as String)
          .where((id) => seen.add(id))
          .take(10)
          .toList();
    } catch (e, st) {
      _log.error('fetchRecentDrinkIds failed', e, st);
      rethrow;
    }
  }

  Future<Drink> insertDrink(String name, {required String userId}) async {
    try {
      final data = await _client
          .from('drinks')
          .insert({
            'name': name,
            'added_via': 'user',
            'added_by_user_id': userId,
          })
          .select()
          .single();
      return Drink.fromDbRow(data);
    } catch (e, st) {
      _log.error('insertDrink failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteDrink(String drinkId) async {
    try {
      await _client.from('drink_entries').delete().eq('drink_id', drinkId);
      await _client.from('drinks').delete().eq('id', drinkId);
    } catch (e, st) {
      _log.error('deleteDrink failed', e, st);
      rethrow;
    }
  }
}

final drinkServiceProvider = Provider<DrinkService>(
  (ref) => DrinkService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 2: Convert `IngredientService`**

Key change: `search` and `insertIfNew` now take `userId` as parameter.

**IMPORTANT — Compilability:** After changing these signatures, immediately update callers in `meal_tracker_provider.dart` to pass `userId`. Replace `IngredientService.search(query)` with `ref.read(ingredientServiceProvider).search(query, userId: ref.read(currentUserIdProvider))` and similarly for `insertIfNew`. These callers will be fully rewritten in Task 11 — this is a temporary fix.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class IngredientSuggestion {
  final String id;
  final String name;
  final bool isOwn;

  const IngredientSuggestion({
    required this.id,
    required this.name,
    required this.isOwn,
  });
}

class IngredientService {
  static const _log = AppLogger('IngredientService');
  final SupabaseClient _client;

  IngredientService(this._client);

  Future<List<IngredientSuggestion>> search(
    String query, {
    required String? userId,
    int limit = 10,
  }) async {
    try {
      final data = await _client
          .from('ingredients')
          .select('id, name, added_by_user_id')
          .ilike('name', '%$query%')
          .limit(limit);
      return data
          .map(
            (e) => IngredientSuggestion(
              id: e['id'] as String,
              name: e['name'] as String,
              isOwn: e['added_by_user_id'] == userId,
            ),
          )
          .toList();
    } catch (e, st) {
      _log.error('search failed', e, st);
      rethrow;
    }
  }

  Future<void> insertIfNew(String name, {required String? userId}) async {
    try {
      if (userId == null) return;
      final existing = await _client
          .from('ingredients')
          .select('id')
          .ilike('name', name)
          .limit(1);
      if (existing.isNotEmpty) return;
      await _client.from('ingredients').insert({
        'name': name,
        'added_via': 'user',
        'added_by_user_id': userId,
      });
    } catch (e, st) {
      _log.error('insertIfNew failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteUserIngredient(String id) async {
    try {
      await _client.from('ingredients').delete().eq('id', id);
    } catch (e, st) {
      _log.error('deleteUserIngredient failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSuggestions(String userId) async {
    try {
      return await _client
          .from('ingredient_suggestions')
          .select(
            'id, detected_ingredient_id, helptext, meal_id, seen_at, dismissed_at, '
            'ingredients!ingredient_suggestions_detected_ingredient_id_fkey(id, name, image_url)',
          )
          .eq('user_id', userId)
          .isFilter('dismissed_at', null);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReplacements(
    List<String> suggestionIds,
  ) async {
    if (suggestionIds.isEmpty) return [];
    try {
      return await _client
          .from('ingredient_suggestion_replacements')
          .select('suggestion_id, ingredients(id, name, image_url)')
          .inFilter('suggestion_id', suggestionIds);
    } catch (e, st) {
      _log.error('fetchReplacements failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMealDetails(
    List<String> mealIds,
  ) async {
    if (mealIds.isEmpty) return [];
    try {
      return await _client
          .from('meal_entries')
          .select('id, title, tracked_at, image_url')
          .inFilter('id', mealIds);
    } catch (e, st) {
      _log.error('fetchMealDetails failed', e, st);
      rethrow;
    }
  }

  Future<void> markAllSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('ingredient_suggestions')
          .update({'seen_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);
    } catch (e, st) {
      _log.error('markAllSeen failed', e, st);
      rethrow;
    }
  }

  Future<void> dismissSuggestions(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('ingredient_suggestions')
          .update({'dismissed_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);
    } catch (e, st) {
      _log.error('dismissSuggestions failed', e, st);
      rethrow;
    }
  }

  Future<int> fetchNewCount(String userId) async {
    try {
      final data = await _client
          .from('ingredient_suggestions')
          .select('id')
          .eq('user_id', userId)
          .isFilter('seen_at', null)
          .isFilter('dismissed_at', null);
      return data.length;
    } catch (e, st) {
      _log.error('fetchNewCount failed', e, st);
      rethrow;
    }
  }
}

final ingredientServiceProvider = Provider<IngredientService>(
  (ref) => IngredientService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 3: Convert `RecipeService`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class RecipeService {
  static const _log = AppLogger('RecipeService');
  final SupabaseClient _client;

  RecipeService(this._client);

  Future<List<Recipe>> fetchAll() async {
    try {
      final data = await _client.from('recipes').select().order('title');
      return data.map((e) => Recipe.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchAll failed', e, st);
      rethrow;
    }
  }

  Future<Set<String>> fetchFavoriteIds(String userId) async {
    try {
      final data = await _client
          .from('user_favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);
      return data.map((e) => e['recipe_id'] as String).toSet();
    } catch (e, st) {
      _log.error('fetchFavoriteIds failed', e, st);
      rethrow;
    }
  }

  Future<void> addFavorite(String userId, String recipeId) async {
    try {
      await _client.from('user_favorite_recipes').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } catch (e, st) {
      _log.error('addFavorite failed', e, st);
      rethrow;
    }
  }

  Future<void> removeFavorite(String userId, String recipeId) async {
    try {
      await _client
          .from('user_favorite_recipes')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
    } catch (e, st) {
      _log.error('removeFavorite failed', e, st);
      rethrow;
    }
  }
}

final recipeServiceProvider = Provider<RecipeService>(
  (ref) => RecipeService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 4: Convert `RecommendationService`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

class RecommendationService {
  static const _log = AppLogger('RecommendationService');
  final SupabaseClient _client;

  RecommendationService(this._client);

  Future<List<Recommendation>> fetchByUserId(String userId) async {
    try {
      final data = await _client
          .from('recommendations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map((e) => Recommendation.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchByUserId failed', e, st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchRecentContext(String userId) async {
    try {
      final sevenDaysAgo = last7Days().toIso8601String();

      final mealsFuture = _client
          .from('meal_entries')
          .select('title, ingredients')
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(20);

      final toiletFuture = _client
          .from('toilet_entries')
          .select('stool_type')
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(10);

      final results = await Future.wait([mealsFuture, toiletFuture]);

      return {'recentMeals': results[0], 'recentToilet': results[1]};
    } catch (e, st) {
      _log.error('fetchRecentContext failed', e, st);
      rethrow;
    }
  }
}

final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => RecommendationService(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze`

- [ ] **Step 6: Commit**

```bash
git add lib/services/drink_service.dart lib/services/ingredient_service.dart lib/services/recipe_service.dart lib/services/recommendation_service.dart
git commit -m "refactor: convert DrinkService, IngredientService, RecipeService, RecommendationService to instance-based"
```

---

## Task 5: Convert PushNotificationService

**Files:**
- Modify: `lib/services/push_notification_service.dart`

`PushNotificationService._saveToken` and `clearToken` call `SupabaseService.userId` and `ProfileService.update()` statically. These must be updated. `LocalNotificationService` and `NotificationService` (facade) have no Supabase dependencies and stay static.

- [ ] **Step 1: Update `PushNotificationService` to accept dependencies**

Since `PushNotificationService` methods are called from `app.dart` (which has `ref`), we change `_saveToken` and `clearToken` to accept userId and use a `ProfileService` that's passed in or accessible. The simplest approach: make `saveToken` and `clearToken` accept parameters.

```dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';

import '../utils/logger.dart';
import 'profile_service.dart';

class PushNotificationService {
  static const _log = AppLogger('PushNotificationService');
  static final _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenRefreshSub;

  static ProfileService? _profileService;
  static String? Function()? _getUserId;

  static Stream<RemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage;

  static Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Initialize FCM with injected dependencies for token persistence.
  static Future<void> initialize({
    required ProfileService profileService,
    required String? Function() getUserId,
  }) async {
    _profileService = profileService;
    _getUserId = getUserId;

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      _saveToken,
      onError: (e) => _log.error('token refresh error', e),
    );

    _log.debug('initialized');
  }

  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    _log.debug('permission: ${settings.authorizationStatus}');

    if (granted) {
      if (Platform.isIOS) {
        String? apnsToken;
        for (var i = 0; i < 10; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (apnsToken == null) {
          _log.debug(
            'APNs token not available — push notifications require a physical device on iOS',
          );
          return granted;
        }
      }

      try {
        final token = await _messaging.getToken();
        if (token != null) {
          await _saveToken(token);
        }
      } catch (e) {
        _log.error('failed to get FCM token', e);
      }
    }

    return granted;
  }

  static Future<RemoteMessage?> getInitialMessage() async {
    return _messaging.getInitialMessage();
  }

  static String? extractRoute(RemoteMessage message) {
    return message.data['route'] as String?;
  }

  static Future<void> _saveToken(String token) async {
    final userId = _getUserId?.call();
    if (userId == null || _profileService == null) return;

    try {
      await _profileService!.update(userId, {'fcm_token': token});
      _log.debug('saved FCM token');
    } catch (e) {
      _log.error('failed to save FCM token', e);
    }
  }

  static Future<void> clearToken() async {
    final userId = _getUserId?.call();
    if (userId == null || _profileService == null) return;

    try {
      await _profileService!.update(userId, {'fcm_token': null});
      _log.debug('cleared FCM token');
    } catch (e) {
      _log.error('failed to clear FCM token', e);
    }
  }
}
```

- [ ] **Step 2: Update `NotificationService` facade**

```dart
import '../utils/logger.dart';
import 'local_notification_service.dart';
import 'profile_service.dart';
import 'push_notification_service.dart';

class NotificationService {
  static const _log = AppLogger('NotificationService');

  static Future<void> initialize({
    required void Function(String? route) onNotificationTap,
    required ProfileService profileService,
    required String? Function() getUserId,
  }) async {
    await LocalNotificationService.initialize(
      onNotificationTap: onNotificationTap,
    );
    await PushNotificationService.initialize(
      profileService: profileService,
      getUserId: getUserId,
    );
    _log.debug('all notification services initialized');
  }
}
```

- [ ] **Step 3: Update `main.dart`**

The `NotificationService.initialize` call in `main.dart` must pass the `ProfileService` and userId getter. Since Riverpod container is created before this call, use it:

Find the `NotificationService.initialize(...)` call and update to:
```dart
await NotificationService.initialize(
  onNotificationTap: (route) { ... },
  profileService: container.read(profileServiceProvider),
  getUserId: () => container.read(currentUserIdProvider),
);
```

This requires `profileServiceProvider` and `currentUserIdProvider` to be importable — they will be after Tasks 1-3.

- [ ] **Step 4: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/services/push_notification_service.dart lib/services/notification_service.dart lib/main.dart
git commit -m "refactor: inject dependencies into PushNotificationService"
```

---

## Task 6: Delete SupabaseService + Update signed_url_helper + main.dart

**Files:**
- Delete: `lib/services/supabase_service.dart`
- Modify: `lib/utils/signed_url_helper.dart`

- [ ] **Step 1: Update `signed_url_helper.dart` to use Supabase singleton directly**

Remove the `StorageService` import. Use `Supabase.instance.client.storage` directly since this utility is called from plain `StatefulWidget`s (`meal_image.dart`, `meal_thumbnail.dart`, `suggestion_detail_modal.dart`) that don't have Riverpod `ref` access. The signature stays unchanged — callers need zero modifications.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

String extractStoragePath(String urlOrPath, String bucket) {
  if (!urlOrPath.startsWith('http')) return urlOrPath;

  final publicRegex = RegExp('/storage/v1/object/public/$bucket/(.+)');
  final publicMatch = publicRegex.firstMatch(urlOrPath);
  if (publicMatch != null) return publicMatch.group(1)!;

  final signedRegex = RegExp('/storage/v1/object/sign/$bucket/(.+?)\\?');
  final signedMatch = signedRegex.firstMatch(urlOrPath);
  if (signedMatch != null) return signedMatch.group(1)!;

  final otherRegex = RegExp('/storage/v1/object/[^/]+/$bucket/(.+)');
  final otherMatch = otherRegex.firstMatch(urlOrPath);
  if (otherMatch != null) return otherMatch.group(1)!;

  return urlOrPath;
}

Future<String?> resolveSignedMealImageUrl(String? urlOrPath) async {
  if (urlOrPath == null || urlOrPath.isEmpty) return null;

  if (urlOrPath.contains('token=')) return urlOrPath;

  try {
    final path = extractStoragePath(urlOrPath, 'meal-images');
    return await Supabase.instance.client.storage
        .from('meal-images')
        .createSignedUrl(path, 3600);
  } catch (e) {
    const AppLogger('SignedUrlHelper').error('failed to resolve URL', e);
    return urlOrPath;
  }
}
```

Run: `grep -rn 'resolveSignedMealImageUrl' lib/` to find all callers, then update each to pass the `storageService` parameter.

- [ ] **Step 3: Delete `lib/services/supabase_service.dart`**

```bash
git rm lib/services/supabase_service.dart
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze`
Expected: No references to `SupabaseService` remain anywhere. If they do, fix them by replacing with `ref.read(supabaseClientProvider)` or the appropriate core provider.

- [ ] **Step 5: Run existing tests**

Run: `flutter test`
Expected: All tests pass. The `signed_url_helper_test.dart` test may need updating since the function signature changed.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: delete SupabaseService, update signed_url_helper to use injected StorageService"
```

---

## Task 7: Create Repository Layer — AuthRepository + ProfileRepository

**Files:**
- Create: `lib/repositories/auth_repository.dart`
- Create: `lib/repositories/profile_repository.dart`

- [ ] **Step 1: Create `AuthRepository`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) =>
      _authService.signInWithEmail(email, password);

  Future<AuthResponse> signUpWithEmail(String email, String password) =>
      _authService.signUpWithEmail(email, password);

  Future<AuthResponse> signInWithGoogle() => _authService.signInWithGoogle();

  Future<AuthResponse> signInWithApple() => _authService.signInWithApple();

  Future<void> signOut() => _authService.signOut();

  Future<void> resetPassword(String email) =>
      _authService.resetPassword(email);

  Future<UserResponse> updatePassword(String newPassword) =>
      _authService.updatePassword(newPassword);

  Future<void> deleteAccount() => _authService.deleteAccount();

  String? detectAuthMethod() => _authService.detectAuthMethod();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authServiceProvider)),
);
```

- [ ] **Step 2: Create `ProfileRepository`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

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

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`

- [ ] **Step 4: Commit**

```bash
git add lib/repositories/auth_repository.dart lib/repositories/profile_repository.dart
git commit -m "refactor: add AuthRepository and ProfileRepository"
```

---

## Task 8: Create Repository Layer — EntryRepository + DrinkRepository

**Files:**
- Create: `lib/repositories/entry_repository.dart`
- Create: `lib/repositories/drink_repository.dart`

- [ ] **Step 1: Create `EntryRepository`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/entry_crud_service.dart';
import '../services/entry_query_service.dart';

class EntryRepository {
  final EntryCrudService _crudService;
  final EntryQueryService _queryService;

  EntryRepository(this._crudService, this._queryService);

  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) =>
      _queryService.fetchEntriesForDateRange(
        userId: userId,
        date: date,
        ordered: ordered,
      );

  Future<void> insertEntry(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) =>
      _crudService.insert(table, data, userId: userId);

  Future<void> updateEntry(
    String table,
    String id,
    Map<String, dynamic> data,
  ) =>
      _crudService.update(table, id, data);

  Future<void> deleteEntry(String table, String id) =>
      _crudService.delete(table, id);

  Future<void> deleteByType(String type, String id) =>
      _crudService.deleteByType(type, id);
}

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepository(
    ref.watch(entryCrudServiceProvider),
    ref.watch(entryQueryServiceProvider),
  ),
);
```

- [ ] **Step 2: Create `DrinkRepository`**

```dart
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
```

- [ ] **Step 3: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/repositories/entry_repository.dart lib/repositories/drink_repository.dart
git commit -m "refactor: add EntryRepository and DrinkRepository"
```

---

## Task 9: Create Repository Layer — Remaining Repositories + NotificationRepository

**Files:**
- Create: `lib/repositories/ingredient_repository.dart`
- Create: `lib/repositories/recipe_repository.dart`
- Create: `lib/repositories/recommendation_repository.dart`
- Create: `lib/repositories/meal_media_repository.dart`

- [ ] **Step 1: Create `IngredientRepository`**

```dart
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

  Future<List<IngredientSuggestion>> search(
    String query, {
    required String? userId,
    int limit = 10,
  }) =>
      _ingredientService.search(query, userId: userId, limit: limit);

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
}

final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => IngredientRepository(ref.watch(ingredientServiceProvider)),
);
```

- [ ] **Step 2: Create `RecipeRepository`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecipeRepository {
  final RecipeService _recipeService;
  static const _log = AppLogger('RecipeRepository');

  RecipeRepository(this._recipeService);

  Future<List<Recipe>> fetchAll() => retryAsync(
        _recipeService.fetchAll,
        log: _log,
        label: 'loadRecipes',
      );

  Future<Set<String>> fetchFavoriteIds(String userId) =>
      _recipeService.fetchFavoriteIds(userId);

  Future<void> addFavorite(String userId, String recipeId) =>
      _recipeService.addFavorite(userId, recipeId);

  Future<void> removeFavorite(String userId, String recipeId) =>
      _recipeService.removeFavorite(userId, recipeId);
}

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(recipeServiceProvider)),
);
```

- [ ] **Step 3: Create `RecommendationRepository`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../models/user_profile.dart';
import '../services/edge_function_service.dart';
import '../services/recommendation_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecommendationRepository {
  final RecommendationService _recommendationService;
  final EdgeFunctionService _edgeFunctionService;
  static const _log = AppLogger('RecommendationRepository');

  RecommendationRepository(
    this._recommendationService,
    this._edgeFunctionService,
  );

  Future<List<Recommendation>> fetchByUserId(String userId) => retryAsync(
        () => _recommendationService.fetchByUserId(userId),
      );

  Future<List<Recommendation>> refreshRecommendations({
    required String userId,
    required UserProfile? profile,
  }) async {
    final context =
        await _recommendationService.fetchRecentContext(userId);

    final body = <String, dynamic>{
      if (profile != null) ...{
        'symptoms': profile.symptoms,
        'intolerances': profile.intolerances,
        'diet': profile.diet,
      },
      ...context,
    };

    await _edgeFunctionService.invoke('diet-recommendations', body: body);
    return _recommendationService.fetchByUserId(userId);
  }
}

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(
    ref.watch(recommendationServiceProvider),
    ref.watch(edgeFunctionServiceProvider),
  ),
);
```

- [ ] **Step 4: Create `MealMediaRepository`**

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/edge_function_service.dart';
import '../services/storage_service.dart';
import '../utils/meal_helpers.dart';

class MealMediaRepository {
  final StorageService _storageService;
  final EdgeFunctionService _edgeFunctionService;

  MealMediaRepository(this._storageService, this._edgeFunctionService);

  Future<String> uploadMealImage({
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) =>
      _storageService.uploadImage(
        bucket: 'meal-images',
        userId: userId,
        fileBytes: fileBytes,
        extension: extension,
      );

  Future<Map<String, dynamic>> analyzeMealImage(
    Uint8List bytes,
    String filename,
  ) async {
    final base64Data = MealHelpers.buildImageBase64(bytes, filename);
    return _edgeFunctionService.invoke(
      'analyze-meal',
      body: {'imageBase64': base64Data},
    );
  }

  /// Fire-and-forget: trigger ingredient suggestion refresh
  void triggerSuggestionRefresh() {
    _edgeFunctionService.invoke('refresh-ingredient-suggestions').ignore();
  }
}

final mealMediaRepositoryProvider = Provider<MealMediaRepository>(
  (ref) => MealMediaRepository(
    ref.watch(storageServiceProvider),
    ref.watch(edgeFunctionServiceProvider),
  ),
);
```

- [ ] **Step 5: Create `NotificationRepository`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/local_notification_service.dart';
import '../utils/logger.dart';

class NotificationRepository {
  static const _log = AppLogger('NotificationRepository');

  Future<void> syncNotifications(UserProfile profile) async {
    final timezone = profile.timezone ?? 'Europe/Berlin';

    if (profile.remindersEnabled && profile.reminderTimes.isNotEmpty) {
      await LocalNotificationService.scheduleReminders(
        reminderTimes: profile.reminderTimes,
        timezone: timezone,
      );
    } else {
      await LocalNotificationService.cancelReminders();
    }

    if (profile.dailySummaryEnabled) {
      await LocalNotificationService.scheduleDailySummary(
        dailySummaryTime: profile.dailySummaryTime,
        timezone: timezone,
      );
    } else {
      await LocalNotificationService.cancelDailySummary();
    }

    _log.debug(
      'synced: reminders=${profile.remindersEnabled}, '
      'summary=${profile.dailySummaryEnabled}, '
      'push=${profile.pushEnabled}',
    );
  }

  Future<void> cancelAll() async {
    await LocalNotificationService.cancelAll();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);
```

- [ ] **Step 6: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/repositories/
git commit -m "refactor: add IngredientRepository, RecipeRepository, RecommendationRepository, MealMediaRepository, NotificationRepository"
```

---

## Task 10: Rewire Auth Providers + Create AuthNotifier

**Files:**
- Modify: `lib/providers/auth_provider.dart`

- [ ] **Step 1: Rewrite `auth_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import 'core_providers.dart';

/// Stream of auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Current user (nullable)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.user) ??
      Supabase.instance.client.auth.currentUser;
});

/// Whether user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session != null,
    loading: () => Supabase.instance.client.auth.currentUser != null,
    error: (_, __) => false,
  );
});

/// Centralized auth operations — screens call this instead of AuthService
class AuthNotifier extends Notifier<AsyncValue<void>> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signInWithEmail(email, password);
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signUpWithEmail(email, password);
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signInWithGoogle();
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signInWithApple();
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) => _repo.resetPassword(email);

  Future<UserResponse> updatePassword(String newPassword) =>
      _repo.updatePassword(newPassword);

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteAccount();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  String? detectAuthMethod() => _repo.detectAuthMethod();
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);
```

- [ ] **Step 2: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/providers/auth_provider.dart
git commit -m "refactor: rewire auth providers to use AuthRepository, add AuthNotifier"
```

---

## Task 11: Rewire ProfileNotifier + EntriesNotifier + DiaryProvider

**Files:**
- Modify: `lib/providers/profile_provider.dart`
- Modify: `lib/providers/entries_provider.dart`
- Modify: `lib/providers/diary_provider.dart`

- [ ] **Step 1: Rewrite `ProfileNotifier`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import 'core_providers.dart';

class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  AsyncValue<UserProfile?> build() => const AsyncValue.loading();

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await _repo.getProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createProfile(UserProfile profile) async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      await _repo.createProfile(userId, profile);
      await fetchProfile();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final previous = state;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Not authenticated');

    state = AsyncValue.data(profile.copyWith(userId: userId));

    try {
      await _repo.updateProfile(userId, profile);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>(
      ProfileNotifier.new,
    );

final hasProfileProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileProvider);
  return profileState.whenOrNull(data: (profile) => profile != null) ?? false;
});

final hasCompletedRegistrationProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileProvider);
  return profileState.whenOrNull(
        data: (profile) => profile?.isComplete ?? false,
      ) ??
      false;
});
```

- [ ] **Step 2: Rewrite `EntriesNotifier`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../repositories/entry_repository.dart';
import '../services/entry_crud_service.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

class EntriesState {
  final List<MealEntry> meals;
  final List<ToiletEntry> toiletEntries;
  final List<GutFeelingEntry> gutFeelings;
  final List<DrinkEntry> drinks;
  final bool isLoading;
  final Object? error;

  const EntriesState({
    this.meals = const [],
    this.toiletEntries = const [],
    this.gutFeelings = const [],
    this.drinks = const [],
    this.isLoading = false,
    this.error,
  });

  EntriesState copyWith({
    List<MealEntry>? meals,
    List<ToiletEntry>? toiletEntries,
    List<GutFeelingEntry>? gutFeelings,
    List<DrinkEntry>? drinks,
    bool? isLoading,
    Object? error,
  }) {
    return EntriesState(
      meals: meals ?? this.meals,
      toiletEntries: toiletEntries ?? this.toiletEntries,
      gutFeelings: gutFeelings ?? this.gutFeelings,
      drinks: drinks ?? this.drinks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EntriesNotifier extends Notifier<EntriesState> {
  static const _log = AppLogger('EntriesNotifier');
  EntryRepository get _repo => ref.read(entryRepositoryProvider);

  @override
  EntriesState build() => const EntriesState();

  Future<void> loadEntries(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('loadEntries: no user');
        return;
      }

      final result = await _repo.fetchForDate(
        userId: userId,
        date: date,
        ordered: true,
      );

      state = state.copyWith(
        meals: result.meals,
        toiletEntries: result.toiletEntries,
        gutFeelings: result.gutFeelings,
        drinks: result.drinks,
        isLoading: false,
      );
    } catch (e, st) {
      _log.error('loadEntries failed for $date', e, st);
      state = state.copyWith(isLoading: false, error: e);
      rethrow;
    }
  }

  String get _userId => ref.read(currentUserIdProvider)!;

  Future<void> addMeal(MealEntry meal) =>
      _repo.insertEntry(entryTableFor['meal']!, meal.toJson(), userId: _userId);

  Future<void> updateMeal(MealEntry meal) =>
      _repo.updateEntry(entryTableFor['meal']!, meal.id, meal.toJson());

  Future<void> deleteMeal(String id) =>
      _repo.deleteEntry(entryTableFor['meal']!, id);

  Future<void> addToiletEntry(ToiletEntry entry) => _repo.insertEntry(
      entryTableFor['toilet']!, entry.toJson(), userId: _userId);

  Future<void> updateToiletEntry(ToiletEntry entry) =>
      _repo.updateEntry(entryTableFor['toilet']!, entry.id, entry.toJson());

  Future<void> deleteToiletEntry(String id) =>
      _repo.deleteEntry(entryTableFor['toilet']!, id);

  Future<void> addGutFeeling(GutFeelingEntry entry) => _repo.insertEntry(
      entryTableFor['gutFeeling']!, entry.toJson(), userId: _userId);

  Future<void> updateGutFeeling(GutFeelingEntry entry) => _repo.updateEntry(
      entryTableFor['gutFeeling']!, entry.id, entry.toJson());

  Future<void> deleteGutFeeling(String id) =>
      _repo.deleteEntry(entryTableFor['gutFeeling']!, id);

  Future<void> addDrinkEntry(DrinkEntry entry) => _repo.insertEntry(
      entryTableFor['drink']!, entry.toInsertJson(), userId: _userId);

  Future<void> updateDrinkEntry(DrinkEntry entry) =>
      _repo.updateEntry(entryTableFor['drink']!, entry.id, entry.toInsertJson());

  Future<void> deleteDrinkEntry(String id) =>
      _repo.deleteEntry(entryTableFor['drink']!, id);

  Future<void> deleteByType(String type, String id) =>
      _repo.deleteByType(type, id);

  Future<void> updateGutFeelingById(
    String id, {
    required int bloating,
    required int gas,
    required int cramps,
    required int fullness,
    int? stress,
    int? happiness,
    int? energy,
    int? focus,
    int? bodyFeel,
  }) => _repo.updateEntry(entryTableFor['gutFeeling']!, id, {
    'bloating': bloating,
    'gas': gas,
    'cramps': cramps,
    'fullness': fullness,
    'stress': stress,
    'happiness': happiness,
    'energy': energy,
    'focus': focus,
    'body_feel': bodyFeel,
  });

  Future<void> updateToiletById(String id, {required int stoolType}) =>
      _repo.updateEntry(entryTableFor['toilet']!, id, {
        'stool_type': stoolType,
      });

  Future<void> updateDrinkById(
    String id, {
    required int amountMl,
    String? notes,
  }) => _repo.updateEntry(entryTableFor['drink']!, id, {
    'amount_ml': amountMl,
    'notes': notes,
  });

  void reset() {
    state = const EntriesState();
  }
}

final entriesProvider = NotifierProvider<EntriesNotifier, EntriesState>(
  EntriesNotifier.new,
);
```

- [ ] **Step 3: Rewrite `diary_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary_entry.dart';
import '../repositories/entry_repository.dart';
import '../utils/diary_helpers.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

export '../models/diary_entry.dart';

const _log = AppLogger('DiaryProvider');

class _DiaryDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime date) => state = date;
}

final diaryDateProvider = NotifierProvider<_DiaryDateNotifier, DateTime>(
  _DiaryDateNotifier.new,
);

final diaryEntriesProvider =
    FutureProvider.family<List<DiaryEntry>, DateTime>((ref, date) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return [];

  try {
    final result = await ref.read(entryRepositoryProvider).fetchForDate(
          userId: userId,
          date: date,
        );

    return DiaryHelpers.buildEntries(result);
  } catch (e, st) {
    _log.error('failed to load diary entries for $date', e, st);
    rethrow;
  }
});
```

- [ ] **Step 4: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/providers/profile_provider.dart lib/providers/entries_provider.dart lib/providers/diary_provider.dart
git commit -m "refactor: rewire ProfileNotifier, EntriesNotifier, DiaryProvider to use repositories"
```

---

## Task 12: Rewire Tracker Providers

**Files:**
- Modify: `lib/providers/meal_tracker_provider.dart`
- Modify: `lib/providers/drink_tracker_provider.dart`

- [ ] **Step 1: Rewrite `MealTrackerNotifier`**

Replace service imports with repository imports. Key changes:
- `EdgeFunctionService.invoke` → `_mealMedia.analyzeMealImage` / `_mealMedia.triggerSuggestionRefresh`
- `StorageService.uploadImage` → `_mealMedia.uploadMealImage`
- `IngredientService.search` → `_ingredientRepo.search`
- `IngredientService.insertIfNew` → `_ingredientRepo.insertIfNew`
- `SupabaseService.userId` → `ref.read(currentUserIdProvider)`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/meal_media_repository.dart';
import '../services/ingredient_service.dart';
import '../utils/logger.dart';
import 'core_providers.dart';
import 'entries_provider.dart';

class MealTrackerState {
  final String title;
  final List<String> ingredients;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool isAnalyzing;
  final bool isSaving;
  final bool showSuccess;
  final List<IngredientSuggestion> ingredientSuggestions;
  final Object? ingredientSearchError;
  final String? notes;
  final DateTime trackedAt;

  MealTrackerState({
    this.title = 'Neue Mahlzeit',
    this.ingredients = const [],
    this.imageBytes,
    this.imageFileName,
    this.isAnalyzing = false,
    this.isSaving = false,
    this.showSuccess = false,
    this.ingredientSuggestions = const [],
    this.ingredientSearchError,
    this.notes,
    DateTime? trackedAt,
  }) : trackedAt = trackedAt ?? DateTime.now();

  MealTrackerState copyWith({
    String? title,
    List<String>? ingredients,
    Uint8List? imageBytes,
    String? imageFileName,
    bool? isAnalyzing,
    bool? isSaving,
    bool? showSuccess,
    List<IngredientSuggestion>? ingredientSuggestions,
    Object? ingredientSearchError,
    String? notes,
    DateTime? trackedAt,
  }) {
    return MealTrackerState(
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      imageBytes: imageBytes ?? this.imageBytes,
      imageFileName: imageFileName ?? this.imageFileName,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isSaving: isSaving ?? this.isSaving,
      showSuccess: showSuccess ?? this.showSuccess,
      ingredientSuggestions:
          ingredientSuggestions ?? this.ingredientSuggestions,
      ingredientSearchError: ingredientSearchError,
      notes: notes ?? this.notes,
      trackedAt: trackedAt ?? this.trackedAt,
    );
  }
}

class MealTrackerNotifier extends Notifier<MealTrackerState> {
  static const _log = AppLogger('MealTracker');

  MealMediaRepository get _mealMedia =>
      ref.read(mealMediaRepositoryProvider);
  IngredientRepository get _ingredientRepo =>
      ref.read(ingredientRepositoryProvider);

  @override
  MealTrackerState build() => MealTrackerState(trackedAt: DateTime.now());

  void setTitle(String title) => state = state.copyWith(title: title);
  void setNotes(String? notes) => state = state.copyWith(notes: notes);
  void setTrackedAt(DateTime dt) => state = state.copyWith(trackedAt: dt);

  void setImage(Uint8List bytes, String fileName) {
    state = state.copyWith(imageBytes: bytes, imageFileName: fileName);
  }

  void clearImage() {
    state = MealTrackerState(trackedAt: state.trackedAt, notes: state.notes);
  }

  Future<void> analyzeImage(Uint8List bytes, String filename) async {
    state = state.copyWith(isAnalyzing: true);
    try {
      final result = await _mealMedia.analyzeMealImage(bytes, filename);

      state = state.copyWith(
        title: result['title'] as String? ?? state.title,
        ingredients: result['ingredients'] != null
            ? List<String>.from(result['ingredients'] as List? ?? [])
            : state.ingredients,
        isAnalyzing: false,
      );
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      rethrow;
    }
  }

  Future<void> searchIngredients(String query) async {
    if (query.length < 3) {
      state = state.copyWith(ingredientSuggestions: []);
      return;
    }
    state = state.copyWith(ingredientSearchError: null);
    try {
      final userId = ref.read(currentUserIdProvider);
      final results = await _ingredientRepo.search(query, userId: userId);
      state = state.copyWith(ingredientSuggestions: results);
    } catch (e, st) {
      _log.error('ingredient search failed', e, st);
      state = state.copyWith(ingredientSearchError: e);
    }
  }

  void addIngredient(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.ingredients.contains(trimmed)) return;
    state = state.copyWith(
      ingredients: [...state.ingredients, trimmed],
      ingredientSuggestions: [],
    );
    final userId = ref.read(currentUserIdProvider);
    _ingredientRepo.insertIfNew(trimmed, userId: userId).ignore();
  }

  void removeIngredient(String name) {
    state = state.copyWith(
      ingredients: state.ingredients.where((i) => i != name).toList(),
    );
  }

  Future<void> deleteUserIngredient(String id) async {
    await _ingredientRepo.deleteUserIngredient(id);
    state = state.copyWith(
      ingredientSuggestions:
          state.ingredientSuggestions.where((s) => s.id != id).toList(),
    );
  }

  Future<void> save() async {
    state = state.copyWith(isSaving: true);
    try {
      String? imageUrl;
      if (state.imageBytes != null && state.imageFileName != null) {
        final ext = state.imageFileName!.split('.').last;
        imageUrl = await _mealMedia.uploadMealImage(
          userId: ref.read(currentUserIdProvider)!,
          fileBytes: state.imageBytes!,
          extension: ext,
        );
      }

      final meal = MealEntry(
        id: const Uuid().v4(),
        trackedAt: state.trackedAt,
        title: state.title,
        ingredients: state.ingredients,
        imageUrl: imageUrl,
        notes: state.notes,
      );

      await ref.read(entriesProvider.notifier).addMeal(meal);

      _mealMedia.triggerSuggestionRefresh();

      state = state.copyWith(isSaving: false, showSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final mealTrackerProvider =
    NotifierProvider<MealTrackerNotifier, MealTrackerState>(
      MealTrackerNotifier.new,
    );
```

- [ ] **Step 2: Rewrite `DrinkTrackerNotifier`**

Replace `DrinkService.*` with `_drinkRepo.*`, `SupabaseService.userId` with `ref.read(currentUserIdProvider)`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/drink.dart';
import '../models/drink_entry.dart';
import '../repositories/drink_repository.dart';
import '../utils/drink_helpers.dart';
import '../utils/logger.dart';
import 'core_providers.dart';
import 'entries_provider.dart';

class DrinkTrackerState {
  final List<Drink> allDrinks;
  final List<Drink> quickDrinks;
  final List<Drink> suggestions;
  final Drink? selectedDrink;
  final int? selectedAmount;
  final String customAmount;
  final bool isLoading;
  final bool isSaving;
  final bool showSuccess;
  final int todayTotal;
  final DateTime trackedAt;

  DrinkTrackerState({
    this.allDrinks = const [],
    this.quickDrinks = const [],
    this.suggestions = const [],
    this.selectedDrink,
    this.selectedAmount,
    this.customAmount = '',
    this.isLoading = true,
    this.isSaving = false,
    this.showSuccess = false,
    this.todayTotal = 0,
    DateTime? trackedAt,
  }) : trackedAt = trackedAt ?? DateTime.now();

  static const _unset = Object();

  DrinkTrackerState copyWith({
    List<Drink>? allDrinks,
    List<Drink>? quickDrinks,
    List<Drink>? suggestions,
    Object? selectedDrink = _unset,
    Object? selectedAmount = _unset,
    String? customAmount,
    bool? isLoading,
    bool? isSaving,
    bool? showSuccess,
    int? todayTotal,
    DateTime? trackedAt,
  }) {
    return DrinkTrackerState(
      allDrinks: allDrinks ?? this.allDrinks,
      quickDrinks: quickDrinks ?? this.quickDrinks,
      suggestions: suggestions ?? this.suggestions,
      selectedDrink: identical(selectedDrink, _unset)
          ? this.selectedDrink
          : selectedDrink as Drink?,
      selectedAmount: identical(selectedAmount, _unset)
          ? this.selectedAmount
          : selectedAmount as int?,
      customAmount: customAmount ?? this.customAmount,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      showSuccess: showSuccess ?? this.showSuccess,
      todayTotal: todayTotal ?? this.todayTotal,
      trackedAt: trackedAt ?? this.trackedAt,
    );
  }
}

class DrinkTrackerNotifier extends Notifier<DrinkTrackerState> {
  static const _log = AppLogger('DrinkTracker');
  DrinkRepository get _drinkRepo => ref.read(drinkRepositoryProvider);

  @override
  DrinkTrackerState build() => DrinkTrackerState(trackedAt: DateTime.now());

  Future<void> loadDrinks() async {
    try {
      final drinks = await _drinkRepo.fetchAll();

      final userId = ref.read(currentUserIdProvider);
      List<Drink> quick;
      if (userId != null) {
        final recentIds = await _drinkRepo.fetchRecentDrinkIds(userId);
        quick = DrinkHelpers.buildQuickDrinks(drinks, recentIds);
      } else {
        quick = drinks.take(11).toList();
      }

      state = state.copyWith(
        allDrinks: drinks,
        quickDrinks: quick,
        isLoading: false,
      );
    } catch (e, st) {
      _log.error('failed to load drinks', e, st);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadTodayTotal() async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('loadTodayTotal: no user');
        return;
      }
      final total = await _drinkRepo.fetchTodayTotal(userId);
      state = state.copyWith(todayTotal: total);
    } catch (e, st) {
      _log.error('failed to load today total', e, st);
    }
  }

  void searchDrinks(String query) {
    final results = DrinkHelpers.search(query, state.allDrinks);
    state = state.copyWith(suggestions: results);
  }

  void toggleDrink(Drink drink) {
    if (state.selectedDrink?.id == drink.id) {
      state = state.copyWith(
        selectedDrink: null,
        selectedAmount: null,
        customAmount: '',
        suggestions: [],
      );
    } else {
      state = state.copyWith(selectedDrink: drink, suggestions: []);
    }
  }

  void clearSelection() {
    state = state.copyWith(
      selectedDrink: null,
      selectedAmount: null,
      customAmount: '',
    );
  }

  void selectAmount(int amount) {
    state = state.copyWith(selectedAmount: amount, customAmount: '');
  }

  void setCustomAmount(String value) {
    state = state.copyWith(
      customAmount: value,
      selectedAmount: DrinkHelpers.parseAmount(value),
    );
  }

  void setTrackedAt(DateTime dt) {
    state = state.copyWith(trackedAt: dt);
  }

  Future<void> createDrink(String name) async {
    final userId = ref.read(currentUserIdProvider)!;
    final newDrink = await _drinkRepo.insertDrink(name, userId: userId);
    final updatedAll = [...state.allDrinks, newDrink]
      ..sort((a, b) => a.name.compareTo(b.name));
    state = state.copyWith(
      allDrinks: updatedAll,
      quickDrinks: [newDrink, ...state.quickDrinks],
      selectedDrink: newDrink,
      suggestions: [],
    );
  }

  Future<void> deleteDrink(Drink drink) async {
    try {
      await _drinkRepo.deleteDrink(drink.id);
      final updatedAll =
          state.allDrinks.where((d) => d.id != drink.id).toList();
      final updatedQuick =
          state.quickDrinks.where((d) => d.id != drink.id).toList();
      final updatedSuggestions =
          state.suggestions.where((d) => d.id != drink.id).toList();
      state = state.copyWith(
        allDrinks: updatedAll,
        quickDrinks: updatedQuick,
        suggestions: updatedSuggestions,
      );
      if (state.selectedDrink?.id == drink.id) {
        clearSelection();
      }
    } catch (e, st) {
      _log.error('failed to delete drink', e, st);
      rethrow;
    }
  }

  Future<void> save() async {
    if (state.selectedDrink == null || state.selectedAmount == null) return;
    state = state.copyWith(isSaving: true);
    try {
      final entry = DrinkEntry(
        id: const Uuid().v4(),
        trackedAt: state.trackedAt,
        drinkId: state.selectedDrink!.id,
        drinkName: state.selectedDrink!.name,
        amountMl: state.selectedAmount!,
      );
      await ref.read(entriesProvider.notifier).addDrinkEntry(entry);
      await loadTodayTotal();
      state = state.copyWith(isSaving: false, showSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final drinkTrackerProvider =
    NotifierProvider<DrinkTrackerNotifier, DrinkTrackerState>(
      DrinkTrackerNotifier.new,
    );
```

- [ ] **Step 3: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/providers/meal_tracker_provider.dart lib/providers/drink_tracker_provider.dart
git commit -m "refactor: rewire MealTrackerNotifier and DrinkTrackerNotifier to use repositories"
```

---

## Task 13: Rewire Remaining Providers + NotificationProvider

**Files:**
- Modify: `lib/providers/ingredient_suggestion_provider.dart`
- Modify: `lib/providers/recipes_provider.dart`
- Modify: `lib/providers/recommendation_provider.dart`

- [ ] **Step 1: Rewrite `IngredientSuggestionNotifier`**

Replace `IngredientService.*` with `_repo.*`, `SupabaseService.userId` with `ref.read(currentUserIdProvider)`. Absorb grouping logic into repository (already done in Task 8).

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../repositories/ingredient_repository.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');
  IngredientRepository get _repo => ref.read(ingredientRepositoryProvider);

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() =>
      const AsyncValue.loading();

  Future<void> fetchSuggestions() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final groups = await _repo.fetchSuggestionGroups(userId);
      state = AsyncValue.data(groups);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllNewAsSeen() async {
    final groups = state.whenOrNull(data: (g) => g);
    if (groups == null) return;

    final unseenIds = groups
        .where((g) => g.isNew)
        .expand((g) => g.suggestionIds)
        .toList();
    if (unseenIds.isEmpty) return;

    try {
      await _repo.markAllSeen(unseenIds);
      state = AsyncValue.data(
        groups.map((g) => g.isNew ? g.copyWith(isNew: false) : g).toList(),
      );
    } catch (e, st) {
      _log.error('markAllNewAsSeen failed', e, st);
    }
  }

  Future<void> dismissSuggestion(List<String> ids) async {
    try {
      await _repo.dismissSuggestions(ids);
      final idsSet = ids.toSet();
      state = state.whenData(
        (groups) =>
            groups.where((g) => !g.suggestionIds.any(idsSet.contains)).toList(),
      );
    } catch (e, st) {
      _log.error('dismissSuggestion failed', e, st);
    }
  }

  int get newCount {
    return state.whenOrNull(
          data: (groups) => groups.where((g) => g.isNew).length,
        ) ??
        0;
  }
}

final ingredientSuggestionProvider =
    NotifierProvider<
      IngredientSuggestionNotifier,
      AsyncValue<List<IngredientSuggestionGroup>>
    >(IngredientSuggestionNotifier.new);
```

- [ ] **Step 2: Rewrite `RecipesNotifier`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../repositories/recipe_repository.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

class RecipesState {
  final List<Recipe> allRecipes;
  final List<Recipe> filtered;
  final Set<String> favorites;
  final bool isLoading;
  final String search;
  final Set<String> filters;
  final Object? error;

  const RecipesState({
    this.allRecipes = const [],
    this.filtered = const [],
    this.favorites = const {},
    this.isLoading = true,
    this.search = '',
    this.filters = const {},
    this.error,
  });

  RecipesState copyWith({
    List<Recipe>? allRecipes,
    List<Recipe>? filtered,
    Set<String>? favorites,
    bool? isLoading,
    String? search,
    Set<String>? filters,
    Object? error,
  }) {
    return RecipesState(
      allRecipes: allRecipes ?? this.allRecipes,
      filtered: filtered ?? this.filtered,
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      error: error,
    );
  }
}

class RecipesNotifier extends Notifier<RecipesState> {
  static const _log = AppLogger('RecipesProvider');
  RecipeRepository get _repo => ref.read(recipeRepositoryProvider);

  @override
  RecipesState build() {
    _loadAll();
    return const RecipesState();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadRecipes(), _loadFavorites()]);
  }

  Future<void> _loadRecipes() async {
    state = state.copyWith(error: null);
    try {
      final recipes = await _repo.fetchAll();
      state = state.copyWith(
        allRecipes: recipes,
        filtered: recipes,
        isLoading: false,
      );
      _applyFilters();
    } catch (e) {
      _log.error('failed to load recipes', e);
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> _loadFavorites() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final favorites = await _repo.fetchFavoriteIds(userId);
      state = state.copyWith(favorites: favorites);
    } catch (e) {
      _log.error('failed to load favorites', e);
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final newFavorites = Set<String>.from(state.favorites);
    try {
      if (newFavorites.contains(recipeId)) {
        await _repo.removeFavorite(userId, recipeId);
        newFavorites.remove(recipeId);
      } else {
        await _repo.addFavorite(userId, recipeId);
        newFavorites.add(recipeId);
      }
      state = state.copyWith(favorites: newFavorites);
    } catch (e) {
      _log.error('failed to toggle favorite', e);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(search: query);
    _applyFilters();
  }

  void toggleFilter(String tag) {
    final newFilters = Set<String>.from(state.filters);
    if (newFilters.contains(tag)) {
      newFilters.remove(tag);
    } else {
      newFilters.add(tag);
    }
    state = state.copyWith(filters: newFilters);
    _applyFilters();
  }

  void _applyFilters() {
    final filtered = state.allRecipes.where((r) {
      final title = r.title.toLowerCase();
      final tags = r.tags;
      final matchesSearch =
          state.search.isEmpty || title.contains(state.search.toLowerCase());
      final matchesFilters =
          state.filters.isEmpty || state.filters.every((f) => tags.contains(f));
      return matchesSearch && matchesFilters;
    }).toList();
    state = state.copyWith(filtered: filtered);
  }
}

final recipesProvider = NotifierProvider<RecipesNotifier, RecipesState>(
  RecipesNotifier.new,
);
```

- [ ] **Step 3: Rewrite `RecommendationNotifier`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../repositories/recommendation_repository.dart';
import '../utils/logger.dart';
import 'core_providers.dart';
import 'profile_provider.dart';

class RecommendationNotifier
    extends Notifier<AsyncValue<List<Recommendation>>> {
  static const _log = AppLogger('RecommendationNotifier');
  RecommendationRepository get _repo =>
      ref.read(recommendationRepositoryProvider);

  @override
  AsyncValue<List<Recommendation>> build() => const AsyncValue.loading();

  Future<void> fetchRecommendations() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('fetchRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      final recommendations = await _repo.fetchByUserId(userId);
      state = AsyncValue.data(recommendations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshRecommendations() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('refreshRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
      final recommendations = await _repo.refreshRecommendations(
        userId: userId,
        profile: profile,
      );
      state = AsyncValue.data(recommendations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, AsyncValue<List<Recommendation>>>(
      RecommendationNotifier.new,
    );
```

- [ ] **Step 4: Rewrite `notificationSyncProvider`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notification_repository.dart';
import '../utils/logger.dart';
import 'profile_provider.dart';

const _log = AppLogger('NotificationProvider');

final notificationSyncProvider = Provider<void>((ref) {
  final profileState = ref.watch(profileProvider);

  profileState.whenData((profile) {
    if (profile == null) return;
    ref.read(notificationRepositoryProvider).syncNotifications(profile).catchError((e, st) {
      _log.error('failed to sync notifications', e, st);
    });
  });
});
```

- [ ] **Step 5: Verify and commit**

Run: `flutter analyze`

```bash
git add lib/providers/ingredient_suggestion_provider.dart lib/providers/recipes_provider.dart lib/providers/recommendation_provider.dart lib/providers/notification_provider.dart
git commit -m "refactor: rewire IngredientSuggestionNotifier, RecipesNotifier, RecommendationNotifier, NotificationProvider to use repositories"
```

---

## Task 14: Update app.dart + Screens to Use Providers Instead of Services

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/screens/auth/auth_screen.dart`
- Modify: `lib/screens/auth/reset_password_screen.dart`
- Modify: `lib/screens/registration/registration_wizard_screen.dart`
- Modify: `lib/screens/settings/widgets/settings_account_screen.dart`
- Modify: `lib/screens/settings/widgets/password_change_section.dart`
- Modify: `lib/screens/settings/widgets/delete_account_dialog.dart`
- Modify: `lib/screens/settings/widgets/settings_notifications_screen.dart`
- Modify: `lib/screens/trackers/drink/widgets/drink_search.dart`

- [ ] **Step 1: Update `app.dart`**

Replace `SupabaseService.isAuthenticated`/`.userId` with core providers:

In imports: replace `import 'services/supabase_service.dart'` with `import 'providers/core_providers.dart'`. Remove `import 'services/local_notification_service.dart'` and `import 'services/push_notification_service.dart'` since `PushNotificationService` static methods like `extractRoute`, `onForegroundMessage`, `onMessageOpenedApp`, `getInitialMessage` remain static and don't need Supabase — only the `clearToken` call needs updating.

In `initState`: replace `SupabaseService.isAuthenticated` with `ref.read(isAuthenticatedProvider)` and `SupabaseService.userId` with `ref.read(currentUserIdProvider)`.

In `build` (auth listener): replace `PushNotificationService.clearToken()` (which now uses injected deps internally, so the call stays the same but no longer imports `SupabaseService`).

- [ ] **Step 2: Update auth screens**

For each screen (`auth_screen.dart`, `reset_password_screen.dart`, `registration_wizard_screen.dart`):
- Replace `import '../../services/auth_service.dart'` with `import '../../providers/auth_provider.dart'`
- Replace `AuthService.signInWithEmail(...)` with `ref.read(authNotifierProvider.notifier).signInWithEmail(...)`
- Replace `AuthService.signUpWithEmail(...)` with `ref.read(authNotifierProvider.notifier).signUpWithEmail(...)`
- Replace `AuthService.signInWithGoogle()` with `ref.read(authNotifierProvider.notifier).signInWithGoogle()`
- Replace `AuthService.signInWithApple()` with `ref.read(authNotifierProvider.notifier).signInWithApple()`
- Replace `AuthService.resetPassword(...)` with `ref.read(authNotifierProvider.notifier).resetPassword(...)`
- Replace `AuthService.updatePassword(...)` with `ref.read(authNotifierProvider.notifier).updatePassword(...)`
- Replace `AuthService.isAppleSignInAvailable` with `AuthService.isAppleSignInAvailable` (stays static — no instance needed)
- If widget is `StatefulWidget`, convert to `ConsumerStatefulWidget` to get `ref`

- [ ] **Step 3: Update settings screens**

For `settings_account_screen.dart`:
- Replace `AuthService.signOut()` with `ref.read(authNotifierProvider.notifier).signOut()`
- Replace `AuthService.detectAuthMethod()` with `ref.read(authNotifierProvider.notifier).detectAuthMethod()`
- Replace `SupabaseService.currentUser` with `ref.watch(currentUserProvider)`
- Remove `supabase_service.dart` and `auth_service.dart` imports

For `password_change_section.dart`:
- Replace all `AuthService.*` calls with `ref.read(authNotifierProvider.notifier).*`
- Replace `SupabaseService.currentUser?.email` with `ref.read(currentUserProvider)?.email`
- Remove service imports

For `delete_account_dialog.dart`:
- Replace `AuthService.deleteAccount()` with `ref.read(authNotifierProvider.notifier).deleteAccount()`
- Remove `auth_service.dart` import

For `settings_notifications_screen.dart`:
- Replace `SupabaseService.userId` with `ref.read(currentUserIdProvider)`
- Replace `EdgeFunctionService` usage with `ref.read(edgeFunctionServiceProvider)` (for edge function calls)
- Remove `supabase_service.dart` and `edge_function_service.dart` imports, add `core_providers.dart` and `edge_function_service.dart` provider import

- [ ] **Step 4: Update `drink_search.dart`**

Replace `SupabaseService.userId` with `ref.read(currentUserIdProvider)`. If the widget isn't already a `ConsumerWidget`, it may need to receive the userId from its parent or be converted.

- [ ] **Step 5: Verify and commit**

Run: `flutter analyze`
Expected: Zero issues. No file in `lib/screens/` or `lib/widgets/` imports any service except `HapticService` and `IngredientService` (for the `IngredientSuggestion` type).

Run: `flutter test`
Expected: All existing tests pass.

```bash
git add -A
git commit -m "refactor: update app.dart and screens to use providers instead of direct service calls"
```

---

## Task 15: Final Verification + Cleanup

**Files:**
- All files

- [ ] **Step 1: Verify no service imports remain in providers (except via repositories)**

Run: `grep -rn "import.*services/" lib/providers/` — the only allowed imports are:
- `core_providers.dart` importing nothing from services (it uses `supabase_flutter` directly)
- `entries_provider.dart` importing `entry_crud_service.dart` for the `entryTableFor` constant
- `meal_tracker_provider.dart` importing `ingredient_service.dart` for the `IngredientSuggestion` type

All other service imports in providers should be gone.

- [ ] **Step 2: Verify no `SupabaseService` references remain anywhere**

Run: `grep -rn "SupabaseService" lib/`
Expected: Zero results.

- [ ] **Step 3: Run full analysis and tests**

Run: `flutter analyze && flutter test`
Expected: Zero issues, all tests pass.

- [ ] **Step 4: Run `dart format`**

Run: `dart format lib/`

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "refactor: final cleanup — verify no stale service imports remain"
```
