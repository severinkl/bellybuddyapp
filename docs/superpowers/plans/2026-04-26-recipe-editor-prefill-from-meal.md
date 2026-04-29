# Recipe editor prefilled from a recent meal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the chooser-sheet's "Aus kürzlicher Mahlzeit" → immediate `userRecipes.create` with: tap a meal → open the recipe editor prefilled with the meal's title/ingredients/image, in display mode (no autofocus).

**Architecture:** `RecipeEditorScreen` gains an optional `MealEntry? initialMeal` constructor param that prefills `_title`, `_ingredients`, `_imageUrl` synchronously in `initState`. The `/recipe/new` GoRoute forwards `state.extra` (when it's a `MealEntry`) into that param — same pattern the meal-tracker route already uses for `UserRecipe`. The recent-meal picker sheet pops itself and pushes `/recipe/new` with the meal as `extra` instead of calling the provider's `create`.

**Tech Stack:** Flutter, Riverpod, GoRouter (existing in repo).

**Spec:** `docs/superpowers/specs/2026-04-26-recipe-editor-prefill-from-meal-design.md`

---

## File map

**Modify (4 files):**
- `lib/screens/recipes/recipe_editor_screen.dart` — new `initialMeal` constructor param, prefill in `initState`, gate `autofocusOnMount`.
- `lib/router/app_router.dart` — `/recipe/new` route reads `state.extra` and forwards to `RecipeEditorScreen`.
- `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart` — replace `_saveMeal` with `_openEditorWith`; drop the immediate `userRecipes.create` and the success/error SnackBars.
- `test/screens/recipes/recipe_editor_screen_test.dart` — add a `create mode prefilled from initialMeal` test group.

**No new files. No new routes. No deletions.**

---

### Task 1: `RecipeEditorScreen.initialMeal` — prefill + autofocus gate

**Files:**
- Modify: `lib/screens/recipes/recipe_editor_screen.dart`
- Test: `test/screens/recipes/recipe_editor_screen_test.dart`

- [ ] **Step 1: Read the current editor**

Run: `cat /Users/sevi/projects/bellybuddy/lib/screens/recipes/recipe_editor_screen.dart`

Confirm the constructor is `const RecipeEditorScreen({super.key, this.recipeId})`, the State has fields `String _title = ''; List<String> _ingredients = []; String? _imageUrl;`, `initState` only handles edit-mode, and the AppBar passes `autofocusOnMount: !_isEditMode`. Imports include `package:belly_buddy/models/user_recipe.dart` but **not** `package:belly_buddy/models/meal_entry.dart`.

- [ ] **Step 2: Read the existing test file**

Run: `cat /Users/sevi/projects/bellybuddy/test/screens/recipes/recipe_editor_screen_test.dart`

Confirm `pumpEditor(WidgetTester tester, {String? recipeId, List<dynamic> recipes = const []})` exists. Note the `import '../../helpers/fakes.dart'` and `import '../../helpers/fixtures.dart'` lines — `testMealEntry(...)` is exported from `fixtures.dart`.

- [ ] **Step 3: Write the failing test**

In `test/screens/recipes/recipe_editor_screen_test.dart`, add a new top-level `group` after the existing `group('edit mode', …)` block (before the closing `}` of `void main`). Use the existing `pumpEditor` helper as a template — the new helper passes `initialMeal` and skips the `recipeId` argument.

Add this code to the test file. Place the new helper right above the new `group` (between the existing `pumpEditor` definition's closing `}` and the first `group(`):

```dart
  Future<void> pumpEditorWithMeal(
    WidgetTester tester, {
    required MealEntry meal,
  }) async {
    when(
      () => repo.fetchForUser(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => repo.create(
        userId: any(named: 'userId'),
        title: any(named: 'title'),
        ingredients: any(named: 'ingredients'),
        imageUrl: any(named: 'imageUrl'),
      ),
    ).thenAnswer(
      (_) async => testUserRecipe(
        title: meal.title,
        ingredients: meal.ingredients,
        imageUrl: meal.imageUrl,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          mealMediaRepositoryProvider.overrideWithValue(mediaRepo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: MaterialApp(home: RecipeEditorScreen(initialMeal: meal)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('create mode prefilled from initialMeal', () {
    testWidgets('renders title in display mode (not autofocused)', (tester) async {
      final meal = testMealEntry(title: 'Linseneintopf');
      await pumpEditorWithMeal(tester, meal: meal);

      // Display mode: the title is rendered as Text, not TextField.
      expect(
        find.descendant(
          of: find.byType(EditableAppBarTitle),
          matching: find.text('Linseneintopf'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EditableAppBarTitle),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
    });

    testWidgets('renders a chip per ingredient from the meal', (tester) async {
      final meal = testMealEntry(
        title: 'Linseneintopf',
        ingredients: const ['Linsen', 'Tomaten', 'Zwiebel'],
      );
      await pumpEditorWithMeal(tester, meal: meal);

      expect(find.widgetWithText(Chip, 'Linsen'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Tomaten'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Zwiebel'), findsOneWidget);
    });

    testWidgets(
      'tapping Speichern calls repo.create with the prefilled values',
      (tester) async {
        final meal = testMealEntry(
          title: 'Linseneintopf',
          ingredients: const ['Linsen', 'Tomaten'],
        );
        await pumpEditorWithMeal(tester, meal: meal);

        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();

        verify(
          () => repo.create(
            userId: testUserId,
            title: 'Linseneintopf',
            ingredients: const ['Linsen', 'Tomaten'],
            imageUrl: any(named: 'imageUrl'),
          ),
        ).called(1);
      },
    );
  });
```

The test file currently imports `MealEntry` indirectly through fixtures, but the new tests reference `MealEntry` and `testMealEntry` directly. Check the imports at the top of the file. If `import 'package:belly_buddy/models/meal_entry.dart';` isn't there, add it. (The existing `import '../../helpers/fixtures.dart';` already exposes `testMealEntry`, so no second import needed.)

- [ ] **Step 4: Run test to verify it fails**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test test/screens/recipes/recipe_editor_screen_test.dart`
Expected: FAIL — `RecipeEditorScreen` has no `initialMeal` named parameter, compile error.

- [ ] **Step 5: Add the `initialMeal` constructor param**

In `lib/screens/recipes/recipe_editor_screen.dart`, add the import near the top (alphabetized with the other model imports — there's already `import '../../models/user_recipe.dart';` indirectly via the provider, but not the editor screen itself; check by grepping). Add:

```dart
import '../../models/meal_entry.dart';
```

Replace the existing class declaration:

```dart
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});

  /// Null → create mode. Non-null → edit mode (prefills from provider).
  final String? recipeId;
