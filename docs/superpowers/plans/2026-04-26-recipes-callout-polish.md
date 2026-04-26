# Recipes callout polish + editor layout fix — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four small UX/layout polish items: copy edit on the meal-success callout, button-state swap on save (instead of slot collapse), pre-detect duplicate-title recipes, and fix the editor's edit-mode layout crash by restructuring the ingredient input.

**Architecture:** All four are local UI tweaks. `_buildSaveAsRecipeBottom` becomes the single rendering site for both pre-save and post-save state, branching on a derived `saved` boolean. The editor's ingredient-input row is restructured to a vertical stack (no `Row` + `Expanded`).

**Tech Stack:** Flutter, Riverpod.

**Spec:** `docs/superpowers/specs/2026-04-26-recipes-callout-polish-design.md`

**Branch:** `feat/recipes-callout-polish` (off `feat/recipes-ux-polish`). Spec doc already committed.

---

## File structure

Modified (2):
- `lib/screens/trackers/meal/meal_tracker_screen.dart` — copy edit, button-state branching, `_hasMatchingRecipe` helper, drop the `null`-collapse and the success SnackBar.
- `lib/screens/recipes/recipe_editor_screen.dart` — restructure the ingredient-input row to a vertical stack.

Tests:
- `test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart` — only update if a case asserts the dropped success SnackBar string.

No new files.

---

## Task 1: Copy edit + button-state swap + always-render slot

**Files:**
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart`

- [ ] **Step 1: Read the current `_buildSaveAsRecipeBottom` and the `successBottomCallout:` call site to anchor edits**

The relevant blocks:
- `successBottomCallout: _savedAsRecipe ? null : _buildSaveAsRecipeBottom(state),` (around line 266-268)
- `_buildSaveAsRecipeBottom(MealTrackerState state)` method (starts around line 274)

- [ ] **Step 2: Replace the `successBottomCallout:` line**

Find:
```dart
        successBottomCallout: _savedAsRecipe
            ? null
            : _buildSaveAsRecipeBottom(state),
```

Replace with:
```dart
        successBottomCallout: _buildSaveAsRecipeBottom(state),
```

- [ ] **Step 3: Replace the body of `_buildSaveAsRecipeBottom`**

Replace the whole method (currently around lines 274-300) with:

```dart
  Widget _buildSaveAsRecipeBottom(MealTrackerState state) {
    final saved = _savedAsRecipe || _hasMatchingRecipe(state.title);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Speicher diese Mahlzeit als Rezept, um sie später schneller wieder einzutragen.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          AppConstants.gap8,
          BbButton(
            label: saved ? 'Als Rezept gespeichert' : 'Als Rezept speichern',
            icon: saved ? Icons.check : Icons.bookmark_add_outlined,
            isLoading: _savingAsRecipe,
            onPressed: saved ? null : () => _saveAsRecipe(state),
          ),
        ],
      ),
    );
  }
```

Three things to notice:
- The explanation `Text` no longer mentions "Tipp" — that's the copy edit (#1).
- `saved` derives from BOTH `_savedAsRecipe` (manual save during this session) AND `_hasMatchingRecipe(state.title)` (a pre-existing recipe with the same title) — that's the duplicate-pre-detection (#3).
- Button label / icon / `onPressed` switches on `saved` — that's the visible "gespeichert" state (#2).

- [ ] **Step 4: Add the `_hasMatchingRecipe` helper**

Add this method to `_MealTrackerScreenState` (place it directly above `_buildSaveAsRecipeBottom` so the read order is helper → consumer):

```dart
  /// True iff the user already owns a recipe whose title matches [title]
  /// after trimming + lowercasing. Reads the cached userRecipesProvider
  /// value; safe to call during build because it never mutates the provider.
  bool _hasMatchingRecipe(String title) {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final recipes = ref.read(userRecipesProvider).value;
    if (recipes == null) return false;
    return recipes.any(
      (r) => r.title.trim().toLowerCase() == normalized,
    );
  }
