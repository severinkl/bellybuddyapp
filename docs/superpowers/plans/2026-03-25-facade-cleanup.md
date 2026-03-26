# Facade Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the last 3 layer violations so no screen/widget/provider bypasses the repository layer.

**Architecture:** Expand existing repositories to facade all remaining direct service/singleton access. 14 files modified, zero new files.

**Tech Stack:** Flutter, Riverpod, mocktail

**Spec:** `docs/superpowers/specs/2026-03-25-facade-cleanup-design.md`

---

## Task 1: Expand NotificationRepository + Update app.dart + Settings Screen

**Files:**
- Modify: `lib/repositories/notification_repository.dart`
- Modify: `lib/app.dart`
- Modify: `lib/screens/settings/widgets/settings_notifications_screen.dart`
- Modify: `test/helpers/fakes.dart` (FakeNotificationRepository)
- Modify: `test/repositories/notification_repository_test.dart`

### Step 1: Add push methods to NotificationRepository

Read `lib/repositories/notification_repository.dart` and `lib/services/push_notification_service.dart`. Add these methods to `NotificationRepository`, delegating to `PushNotificationService` static methods:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/push_notification_service.dart';

// Add to NotificationRepository class:
Stream<RemoteMessage> get onForegroundMessage =>
    PushNotificationService.onForegroundMessage;

Stream<RemoteMessage> get onMessageOpenedApp =>
    PushNotificationService.onMessageOpenedApp;

Future<RemoteMessage?> getInitialMessage() =>
    PushNotificationService.getInitialMessage();

String? extractRoute(RemoteMessage message) =>
    PushNotificationService.extractRoute(message);

Future<bool> requestPermission() =>
    PushNotificationService.requestPermission();

Future<void> clearToken() =>
    PushNotificationService.clearToken();
```

### Step 2: Update app.dart

Read `lib/app.dart`. Replace ALL `PushNotificationService.*` and `LocalNotificationService.*` calls with `ref.read(notificationRepositoryProvider).*`:

- Remove imports: `services/local_notification_service.dart`, `services/push_notification_service.dart`
- Keep import: `package:firebase_messaging/firebase_messaging.dart` (for `RemoteMessage` type)
- Add import: `repositories/notification_repository.dart`
- Replace `PushNotificationService.onMessageOpenedApp` → `ref.read(notificationRepositoryProvider).onMessageOpenedApp`
- Replace `PushNotificationService.onForegroundMessage` → `ref.read(notificationRepositoryProvider).onForegroundMessage`
- Replace `PushNotificationService.extractRoute(msg)` → `ref.read(notificationRepositoryProvider).extractRoute(msg)`
- Replace `PushNotificationService.getInitialMessage()` → `ref.read(notificationRepositoryProvider).getInitialMessage()`
- Replace `LocalNotificationService.cancelAll()` → `ref.read(notificationRepositoryProvider).cancelAll()`
- Replace `PushNotificationService.clearToken()` → `ref.read(notificationRepositoryProvider).clearToken()`

### Step 3: Update settings_notifications_screen.dart

Read `lib/screens/settings/widgets/settings_notifications_screen.dart`. Replace:
- `PushNotificationService.requestPermission()` → `ref.read(notificationRepositoryProvider).requestPermission()`
- Remove import: `services/push_notification_service.dart`
- Add import: `repositories/notification_repository.dart`

### Step 4: Update FakeNotificationRepository in test/helpers/fakes.dart

Add stub implementations for new methods:
```dart
@override
Stream<RemoteMessage> get onForegroundMessage => const Stream.empty();
@override
Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();
@override
Future<RemoteMessage?> getInitialMessage() async => null;
@override
String? extractRoute(RemoteMessage message) => null;
@override
Future<bool> requestPermission() async => true;
@override
Future<void> clearToken() async {}
```

### Step 5: Add tests to notification_repository_test.dart

Add tests for the new delegation methods (requestPermission, clearToken, extractRoute, etc.).

### Step 6: Verify and commit

Run: `flutter analyze && flutter test`
Commit: `git commit -m "refactor: expand NotificationRepository into full notification facade"`

---

## Task 2: Move Signed URL Resolution to MealMediaRepository

**Files:**
- Modify: `lib/repositories/meal_media_repository.dart`
- Modify: `lib/utils/signed_url_helper.dart`
- Modify: `lib/screens/diary/widgets/meal_image.dart`
- Modify: `lib/screens/diary/widgets/meal_thumbnail.dart`
- Modify: `lib/screens/ingredient_suggestions/widgets/suggestion_detail_modal.dart`
- Modify: `test/helpers/fakes.dart` (FakeMealMediaRepository)
- Modify: `test/repositories/meal_media_repository_test.dart`

### Step 1: Add resolveSignedUrl to MealMediaRepository

Read `lib/repositories/meal_media_repository.dart` and `lib/utils/signed_url_helper.dart`. Add method:

```dart
import '../utils/signed_url_helper.dart';

