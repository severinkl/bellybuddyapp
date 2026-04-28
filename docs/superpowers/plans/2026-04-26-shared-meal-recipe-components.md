# Shared meal/recipe components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a shared editable-AppBar-title widget, share `IngredientSearch` between meal tracker and recipe editor, and consolidate ingredient autocomplete into a single Riverpod provider.

**Architecture:** Three reusable units in `lib/widgets/common/` and `lib/providers/`. Both screens consume them. The `MealTrackerProvider` loses its autocomplete responsibilities (state field + two methods); the recipe editor loses its body title field and its hand-rolled ingredient input.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Supabase (via `IngredientRepository`), `mocktail` for tests.

**Spec:** `docs/superpowers/specs/2026-04-26-shared-meal-recipe-components-design.md`

**Naming note:** the spec uses `ingredientSuggestionsProvider`. There's already a `lib/providers/ingredient_suggestion_provider.dart` (singular, dashboard-banner concept). To avoid collision, this plan implements the new shared autocomplete provider as **`ingredientAutocompleteProvider`** at `lib/providers/ingredient_autocomplete_provider.dart`.

---

## File map

**Create**
- `lib/widgets/common/editable_app_bar_title.dart`
- `lib/providers/ingredient_autocomplete_provider.dart`
- `test/widgets/common/editable_app_bar_title_test.dart`
- `test/providers/ingredient_autocomplete_provider_test.dart`

**Move (rename + update imports)**
- `lib/screens/trackers/meal/widgets/ingredient_search.dart` → `lib/widgets/common/ingredient_search.dart`