```

If `userRecipesProvider` isn't already imported in this file, add `import '../../../providers/user_recipes_provider.dart';` (it almost certainly already is, since the FAB uses it; verify by grep).

- [ ] **Step 5: Drop the success SnackBar in `_saveAsRecipe`**

In `_saveAsRecipe` (around lines 302-329), the success branch currently does:

```dart
      if (!mounted) return;
      setState(() {
        _savedAsRecipe = true;
        _savingAsRecipe = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zu Meine Rezepte hinzugefügt')),
      );
```

Replace with:

```dart
      if (!mounted) return;
      setState(() {
        _savedAsRecipe = true;
        _savingAsRecipe = false;
      });
```

(The error SnackBar in the catch block stays.)

- [ ] **Step 6: Run analyzer + meal-tracker tests**

Run: `flutter analyze lib/screens/trackers/meal/meal_tracker_screen.dart`
Expected: `No issues found!`

Run: `flutter test test/screens/trackers/meal/`
Expected: PASS. If the existing `meal_tracker_save_as_recipe_test.dart` asserts `find.text('Zu Meine Rezepte hinzugefügt')` anywhere, drop those expectations (the SnackBar is gone). The other notifier-level cases (create-was-called) stay valid.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/trackers/meal/meal_tracker_screen.dart test/screens/trackers/meal/meal_tracker_save_as_recipe_test.dart
git commit -m "$(cat <<'EOF'
feat(meal-tracker): callout button reflects save state + dedupe-pre-detect

Three changes inside _buildSaveAsRecipeBottom:
- Drop "Tipp" from the explanation copy ("Speicher diese Mahlzeit als
  Rezept, um sie später schneller wieder einzutragen.")
- BbButton label/icon/onPressed branches on a `saved` flag (label flips
  to "Als Rezept gespeichert" with a check icon; onPressed nulls out for
  the disabled style).
- `saved` is true when either _savedAsRecipe is set after a manual tap
  OR _hasMatchingRecipe() finds an existing user recipe with the same
  trimmed/lowercased title at success-screen mount.

Slot stays mounted instead of collapsing to null. Success SnackBar
dropped in favor of the visible button state; error SnackBar kept.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Editor — restructure ingredient input as vertical stack

**Files:**
- Modify: `lib/screens/recipes/recipe_editor_screen.dart`

- [ ] **Step 1: Read `_buildIngredientSection` to anchor the edit**

The current block (around lines 211-256) renders:

```dart
  Widget _buildIngredientSection() {
    return Container(
      padding: AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Zutaten',
            style: TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredientController,
                  decoration: const InputDecoration(
                    hintText: 'Zutat eingeben',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingSm,
                    ),
                  ),
                  style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                  onSubmitted: (_) => _addIngredient(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              OutlinedButton(
                onPressed: _addIngredient,
                child: const Text('Hinzufügen'),
              ),
            ],
          ),
          if (_ingredients.isNotEmpty) ...[
            // Wrap of Chips, unchanged
          ],
        ],
      ),
    );
  }
```

- [ ] **Step 2: Replace the `Row(...)` with a vertical-stack pattern**

Replace ONLY the `Row(...)` block (the one immediately after `AppConstants.gap8` between the heading and the `if (_ingredients.isNotEmpty)` chips) with:

```dart
          TextField(
            controller: _ingredientController,
            decoration: const InputDecoration(
              hintText: 'Zutat eingeben',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
            ),
            style: const TextStyle(fontSize: AppTheme.fontSizeBody),
            onSubmitted: (_) => _addIngredient(),
            textInputAction: TextInputAction.done,
          ),
          AppConstants.gap8,
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _addIngredient,
              child: const Text('Hinzufügen'),
            ),
          ),
```

The TextField now sits on its own row (full width because parent Column is `stretch`), the `Hinzufügen` button right-aligns below it. No `Row`, no `Expanded` — the layout is immune to intrinsic-width measurement that was crashing in edit mode.

- [ ] **Step 3: Analyzer**

Run: `flutter analyze lib/screens/recipes/recipe_editor_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run editor + recipes test files**

Run: `flutter test test/screens/recipes/`
Expected: PASS. If a test pinned `find.byType(Row)` inside the editor's ingredient section it would break — unlikely but check.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: no NEW regressions.

- [ ] **Step 6: Manual smoke (if you have a device handy)**

