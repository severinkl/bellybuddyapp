# Recipe selector sheet redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the meal-tracker's recipe selector bottom sheet with a card-row layout that has a pinned `RecipesSearchField`, a "+ Neues Rezept erstellen" footer, an auto-sizing `DraggableScrollableSheet`, and a pastel-plus-book-icon placeholder for image-less recipes.

**Architecture:** Single-file rewrite of `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`. Reuse existing widgets (`RecipesSearchField`, `SignedPathImage`, `pastelForTitle`); add four private widgets in the same file (`_RecipeRowCard`, `_RecipeThumb`, `_IngredientChip`, `_NewRecipeRow`). New widget test file. One small `AppConstants` addition (`iconSizeMd = 24.0`).

**Tech Stack:** Flutter, Riverpod (`userRecipesProvider`, `RecipesSearchField`), GoRouter (`/recipe/new`), `mocktail` for tests.

**Spec:** `docs/superpowers/specs/2026-04-27-recipe-selector-sheet-redesign-design.md`

---

## File map

**Modify (2):**
- `lib/config/constants.dart` — add `static const double iconSizeMd = 24.0;` to the "Icon sizes" section.
- `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart` — rewrite the body and add four private widgets.

**Create (1):**
- `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart` — widget tests for the new sheet.

**No router changes. No new top-level widgets.**

---

### Task 1: Add `iconSizeMd` constant

**Files:**
- Modify: `lib/config/constants.dart` (the "Icon sizes" block)

- [ ] **Step 1: Add the constant**

In `lib/config/constants.dart`, find the "Icon sizes" block:

```dart
  // Icon sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 18.0;
  static const double iconSizeClose = 20.0;
  static const double iconSizeLg = 32.0;
```

Replace with:

```dart
  // Icon sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 18.0;
  static const double iconSizeClose = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
```

- [ ] **Step 2: Run analyze**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze lib/config/constants.dart`
Expected: `No issues found`.

- [ ] **Step 3: Commit**

```bash
cd /Users/sevi/projects/bellybuddy && git add lib/config/constants.dart && git commit -m "feat(constants): add iconSizeMd = 24.0

