# Drink Tracker Date Prefill From Meal Tracker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the user launches the drink tracker from the meal tracker (form button or post-save success card), the drink tracker pre-fills `trackedAt` with the meal's exact timestamp instead of `DateTime.now()`.

**Architecture:** Plumb an optional `initialDate` (DateTime, full timestamp) into `DrinkTrackerScreen`. Wire the GoRouter `/drink-tracker` route to read `state.extra as DateTime?` and forward. Update the two meal-tracker callsites to push with `extra: state.trackedAt`. Apply via `notifier.setTrackedAt(initialDate)` after `notifier.reset()` in the existing `initState` post-frame callback. No `buildTrackedAt` wrapping — full timestamp passes through verbatim.

**Tech Stack:** Flutter, Riverpod 3 (`Notifier`), GoRouter, mocktail-style fakes, `flutter_test` widget tests.

**Spec:** `docs/superpowers/specs/2026-05-03-drink-tracker-date-from-meal-tracker.md`

---

## File map

- **Modify** `lib/screens/trackers/drink/drink_tracker_screen.dart` — add `initialDate` constructor param; apply in `initState`.
- **Modify** `lib/router/app_router.dart` — read `state.extra as DateTime?` and forward to the screen.
- **Modify** `lib/screens/trackers/meal/meal_tracker_screen.dart` — pass `state.trackedAt` as `extra` from the form button (line ~412) and the success-card link (line ~213).
- **Modify** `test/screens/trackers/drink/drink_tracker_test.dart` — add a test that an `initialDate` constructor arg seeds `trackedAt`.
- **Create** `test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart` — assert both meal-tracker surfaces forward `state.trackedAt` as `extra` to `/drink-tracker`.

---

## Task 1: `DrinkTrackerScreen` accepts `initialDate` and applies it on mount

**Files:**
- Modify: `lib/screens/trackers/drink/drink_tracker_screen.dart`
- Test: `test/screens/trackers/drink/drink_tracker_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test inside the existing `group('DrinkTrackerScreen', () { ... })` in `test/screens/trackers/drink/drink_tracker_test.dart`. Place it after the `'renders quick drink grid after loading'` test:

```dart
testWidgets(
  'initialDate seeds the drink-tracker trackedAt verbatim '
  '(no buildTrackedAt — full timestamp through)',
  (tester) async {
    final initial = DateTime(2026, 5, 1, 12, 30);
    // Use UncontrolledProviderScope so we can read provider state after
    // the post-frame callback fires.
    final container = ProviderContainer.test(overrides: _overrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DrinkTrackerScreen(initialDate: initial),
        ),
      ),
    );
    // Drain the post-frame callback that calls notifier.setTrackedAt.
    await tester.pump(const Duration(milliseconds: 200));

    final state = container.read(drinkTrackerProvider);
    expect(state.trackedAt, equals(initial));
  },
);
```

You will also need these imports at the top of the test file (add only the missing ones):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

```
flutter test test/screens/trackers/drink/drink_tracker_test.dart
```

Expected: FAIL on the new test. Reason: the constructor doesn't accept `initialDate` yet, so this won't compile. The error will be `The named parameter 'initialDate' isn't defined.`

- [ ] **Step 3: Add `initialDate` constructor param + apply in initState**

Edit `lib/screens/trackers/drink/drink_tracker_screen.dart`. Change the class declaration block from:

```dart
class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key});

  static const trackerKey = Key('drink_tracker_screen');

  @override
  ConsumerState<DrinkTrackerScreen> createState() => _DrinkTrackerScreenState();
}
```

to:

```dart
class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key, this.initialDate});

  /// When non-null, pre-fills the tracker's `trackedAt` to this exact
  /// timestamp (date + time, verbatim). Passed by callers like the meal
  /// tracker so the user's chosen meal time carries through to the drink.
  final DateTime? initialDate;

  static const trackerKey = Key('drink_tracker_screen');

  @override
  ConsumerState<DrinkTrackerScreen> createState() => _DrinkTrackerScreenState();
}
```