Future<String?> resolveSignedUrl(String? urlOrPath) async {
  if (urlOrPath == null || urlOrPath.isEmpty) return null;
  if (urlOrPath.contains('token=')) return urlOrPath;

  try {
    final path = extractStoragePath(urlOrPath, 'meal-images');
    return await _storageService.getSignedUrl(
      bucket: 'meal-images',
      path: path,
    );
  } catch (e) {
    return urlOrPath;
  }
}
```

### Step 2: Remove resolveSignedMealImageUrl from signed_url_helper.dart

Keep `extractStoragePath()` (pure function, no deps). Remove `resolveSignedMealImageUrl()` and the `Supabase` import.

### Step 3: Convert 3 widgets to ConsumerStatefulWidget

For each of `meal_image.dart`, `meal_thumbnail.dart`, and `suggestion_detail_modal.dart`:
- Read the file first
- Change `StatefulWidget` → `ConsumerStatefulWidget`, `State<X>` → `ConsumerState<X>`
- Replace `await resolveSignedMealImageUrl(widget.imageUrl)` with `await ref.read(mealMediaRepositoryProvider).resolveSignedUrl(widget.imageUrl)`
- Add import for `flutter_riverpod` and `meal_media_repository.dart`
- Remove import for `signed_url_helper.dart`

### Step 4: Update FakeMealMediaRepository

Add: `Future<String?> resolveSignedUrl(String? urlOrPath) async => urlOrPath;`

### Step 5: Add test to meal_media_repository_test.dart

Test that `resolveSignedUrl` delegates to `StorageService.getSignedUrl` with correct bucket/path.

### Step 6: Verify and commit

Run: `flutter analyze && flutter test`
Commit: `git commit -m "refactor: move signed URL resolution to MealMediaRepository"`

---

## Task 3: Route Auth Fallbacks Through AuthRepository

**Files:**
- Modify: `lib/services/auth_service.dart`
- Modify: `lib/repositories/auth_repository.dart`
- Modify: `lib/providers/auth_provider.dart`
- Modify: `test/helpers/fakes.dart` (FakeAuthRepository)

### Step 1: Add currentUser getter to AuthService

Read `lib/services/auth_service.dart`. Add:
```dart
User? get currentUser => _auth.currentUser;
```

### Step 2: Add getters to AuthRepository

Read `lib/repositories/auth_repository.dart`. Add:
```dart
User? get currentUser => _authService.currentUser;
bool get isAuthenticated => _authService.currentUser != null;
```

### Step 3: Update auth_provider.dart

Read `lib/providers/auth_provider.dart`. Replace both `Supabase.instance.client.auth.currentUser` references with `ref.read(authRepositoryProvider).currentUser`. Remove the `Supabase` import if no longer needed.

### Step 4: Update FakeAuthRepository

Add:
```dart
@override
User? get currentUser => null;
@override
bool get isAuthenticated => signedIn;
```

### Step 5: Verify and commit

Run: `flutter analyze && flutter test`

Verify: `grep -rn "Supabase\.instance" lib/` should only match `core_providers.dart` and `main.dart`.

Commit: `git commit -m "refactor: route auth fallbacks through AuthRepository"`

---

## Task 4: Final Verification

- [ ] `grep -rn "PushNotificationService\|LocalNotificationService" lib/` — only matches in `lib/services/` and `lib/repositories/`
- [ ] `grep -rn "Supabase\.instance" lib/` — only matches in `lib/providers/core_providers.dart` and `lib/main.dart`
- [ ] `grep -rn "import.*services/" lib/screens/ lib/widgets/ lib/app.dart` — only matches `HapticService` and `ingredient_service.dart` (type import)
- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — all pass
