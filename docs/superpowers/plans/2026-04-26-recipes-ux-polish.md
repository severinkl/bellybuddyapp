# Recipes UX polish — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four small UX changes layered on top of `feat/recipes-grid-search` — bottom callout for save-as-recipe with explanation copy, sharper empty-state wording, checkmark-free pill toggle on the recipes tab switcher, and a floating book-icon FAB for the meal tracker's recipe selector.

**Architecture:** Independent UI tweaks. `BbSuccessOverlay` gains an optional `bottomCallout` slot; `TrackerScreenScaffold` relays it. `MealTrackerScreen` re-shapes the success-screen actions and replaces its recipe-selector OutlinedButton row with a Positioned `Material` FAB inside a Stack-wrapped body. New `RecipesTabToggle` widget replaces `SegmentedButton` on `RecipesScreen`. One copy edit on `MyRecipesTab`.

**Tech Stack:** Flutter, Riverpod, Material.

**Spec:** `docs/superpowers/specs/2026-04-26-recipes-ux-polish-design.md`

**Branch:** `feat/recipes-ux-polish` (already checked out, off `feat/recipes-grid-search`). Spec doc already committed.

---

## File structure

Modified (5):
- `lib/widgets/common/bb_success_overlay.dart` — adds `Widget? bottomCallout` param + render slot.
- `lib/widgets/common/tracker_screen_scaffold.dart` — adds matching `bottomCallout` param, relays it.
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — moves recipe action out of `successActions` into a `bottomCallout` widget; replaces the OutlinedButton-row recipe selector with a top-right floating icon button inside a Stack.
- `lib/screens/recipes/my_recipes_tab.dart` — empty-state copy edit.
- `lib/screens/recipes/recipes_screen.dart` — swaps `SegmentedButton` for `RecipesTabToggle`.

New (1 + tests):
- `lib/screens/recipes/widgets/recipes_tab_toggle.dart`
- `test/screens/recipes/widgets/recipes_tab_toggle_test.dart`

Test updates:
- `test/widgets/common/bb_success_overlay_test.dart` — add `bottomCallout` rendering case.
- `test/screens/recipes/recipes_screen_test.dart` — relax assertions if any pinned the `SegmentedButton` class.
- `test/screens/recipes/my_recipes_tab_test.dart` — update if the old empty-state copy is asserted verbatim.
- `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart` — update if any assertion pinned the action's location inside `successActions`.

---

## Phase 1 — `BbSuccessOverlay` `bottomCallout` API

Delivers: optional bottom-callout slot that renders below `actions`. No call-site changes — `bottomCallout` defaults to `null`.

### Task 1: add `bottomCallout` to `BbSuccessOverlay` (TDD)

**Files:**
- Modify: `lib/widgets/common/bb_success_overlay.dart`
- Modify: `test/widgets/common/bb_success_overlay_test.dart`

- [ ] **Step 1: Append the failing test**

Append the following to the existing `main()` group in `test/widgets/common/bb_success_overlay_test.dart`:

```dart
  testWidgets('renders bottomCallout below actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BbSuccessOverlay(
          message: 'Gespeichert',
          onDismissed: () {},
          actions: const [Text('ACTION_ONE')],
          bottomCallout: const Text('CALLOUT_TEXT'),
        ),
      ),
    );

    expect(find.text('ACTION_ONE'), findsOneWidget);
    expect(find.text('CALLOUT_TEXT'), findsOneWidget);
  });

  testWidgets('renders cleanly without bottomCallout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BbSuccessOverlay(
          message: 'Gespeichert',
          onDismissed: () {},
          actions: const [Text('ACTION_ONE')],
        ),
      ),
    );

    expect(find.text('ACTION_ONE'), findsOneWidget);
  });
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/widgets/common/bb_success_overlay_test.dart`
Expected: FAIL — `The named parameter 'bottomCallout' isn't defined`.

- [ ] **Step 3: Add the param + render slot**

