# Recipe integration tests — three user-loop flows

**Date:** 2026-04-28
**Status:** Approved, ready for implementation plan
**Scope:** Add three end-to-end integration tests in `integration_test/recipes_flow_test.dart` covering the recipe feature's high-traffic user journeys: create from scratch, prefill meal-tracker from a recipe, and save a meal as a recipe.

## Problem

The existing two integration tests cover navigation (dashboard → recipes screen) and list rendering (seeded recipes appear in the grid). They don't exercise any user-driven mutation. The three loops the recipes feature was built for — create, recipe-as-meal-template, meal-as-recipe — are tested at unit/widget level only. Regressions in tap chains, sheet dismissal, post-success navigation, or repository wiring slip through CI.

## Goal

Three new integration tests, each asserting both the rendered UI state and the underlying repository state (round-trip), pinning the contracts most users hit daily.

## Approach

### Files

**Modify (1):**
- `integration_test/recipes_flow_test.dart` — add 3 tests after the 2 existing ones.

**No new fakes.** `buildTestApp` (at `integration_test/helpers/test_app.dart`) already wires `FakeUserRecipeRepository`, `FakeIngredientRepository`, `FakeEntryRepository`, `FakeMealMediaRepository`. The fakes record creates/updates/inserts so tests can assert via the seeded repo reference.

### Test 3 — Create recipe from scratch

```
dashboard → tap Rezepte FeatureCard → /recipes (empty state)
         → tap "Erstes Rezept erstellen" → AddRecipeChooserSheet opens
         → tap "Neu erstellen" → /recipe/new (RecipeEditorScreen mounts)
         → enter title via EditableAppBarTitle's TextField → submit
         → tap "+ Hinzufügen" in IngredientSearch
         → enter ingredient → wait debounce (350 ms) → submit
         → tap "Speichern" (gated on title + ≥1 ingredient)
         → returns to /recipes
         → recipe title appears in MyRecipesTab grid
```

Asserts:
- `find.text('Eiersalat')` in the recipes grid.
- `repo.fetchForUser('test-user-id')` returns a list whose `.title` includes `'Eiersalat'` (round-trip via the FakeUserRecipeRepository).

### Test 4 — Prefill meal tracker from a recipe → save → land on dashboard

Setup:
- Seed `FakeUserRecipeRepository` with one recipe: title `'Curry mit Reis'`, ingredients `['Reis', 'Curry']`, `imageUrl: null`.
- Default `FakeEntryRepository`.

```
dashboard → tap BbBottomNav.centerButtonKey → /meal-tracker (create mode)
         → empty-state image card shows three buttons (Kamera/Galerie/Rezept)
         → tap "Rezept" → RecipeSelectorSheet opens
         → tap the seeded recipe row → sheet dismisses, prefillFromRecipe runs
         → AppBar title shows 'Curry mit Reis', ingredient chips show 'Reis' and 'Curry'
         → tap "Speichern"
         → BbSuccessOverlay appears
         → tap the overlay (it's a GestureDetector that calls onDismissed)
         → because widget.initialRecipe != null, context.go(/dashboard) fires
         → DashboardScreen is visible
```

The seeded recipe has `imageUrl: null` so `BbPastelThumb` renders the pastel placeholder (no `SignedPathImage` network call).

Asserts:
- After save, `FakeEntryRepository.addedMeals` contains exactly one `MealEntry` with `title == 'Curry mit Reis'` and `ingredients == ['Reis', 'Curry']`.
- After dismiss, `find.byType(DashboardScreen)` is one widget (proving the recipe-driven save → dashboard fix landed earlier in this PR is exercised end-to-end).

### Test 5 — Save-as-recipe from the meal tracker success screen

Setup:
- Default `buildTestApp` (empty `FakeUserRecipeRepository`, empty `FakeEntryRepository`).