Used by the redesigned recipe selector sheet's book-icon placeholder."
```

---

### Task 2: Rewrite the recipe selector sheet

**Files:**
- Modify: `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`
- Test: `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart` (new)

- [ ] **Step 1: Read the current sheet**

Run: `cat /Users/sevi/projects/bellybuddy/lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`

Confirm: `showRecipeSelectorSheet` returns `Future<UserRecipe?>`, body uses `FractionallySizedBox(heightFactor: 0.8)`, list is `ListView.separated` of `ListTile`s with `Container(color: AppTheme.muted)` placeholders.

- [ ] **Step 2: Read the existing test scaffolding**

Run: `cat /Users/sevi/projects/bellybuddy/test/screens/recipes/widgets/recent_meal_picker_sheet_test.dart`

Confirm the 2-route GoRouter pattern + the sentinel route reading `state.extra`. We'll mirror that shape for the "+ Neues Rezept" navigation test.

- [ ] **Step 3: Inspect the user-recipes notifier overrides used in `MyRecipesTab` tests**

Run: `cd /Users/sevi/projects/bellybuddy && grep -B 1 -A 30 "_FakeUserRecipesNotifier\|class.*UserRecipesNotifier" test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart 2>/dev/null | head -50`

Confirm the existing `_FakeUserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>> implements UserRecipesNotifier` pattern. We'll reuse the shape inline in the new test for sheet-state seeding (or copy minimal portions — the new test only needs `build()` to return a seeded list and `setQuery(...)` to record calls).

- [ ] **Step 4: Write the failing test file**

Create `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`:

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/recipe_selector_sheet.dart';

import '../../../../helpers/fakes.dart';

class _FakeUserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>>
    implements UserRecipesNotifier {
  _FakeUserRecipesNotifier(this._recipes);

  final List<UserRecipe> _recipes;
  String? _query;
  final List<String?> setQueryCalls = [];

  @override
  AsyncValue<List<UserRecipe>> build() => AsyncValue.data(_recipes);

  @override
  Future<void> fetch({bool force = false}) async {}

  @override
  void setQuery(String? q) {
    setQueryCalls.add(q);
    _query = q;
  }

  @override
  String? get activeQuery => _query;

  @override
  bool get hasActiveQuery => _query != null;

  @override
  Future<UserRecipe> create({
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) => throw UnimplementedError();

  @override
  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}
}

GoRouter _buildRouter(_FakeUserRecipesNotifier notifier) => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showRecipeSelectorSheet(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.recipeNew,
      builder: (_, _) => const Scaffold(body: Text('recipe-new-sentinel')),
    ),
  ],
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required List<UserRecipe> recipes,
}) async {
  final notifier = _FakeUserRecipesNotifier(recipes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRecipesProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter(notifier)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'renders one card row per recipe with title and up to 3 ingredients',
    (tester) async {
      final recipes = [
        testUserRecipe(
          id: 'r1',
          title: 'Curry mit Reis',
          ingredients: ['Reis', 'Curry', 'Zwiebel', 'Knoblauch'],
        ),
        testUserRecipe(
          id: 'r2',
          title: 'Schnitzel mit Pommes',
          ingredients: ['Schwein', 'Kartoffel'],
        ),
      ];
      await _pumpSheet(tester, recipes: recipes);

      expect(find.text('Curry mit Reis'), findsOneWidget);
      expect(find.text('Schnitzel mit Pommes'), findsOneWidget);
      // First 3 ingredients of recipe 1.
      expect(find.text('Reis'), findsOneWidget);
      expect(find.text('Curry'), findsOneWidget);
      expect(find.text('Zwiebel'), findsOneWidget);
      // 4th ingredient is not rendered (take(3) cap).
      expect(find.text('Knoblauch'), findsNothing);
    },
  );

  testWidgets('tapping a recipe card pops the sheet with that recipe', (
    tester,
  ) async {
    final target = testUserRecipe(id: 'r1', title: 'Curry mit Reis');
    await _pumpSheet(tester, recipes: [target]);

    expect(find.text('Curry mit Reis'), findsOneWidget);
    await tester.tap(find.text('Curry mit Reis'));
    await tester.pumpAndSettle();

    // Sheet dismissed.
    expect(find.text('Curry mit Reis'), findsNothing);
    // Back on the home screen with the open button.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'tapping "Neues Rezept erstellen" pops the sheet and navigates to /recipe/new',
    (tester) async {
      await _pumpSheet(tester, recipes: const []);

      expect(find.text('Neues Rezept erstellen'), findsOneWidget);
      await tester.tap(find.text('Neues Rezept erstellen'));
      await tester.pumpAndSettle();

      expect(find.text('recipe-new-sentinel'), findsOneWidget);
    },
  );

  testWidgets('empty library shows "Noch keine Rezepte" plus the create row', (
    tester,
  ) async {
    await _pumpSheet(tester, recipes: const []);

    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    expect(find.text('Neues Rezept erstellen'), findsOneWidget);
  });

  testWidgets('dismissing the sheet clears the active query', (tester) async {
    final notifier = _FakeUserRecipesNotifier(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipesProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp.router(routerConfig: _buildRouter(notifier)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Dismiss the sheet by tapping the barrier (simulate by popping the route).
    final navContext = tester.element(find.byType(Scaffold).first);
    Navigator.of(navContext).pop();
    await tester.pumpAndSettle();

    // The dispose path should have called setQuery(null).
    expect(notifier.setQueryCalls, contains(null));
  });
}
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`
Expected: FAIL — "Neues Rezept erstellen" text not found, "Noch keine Rezepte" missing in some new state, etc. The current sheet doesn't render these strings.