Then change the `initState` post-frame callback. Currently it reads:

```dart
@override
void initState() {
  super.initState();
  final notifier = ref.read(drinkTrackerProvider.notifier);
  // Reset stale state from previous visit, then reload.
  // Deferred to avoid state change during widget tree construction.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    notifier.reset();
    notifier.loadDrinks();
    notifier.loadTodayTotal();
  });
}
```

Change to:

```dart
@override
void initState() {
  super.initState();
  final notifier = ref.read(drinkTrackerProvider.notifier);
  // Reset stale state from previous visit, then reload.
  // Deferred to avoid state change during widget tree construction.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    notifier.reset();
    if (widget.initialDate != null) {
      notifier.setTrackedAt(widget.initialDate!);
    }
    notifier.loadDrinks();
    notifier.loadTodayTotal();
  });
}
```

- [ ] **Step 4: Run the test to verify it passes**

```
flutter test test/screens/trackers/drink/drink_tracker_test.dart
```

Expected: PASS — all tests in the file (existing 5 + the new one) pass.

- [ ] **Step 5: Run analyze + format**

```
dart format lib/screens/trackers/drink/drink_tracker_screen.dart test/screens/trackers/drink/drink_tracker_test.dart
flutter analyze lib/screens/trackers/drink/ test/screens/trackers/drink/
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```
git add lib/screens/trackers/drink/drink_tracker_screen.dart test/screens/trackers/drink/drink_tracker_test.dart
git commit -m "feat(drink-tracker): accept initialDate and seed trackedAt"
```

---

## Task 2: Route `/drink-tracker` forwards `state.extra` as `DateTime?`

**Files:**
- Modify: `lib/router/app_router.dart`

This task has no dedicated test — Task 3's meal-tracker tests use a real `GoRouter` route hooked into the actual app router shape, but the most direct coverage is Task 3's tests asserting the screen receives the timestamp end-to-end. We commit this small route change separately because Task 3's button-press tests would fail without it.

- [ ] **Step 1: Update the route builder**

Edit `lib/router/app_router.dart`. Find the existing `/drink-tracker` `GoRoute` block (around line 168):

```dart
GoRoute(
  path: RoutePaths.drinkTracker,
  name: RouteNames.drinkTracker,
  builder: (context, state) => const DrinkTrackerScreen(),
),
```

Change to:

```dart
GoRoute(
  path: RoutePaths.drinkTracker,
  name: RouteNames.drinkTracker,
  builder: (context, state) =>
      DrinkTrackerScreen(initialDate: state.extra as DateTime?),
),
```

- [ ] **Step 2: Run analyze**

```
flutter analyze lib/router/
```

Expected: `No issues found!`

- [ ] **Step 3: Run the existing app-level tests to make sure nothing regresses**

```
flutter test test/screens/trackers/drink/drink_tracker_test.dart
```

Expected: PASS (all 6 tests).

- [ ] **Step 4: Commit**

```
git add lib/router/app_router.dart
git commit -m "feat(router): forward state.extra to drink tracker as initialDate"
```

---

## Task 3: Meal-tracker callsites pass `state.trackedAt` as `extra`

**Files:**
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart` (two callsites: success-card link ~line 213, form button ~line 412)
- Test: `test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart` (new file)

Both callsites currently use `() => context.push(RoutePaths.drinkTracker)`. We change both to forward the meal tracker's current `trackedAt`. Note the existing `state` (and `ref`) variables are already in scope at both sites — the success-card `successActions` builder runs inside the same `build` body where `final state = ref.watch(mealTrackerProvider);` is read on line ~186, so `state.trackedAt` is directly available.

- [ ] **Step 1: Write the failing test**

Create the new file `test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart` with the full content below. The test stands up a 2-route `GoRouter` (the meal tracker at `/meal-tracker` and a sentinel `/drink-tracker` route that renders the `extra` it received), sets a fixed `mealTrackerProvider.trackedAt`, and asserts both surfaces forward that exact `DateTime`.

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';