```

with:

```dart
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({
    super.key,
    this.recipeId,
    this.initialMeal,
  });

  /// Null → create mode. Non-null → edit mode (prefills from provider).
  final String? recipeId;

  /// When non-null and in create mode, pre-fills title/ingredients/image
  /// from this meal. Passed by the recent-meal picker sheet via GoRouter
  /// extra. Ignored in edit mode.
  final MealEntry? initialMeal;
```

- [ ] **Step 6: Prefill state synchronously in `initState`**

In `_RecipeEditorScreenState.initState`, after the existing `if (_isEditMode) { … }` block but before the closing `}`, add the create-mode prefill branch:

```dart
@override
void initState() {
  super.initState();
  if (_isEditMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Trigger a fetch so the provider has data, then prefill.
      await ref.read(userRecipesProvider.notifier).fetch();
      if (!mounted) return;
      _prefillFromProvider();
    });
  } else if (widget.initialMeal != null) {
    final meal = widget.initialMeal!;
    _title = meal.title;
    _ingredients = List<String>.from(meal.ingredients);
    _imageUrl = meal.imageUrl;
  }
}
```

This is a synchronous prefill — no post-frame callback needed because there's no async fetch, and the assignments touch only the State's own fields, not Riverpod state.

- [ ] **Step 7: Gate `autofocusOnMount` so prefilled mode mounts in display mode**

In the `build` method, find the existing `EditableAppBarTitle` block:

```dart
title: EditableAppBarTitle(
  initialTitle: _title,
  placeholder: 'Rezept benennen',
  autofocusOnMount: !_isEditMode,
  onTextChanged: (v) => setState(() => _title = v),
),
```

Replace with:

```dart
title: EditableAppBarTitle(
  initialTitle: _title,
  placeholder: 'Rezept benennen',
  autofocusOnMount: !_isEditMode && widget.initialMeal == null,
  onTextChanged: (v) => setState(() => _title = v),
),
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test test/screens/recipes/recipe_editor_screen_test.dart`
Expected: PASS — all 7 tests (4 existing + 3 new). The first new test verifies the `EditableAppBarTitle` is in display mode (a `Text` child, no `TextField`); the second asserts the chips render; the third asserts `repo.create` is called with the prefilled title and ingredients on tap of Speichern.

If a test fails because the chip widget isn't rendered, scroll the body or set a tall viewport — but `Chip` is in the body's `Wrap`, which the existing tests already pump without a viewport tweak, so this is unlikely.

- [ ] **Step 9: Run analyze + format**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze lib test/screens/recipes/recipe_editor_screen_test.dart`
Expected: `No issues found!`.

Run: `cd /Users/sevi/projects/bellybuddy && dart format lib/screens/recipes/recipe_editor_screen.dart test/screens/recipes/recipe_editor_screen_test.dart`
Expected: `0 changed`.