- [ ] **Step 6: Rewrite the sheet file**

Replace the entire contents of `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/user_recipe.dart';
import '../../../../providers/user_recipes_provider.dart';
import '../../../../router/route_names.dart';
import '../../../../utils/title_color.dart';
import '../../../../widgets/common/signed_path_image.dart';
import '../../../recipes/widgets/recipes_search_field.dart';

/// Opens a modal bottom sheet that lets the user pick one of their saved
/// recipes. Returns the selected [UserRecipe], or `null` if dismissed.
///
/// The sheet has a pinned search field at the top (filters via the existing
/// FTS-backed [userRecipesProvider]) and a "+ Neues Rezept erstellen" footer
/// row that pops the sheet and pushes [/recipe/new].
Future<UserRecipe?> showRecipeSelectorSheet(BuildContext context) {
  return showModalBottomSheet<UserRecipe>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => SafeArea(
        top: false,
        child: _RecipeSelectorBody(scrollController: scrollController),
      ),
    ),
  );
}

class _RecipeSelectorBody extends ConsumerStatefulWidget {
  const _RecipeSelectorBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_RecipeSelectorBody> createState() =>
      _RecipeSelectorBodyState();
}

class _RecipeSelectorBodyState extends ConsumerState<_RecipeSelectorBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userRecipesProvider.notifier).fetch();
    });
  }

  @override
  void dispose() {
    // Clear sheet-scoped search so the recipes tab isn't pre-filtered the
    // next time it mounts. setQuery(null) is idempotent and triggers a
    // background re-fetch of the unfiltered list.
    ref.read(userRecipesProvider.notifier).setQuery(null);
    super.dispose();
  }

  void _openNewRecipe(BuildContext context) {
    Navigator.of(context).pop();
    context.push(RoutePaths.recipeNew);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userRecipesProvider);
    final hasActiveQuery = ref
        .watch(userRecipesProvider.notifier)
        .hasActiveQuery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        Center(
          child: Container(
            width: AppConstants.dragHandleWidth,
            height: AppConstants.dragHandleHeight,
            decoration: BoxDecoration(
              color: AppTheme.muted,
              borderRadius: BorderRadius.circular(
                AppConstants.dragHandleRadius,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingMd,
            AppConstants.spacingLg,
            AppConstants.spacingSm,
          ),
          child: Text(
            'Rezept auswählen',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
          child: RecipesSearchField(),
        ),
        AppConstants.gap8,
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const Center(
              child: Text(
                'Konnte Rezepte nicht laden',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return Center(
                  child: Text(
                    hasActiveQuery ? 'Keine Treffer' : 'Noch keine Rezepte',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                itemCount: recipes.length,
                separatorBuilder: (_, _) => AppConstants.gap8,
                itemBuilder: (context, i) {
                  final recipe = recipes[i];
                  return _RecipeRowCard(
                    recipe: recipe,
                    onTap: () => Navigator.of(context).pop(recipe),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingSm,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
          ),
          child: _NewRecipeRow(onTap: () => _openNewRecipe(context)),
        ),
      ],
    );
  }
}

class _RecipeRowCard extends StatelessWidget {
  const _RecipeRowCard({required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              _RecipeThumb(recipe: recipe),
              AppConstants.gap12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                    if (recipe.ingredients.isNotEmpty) ...[
                      AppConstants.gap4,
                      Wrap(
                        spacing: AppConstants.spacingXs,
                        runSpacing: AppConstants.spacingXs,
                        children: [
                          for (final ingredient in recipe.ingredients.take(3))
                            _IngredientChip(label: ingredient),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.recipe});

  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.imageUrl != null) {
      return SizedBox(
        width: AppConstants.iconBadgeXl,
        height: AppConstants.iconBadgeXl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: SignedPathImage(
            pathOrUrl: recipe.imageUrl,
            width: AppConstants.iconBadgeXl,
            height: AppConstants.iconBadgeXl,
            placeholder: Container(color: AppTheme.muted),
            errorWidget: _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: AppConstants.iconBadgeXl,
      height: AppConstants.iconBadgeXl,
      decoration: BoxDecoration(
        color: pastelForTitle(recipe.title),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        color: AppTheme.foreground.withValues(alpha: 0.45),
        size: AppConstants.iconSizeMd,
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          color: AppTheme.mutedForeground,
        ),
      ),
    );
  }
}

class _NewRecipeRow extends StatelessWidget {
  const _NewRecipeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              Container(
                width: AppConstants.iconBadgeXl,
                height: AppConstants.iconBadgeXl,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: AppTheme.primary),
              ),
              AppConstants.gap12,
              const Text(
                'Neues Rezept erstellen',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`