import '../../../helpers/fakes.dart';

/// Builds a 2-route GoRouter: the meal tracker plus a sentinel
/// `/drink-tracker` route that reads `state.extra as DateTime?` and renders
/// it as text. Tests assert on the rendered ISO string.
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/meal-tracker',
    routes: [
      GoRoute(
        path: '/meal-tracker',
        builder: (_, _) => const MealTrackerScreen(),
      ),
      GoRoute(
        path: RoutePaths.drinkTracker,
        builder: (_, state) {
          final extra = state.extra as DateTime?;
          return Scaffold(
            body: Text('drink-extra:${extra?.toIso8601String() ?? "null"}'),
          );
        },
      ),
    ],
  );
}

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

Future<ProviderContainer> _pumpMealTracker(WidgetTester tester) async {
  final container = ProviderContainer.test(overrides: _overrides());
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: _buildRouter(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'DE')],
        locale: const Locale('de', 'DE'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('MealTrackerScreen → DrinkTrackerScreen handoff', () {
    testWidgets(
      'form-button "Getränk tracken" forwards state.trackedAt as extra',
      (tester) async {
        final container = await _pumpMealTracker(tester);

        // Drive the meal-tracker provider to a known timestamp so we can
        // assert the exact value flows through.
        final fixed = DateTime(2026, 5, 1, 12, 30);
        container.read(mealTrackerProvider.notifier).setTrackedAt(fixed);
        await tester.pumpAndSettle();

        // Scroll the form button into view (it sits below ingredients).
        await tester.ensureVisible(
          find.byKey(MealTrackerScreen.drinkTrackerButtonKey),
        );
        await tester.tap(find.byKey(MealTrackerScreen.drinkTrackerButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.text('drink-extra:${fixed.toIso8601String()}'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'success-card "Getränk hinzufügen" forwards state.trackedAt as extra',
      (tester) async {
        final container = await _pumpMealTracker(tester);

        final fixed = DateTime(2026, 5, 1, 12, 30);
        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.setTrackedAt(fixed);
        // Force the success card visible without doing a real save.
        notifier.markShowSuccess();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Getränk hinzufügen'));
        await tester.pumpAndSettle();

        expect(
          find.text('drink-extra:${fixed.toIso8601String()}'),
          findsOneWidget,
        );
      },
    );
  });
}
```

**Note:** `MealTrackerNotifier` currently flips `state.showSuccess` only inside `save()`. Add a tiny test-only helper before running this step. In `lib/providers/meal_tracker_provider.dart`, find the `MealTrackerNotifier` class and add this method anywhere near the other small setters (e.g., right after `setTrackedAt`):

```dart
@visibleForTesting
void markShowSuccess() => state = state.copyWith(showSuccess: true);
```

Make sure `package:flutter/foundation.dart` is imported at the top of the file (for `@visibleForTesting`). If it isn't already imported, add:

```dart
import 'package:flutter/foundation.dart';
```

Then in the test, call `notifier.markShowSuccess()` (instead of `notifier.showSuccess()`). Update the test code in this step accordingly: replace `notifier.showSuccess();` with `notifier.markShowSuccess();`.

- [ ] **Step 2: Run the test to verify it fails**

```
flutter test test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart
```

Expected: FAIL on both new tests. Reason: the meal tracker still calls `context.push(RoutePaths.drinkTracker)` with no `extra`, so the sentinel renders `drink-extra:null` and the `findsOneWidget` for `drink-extra:2026-05-01T12:30:00.000` does not match.

- [ ] **Step 3: Update the form button callsite**

Edit `lib/screens/trackers/meal/meal_tracker_screen.dart`. Find the `OutlinedButton.icon` block at around line 410:

```dart
OutlinedButton.icon(
  key: MealTrackerScreen.drinkTrackerButtonKey,
  onPressed: () => context.push(RoutePaths.drinkTracker),
  icon: const Icon(Icons.water_drop_outlined),
  label: const Text('Getränk tracken'),
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppTheme.info,
    side: const BorderSide(color: AppTheme.info),
  ),
),
```

Change `onPressed` to forward the meal's tracked timestamp:

```dart
OutlinedButton.icon(
  key: MealTrackerScreen.drinkTrackerButtonKey,
  onPressed: () => context.push(
    RoutePaths.drinkTracker,
    extra: ref.read(mealTrackerProvider).trackedAt,
  ),
  icon: const Icon(Icons.water_drop_outlined),
  label: const Text('Getränk tracken'),
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppTheme.info,
    side: const BorderSide(color: AppTheme.info),
  ),
),
```

`ref` is in scope here because `MealTrackerScreen` extends `ConsumerStatefulWidget` and the build method is defined on a `ConsumerState`, which exposes `ref` directly.

- [ ] **Step 4: Update the success-card link callsite**

In the same file, the `successActions` `GestureDetector` lives at around line 211:

```dart
successActions: [
  GestureDetector(
    onTap: () => context.push(RoutePaths.drinkTracker),
    child: const Row(
      ...
```

Change `onTap` to use the same `state.trackedAt` value (the local `final state = ref.watch(mealTrackerProvider);` from line ~186 is in scope):

```dart
successActions: [
  GestureDetector(
    onTap: () => context.push(
      RoutePaths.drinkTracker,
      extra: state.trackedAt,
    ),
    child: const Row(
      ...
```

Leave the rest of the `Row(...)` unchanged.

- [ ] **Step 5: Run the test to verify it passes**

```
flutter test test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart
```

Expected: PASS — both tests pass.

- [ ] **Step 6: Run the full meal/drink tracker test suite to catch regressions**

```
flutter test test/screens/trackers/meal/ test/screens/trackers/drink/
```

Expected: PASS for the entire directory.

- [ ] **Step 7: Run analyze + format**

```
dart format lib/screens/trackers/meal/meal_tracker_screen.dart test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart
flutter analyze lib/screens/trackers/meal/ test/screens/trackers/meal/
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```
git add lib/providers/meal_tracker_provider.dart lib/screens/trackers/meal/meal_tracker_screen.dart test/screens/trackers/meal/meal_tracker_drink_handoff_test.dart
git commit -m "feat(meal-tracker): pass trackedAt to drink tracker via extra"
```

---

## Final verification

- [ ] **Step 1: Full local test sweep**

```
flutter test
```

Expected: every test passes.

- [ ] **Step 2: Manual smoke (optional but recommended)**

```
flutter run
```

In the running app:
1. Open the meal tracker, change the date/time chips to a non-today day at, e.g., 09:15.
2. Tap "Getränk tracken" — the drink tracker opens with chips already showing that day at 09:15.
3. Go back, save the meal, then in the success card tap "Getränk hinzufügen" — drink tracker opens with the same chosen timestamp.

- [ ] **Step 3: Open PR**

```
git push -u origin feat/drink-tracker-date-from-meal
gh pr create --base develop --head feat/drink-tracker-date-from-meal --title "feat(drink-tracker): prefill date from meal tracker" --body "$(cat <<'EOF'
## Summary
- Adds optional \`initialDate\` to \`DrinkTrackerScreen\`; applied in \`initState\` after \`reset()\`.
- Routes \`state.extra as DateTime?\` from \`/drink-tracker\` into the screen.
- Meal-tracker form button and success-card link both push with \`extra: state.trackedAt\` (full timestamp, no \`buildTrackedAt\` wrapping).

Spec: \`docs/superpowers/specs/2026-05-03-drink-tracker-date-from-meal-tracker.md\`

## Test plan
- [ ] \`flutter test\` clean
- [ ] Smoke: meal tracker → set non-today date → tap "Getränk tracken" → drink tracker shows the same date+time.
- [ ] Smoke: save meal → success card → tap "Getränk hinzufügen" → same prefill.
EOF
)"
```

(Per the durable preference: stop at \`gh pr create\`. Do not arm \`--auto\`.)
