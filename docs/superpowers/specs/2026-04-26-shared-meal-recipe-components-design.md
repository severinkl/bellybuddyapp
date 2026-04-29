# Shared editable-title and ingredient-section components — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** Extract two reusable widgets and a shared Riverpod provider so the meal tracker and recipe editor share UX for the title-in-AppBar and the ingredient input section.

## Problem

Today the meal tracker has a polished tap-to-edit title in the AppBar plus a fully featured ingredient section with autocomplete (powered by `mealTrackerProvider.ingredientSuggestions` and `ingredientRepository.search`). The recipe editor has neither: its title is a labeled `TextField` in the body, and its ingredient input is a plain `TextField + OutlinedButton('Hinzufügen')`. Three concrete consequences:

1. Two different visual treatments for the same concept (title) inside the same app.
2. The recipe editor doesn't get autocomplete, so users re-type ingredients they've already entered into the system.
3. The "Titel" body field eats vertical space the AppBar already provides for free.

## Goal

- One `EditableAppBarTitle` widget used by both screens for the inline-tap-to-edit title pattern.
- One `IngredientSearch` widget used by both screens for ingredient input with autocomplete.
- One `ingredientSuggestionsProvider` as the single source of truth for autocomplete suggestions across the app — adding an ingredient anywhere should make it autocomplete everywhere.
- Recipe editor: title moves to AppBar; auto-enter edit mode on first mount when creating a new recipe; the body's "Titel" `TextField` is removed.

## Approach

### Component layout

**Create:**
- `lib/widgets/common/editable_app_bar_title.dart` — `EditableAppBarTitle` (`StatefulWidget`).
- `lib/widgets/common/ingredient_search.dart` — `IngredientSearch` (moved from `lib/screens/trackers/meal/widgets/`).
- `lib/providers/ingredient_suggestions_provider.dart` — shared `Notifier` exposing `suggestions`, `searchIngredients(query)`, `addIngredient(name)`, `deleteUserIngredient(id)`.

**Modify:**
- `lib/screens/recipes/recipe_editor_screen.dart` — title moves to AppBar via `EditableAppBarTitle`; body title `TextField` removed; `_buildIngredientSection` replaced with the shared `IngredientSearch` wired to the shared provider.
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — inline editable-title plumbing replaced with `EditableAppBarTitle`; ingredient suggestions read from the shared provider instead of `mealTrackerProvider.state.ingredientSuggestions`.
- `lib/providers/meal_tracker_provider.dart` — drops `ingredientSuggestions` and `ingredientSearchError` fields; drops `searchIngredients()` and `deleteUserIngredient()` methods; `addIngredient()` keeps the per-tracker list update but delegates the DB `insertIfNew` to the shared provider.

**Delete:**
- `lib/screens/trackers/meal/widgets/ingredient_search.dart` (moved to common).

### `EditableAppBarTitle` contract

```dart
class EditableAppBarTitle extends StatefulWidget {
  final String initialTitle;
  final String placeholder;          // 'Rezept benennen' / 'Mahlzeit benennen'
  final bool autofocusOnMount;       // recipe-create: true; everything else: false
  final ValueChanged<String> onChanged;

  const EditableAppBarTitle({
    super.key,
    required this.initialTitle,
    required this.placeholder,
    required this.onChanged,
    this.autofocusOnMount = false,
  });
}
```

Internal state owns `TextEditingController`, `FocusNode`, and `_isEditing` flag.

- **Display mode**: `Row(children: [Flexible(child: Text(_controller.text or muted placeholder)), SizedBox(spacingXs), Icon(Icons.edit, size: 16, color: AppTheme.mutedForeground)])` wrapped in a `GestureDetector` that flips `_isEditing` to `true` and requests focus in a post-frame callback.
- **Edit mode**: `TextField(controller: _controller, autofocus: true, focusNode: _focusNode)` styled to match the AppBar title typography. Commits on `onSubmitted` (calls `widget.onChanged(value.trim())` and flips `_isEditing` to `false`). The `FocusNode` listener also commits on blur.
- **`autofocusOnMount: true`**: `_isEditing` initializes to `true`. `initState` schedules `_focusNode.requestFocus()` via `WidgetsBinding.instance.addPostFrameCallback` so it fires after the route transition completes (otherwise the keyboard opens mid-animation and feels janky).
- **Placeholder**: when `_controller.text.trim().isEmpty` in display mode, render `widget.placeholder` with `color: AppTheme.mutedForeground`. The pencil icon stays visible.

### `IngredientSearch` move

The widget moves verbatim from `lib/screens/trackers/meal/widgets/ingredient_search.dart` to `lib/widgets/common/ingredient_search.dart`. Its public contract is unchanged:

```dart
IngredientSearch({
  required List<String> ingredients,
  required List<IngredientSearchResult> suggestions,
  required ValueChanged<String> onSearch,
  required ValueChanged<String> onAdd,
  required ValueChanged<String> onRemove,
  required ValueChanged<String> onDeleteIngredient,
});
```