- [ ] **Step 10: Commit**

```bash
cd /Users/sevi/projects/bellybuddy && git add lib/screens/recipes/recipe_editor_screen.dart test/screens/recipes/recipe_editor_screen_test.dart && git commit -m "feat(recipe-editor): accept MealEntry prefill via initialMeal

In create mode, when a MealEntry is provided via the new initialMeal
constructor param, the editor synchronously prefills title,
ingredients, and imageUrl in initState. The AppBar title mounts in
display mode (no autofocus) since the value is already present.

Wired up by the route in the next task."
```

---

### Task 2: Forward `state.extra` from `/recipe/new` route

**Files:**
- Modify: `lib/router/app_router.dart`

- [ ] **Step 1: Inspect the existing route**

Run: `cd /Users/sevi/projects/bellybuddy && grep -n "RoutePaths.recipeNew\|RouteNames.recipeNew" lib/router/app_router.dart`
Expected: one builder definition near line 213-217.

Read those lines to confirm the current shape:
```dart
GoRoute(
  path: RoutePaths.recipeNew,
  name: RouteNames.recipeNew,
  builder: (context, state) => const RecipeEditorScreen(),
),
```

- [ ] **Step 2: Replace the route builder**

In `lib/router/app_router.dart`, replace the `/recipe/new` GoRoute block above with:

```dart
GoRoute(
  path: RoutePaths.recipeNew,
  name: RouteNames.recipeNew,
  builder: (context, state) {
    final extra = state.extra;
    return RecipeEditorScreen(
      initialMeal: extra is MealEntry ? extra : null,
    );
  },
),
```

The `extra is MealEntry ? extra : null` cast pattern matches the existing `mealTrackerEdit` route's handling of `state.extra` (lines ~140-144 of the same file).

- [ ] **Step 3: Confirm `MealEntry` is already imported**

Run: `cd /Users/sevi/projects/bellybuddy && grep -n "meal_entry.dart" lib/router/app_router.dart`
Expected: at least one matching import line (the file already references `MealEntry` in the `mealTrackerEdit` route).

If the grep returns zero matches, add `import '../models/meal_entry.dart';` to the imports at the top of the file.

- [ ] **Step 4: Run analyze**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze lib/router/app_router.dart`
Expected: `No issues found!`.

- [ ] **Step 5: Run the recipe editor + router-adjacent tests**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test test/screens/recipes/ test/router/`
Expected: all pass. The new tests from Task 1 don't go through the router (they pump `RecipeEditorScreen` directly), but other tests that DO use the router shouldn't regress.

- [ ] **Step 6: Commit**

```bash
cd /Users/sevi/projects/bellybuddy && git add lib/router/app_router.dart && git commit -m "feat(router): forward MealEntry extra to /recipe/new

The recent-meal picker sheet (next task) will push /recipe/new with
the chosen MealEntry as extra. The editor's new initialMeal param
triggers the prefill flow."
```

---

### Task 3: Recent-meal picker sheet — open editor instead of immediate-save

**Files:**
- Modify: `lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`

- [ ] **Step 1: Read the current sheet**

Run: `cd /Users/sevi/projects/bellybuddy && cat lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`

Confirm:
- A `_saveMeal(BuildContext, MealEntry)` method exists.
- It calls `Navigator.of(context).pop()` then `userRecipesProvider.notifier.create(...)` then a SnackBar.
- The `ListTile.onTap: () => _saveMeal(context, meal)` is the only call site.
- Imports include `flutter_riverpod`, `core_providers`, `entry_repository`, `user_recipes_provider`, and various model/util files.

- [ ] **Step 2: Add the GoRouter and RoutePaths imports**

At the top of the file, add:

```dart
import 'package:go_router/go_router.dart';
```

and

```dart
import '../../../router/route_names.dart';
```

(alphabetize with the other relative imports).

- [ ] **Step 3: Replace `_saveMeal` with `_openEditorWith`**

Find this method in `_RecentMealPickerSheetState`:

```dart
Future<void> _saveMeal(BuildContext context, MealEntry meal) async {
  Navigator.of(context).pop();
  try {
    await ref
        .read(userRecipesProvider.notifier)
        .create(
          title: meal.title,
          ingredients: meal.ingredients,
          imageUrl: meal.imageUrl,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zu Meine Rezepte hinzugefügt')),
      );
    }
  } catch (e, st) {
    _log.error('create recipe from meal failed', e, st);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fehler beim Speichern')));
    }
  }
}
```

Replace with:

```dart
void _openEditorWith(BuildContext context, MealEntry meal) {
  Navigator.of(context).pop();
  context.push(RoutePaths.recipeNew, extra: meal);
}
```

- [ ] **Step 4: Update the `ListTile.onTap` call site**