In `lib/widgets/common/bb_success_overlay.dart`, add a new field next to `actions` (around line 11):

```dart
  final List<Widget>? actions;
  final Widget? bottomCallout;
  final String? mascotAsset;
```

Add the matching constructor entry next to `this.actions` (around line 19):

```dart
    this.actions,
    this.bottomCallout,
    this.mascotAsset,
```

In `build`, after the `if (widget.actions != null && widget.actions!.isNotEmpty) { ... }` block (currently around lines 207-221), add:

```dart
                if (widget.bottomCallout != null) ...[
                  AppConstants.gap16,
                  widget.bottomCallout!,
                ],
```

Place this BEFORE the `// Tap hint` comment block. The vertical rhythm is: actions → gap16 → callout → existing tap-hint flow.

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/widgets/common/bb_success_overlay_test.dart`
Expected: PASS (existing cases + 2 new).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/widgets/common/bb_success_overlay.dart test/widgets/common/bb_success_overlay_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/common/bb_success_overlay.dart test/widgets/common/bb_success_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(ui): BbSuccessOverlay.bottomCallout slot

New optional Widget? bottomCallout renders below the actions list,
above the tap-to-continue hint. Existing call sites pass null and
render unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2: relay `bottomCallout` through `TrackerScreenScaffold`

**Files:**
- Modify: `lib/widgets/common/tracker_screen_scaffold.dart`

- [ ] **Step 1: Add the param + relay**

Open `lib/widgets/common/tracker_screen_scaffold.dart`. Around line 15 (next to `final List<Widget>? successActions;`), add:

```dart
  final List<Widget>? successActions;
  final Widget? successBottomCallout;
```

Around line 28 in the constructor (next to `this.successActions`), add:

```dart
    this.successActions,
    this.successBottomCallout,
```

In the `build` method around line 41 (the `BbSuccessOverlay(... actions: successActions, ...)` call), pass the param through:

```dart
        actions: successActions,
        bottomCallout: successBottomCallout,
```

- [ ] **Step 2: Analyzer**

Run: `flutter analyze lib/widgets/common/tracker_screen_scaffold.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the existing scaffold tests** to confirm nothing regresses

Run: `flutter test test/widgets/common/tracker_screen_scaffold_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/common/tracker_screen_scaffold.dart
git commit -m "$(cat <<'EOF'
feat(ui): TrackerScreenScaffold relays successBottomCallout

Single named param forwarded to BbSuccessOverlay.bottomCallout. No
existing call sites pass it yet; meal tracker uses it next.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — Meal-tracker success screen restructure

### Task 3: move "Als Rezept speichern" out of `successActions` into a bottom callout

**Files:**
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart`
- Modify: `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart` (if its assertions break)

- [ ] **Step 1: Read the current `successActions` block**

Open `lib/screens/trackers/meal/meal_tracker_screen.dart` and locate the `successActions: [GestureDetector(... 'Als Rezept speichern' ...), GestureDetector(... 'Getränk hinzufügen' ...)]` block (around lines 246-288). The first GestureDetector is the recipe action — it moves out of `successActions` entirely.

- [ ] **Step 2: Replace `successActions:` and add `successBottomCallout:`**

Change the block to:

```dart
        successActions: [
          GestureDetector(
            onTap: () => context.push(RoutePaths.drinkTracker),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  size: AppConstants.iconSizeSm,
                  color: AppTheme.info,
                ),
                SizedBox(width: AppConstants.spacingSm),
                Text(
                  'Getränk hinzufügen',
                  style: TextStyle(color: AppTheme.info),
                ),
              ],
            ),
          ),
        ],
        successBottomCallout: _savedAsRecipe
            ? null
            : _buildSaveAsRecipeBottom(state),
        body: _buildBody(state),
```

- [ ] **Step 3: Add the `_buildSaveAsRecipeBottom` helper**

Inside `_MealTrackerScreenState`, add a new method (place near the existing `_saveAsRecipe` method):