Expected: PASS (5/5).

If a test fails because the bottom sheet's render hierarchy hides text behind a viewport (e.g., the sheet renders below the fold of the test's default viewport), use `tester.view.physicalSize = const Size(1080, 2400);` and `tester.view.devicePixelRatio = 1.0;` at the top of `_pumpSheet`, with `addTearDown(tester.view.resetPhysicalSize)` and `addTearDown(tester.view.resetDevicePixelRatio)` to restore. The cross-screen test (`test/screens/cross_screen_ingredient_autocomplete_test.dart`) uses this pattern.

If the dispose-clear test (last one) fails because `Navigator.of(...).pop()` doesn't dispose the modal sheet's State synchronously: try `await tester.tapAt(const Offset(20, 20))` (taps the modal barrier above the sheet) instead of the explicit `Navigator.pop`. That's the way `showModalBottomSheet` is normally dismissed.

- [ ] **Step 8: Run analyze + format**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`
Expected: `No issues found`.

Run: `cd /Users/sevi/projects/bellybuddy && dart format lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`
Expected: 0 changed (or auto-format and re-stage).

- [ ] **Step 9: Commit**

```bash
cd /Users/sevi/projects/bellybuddy && git add lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart && git commit -m "feat(recipes): redesign recipe selector sheet

Replace the ListTile-of-gray-squares with card rows + ingredient
chips, a pinned RecipesSearchField, and a '+ Neues Rezept erstellen'
footer that pushes /recipe/new. Image-less recipes get a
pastelForTitle background plus a faded book-icon glyph instead of
the flat gray placeholder.

Sheet sizing switches from FractionallySizedBox(0.8) to
DraggableScrollableSheet (0.6 initial, 0.4-0.92 range) so few
recipes don't yield empty space.

Sheet-scoped search: setQuery(null) on dispose so dismissing the
sheet doesn't pre-filter the recipes tab next time it mounts."
```

---

### Task 3: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Full analyze**

Run: `cd /Users/sevi/projects/bellybuddy && flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 2: Full format check**

Run: `cd /Users/sevi/projects/bellybuddy && dart format --set-exit-if-changed .`
Expected: exit 0.

- [ ] **Step 3: Full test suite**

Run: `cd /Users/sevi/projects/bellybuddy && flutter test`
Expected: all tests pass (current baseline 735 + 5 new from Task 2 = 740).

- [ ] **Step 4: Manual smoke (optional, recommended)**

Walk:
1. Open meal tracker, tap **Rezept** in the empty-state card → sheet opens at ~60% height.
2. Each saved recipe renders as a card row. Recipes without an image show the pastel + book-icon placeholder (different colors per recipe due to `pastelForTitle`).
3. Type 3+ chars in the search field → list filters via the FTS column.
4. Tap a recipe → sheet dismisses, meal tracker prefills.
5. Reopen the sheet → search field is empty (the dispose cleared it).
6. Tap **+ Neues Rezept erstellen** → sheet dismisses, recipe editor opens with empty form.
7. Drag the sheet down → it can shrink to ~40%; drag up → expands to ~92%.

If anything misbehaves, fix and re-run from Step 1.