Update relative imports inside the file:
- `'../../../../config/app_theme.dart'` → `'../../config/app_theme.dart'`
- `'../../../../models/ingredient_search_result.dart'` → `'../../models/ingredient_search_result.dart'`
- `'../../../../config/constants.dart'` → `'../../config/constants.dart'`

### `ingredientSuggestionsProvider`

```dart
class IngredientSuggestionsState {
  final List<IngredientSearchResult> suggestions;
  final Object? searchError;

  const IngredientSuggestionsState({
    this.suggestions = const [],
    this.searchError,
  });

  IngredientSuggestionsState copyWith({
    List<IngredientSearchResult>? suggestions,
    Object? searchError,
  }) => IngredientSuggestionsState(
        suggestions: suggestions ?? this.suggestions,
        searchError: searchError,
      );
}

class IngredientSuggestionsNotifier extends Notifier<IngredientSuggestionsState> {
  static const _log = AppLogger('IngredientSuggestions');

  @override
  IngredientSuggestionsState build() => const IngredientSuggestionsState();

  Future<void> searchIngredients(String query) async {
    if (query.length < 3) {
      state = state.copyWith(suggestions: []);
      return;
    }
    state = state.copyWith(searchError: null);
    try {
      final userId = ref.read(currentUserIdProvider);
      final results = await ref
          .read(ingredientRepositoryProvider)
          .search(query, userId: userId);
      state = state.copyWith(suggestions: results);
    } catch (e, st) {
      _log.error('search failed', e, st);
      state = state.copyWith(searchError: e);
    }
  }

  Future<void> addIngredient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(suggestions: []);
    final userId = ref.read(currentUserIdProvider);
    await ref
        .read(ingredientRepositoryProvider)
        .insertIfNew(trimmed, userId: userId);
  }

  Future<void> deleteUserIngredient(String id) async {
    await ref.read(ingredientRepositoryProvider).deleteUserIngredient(id);
    state = state.copyWith(
      suggestions: state.suggestions.where((s) => s.id != id).toList(),
    );
  }
}

final ingredientSuggestionsProvider =
    NotifierProvider<IngredientSuggestionsNotifier, IngredientSuggestionsState>(
  IngredientSuggestionsNotifier.new,
);
```

Both screens read `ref.watch(ingredientSuggestionsProvider).suggestions` and call notifier methods directly. The query-length-3 short-circuit, the `<3` clearing behavior, and the `insertIfNew` semantics match what `mealTrackerProvider` currently does — no behavior change for the meal tracker user.

### Meal tracker provider refactor

`MealTrackerState`: remove `ingredientSuggestions` and `ingredientSearchError` fields (and from `copyWith`). Keep `ingredients` (per-tracker list).

`MealTrackerNotifier`:
- Remove `searchIngredients()` method.
- Remove `deleteUserIngredient()` method.
- `addIngredient(name)` keeps its per-tracker-list update and delegates the DB write to the shared notifier:

```dart
void addIngredient(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || state.ingredients.contains(trimmed)) return;
  state = state.copyWith(ingredients: [...state.ingredients, trimmed]);
  ref.read(ingredientSuggestionsProvider.notifier).addIngredient(trimmed);
}
```

- `removeIngredient(name)` unchanged.

### Recipe editor wiring

```dart
// AppBar
appBar: AppBar(
  backgroundColor: AppTheme.screenBackground,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => context.pop(),
  ),
  title: EditableAppBarTitle(
    initialTitle: _title,
    placeholder: 'Rezept benennen',
    autofocusOnMount: !_isEditMode,
    onChanged: (v) => setState(() => _title = v),
  ),
),
```

Body changes:
- The `TextField(labelText: 'Titel', …)` block (and the surrounding `AppConstants.gap16`) is **deleted**. Body now starts directly with `MealImageSection`.
- `_buildIngredientSection()` and the helpers `_addIngredient`, `_removeIngredient`, `_ingredientController` are **deleted**.
- The ingredient slot becomes:

```dart
Consumer(
  builder: (context, ref, _) {
    final suggestions = ref.watch(ingredientSuggestionsProvider).suggestions;
    final notifier = ref.read(ingredientSuggestionsProvider.notifier);
    return IngredientSearch(
      ingredients: _ingredients,
      suggestions: suggestions,
      onSearch: notifier.searchIngredients,
      onAdd: (name) {
        if (_ingredients.contains(name)) return;
        setState(() => _ingredients = [..._ingredients, name]);
        notifier.addIngredient(name);
      },
      onRemove: (name) => setState(() {
        _ingredients = _ingredients.where((i) => i != name).toList();
      }),
      onDeleteIngredient: notifier.deleteUserIngredient,
    );
  },
),
```