**Modify**
- `lib/providers/meal_tracker_provider.dart` (remove `ingredientSuggestions`, `ingredientSearchError`, `searchIngredients`, `deleteUserIngredient`; delegate `addIngredient`'s DB write)
- `lib/screens/trackers/meal/meal_tracker_screen.dart` (replace title block; rewire ingredient slot; update import path)
- `lib/screens/recipes/recipe_editor_screen.dart` (move title to AppBar, drop body title `TextField`, replace `_buildIngredientSection` with shared widget)
- `test/providers/meal_tracker_provider_test.dart` (drop assertions on removed fields/methods; verify `addIngredient` updates `state.ingredients`)

---

### Task 1: `EditableAppBarTitle` widget

**Files:**
- Create: `lib/widgets/common/editable_app_bar_title.dart`
- Test: `test/widgets/common/editable_app_bar_title_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/common/editable_app_bar_title_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/widgets/common/editable_app_bar_title.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(appBar: AppBar(title: child)),
    );

void main() {
  group('EditableAppBarTitle', () {
    testWidgets('renders title text + pencil icon in display mode', (tester) async {
      await tester.pumpWidget(_wrap(EditableAppBarTitle(
        initialTitle: 'Mahlzeit X',
        placeholder: 'Mahlzeit benennen',
        onChanged: (_) {},
      )));

      expect(find.text('Mahlzeit X'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('shows placeholder when title is empty', (tester) async {
      await tester.pumpWidget(_wrap(EditableAppBarTitle(
        initialTitle: '',
        placeholder: 'Mahlzeit benennen',
        onChanged: (_) {},
      )));

      expect(find.text('Mahlzeit benennen'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('tapping the title enters edit mode with a TextField', (tester) async {
      await tester.pumpWidget(_wrap(EditableAppBarTitle(
        initialTitle: 'Mahlzeit X',
        placeholder: 'Mahlzeit benennen',
        onChanged: (_) {},
      )));

      await tester.tap(find.text('Mahlzeit X'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('onChanged fires with trimmed value on submit; widget returns to display mode',
        (tester) async {
      String? captured;
      await tester.pumpWidget(_wrap(EditableAppBarTitle(
        initialTitle: '',
        placeholder: 'Mahlzeit benennen',
        onChanged: (v) => captured = v,
      )));

      await tester.tap(find.text('Mahlzeit benennen'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '  Pizza Funghi  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(captured, equals('Pizza Funghi'));
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Pizza Funghi'), findsOneWidget);
    });

    testWidgets('autofocusOnMount: true starts in edit mode', (tester) async {
      await tester.pumpWidget(_wrap(EditableAppBarTitle(
        initialTitle: '',
        placeholder: 'Rezept benennen',
        autofocusOnMount: true,
        onChanged: (_) {},
      )));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/common/editable_app_bar_title_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:belly_buddy/widgets/common/editable_app_bar_title.dart'`.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/common/editable_app_bar_title.dart`:

```dart
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// AppBar title that flips between a tappable label and an inline TextField.
///
/// Owns its own controller, focus node, and edit-mode flag. Parents pass
/// the current title and receive a trimmed string via [onChanged] when the
/// user commits (submit or blur).
class EditableAppBarTitle extends StatefulWidget {
  final String initialTitle;
  final String placeholder;
  final bool autofocusOnMount;
  final ValueChanged<String> onChanged;

  const EditableAppBarTitle({
    super.key,
    required this.initialTitle,
    required this.placeholder,
    required this.onChanged,
    this.autofocusOnMount = false,
  });

  @override
  State<EditableAppBarTitle> createState() => _EditableAppBarTitleState();
}

class _EditableAppBarTitleState extends State<EditableAppBarTitle> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
    _focusNode = FocusNode();
    _isEditing = widget.autofocusOnMount;

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _commit();
      }
    });

    if (widget.autofocusOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant EditableAppBarTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External writes (e.g. recipe edit-mode prefill that happens after first
    // build) should reflect in the displayed text without disturbing the
    // user mid-edit.
    if (!_isEditing && widget.initialTitle != _controller.text) {
      _controller.text = widget.initialTitle;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _controller.text.trim();
    widget.onChanged(value);
    if (mounted) setState(() => _isEditing = false);
  }

  void _enterEdit() {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeTitle,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.placeholder,
        ),
        onSubmitted: (_) => _commit(),
      );
    }

    final text = _controller.text.trim();
    final isEmpty = text.isEmpty;
    return GestureDetector(
      onTap: _enterEdit,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isEmpty ? widget.placeholder : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: isEmpty ? AppTheme.mutedForeground : null,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingXs),
          const Icon(Icons.edit, size: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/common/editable_app_bar_title_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run analyze + format**

Run: `flutter analyze lib/widgets/common/editable_app_bar_title.dart test/widgets/common/editable_app_bar_title_test.dart`
Expected: No issues found.

Run: `dart format lib/widgets/common/editable_app_bar_title.dart test/widgets/common/editable_app_bar_title_test.dart`
Expected: 0 changed (or 2 reformatted — re-stage if so).

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/common/editable_app_bar_title.dart test/widgets/common/editable_app_bar_title_test.dart
git commit -m "feat: add EditableAppBarTitle shared widget

Tap-to-edit AppBar title with placeholder + pencil icon. Will be
reused by the meal tracker and recipe editor."
```

---

### Task 2: Move `IngredientSearch` to `lib/widgets/common/`

**Files:**
- Delete: `lib/screens/trackers/meal/widgets/ingredient_search.dart`
- Create: `lib/widgets/common/ingredient_search.dart` (same contents, fixed imports)
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart:19` (one import line)

This task is purely a move. Public API is unchanged. The meal tracker still works after the move; no other files import `IngredientSearch` today.

- [ ] **Step 1: Verify no other imports**

Run: `grep -rn "trackers/meal/widgets/ingredient_search.dart" lib test --include="*.dart"`
Expected: only `lib/screens/trackers/meal/meal_tracker_screen.dart:19` (one match).

- [ ] **Step 2: Create the new file**

Create `lib/widgets/common/ingredient_search.dart` with the contents below. The only diffs versus the old file are the three relative import paths at the top (now two levels up instead of four).

```dart
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/ingredient_search_result.dart';

class IngredientSearch extends StatefulWidget {
  final List<String> ingredients;
  final List<IngredientSearchResult> suggestions;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onDeleteIngredient;

  const IngredientSearch({
    super.key,
    required this.ingredients,
    required this.suggestions,
    required this.onSearch,
    required this.onAdd,
    required this.onRemove,
    required this.onDeleteIngredient,
  });

  @override
  State<IngredientSearch> createState() => _IngredientSearchState();
}

class _IngredientSearchState extends State<IngredientSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isAdding) {
        _submitIngredient();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitIngredient() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
    widget.onSearch('');
    setState(() => _isAdding = false);
  }

  void _scrollToField() {
    if (!mounted) return;
    final ctx = _focusNode.context;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: AppConstants.animMedium,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuggestions = widget.suggestions
        .where((s) => !widget.ingredients.contains(s.name))
        .toList();

    return Container(
      padding: AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Zutaten',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSubtitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              if (_isAdding)
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                    decoration: InputDecoration(
                      hintText: 'Mind. 3 Zeichen...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          _controller.clear();
                          widget.onSearch('');
                          setState(() => _isAdding = false);
                        },
                        child: const Icon(Icons.close, size: 18),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    onChanged: widget.onSearch,
                    onSubmitted: (_) => _submitIngredient(),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    setState(() => _isAdding = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _focusNode.requestFocus();
                      Future.delayed(AppConstants.animSlow, _scrollToField);
                    });
                  },
                  child: const Text(
                    '+ Hinzufügen',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (_isAdding && filteredSuggestions.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: filteredSuggestions.map((s) {
                  return ListTile(
                    title: Text(s.name),
                    dense: true,
                    onTap: () {
                      widget.onAdd(s.name);
                      _controller.clear();
                      widget.onSearch('');
                      setState(() => _isAdding = false);
                    },
                    trailing: s.isOwn
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppTheme.mutedForeground,
                            ),
                            onPressed: () => widget.onDeleteIngredient(s.id),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],
          if (widget.ingredients.isNotEmpty) ...[
            AppConstants.gap8,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  labelStyle: const TextStyle(color: Colors.black),
                  onDeleted: () => widget.onRemove(ingredient),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update the meal tracker import**

In `lib/screens/trackers/meal/meal_tracker_screen.dart`, change line 19:

Old:
```dart
import 'widgets/ingredient_search.dart';
```

New:
```dart
import '../../../widgets/common/ingredient_search.dart';
```

- [ ] **Step 4: Delete the old file**

```bash
git rm lib/screens/trackers/meal/widgets/ingredient_search.dart
```

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib`
Expected: No issues found.

- [ ] **Step 6: Run the existing meal-tracker tests to confirm nothing broke**

Run: `flutter test test/providers/meal_tracker_provider_test.dart`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/common/ingredient_search.dart lib/screens/trackers/meal/meal_tracker_screen.dart
git commit -m "refactor: move IngredientSearch to widgets/common

Pure move, no behavior change. Recipe editor will reuse it next."
```

---

### Task 3: `ingredientAutocompleteProvider`

**Files:**
- Create: `lib/providers/ingredient_autocomplete_provider.dart`
- Test: `test/providers/ingredient_autocomplete_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/providers/ingredient_autocomplete_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/ingredient_search_result.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_autocomplete_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockIngredientRepository mockRepo;

  setUp(() {
    mockRepo = MockIngredientRepository();
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('IngredientAutocompleteNotifier.searchIngredients', () {
    test('returns empty list when query is shorter than 3 chars', () async {
      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .searchIngredients('ab');

      expect(
        container.read(ingredientAutocompleteProvider).suggestions,
        isEmpty,
      );
      verifyNever(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      );
    });

    test('populates suggestions for 3+ char query', () async {
      when(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const [
          IngredientSearchResult(id: 'i-1', name: 'Zwiebel', isOwn: false),
        ],
      );

      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .searchIngredients('Zwi');

      final state = container.read(ingredientAutocompleteProvider);
      expect(state.suggestions, hasLength(1));
      expect(state.suggestions.first.name, equals('Zwiebel'));
    });

    test('captures error in state instead of throwing', () async {
      when(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      ).thenThrow(Exception('boom'));

      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .searchIngredients('Zwi');

      expect(
        container.read(ingredientAutocompleteProvider).searchError,
        isNotNull,
      );
    });
  });

  group('IngredientAutocompleteNotifier.addIngredient', () {
    test('clears suggestions and calls insertIfNew', () async {
      when(
        () => mockRepo.insertIfNew(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .addIngredient('  Tomate  ');

      expect(
        container.read(ingredientAutocompleteProvider).suggestions,
        isEmpty,
      );
      verify(
        () => mockRepo.insertIfNew('Tomate', userId: testUserId),
      ).called(1);
    });

    test('skips DB write when name is empty after trim', () async {
      final container = makeContainer();
      await container
          .read(ingredientAutocompleteProvider.notifier)
          .addIngredient('   ');

      verifyNever(
        () => mockRepo.insertIfNew(any(), userId: any(named: 'userId')),
      );
    });
  });

  group('IngredientAutocompleteNotifier.deleteUserIngredient', () {
    test('removes the entry from state and calls the repo', () async {
      when(
        () => mockRepo.search(any(), userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const [
          IngredientSearchResult(id: 'i-1', name: 'A', isOwn: true),
          IngredientSearchResult(id: 'i-2', name: 'B', isOwn: false),
        ],
      );
      when(() => mockRepo.deleteUserIngredient('i-1')).thenAnswer((_) async {});

      final container = makeContainer();
      final notifier = container.read(ingredientAutocompleteProvider.notifier);
      await notifier.searchIngredients('abc');
      await notifier.deleteUserIngredient('i-1');

      expect(
        container
            .read(ingredientAutocompleteProvider)
            .suggestions
            .map((s) => s.id),
        ['i-2'],
      );
      verify(() => mockRepo.deleteUserIngredient('i-1')).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/ingredient_autocomplete_provider_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:belly_buddy/providers/ingredient_autocomplete_provider.dart'`.

- [ ] **Step 3: Implement the provider**

Create `lib/providers/ingredient_autocomplete_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingredient_search_result.dart';
import '../repositories/ingredient_repository.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

class IngredientAutocompleteState {
  final List<IngredientSearchResult> suggestions;
  final Object? searchError;

  const IngredientAutocompleteState({
    this.suggestions = const [],
    this.searchError,
  });

  IngredientAutocompleteState copyWith({
    List<IngredientSearchResult>? suggestions,
    Object? searchError,
  }) =>
      IngredientAutocompleteState(
        suggestions: suggestions ?? this.suggestions,
        searchError: searchError,
      );
}

class IngredientAutocompleteNotifier
    extends Notifier<IngredientAutocompleteState> {
  static const _log = AppLogger('IngredientAutocomplete');

  @override
  IngredientAutocompleteState build() => const IngredientAutocompleteState();

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

final ingredientAutocompleteProvider = NotifierProvider<
    IngredientAutocompleteNotifier, IngredientAutocompleteState>(
  IngredientAutocompleteNotifier.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/ingredient_autocomplete_provider_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Run analyze + format**

Run: `flutter analyze lib/providers/ingredient_autocomplete_provider.dart test/providers/ingredient_autocomplete_provider_test.dart`
Expected: No issues found.

Run: `dart format lib/providers/ingredient_autocomplete_provider.dart test/providers/ingredient_autocomplete_provider_test.dart`
Expected: 0 changed.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/ingredient_autocomplete_provider.dart test/providers/ingredient_autocomplete_provider_test.dart
git commit -m "feat: add ingredientAutocompleteProvider

Single source of truth for ingredient autocomplete shared by the meal
tracker and the recipe editor."
```

---

### Task 4: Strip autocomplete from `MealTrackerProvider`

**Files:**
- Modify: `lib/providers/meal_tracker_provider.dart` (remove `ingredientSuggestions`, `ingredientSearchError`, `searchIngredients`, `deleteUserIngredient`; delegate `addIngredient`'s DB write)
- Modify: `test/providers/meal_tracker_provider_test.dart` (drop the `searchIngredients` group; update `addIngredient` group to verify the shared provider's DB call)

- [ ] **Step 1: Update the meal tracker provider tests to reflect the new contract (failing)**

Open `test/providers/meal_tracker_provider_test.dart`. Apply these edits:

1. **Remove** the entire `group('MealTrackerNotifier.searchIngredients', ...)` block at lines 112-150.
2. **Replace** the `group('MealTrackerNotifier.addIngredient', ...)` block (lines 152-187) with:

```dart
  group('MealTrackerNotifier.addIngredient', () {
    test('adds ingredient to state.ingredients', () {
      final container = makeContainer();
      container.read(mealTrackerProvider.notifier).addIngredient('Tomate');

      expect(
        container.read(mealTrackerProvider).ingredients,
        contains('Tomate'),
      );
    });

    test('skips duplicate ingredients', () {
      final container = makeContainer();
      final notifier = container.read(mealTrackerProvider.notifier);
      notifier.addIngredient('Tomate');
      notifier.addIngredient('Tomate');

      expect(
        container
            .read(mealTrackerProvider)
            .ingredients
            .where((i) => i == 'Tomate'),
        hasLength(1),
      );
    });

    test('delegates DB write to the shared autocomplete provider', () {
      when(
        () =>
            mockIngredientRepo.insertIfNew(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      container.read(mealTrackerProvider.notifier).addIngredient('Tomate');

      verify(
        () =>
            mockIngredientRepo.insertIfNew('Tomate', userId: testUserId),
      ).called(1);
    });
  });
```

3. **Remove** the now-unused import of `IngredientSearchResult` if the analyzer flags it (only after Step 3 below removes references in the production code).

- [ ] **Step 2: Run the updated tests to confirm they fail**

Run: `flutter test test/providers/meal_tracker_provider_test.dart`
Expected: Compile error / FAIL — `searchIngredients` and `state.ingredientSuggestions` are still on the production class but the test file no longer references them; production code still has them, so we need to delete production references next.

- [ ] **Step 3: Update `lib/providers/meal_tracker_provider.dart`**

Apply the following edits in order.

**3a.** Remove unused import. At line 9 delete:
```dart
import '../models/ingredient_search_result.dart';
```

**3b.** In `MealTrackerState` (lines 20-118), remove the two fields and their plumbing.

Delete from the field list (lines 30-31):
```dart
  final List<IngredientSearchResult> ingredientSuggestions;
  final Object? ingredientSearchError;
```

Delete from the constructor (lines 50-51):
```dart
    this.ingredientSuggestions = const [],
    this.ingredientSearchError,
```

Delete from the `copyWith` parameters (lines 86-87):
```dart
    List<IngredientSearchResult>? ingredientSuggestions,
    Object? ingredientSearchError,
```

Delete from the `copyWith` body (lines 108-110):
```dart
      ingredientSuggestions:
          ingredientSuggestions ?? this.ingredientSuggestions,
      ingredientSearchError: ingredientSearchError,
```

**3c.** In `MealTrackerNotifier`, delete `searchIngredients` (lines 194-210) and `deleteUserIngredient` (lines 233-240) entirely.

**3d.** Replace `addIngredient` (lines 212-225) so it delegates to the shared provider:

```dart
  void addIngredient(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.ingredients.contains(trimmed)) return;
    state = state.copyWith(ingredients: [...state.ingredients, trimmed]);
    ref.read(ingredientAutocompleteProvider.notifier).addIngredient(trimmed);
  }
```

**3e.** Add the new import near the top of the file (next to the other relative imports inside `lib/providers/`):

```dart
import 'ingredient_autocomplete_provider.dart';
```

- [ ] **Step 4: Run the meal tracker provider tests**

Run: `flutter test test/providers/meal_tracker_provider_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Run the broader analyze**

Run: `flutter analyze lib`
Expected: At least one error in `lib/screens/trackers/meal/meal_tracker_screen.dart` (it still calls `notifier.searchIngredients`, `notifier.deleteUserIngredient`, and reads `state.ingredientSuggestions`). That's intentional — fixed in Task 5.

Don't commit yet — Task 5 closes the compile gap.

---

### Task 5: Wire meal tracker screen to shared provider + `EditableAppBarTitle`

**Files:**
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart`

- [ ] **Step 1: Add the new imports**

In `lib/screens/trackers/meal/meal_tracker_screen.dart` near the top, add (alphabetized with the other `../../../` provider/widget imports):

```dart
import '../../../providers/ingredient_autocomplete_provider.dart';
import '../../../widgets/common/editable_app_bar_title.dart';
```

- [ ] **Step 2: Replace the inline editable-title block**

Replace lines 205-242 (the `titleWidget: GestureDetector(...)` block) with:

```dart
        titleWidget: EditableAppBarTitle(
          key: MealTrackerScreen.mealTrackerTitleKey,
          initialTitle: state.title == kDefaultMealTitle ? '' : state.title,
          placeholder: kDefaultMealTitle,
          onChanged: (v) {
            final notifier = ref.read(mealTrackerProvider.notifier);
            notifier.setTitle(v.isEmpty ? kDefaultMealTitle : v);
          },
        ),
```

- [ ] **Step 3: Delete `_titleController` and `_isEditingTitle`**

Remove the field declarations on lines 64-65:
```dart
  final _titleController = TextEditingController(text: kDefaultMealTitle);
  bool _isEditingTitle = false;
```

Remove `_titleController.dispose();` from `dispose()` at line 120.

The widget no longer has an internal title controller — `state.title` (already in `MealTrackerState`) is the source of truth. Search the file for remaining `_titleController` references and rewrite each one:

- **Line ~94** (inside `initState`'s `prefillFromRecipe` branch): `_titleController.text = widget.initialRecipe!.title;` — **delete the line**. `prefillFromRecipe` already updates `state.title`.
- **Line ~107** (after `notifier.seed(meal)`): `_titleController.text = meal.title;` — **delete the line**. `seed` already updates `state.title`.
- **Line ~126** (top of `_save`): `notifier.setTitle(_titleController.text);` — **delete the line**. The `EditableAppBarTitle.onChanged` callback has already pushed the latest value into state.
- **Line ~138** (inside `_save`'s default-title check): `if (_titleController.text.trim() == kDefaultMealTitle)` — replace with `if (state.title.trim() == kDefaultMealTitle)`. Note: `state` is not in scope inside `_save`; introduce `final state = ref.read(mealTrackerProvider);` at the top of `_save` (alongside the existing `notifier` line) and use it throughout the method.
- **Line ~145** (inside `MealTitleEntered` case): `_titleController.text = t;` — **delete the line** (notifier already setTitle'd).
- **Line ~387** (inside `MealImageSection.onImagePicked`'s success branch): `_titleController.text = s.title;` — **delete the line**.
- **Line ~399** (inside `MealImageSection.onClearImage`): `_titleController.text = kDefaultMealTitle;` — replace with `notifier.setTitle(kDefaultMealTitle);`.
- **Line ~452** (inside `_buildRecipeSelectorFab`): `_titleController.text = recipe.title;` — **delete the line** (`prefillFromRecipe` already updates state).

- [ ] **Step 4: Replace the ingredient `IngredientSearch` site**

In `_buildBody`, replace the `IngredientSearch(...)` block (lines 405-412) with:

```dart
          // 3. Ingredients
          Consumer(
            builder: (context, ref, _) {
              final autocomplete = ref.watch(ingredientAutocompleteProvider);
              final autocompleteNotifier =
                  ref.read(ingredientAutocompleteProvider.notifier);
              final trackerNotifier = ref.read(mealTrackerProvider.notifier);
              return IngredientSearch(
                ingredients: state.ingredients,
                suggestions: autocomplete.suggestions,
                onSearch: autocompleteNotifier.searchIngredients,
                onAdd: trackerNotifier.addIngredient,
                onRemove: trackerNotifier.removeIngredient,
                onDeleteIngredient: autocompleteNotifier.deleteUserIngredient,
              );
            },
          ),
```

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib/screens/trackers/meal/meal_tracker_screen.dart`
Expected: No issues found.

- [ ] **Step 6: Run all meal-tracker-related tests**

Run: `flutter test test/providers/meal_tracker_provider_test.dart test/screens/trackers/meal/`
Expected: All tests pass. If a screen test fails because it expected `state.ingredientSuggestions` or asserted on the old title block, update those test setups to use `ingredientAutocompleteProvider.overrideWithValue` and to expect the `EditableAppBarTitle` rendering (search by `find.byType(EditableAppBarTitle)` or by the existing `MealTrackerScreen.mealTrackerTitleKey`).

- [ ] **Step 7: Run format**

Run: `dart format lib/providers/meal_tracker_provider.dart lib/screens/trackers/meal/meal_tracker_screen.dart test/providers/meal_tracker_provider_test.dart`
Expected: 0 changed (or files reformatted — re-stage if so).

- [ ] **Step 8: Commit**

```bash
git add lib/providers/meal_tracker_provider.dart lib/screens/trackers/meal/meal_tracker_screen.dart test/providers/meal_tracker_provider_test.dart
git commit -m "refactor: meal tracker uses shared autocomplete + title widgets

MealTrackerProvider no longer owns ingredient autocomplete state.
Inline editable-title plumbing replaced with EditableAppBarTitle."
```

---

### Task 6: Recipe editor — title in AppBar via `EditableAppBarTitle`

**Files:**
- Modify: `lib/screens/recipes/recipe_editor_screen.dart`

This task only touches the title flow. Task 7 handles the ingredient section so each commit is reviewable on its own.

- [ ] **Step 1: Add the import**

In `lib/screens/recipes/recipe_editor_screen.dart` add:

```dart
import '../../widgets/common/editable_app_bar_title.dart';
```

- [ ] **Step 2: Replace the title controller with a String field**

In `_RecipeEditorScreenState`:

Delete line 29:
```dart
  final _titleController = TextEditingController();
```

Add (in the same section):
```dart
  String _title = '';
```

Update `_prefillFromProvider` (line 60) — replace `_titleController.text = recipe.title;` with `_title = recipe.title;`.

Update `dispose` (line 68) — delete `_titleController.dispose();`.

Update `_save` (line 89) — replace `final title = _titleController.text.trim();` with `final title = _title.trim();`.

Update `build` (line 143) — replace `final titleEmpty = _titleController.text.trim().isEmpty;` with `final titleEmpty = _title.trim().isEmpty;`.

- [ ] **Step 3: Replace the AppBar title**

In `build`, line 153, replace:
```dart
        title: Text(_isEditMode ? 'Rezept bearbeiten' : 'Neues Rezept'),
```

with:
```dart
        title: EditableAppBarTitle(
          initialTitle: _title,
          placeholder: 'Rezept benennen',
          autofocusOnMount: !_isEditMode,
          onChanged: (v) => setState(() => _title = v),
        ),
```

- [ ] **Step 4: Delete the body title `TextField`**

Delete lines 165-174 (the body's title `TextField` plus the trailing `AppConstants.gap16`):

```dart
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Titel',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                    ),
                    AppConstants.gap16,
```

The body's first child is now `MealImageSection`.

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib/screens/recipes/recipe_editor_screen.dart`
Expected: No issues found.

- [ ] **Step 6: Smoke-check by running existing recipe-editor tests if any**

Run: `flutter test test/screens/recipes/`
Expected: Tests pass (or no recipe-editor tests exist yet — both acceptable).

- [ ] **Step 7: Commit**

```bash
git add lib/screens/recipes/recipe_editor_screen.dart
git commit -m "refactor: recipe editor title moves to AppBar

Uses EditableAppBarTitle with autofocus on first mount in create mode.
Removes the labeled body TextField."
```

---

### Task 7: Recipe editor — shared `IngredientSearch`

**Files:**
- Modify: `lib/screens/recipes/recipe_editor_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import '../../providers/ingredient_autocomplete_provider.dart';
import '../../widgets/common/ingredient_search.dart';
```

- [ ] **Step 2: Drop the unused ingredient controller and helpers**

In `_RecipeEditorScreenState`:

Delete line 30:
```dart
  final _ingredientController = TextEditingController();
```

In `dispose`, delete `_ingredientController.dispose();`.

Delete the entire `_addIngredient` method (lines 73-80) and `_removeIngredient` method (lines 82-86) — both are replaced by inline closures inside the `IngredientSearch` consumer below.

Delete the entire `_buildIngredientSection` method (lines 211-271).

- [ ] **Step 3: Replace the call site**

In `build`, replace `_buildIngredientSection(),` (line 191) with:

```dart
                    Consumer(
                      builder: (context, ref, _) {
                        final autocomplete =
                            ref.watch(ingredientAutocompleteProvider);
                        final autocompleteNotifier =
                            ref.read(ingredientAutocompleteProvider.notifier);
                        return IngredientSearch(
                          ingredients: _ingredients,
                          suggestions: autocomplete.suggestions,
                          onSearch: autocompleteNotifier.searchIngredients,
                          onAdd: (name) {
                            if (_ingredients.contains(name)) return;
                            setState(() => _ingredients = [..._ingredients, name]);
                            autocompleteNotifier.addIngredient(name);
                          },
                          onRemove: (name) => setState(() {
                            _ingredients =
                                _ingredients.where((i) => i != name).toList();
                          }),
                          onDeleteIngredient:
                              autocompleteNotifier.deleteUserIngredient,
                        );
                      },
                    ),
```

- [ ] **Step 4: Run analyze + format**

Run: `flutter analyze lib/screens/recipes/recipe_editor_screen.dart`
Expected: No issues found.

Run: `dart format lib/screens/recipes/recipe_editor_screen.dart`
Expected: 0 changed.

- [ ] **Step 5: Run tests**

Run: `flutter test test/screens/recipes/ test/providers/`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/recipes/recipe_editor_screen.dart
git commit -m "refactor: recipe editor uses shared IngredientSearch

Replaces the hand-rolled TextField + OutlinedButton stack with the
shared IngredientSearch widget wired to ingredientAutocompleteProvider."
```

---

### Task 8: Final verification + smoke test

**Files:** none (verification only)

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 2: Full format check**

Run: `dart format --set-exit-if-changed .`
Expected: exit code 0, "Formatted N files (0 changed)".

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 4: Manual smoke (if device/emulator available)**

Per CLAUDE.md ("For UI or frontend changes, start the dev server and use the feature in a browser before reporting the task as complete"). Walk through:

1. Tap **+** → Mahlzeit. The AppBar shows the "Neue Mahlzeit" placeholder. Tap it → field opens, type "Pasta", submit → AppBar reads "Pasta" + pencil. Re-tap → editable again.
2. In the meal tracker, tap "+ Hinzufügen" under Zutaten, type ≥3 chars → autocomplete suggestions render. Tap a suggestion or hit return → chip appears. Trash icon on a self-added suggestion deletes it.
3. Save the meal. On the success screen, tap "Als Rezept speichern". Reopen the recipes tab, open that recipe.
4. Open Rezepte → "+ Neues Rezept". The AppBar field is in edit mode with the keyboard up. Type a title; image section + ingredients render below.
5. In the recipe editor's ingredient section, type ≥3 chars → autocomplete pulls the same set the meal tracker uses (confirms the shared provider).
6. Open an existing recipe → "Bearbeiten". The AppBar shows the title in display mode; tap to edit. No "Titel" field in the body.

If anything misbehaves, fix and re-run from Step 1.

- [ ] **Step 5: No final commit needed** unless smoke uncovered an issue.

---

## Cross-task notes

- The plan never breaks the build between commits except briefly between Task 4 and Task 5 (Task 4 removes provider-level methods that the screen still calls). Task 5 closes that gap. Don't ship Task 4 without Task 5.
- The recipe editor's `Consumer` builders in Task 7 each create their own `ref` — that's fine because the parent screen is already a `ConsumerStatefulWidget`. Using nested `Consumer` keeps the rebuild scope tight to the ingredient block.
- `mealTrackerProvider.notifier.addIngredient` keeps signature `void Function(String)` so existing callers don't change.
- The plan deletes private `_buildIngredientSection`, `_addIngredient`, `_removeIngredient`, `_ingredientController` from the recipe editor. After Task 7 there should be zero references in `recipe_editor_screen.dart` — `flutter analyze` will catch any orphan use as `unused_local_variable` / undefined name.