1. Open Rezepte → tap an existing recipe → tap the pencil (edit). Confirm the editor opens without the `BoxConstraints forces an infinite width` crash.
2. Add an ingredient via the right-aligned "Hinzufügen" button OR by hitting return on the TextField.
3. Save. Confirm the recipe updates.
4. Open `/recipe/new` from the chooser sheet. Confirm the same input pattern looks right in create mode.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/recipes/recipe_editor_screen.dart
git commit -m "$(cat <<'EOF'
fix(recipes): editor ingredient input stacks vertically

Edit mode crashed with BoxConstraints forces an infinite width because
something upstream (likely MealImageSection's URL preview AspectRatio)
triggered intrinsic-width measurement, and Row+Expanded(TextField)
panics under intrinsic measurement. Restructure the input as a
vertical stack: TextField on its own row, Hinzufügen button
right-aligned below. Removes Row/Expanded entirely — immune to
intrinsic measurement regardless of upstream cause.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Push and open PR

- [ ] **Step 1: Push**

```bash
git push -u origin feat/recipes-callout-polish
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --base feat/recipes-ux-polish --title "feat(recipes): callout polish + editor layout fix" --body "$(cat <<'EOF'
## Summary
- Drop ambiguous "Tipp" from the meal-success callout copy → "Speicher diese Mahlzeit als Rezept, um sie später schneller wieder einzutragen."
- Save-as-recipe button now flips to "Als Rezept gespeichert" + check icon + disabled state instead of the whole callout collapsing
- Pre-detect: if a user recipe with the same trimmed/lowercased title already exists at success-screen mount, the button starts in the saved state — no duplicate creation
- Drop the success SnackBar (visible button state replaces it); keep the error SnackBar
- Fix \`recipe_editor_screen.dart\` edit-mode crash (\`BoxConstraints forces an infinite width\`) by restructuring the ingredient input as a vertical stack — TextField on its own row, "Hinzufügen" right-aligned below. No more Row+Expanded → immune to intrinsic-width measurement triggered by the URL image preview upstream.

Spec: \`docs/superpowers/specs/2026-04-26-recipes-callout-polish-design.md\`
Plan: \`docs/superpowers/plans/2026-04-26-recipes-callout-polish.md\`

This PR targets \`feat/recipes-ux-polish\` (the prior polish PR). Merge that one first.

## Test plan
- [x] \`flutter analyze\` clean
- [x] \`flutter test\` green
- [ ] Manual smoke:
  - [ ] Track a meal whose title doesn't match an existing recipe → callout shows "Als Rezept speichern" enabled. Tap → label swaps to "Als Rezept gespeichert" with check icon, disabled. Callout stays mounted.
  - [ ] Track a meal whose title matches an existing recipe (case-insensitive) → callout starts with "Als Rezept gespeichert" disabled.
  - [ ] Open Rezepte → pencil into a recipe → editor opens without the BoxConstraints crash. Add and remove ingredients via the new vertical-stack input.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Do **not** arm auto-merge.

---

## Self-review

### Spec coverage
- §1 copy edit — Task 1 step 3 (the new explanation Text). ✓
- §2 button-text + gray-out on save — Task 1 step 3 (`saved` ternary on label/icon/onPressed). ✓
- §3 duplicate-title pre-detect — Task 1 step 4 (`_hasMatchingRecipe`) + step 3 (`saved = _savedAsRecipe || _hasMatchingRecipe(state.title)`). ✓
- §4 editor layout fix — Task 2. ✓
- Drop the success SnackBar — Task 1 step 5. ✓
- Slot stays mounted — Task 1 step 2 (drops the `null`-collapse). ✓

No spec section without a task.

### Placeholder scan
None. Every code step has full code; every command shows expected output.

### Type consistency
- `_hasMatchingRecipe(String title)` defined in Task 1 step 4 with that signature; consumed in step 3 with `state.title` (a `String`). ✓
- `BbButton(label, icon, isLoading, onPressed)` named params match the existing call site. ✓
- The vertical-stack restructure in Task 2 keeps the surrounding `Column(crossAxisAlignment: stretch)` parent untouched, so the new `TextField` and `Align` children get the same horizontal constraints the previous `Row` did. ✓