State refactor on `_RecipeEditorScreenState`:
- `_titleController` and `_ingredientController` are removed.
- A new field `String _title = '';` is added; `_prefillFromProvider` writes `_title = recipe.title` instead of `_titleController.text = recipe.title`.
- `_save()` reads `_title.trim()` (not `_titleController.text.trim()`).
- The bottom-bar `BbButton`'s `titleEmpty` becomes `_title.trim().isEmpty`.

### Meal tracker wiring

The existing inline title block (the `GestureDetector`/`_isEditingTitle`/`TextField` shape spanning ~35 lines) is replaced with a single call:

```dart
titleWidget: EditableAppBarTitle(
  initialTitle: state.title,
  placeholder: 'Mahlzeit benennen',
  autofocusOnMount: false,
  onChanged: (v) => ref.read(mealTrackerProvider.notifier).setTitle(v),
),
```

Drop `_titleController` and `_isEditingTitle` fields from `_MealTrackerScreenState` (the widget owns them now).

The ingredient-section site now reads suggestions from the shared provider:

```dart
Consumer(
  builder: (context, ref, _) {
    final suggestions = ref.watch(ingredientSuggestionsProvider).suggestions;
    final suggestionsNotifier = ref.read(ingredientSuggestionsProvider.notifier);
    final trackerNotifier = ref.read(mealTrackerProvider.notifier);
    return IngredientSearch(
      ingredients: state.ingredients,
      suggestions: suggestions,
      onSearch: suggestionsNotifier.searchIngredients,
      onAdd: trackerNotifier.addIngredient,
      onRemove: trackerNotifier.removeIngredient,
      onDeleteIngredient: suggestionsNotifier.deleteUserIngredient,
    );
  },
),
```

Update the `IngredientSearch` import path: `widgets/ingredient_search.dart` → `../../../widgets/common/ingredient_search.dart`.

### Tests

- **New**: `test/widgets/common/editable_app_bar_title_test.dart`
  - Display ↔ edit toggle on tap.
  - `onChanged` fires with trimmed value on `onSubmitted`.
  - `autofocusOnMount: true` puts the widget in edit mode on first frame.
  - Placeholder shows when title empty in display mode.
- **Move**: `test/screens/trackers/meal/widgets/ingredient_search_test.dart` (if it exists) → `test/widgets/common/ingredient_search_test.dart`. Content unchanged.
- **New**: `test/providers/ingredient_suggestions_provider_test.dart`
  - Query <3 chars clears suggestions.
  - Successful search populates suggestions.
  - `deleteUserIngredient` removes the entry from state and calls the repository.
- **Update**: `test/providers/meal_tracker_provider_test.dart`
  - Drop assertions on `state.ingredientSuggestions`, `state.ingredientSearchError`, `searchIngredients`, `deleteUserIngredient`.
  - Add an assertion that `addIngredient` updates `state.ingredients`.
- **Update**: any meal-tracker-screen widget test that pumped state with `ingredientSuggestions` populated — re-wire to override `ingredientSuggestionsProvider` with a stub instead.

## Acceptance

- Recipe editor `/recipe/new`: opens with the AppBar title in edit mode, keyboard up; user types a name and taps the body to commit; AppBar shows the name + pencil icon; tapping the name re-enters edit mode.
- Recipe editor `/recipe/:id/edit`: opens in display mode with the prefilled title in the AppBar; tap to edit.
- Recipe editor body no longer has a labeled "Titel" field. The title field is gone from the body entirely.
- Recipe editor's ingredient section visually matches the meal tracker's: `Zutaten` header + `+ Hinzufügen` link → inline search field with autocomplete suggestions → tap suggestion or hit enter to add → chip rendered below. The trash icon next to a current-user-added suggestion deletes it from the user's library.
- Meal tracker: editable title and ingredient section unchanged in observable behavior.
- Adding an ingredient in the recipe editor makes it appear as a suggestion the next time the meal tracker types the same prefix (and vice versa).
- `flutter analyze` clean. `dart format --set-exit-if-changed` clean.

## Risks

- `EditableAppBarTitle.autofocusOnMount: true` fires during route transition. Mitigation: `requestFocus()` runs in a post-frame callback so it lands after the AppBar is mounted.
- Removing `MealTrackerState.ingredientSuggestions` is a breaking change for any external reader. Search confirms only `meal_tracker_provider.dart` and `meal_tracker_screen.dart` reference the field today; both are updated in this change.
- The shared `addIngredient` writes to the DB via `insertIfNew`. If two screens add the same ingredient concurrently, the second `ilike`-based existence check in `insertIfNew` short-circuits — no duplicate row.

## Out of scope

- Replacing the chip Wrap at the bottom of `IngredientSearch` with a different visual style.
- A separate "rename" intent (single-tap-to-edit covers it).
- Migrating the per-tracker `ingredients` list off `mealTrackerProvider` (still per-tracker scope).
- Sharing other meal-tracker UI (image picker, save-as-recipe callout) with the recipe editor.