```
dashboard → tap BbBottomNav.centerButtonKey → /meal-tracker (create mode)
         → enter title 'Pasta Bolognese' via EditableAppBarTitle
         → tap "+ Hinzufügen" → enter 'Nudeln' → wait debounce → submit
         → tap "Speichern"
         → BbSuccessOverlay appears with "Als Rezept speichern" callout button
         → tap "Als Rezept speichern"
         → button label flips to "Als Rezept gespeichert" + Icons.check
```

Asserts:
- `find.text('Als Rezept gespeichert')` is one widget.
- `find.byIcon(Icons.check)` (inside the BbButton on the callout) is one widget.
- `FakeUserRecipeRepository.fetchForUser('test-user-id')` returns a recipe with `title == 'Pasta Bolognese'` and `ingredients == ['Nudeln']`.

The test stops there (does not navigate to `/recipes` to re-verify the list — Test 3 already pins that round-trip and adding the same assertion here would slow the suite without catching new regressions).

### Shared test helper

A private helper used by Tests 3 and 5 to drive title + single-ingredient entry:

```dart
Future<void> _enterTitleAndIngredient(
  WidgetTester tester, {
  required String title,
  required String ingredient,
}) async {
  // EditableAppBarTitle is in edit mode by default in create mode.
  final titleField = find.descendant(
    of: find.byType(EditableAppBarTitle),
    matching: find.byType(TextField),
  );
  await tester.enterText(titleField, title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  // IngredientSearch: tap "+ Hinzufügen", type, wait for the 300 ms
  // onSearch debounce to clear, then submit.
  await tester.tap(find.text('+ Hinzufügen'));
  await tester.pumpAndSettle();
  final ingredientField = find.descendant(
    of: find.byType(IngredientSearch),
    matching: find.byType(TextField),
  );
  await tester.enterText(ingredientField, ingredient);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}
```

## Acceptance

- `integration_test/recipes_flow_test.dart` contains 5 tests (2 existing + 3 new).
- All 5 pass on a real device: `flutter test integration_test/recipes_flow_test.dart -d <device-id>`.
- No new fakes added; all repository overrides come from the existing `buildTestApp` parameters.
- Each new test asserts both rendered-UI state and the recorded repository state (round-trip).
- `flutter analyze` clean. `dart format --set-exit-if-changed integration_test/` clean.

## Out of scope

- Edit/delete recipe flows — covered indirectly by Test 3's create round-trip (same provider plumbing).
- Recent-meal picker → editor prefill (Rezepte tab `+` → "Aus kürzlicher Mahlzeit") — separate journey; can be added later.
- Search/FTS filtering inside the recipe-selector sheet — `RecipesSearchField` is widget-tested directly.
- Sign-out → sign-in cache invalidation — already pinned by the auth-listener invalidation work; integration assertion would be heavyweight.
- The `RecipeDetailScreen` route — adjacent to but not on the create / use / save loops.

## Risks

- **IngredientSearch's 300 ms debounce.** The shared helper explicitly pumps 350 ms between `enterText` and the submit action. If the debounce constant changes, the helper needs the matching update.
- **`BbSuccessOverlay` has staggered timers** (mascot 100 ms + text 250 ms + animation durations ≤ 600 ms). `pumpAndSettle` with the default 10 s timeout drains them. Test 4 dismisses by tapping the overlay's `GestureDetector` (`tester.tap(find.byType(BbSuccessOverlay))`).
- **`testTextInput.receiveAction(TextInputAction.done)` requires a focused TextField.** The `EditableAppBarTitle`'s autofocus on mount provides the first one; the `+ Hinzufügen` tap focuses the IngredientSearch field via its post-frame `requestFocus`. Both have been verified to work in widget tests.
- **`MealImageSection` empty state on Test 4** assumes `hasRecipes` resolved to `true` before the `Rezept` button is tappable. The post-frame `userRecipesProvider.fetch()` runs synchronously against the seeded fake (no network), so the first `pumpAndSettle` after entering the meal tracker should land in the data state.
- **Test 5 assumes `state.savedImageUrl` is `null`** because no image was picked. The save-as-recipe callout still renders correctly with a null `imageUrl` — the recipe is created with `imageUrl: null`.