```dart
  Widget _buildSaveAsRecipeBottom(MealTrackerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Speicher diese Mahlzeit als Rezept und trag sie später mit einem Tipp wieder ein.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          AppConstants.gap8,
          BbButton(
            label: 'Als Rezept speichern',
            icon: Icons.bookmark_add_outlined,
            isLoading: _savingAsRecipe,
            onPressed: _savingAsRecipe ? null : () => _saveAsRecipe(state),
          ),
        ],
      ),
    );
  }
```

If `BbButton` doesn't accept an `icon` named parameter, drop it — the explanation text + plain "Als Rezept speichern" label is enough. If it does accept it, leaving the icon is the cleaner shape.

- [ ] **Step 4: Update the save-as-recipe test if it pins the action's location**

Open `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart`. The notifier-level cases (`create() stores …`, `create() works with null imageUrl`, `create() throws when repository fails`) don't render the meal tracker — they remain unchanged. The skipped UI test stays skipped.

If any other test in the meal-tracker tree asserts `find.text('Als Rezept speichern')` inside the success overlay's `actions` list specifically, relax it: the label still exists, just under `bottomCallout` now.

- [ ] **Step 5: Run the meal-tracker test files**

Run: `flutter test test/screens/trackers/meal/`
Expected: PASS (no regressions).

- [ ] **Step 6: Analyzer**

