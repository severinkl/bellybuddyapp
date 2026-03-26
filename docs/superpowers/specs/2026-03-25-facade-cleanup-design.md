# Facade Cleanup: Eliminate Remaining Layer Violations

## Overview

Close the last 3 layer boundary violations in the codebase so that no screen, widget, or provider bypasses the repository layer to access services or singletons directly.

### Goals

- `app.dart` imports zero services — all notification operations go through `NotificationRepository`
- `settings_notifications_screen.dart` calls `NotificationRepository` for permission, not `PushNotificationService`
- `signed_url_helper.dart` is eliminated — URL resolution moves to `MealMediaRepository`
- `auth_provider.dart` has zero `Supabase.instance` references — fallbacks route through `AuthRepository`

### Non-Goals

- No changes to `HapticService` (accepted as stateless utility)
- No changes to `main.dart` initialization (accepted as bootstrap layer)
- No changes to `Platform.isIOS` checks (accepted as standard Flutter pattern)
- No changes to type-only service imports (`IngredientSuggestion`, `entryTableFor`)

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Notification facade | Expand `NotificationRepository` | Already owns local notification scheduling; adding push concerns keeps one facade |
| Signed URL resolution | Move to `MealMediaRepository` | URL resolution is a storage/data concern, repo already wraps `StorageService` |
| Auth fallbacks | Route through `AuthRepository` | Clean abstraction; same behavior, just through the proper layer |
| HapticService | Leave as-is | 24 files, zero behavioral benefit from DI |

## Change 1: NotificationRepository Facade

### New Methods

Add to `NotificationRepository`:

```dart
// Push message streams
Stream<RemoteMessage> get onForegroundMessage;
Stream<RemoteMessage> get onMessageOpenedApp;
Future<RemoteMessage?> getInitialMessage();
String? extractRoute(RemoteMessage message);

// Push permission + token
Future<bool> requestPermission();
Future<void> clearToken();

// cancelAll already exists
```

All methods delegate to `PushNotificationService` static methods (platform plugin — stays static internally).

### Files Modified

| File | Change |
|---|---|
| `lib/repositories/notification_repository.dart` | Add 6 new methods wrapping `PushNotificationService` statics |
| `lib/app.dart` | Replace all `PushNotificationService.*` and `LocalNotificationService.*` calls with `ref.read(notificationRepositoryProvider).*`. Remove both service imports. Keep `firebase_messaging` import for `RemoteMessage` type (used in `StreamSubscription<RemoteMessage>` field declarations). |
| `lib/screens/settings/widgets/settings_notifications_screen.dart` | Replace `PushNotificationService.requestPermission()` with `ref.read(notificationRepositoryProvider).requestPermission()`. Remove service import. |
| `test/helpers/fakes.dart` | Update `FakeNotificationRepository` with new methods: stream getters return `Stream.empty()`, `getInitialMessage` returns `null`, `extractRoute` returns `null`, `requestPermission` returns `true`, `clearToken` completes |
| `test/repositories/notification_repository_test.dart` | Add tests for new methods |

## Change 2: Signed URL Resolution → MealMediaRepository

### What Moves