Search for `_saveMeal(context, meal)` in the same file and replace with `_openEditorWith(context, meal)`.

Run: `cd /Users/sevi/projects/bellybuddy && grep -n "_saveMeal\|_openEditorWith" lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`
Expected: zero matches for `_saveMeal`, one definition + one call for `_openEditorWith`.

- [ ] **Step 5: Drop now-unused imports**

The replaced method no longer uses `userRecipesProvider`. Check whether it's still referenced anywhere else in the file:

Run: `cd /Users/sevi/projects/bellybuddy && grep -n "userRecipesProvider" lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`

If zero matches, delete this line from the imports:
```dart
import '../../../providers/user_recipes_provider.dart';
```

The `_log.error` call in the dropped error branch was the only use of `_log` in the deleted method. Check whether `_log` is still used elsewhere in the file:

Run: `cd /Users/sevi/projects/bellybuddy && grep -n "_log" lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`

If `_log` is still used (e.g. `_fetchMeals` catches and logs), keep the `AppLogger` declaration. If not, delete it and also delete `import '../../../utils/logger.dart';`.

- [ ] **Step 6: Run analyze**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`
Expected: `No issues found!`.

If the analyzer complains about an unused import (`'package:belly_buddy/providers/user_recipes_provider.dart' is unused`), remove that import line.

- [ ] **Step 7: Run format**

Run: `cd /Users/sevi/projects/bellybuddy && dart format lib/screens/recipes/widgets/recent_meal_picker_sheet.dart`
Expected: `0 changed`.

- [ ] **Step 8: Run all recipes tests**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test test/screens/recipes/`
Expected: all pass. If a picker-sheet test asserted on the SnackBar text or the immediate `userRecipes.create` call, update it to verify navigation instead — `find.byType(_RecentMealPickerSheet)` should be gone (sheet popped), and a router observer / mock can verify `context.push(RoutePaths.recipeNew, extra: meal)` was invoked. The codebase has no picker-sheet tests today (verified during planning), so no test updates are expected.

- [ ] **Step 9: Commit**

```bash
cd /Users/sevi/projects/bellybuddy && git add lib/screens/recipes/widgets/recent_meal_picker_sheet.dart && git commit -m "feat(recipes): tap-recent-meal opens editor prefilled instead of saving

Tapping a meal in the recent-meal picker sheet now pops the sheet
and pushes /recipe/new with the meal as extra. The editor opens
prefilled with the meal's title, ingredients, and image — the user
reviews and edits before tapping Speichern (or backs out with no
recipe created).

Drops the immediate userRecipes.create round-trip and the
'Zu Meine Rezepte hinzugefügt' SnackBar."
```

---

### Task 4: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Full analyze**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 2: Full format check**

Run: `cd /Users/sevi/projects/bellybuddy && dart format --set-exit-if-changed .`
Expected: exit 0, "Formatted N files (0 changed)".

- [ ] **Step 3: Full test suite**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test`
Expected: all tests pass (current baseline is 725/725 + 3 new from Task 1 = 728/728).

- [ ] **Step 4: Manual smoke (optional, recommended)**

Per CLAUDE.md ("For UI or frontend changes, start the dev server and use the feature in a browser before reporting the task as complete"). Walk:
1. Tap **Rezepte** card on dashboard → /recipes.
2. Tap **+** → chooser sheet → "Aus kürzlicher Mahlzeit" → recent meal picker.
3. Tap any meal. Expect: picker sheet closes, recipe editor opens with title in display mode (not edit), ingredient chips visible, image (if any) showing.
4. Tap the title once — should switch to edit mode with the prefilled value.
5. Tap Speichern. Expect: returns to recipes list, the new recipe appears with the (possibly edited) values.
6. Repeat steps 1-3, then tap the back arrow instead of Speichern. Expect: returns to recipes list, no new recipe.
7. Sanity check: chooser sheet → "Neu erstellen" → editor opens with **empty** form, title field autofocused (keyboard up).

If any step misbehaves, fix and re-run from Step 1.

---

## Cross-task notes

- The plan never breaks the build between commits. Task 1 adds the `initialMeal` param with a default of `null`, so the existing route in Task 2's pre-state still compiles. Task 2 wires the route. Task 3 starts using the wired route. Each commit is independently green.
- The picker sheet's `Navigator.of(context).pop()` followed by `context.push(...)` works because the modal sheet sits on its own `Navigator`; popping it leaves the recipes screen as the active route, and `context.push` from the recipes-screen `BuildContext` (which the sheet captures via `rootContext` in the chooser sheet, but the picker sheet uses its own `context` since it's already a child of the recipes screen) lands on top of recipes. The chooser-sheet pop is handled by the existing `_AddRecipeChooserSheet` flow before the picker even opens.
- No data migration. No new columns. No new providers.