Run: `flutter analyze lib/screens/trackers/meal/meal_tracker_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/screens/trackers/meal/meal_tracker_screen.dart test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart
git commit -m "$(cat <<'EOF'
feat(meal-tracker): move Als Rezept speichern to bottom callout

successActions now holds only the drink shortcut. The recipe action
moves into successBottomCallout: a centered explanation paragraph
('Speicher diese Mahlzeit als Rezept und trag sie später mit einem
Tipp wieder ein.') above a primary BbButton. After the first save,
the callout collapses entirely (we pass null) — no awkward disabled
state lingering.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If the `git add` warns about untouched test files, drop them.

---

## Phase 3 — Empty-state copy

### Task 4: tweak Meine Rezepte empty-state wording

**Files:**
- Modify: `lib/screens/recipes/my_recipes_tab.dart`
- Modify: `test/screens/recipes/my_recipes_tab_test.dart` (if it pins the old copy)

- [ ] **Step 1: Update the copy**

In `lib/screens/recipes/my_recipes_tab.dart`, locate the empty-state Text (currently `'Speichere Mahlzeiten als Rezepte, um sie schnell wieder einzutragen.'`). Replace it with:

```dart
            const Text(
              'Speichere wiederkehrende Mahlzeiten als Rezepte, um sie später schneller wieder einzutragen.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
```

(Only the string changes; the surrounding TextStyle stays as-is.)

- [ ] **Step 2: Update the test if it pins the old copy**

Search `test/screens/recipes/my_recipes_tab_test.dart` for `'Speichere Mahlzeiten als Rezepte'`. If found, replace with `'Speichere wiederkehrende Mahlzeiten'` or use a `findsOneWidget` on a less-fragile substring like `'wiederkehrende Mahlzeiten'`.

- [ ] **Step 3: Run**

Run: `flutter test test/screens/recipes/my_recipes_tab_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recipes/my_recipes_tab.dart test/screens/recipes/my_recipes_tab_test.dart
git commit -m "$(cat <<'EOF'
copy(recipes): empty-state mentions wiederkehrende Mahlzeiten

Reframes the recipe value-prop around 'meals you eat repeatedly'
rather than the vaguer 'meals'. Single-line edit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 — Tab pill toggle

### Task 5: `RecipesTabToggle` widget (TDD)

**Files:**
- Create: `lib/screens/recipes/widgets/recipes_tab_toggle.dart`
- Create: `test/screens/recipes/widgets/recipes_tab_toggle_test.dart`

- [ ] **Step 1: Write the failing test**

`test/screens/recipes/widgets/recipes_tab_toggle_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recipes/widgets/recipes_tab_toggle.dart';

void main() {
  testWidgets('renders both segment labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipesTabToggle(
            value: 0,
            segments: const ['Meine Rezepte', 'Inspiration'],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Meine Rezepte'), findsOneWidget);
    expect(find.text('Inspiration'), findsOneWidget);
  });

  testWidgets('tapping the inactive segment fires onChanged with its index', (tester) async {
    int? lastSelected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipesTabToggle(
            value: 0,
            segments: const ['Meine Rezepte', 'Inspiration'],
            onChanged: (i) => lastSelected = i,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Inspiration'));
    expect(lastSelected, 1);
  });

  testWidgets('renders no checkmark icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipesTabToggle(
            value: 0,
            segments: const ['Meine Rezepte', 'Inspiration'],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsNothing);
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/screens/recipes/widgets/recipes_tab_toggle_test.dart`
Expected: FAIL — URI not found.

- [ ] **Step 3: Create the widget**

`lib/screens/recipes/widgets/recipes_tab_toggle.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// Two-segment (or N-segment) pill toggle without Material's checkmark.
/// Active segment paints a card-colored pill; inactive segments are flat.
class RecipesTabToggle extends StatelessWidget {
  const RecipesTabToggle({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final int value;
  final List<String> segments;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++)
            Expanded(child: _Segment(
              label: segments[i],
              active: i == value,
              onTap: () => onChanged(i),
            )),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingSm,
        ),
        decoration: active
            ? BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              )
            : null,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active
                  ? AppTheme.foreground
                  : AppTheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
```

If `Color(0x14000000)` triggers the no-hardcoded-color lint, replace with `AppTheme.foreground.withValues(alpha: 0.08)`.

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/screens/recipes/widgets/recipes_tab_toggle_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/screens/recipes/widgets/recipes_tab_toggle.dart`
Expected: `No issues found!` (modulo the color note above).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/recipes/widgets/recipes_tab_toggle.dart test/screens/recipes/widgets/recipes_tab_toggle_test.dart
git commit -m "$(cat <<'EOF'
feat(recipes): RecipesTabToggle pill widget

Drop-in replacement for SegmentedButton that doesn't render a
checkmark in the active segment. Generic over N segments; only used
by RecipesScreen for now.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 6: swap `RecipesScreen` to use `RecipesTabToggle`

**Files:**
- Modify: `lib/screens/recipes/recipes_screen.dart`

- [ ] **Step 1: Replace the `SegmentedButton` block**

In `lib/screens/recipes/recipes_screen.dart`, find the existing block:

```dart
            child: SegmentedButton<_RecipesView>(
              segments: const [
                ButtonSegment(value: _RecipesView.myRecipes, label: Text('Meine Rezepte')),
                ButtonSegment(value: _RecipesView.inspiration, label: Text('Inspiration')),
              ],
              selected: {_view},
              onSelectionChanged: (selection) =>
                  setState(() => _view = selection.first),
            ),
```

Replace with:

```dart
            child: RecipesTabToggle(
              value: _view.index,
              segments: const ['Meine Rezepte', 'Inspiration'],
              onChanged: (i) => setState(() => _view = _RecipesView.values[i]),
            ),
```

Add `import 'widgets/recipes_tab_toggle.dart';` to the imports (alongside the other relative imports already present).

- [ ] **Step 2: Run the existing screen test**

Run: `flutter test test/screens/recipes/recipes_screen_test.dart`
Expected: PASS. The existing tests use `find.text('Meine Rezepte')` / `find.text('Inspiration')` and `tester.tap(find.text('Inspiration'))` — those still work because the new widget exposes the same labels.

If a test pinned `find.byType(SegmentedButton)`, replace with `find.byType(RecipesTabToggle)`.

- [ ] **Step 3: Analyzer**

Run: `flutter analyze lib/screens/recipes/recipes_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recipes/recipes_screen.dart test/screens/recipes/recipes_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(recipes): swap SegmentedButton for RecipesTabToggle

Drops the meaningless checkmark Material rendered inside the active
segment. Tab-switch behavior unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 5 — Floating recipe-selector icon on the meal tracker

### Task 7: replace OutlinedButton row with Stack-positioned floating icon

**Files:**
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart`

- [ ] **Step 1: Locate `_buildBody` and remove the OutlinedButton row**

In `lib/screens/trackers/meal/meal_tracker_screen.dart`, find `_buildBody` (around line 350). The body is currently a `Padding(SingleChildScrollView(Column([Consumer..., DateTimeChips..., MealImageSection..., …])))`. The first child of the inner `Column` is the recipe-selector `Consumer + Padding(OutlinedButton.icon)` block (around lines 352-374).

Delete that `// 0. Recipe selector (hidden when user has no recipes)` block AND its `Consumer` widget. The first child of the `Column` is now the `DateTimeChips`.

- [ ] **Step 2: Wrap the body in a `Stack`**

`_buildBody` currently returns a `SingleChildScrollView` (or `Padding(SingleChildScrollView(...))`). Wrap that whole return value in a `Stack(clipBehavior: Clip.none, children: [...])`. The first stack child is the existing scroll content. The second stack child is the new floating icon — added in Step 3.

If the existing return looks like:

```dart
  Widget _buildBody(MealTrackerState state) {
    final notifier = ref.read(mealTrackerProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(...),
      child: Column(...),
    );
  }
```

Change to:

```dart
  Widget _buildBody(MealTrackerState state) {
    final notifier = ref.read(mealTrackerProvider.notifier);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(...),
          child: Column(...),
        ),
        Positioned(
          top: AppConstants.spacingSm,
          right: AppConstants.spacingSm,
          child: _buildRecipeSelectorFab(),
        ),
      ],
    );
  }
```

- [ ] **Step 3: Add the `_buildRecipeSelectorFab` helper**

Inside `_MealTrackerScreenState`, add:

```dart
  Widget _buildRecipeSelectorFab() {
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(userRecipesProvider);
        final hasRecipes = async.value?.isNotEmpty ?? false;
        if (!hasRecipes) return const SizedBox.shrink();
        return Tooltip(
          message: 'Aus Rezept übernehmen',
          child: Material(
            shape: const CircleBorder(),
            color: AppTheme.card,
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                final recipe = await showRecipeSelectorSheet(context);
                if (recipe == null || !mounted) return;
                ref
                    .read(mealTrackerProvider.notifier)
                    .prefillFromRecipe(recipe);
                _titleController.text = recipe.title;
              },
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.menu_book_outlined,
                  size: AppConstants.iconSizeSm,
                  color: AppTheme.foreground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
```

If the analyzer flags hardcoded `width: 32, height: 32`: check `lib/config/constants.dart` for an existing 32-sized icon-badge constant (`AppConstants.iconBadgeSm` is the likely candidate — verify before assuming) and reference that.

- [ ] **Step 4: Run analyzer + tests**

Run: `flutter analyze lib/screens/trackers/meal/meal_tracker_screen.dart`
Expected: `No issues found!`

Run: `flutter test`
Expected: no NEW regressions. (No automated test reaches the FAB; manual verification covers it.)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/trackers/meal/meal_tracker_screen.dart
git commit -m "$(cat <<'EOF'
feat(meal-tracker): floating recipe selector icon top-right

Replaces the OutlinedButton-row 'Aus Rezept auswählen' block with a
32x32 circular Material book-icon button positioned top-right inside
a Stack-wrapped body. Visible only when ≥1 recipe exists. Tooltip
'Aus Rezept übernehmen' on long-press. Tap behavior unchanged
(opens RecipeSelectorSheet, prefills via prefillFromRecipe).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 6 — Ship

### Task 8: full suite + manual smoke

- [ ] **Step 1: Full analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: green (modulo pre-existing skips).

- [ ] **Step 3: `dart format`**

Run: `dart format lib/ test/`
Expected: 0 files changed.

- [ ] **Step 4: Manual smoke**

1. Track a meal. On the success screen: confirm the drink shortcut sits where the recipe action used to (centered link below the message), and below it a centered explanation paragraph + a primary "Als Rezept speichern" button. Tap save-as-recipe → SnackBar → bottom callout collapses entirely on next rebuild.
2. Open Rezepte. With no recipes saved (delete any to test), the empty state shows the new wording: "Speichere wiederkehrende Mahlzeiten als Rezepte…".
3. Save at least one recipe. Open Rezepte: tabs render as a pill toggle without a checkmark in the active segment. Tap "Inspiration" → switches; tap "Meine Rezepte" → switches back.
4. Open the meal tracker (with at least one recipe in the system): confirm a 32x32 circular icon button is in the top-right of the body. The OutlinedButton row is gone. Tap the icon → recipe selector sheet opens. Pick a recipe → form prefills.
5. Delete every recipe. Open the meal tracker: the icon disappears.

### Task 9: push and open PR

- [ ] **Step 1: Push**

```bash
git push -u origin feat/recipes-ux-polish
```

- [ ] **Step 2: Open the PR against `feat/recipes-grid-search`** (parent feature branch)

```bash
gh pr create --base feat/recipes-grid-search --title "feat(recipes): UX polish — bottom callout, copy, tabs, FAB" --body "$(cat <<'EOF'
## Summary
- `BbSuccessOverlay` gains `bottomCallout` slot; `TrackerScreenScaffold` relays it
- Meal-tracker success screen: `Als Rezept speichern` moves out of the actions list into a dedicated bottom callout with a one-line explanation; collapses after first save
- `MyRecipesTab` empty-state copy: "Speichere wiederkehrende Mahlzeiten als Rezepte, um sie später schneller wieder einzutragen."
- New `RecipesTabToggle` widget (no checkmark) replaces `SegmentedButton` on `RecipesScreen`
- Meal-tracker recipe selector: OutlinedButton-row → 32x32 floating book-icon button in the top-right of the body (hidden when no recipes)

Spec: `docs/superpowers/specs/2026-04-26-recipes-ux-polish-design.md`
Plan: `docs/superpowers/plans/2026-04-26-recipes-ux-polish.md`

This PR targets `feat/recipes-grid-search` (the previous polish PR). Merge that one first.

## Test plan
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [ ] Manual smoke per the plan's Task 8

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Do **not** arm auto-merge.

---

## Self-review

### Spec coverage
- §1 bottom callout — Tasks 1, 2, 3. ✓
- §2 empty-state copy — Task 4. ✓
- §3 tab style — Tasks 5, 6. ✓
- §4 floating selector icon — Task 7. ✓

No spec section without a task.

### Placeholder scan
- Task 3 step 3 has a small fork ("If `BbButton` doesn't accept an `icon` named parameter, drop it") — that's an inspect-and-decide note, not a placeholder. The default fallback is explicit (drop the icon).
- Task 5 step 3 has a similar fallback for the shadow `Color(0x14000000)` ↔ `withValues(alpha: 0.08)` decision. Both are concrete, no TBD.
- No "TODO" / "etc" / vague "handle edge cases" anywhere.

### Type consistency
- `Widget? bottomCallout` on `BbSuccessOverlay` (Task 1) is forwarded as `successBottomCallout` on `TrackerScreenScaffold` (Task 2) and consumed via `successBottomCallout:` at the meal-tracker call site (Task 3). The meal tracker passes `_buildSaveAsRecipeBottom(state)` (returns `Widget`) which matches the `Widget?` slot.
- `RecipesTabToggle({value: int, segments: List<String>, onChanged: ValueChanged<int>})` defined in Task 5 is consumed verbatim in Task 6.
- `_buildRecipeSelectorFab()` (Task 7) is the new helper; `_buildSaveAsRecipeBottom(MealTrackerState)` (Task 3) is the other new helper. No naming clash.