`resolveSignedMealImageUrl()` from `lib/utils/signed_url_helper.dart` moves to `MealMediaRepository` as `resolveSignedUrl(String? urlOrPath)`. The `extractStoragePath()` pure function stays in `signed_url_helper.dart` (it's a pure string transformation with no external deps).

### Widget Conversions

The 3 widgets that call `resolveSignedMealImageUrl` become `ConsumerStatefulWidget`s to access `ref`:

| Widget | File |
|---|---|
| `MealImage` | `lib/screens/diary/widgets/meal_image.dart` |
| `MealThumbnail` | `lib/screens/diary/widgets/meal_thumbnail.dart` |
| `_MealImage` (inside suggestion detail) | `lib/screens/ingredient_suggestions/widgets/suggestion_detail_modal.dart` |

Each replaces:
```dart
final url = await resolveSignedMealImageUrl(widget.imageUrl);
```
with:
```dart
final url = await ref.read(mealMediaRepositoryProvider).resolveSignedUrl(widget.imageUrl);
```

### Files Modified

| File | Change |
|---|---|
| `lib/repositories/meal_media_repository.dart` | Add `resolveSignedUrl(String? urlOrPath)` method using `StorageService.getSignedUrl` |
| `lib/utils/signed_url_helper.dart` | Remove `resolveSignedMealImageUrl()`, keep `extractStoragePath()` |
| `lib/screens/diary/widgets/meal_image.dart` | Convert to `ConsumerStatefulWidget`, use `mealMediaRepositoryProvider` |
| `lib/screens/diary/widgets/meal_thumbnail.dart` | Same conversion |
| `lib/screens/ingredient_suggestions/widgets/suggestion_detail_modal.dart` | Same conversion for inner `_MealImage` widget |
| `test/helpers/fakes.dart` | Update `FakeMealMediaRepository` with `resolveSignedUrl` returning the input URL as-is |
| `test/repositories/meal_media_repository_test.dart` | Add test for `resolveSignedUrl` delegation to `StorageService.getSignedUrl` |

## Change 3: Auth Fallbacks → AuthRepository

### What Changes

Add synchronous getters to `AuthRepository`:

```dart
User? get currentUser => _authService.currentUser;
bool get isAuthenticated => _authService.currentUser != null;
```

Where `_authService.currentUser` reads from `_auth.currentUser` (the `GoTrueClient`).

Then in `auth_provider.dart`, replace:
```dart
// Before
Supabase.instance.client.auth.currentUser
// After
ref.read(authRepositoryProvider).currentUser
```

### Files Modified

| File | Change |
|---|---|
| `lib/services/auth_service.dart` | Add `User? get currentUser => _auth.currentUser;` |
| `lib/repositories/auth_repository.dart` | Add `User? get currentUser` and `bool get isAuthenticated` getters |
| `lib/providers/auth_provider.dart` | Replace `Supabase.instance.client.auth.currentUser` with `ref.read(authRepositoryProvider).currentUser` (2 locations) |
| `test/helpers/fakes.dart` | Update `FakeAuthRepository`: `currentUser` returns `null`, `isAuthenticated` returns `signedIn` field |

## File Impact Summary

| Action | Files |
|---|---|
| **Modify** | `lib/repositories/notification_repository.dart` |
| **Modify** | `lib/repositories/meal_media_repository.dart` |
| **Modify** | `lib/repositories/auth_repository.dart` |
| **Modify** | `lib/services/auth_service.dart` (add getter) |
| **Modify** | `lib/providers/auth_provider.dart` |
| **Modify** | `lib/app.dart` |
| **Modify** | `lib/screens/settings/widgets/settings_notifications_screen.dart` |
| **Modify** | `lib/screens/diary/widgets/meal_image.dart` |
| **Modify** | `lib/screens/diary/widgets/meal_thumbnail.dart` |
| **Modify** | `lib/screens/ingredient_suggestions/widgets/suggestion_detail_modal.dart` |
| **Modify** | `lib/utils/signed_url_helper.dart` (remove function) |
| **Modify** | `test/helpers/fakes.dart` |
| **Modify** | `test/repositories/notification_repository_test.dart` |
| **Modify** | `test/repositories/meal_media_repository_test.dart` |
| **Total** | **14 files** |

## Verification

After all changes:
- `grep -rn "PushNotificationService\|LocalNotificationService" lib/` should only match inside `lib/services/` and `lib/repositories/`
- `grep -rn "Supabase\.instance" lib/` should only match in `lib/providers/core_providers.dart` and `lib/main.dart`
- `grep -rn "import.*services/" lib/screens/ lib/widgets/ lib/app.dart` should only match `HapticService` and `ingredient_service.dart` (type-only import for `IngredientSuggestion` in `ingredient_search.dart`)
- `flutter analyze` passes
- `flutter test` passes
