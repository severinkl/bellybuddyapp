# System-nav SafeArea overlap fix — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop bottom-anchored action buttons from overlapping the Android 15 system nav bar on four tracker screens and the recommendation dislike sheet.

**Architecture:** Two targeted `SafeArea(top: false, …)` wraps — one around the body of `TrackerScreenScaffold` (covers meal/mood/gut-feeling/toilet trackers in one change) and one around the dislike sheet's `build` return. No global edge-to-edge opt-out, no manifest changes, no UX redesign.

**Tech Stack:** Flutter, `flutter/material.dart`.

**Spec:** `docs/superpowers/specs/2026-04-24-system-nav-safearea-design.md`

**Branch:** `feat/system-nav-safearea` (already checked out in worktree `/Users/sevi/projects/bellybuddy-system-nav-safearea`). Spec doc already committed.

**Known-issue note for every commit in this worktree:** The pre-commit hook runs `flutter analyze`, which triggers a Flutter tool rebuild that fails with `Flutter SDK version is 0.0.0-unknown` due to local Flutter/Homebrew Cask state drift. This is an environment glitch, NOT a code issue. Before each commit: run `flutter analyze <changed-files>` manually to catch real lint issues. If analyze is clean but the hook still fails with the 0.0.0-unknown error, commit with `--no-verify` — the human pre-approved this for this worktree. Do NOT use `--no-verify` for any other reason.

---

## File structure

- **Modify:** `lib/widgets/common/tracker_screen_scaffold.dart` — one-line wrap of `body` in `SafeArea(top: false, …)`. Shared by meal, mood, gut-feeling, and toilet trackers.
- **Modify:** `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart` — wrap the existing `Padding` returned by `_RecommendationDislikeSheetState.build` in `SafeArea(top: false, …)`. Leaves the keyboard-inset padding logic inside the `Padding` intact.

No new files. No tests — the spec explicitly rejects a tautological "widget tree contains SafeArea" test. Manual smoke on an Android 15 device/emulator is the validation.

---

## Task 1: `TrackerScreenScaffold` SafeArea wrap

**Files:**
- Modify: `lib/widgets/common/tracker_screen_scaffold.dart`

- [ ] **Step 1: Apply the one-line wrap**

The current `build` method returns this at the end (non-success branch):

```dart
    return Scaffold(
      key: trackerKey,
      backgroundColor: AppTheme.screenBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Route through Navigator.maybePop so enclosing PopScope widgets
          // (e.g. the meal tracker's discard-changes guard) can intercept the
          // pop. Falls back to go_router's context.pop when no PopScope blocks.
          onPressed: () async {
            final didPop = await Navigator.maybePop(context);
            if (!didPop && context.mounted) context.popOrGoDashboard();
          },
        ),
        title: titleWidget ?? Text(title),
      ),
      body: body,
    );
```

Change the final `body: body,` line to:

```dart
      body: SafeArea(top: false, child: body),
```

`top: false` is load-bearing — `AppBar` already consumes the status-bar inset, and a second SafeArea there would double-pad. Left/right default to `true`, which is a no-op on portrait phones and handles future landscape correctly.

- [ ] **Step 2: Run analyzer on the changed file**

Run: `flutter analyze lib/widgets/common/tracker_screen_scaffold.dart`

Expected: `No issues found!`

If analyze reports a real issue, fix it before committing.

- [ ] **Step 3: Run the test suite**

Run: `flutter test`

Expected: the test suite runs and does not regress. Pre-existing failures (if any) are unchanged from `origin/develop` baseline; no test in this repo asserts on the exact widget tree under `Scaffold.body`, so this change should have no test impact.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/common/tracker_screen_scaffold.dart
git commit -m "$(cat <<'EOF'
fix(ui): SafeArea(top: false) around TrackerScreenScaffold body

Stops meal, mood, gut-feeling, and toilet tracker save buttons from
clipping under the Android 15 system nav bar. top: false leaves the
AppBar's own status-bar inset untouched.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If the hook fails with the 0.0.0-unknown Flutter SDK glitch, re-run the same commit with `--no-verify` appended (pre-approved for this worktree). Do not use `--no-verify` for any other reason.

---

## Task 2: Recommendation dislike sheet SafeArea wrap

**Files:**
- Modify: `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart`

Context: the sheet is opened with `showModalBottomSheet(useSafeArea: true, …)`, which handles top/left/right. Flutter intentionally sets `bottom: false` on that internal SafeArea — so the sheet's own content must handle the bottom inset. The current `build` already uses `MediaQuery.viewInsetsOf(context).bottom` for the keyboard; we need to ALSO account for the nav bar.

Wrapping the outer `Padding` in `SafeArea(top: false, …)` does this cleanly: `SafeArea` computes from `viewPadding` (system insets excluding the keyboard), and the existing `viewInsetsOf(context).bottom` inside continues to handle the keyboard. When the keyboard is open, `SafeArea` correctly reports 0 for the bottom (keyboard overlays the nav bar), so there's no double-padding.

- [ ] **Step 1: Apply the wrap**

The current `build` method (around lines 124-204) is:

```dart
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        MediaQuery.viewInsetsOf(context).bottom + AppConstants.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ /* ... unchanged ... */ ],
      ),
    );
  }
```

Change the `return Padding(` line to wrap in `SafeArea(top: false, child: Padding(` and add the matching closing `)` at the end. The resulting shape:

```dart
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spacingMd,
          AppConstants.spacingSm,
          AppConstants.spacingMd,
          MediaQuery.viewInsetsOf(context).bottom + AppConstants.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ /* ... unchanged ... */ ],
        ),
      ),
    );
  }
```

Do NOT touch the `showModalBottomSheet` call at line 17 — `useSafeArea: true` still does useful work for the non-bottom edges.

Do NOT change the `MediaQuery.viewInsetsOf(context).bottom + AppConstants.spacingMd` expression — keyboard handling stays exactly as it was.

- [ ] **Step 2: Run analyzer on the changed file**

Run: `flutter analyze lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart`

Expected: `No issues found!`

- [ ] **Step 3: Run the test suite**

Run: `flutter test`

Expected: no regression. `test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart` already exists — it should still pass. If it fails with a "found SafeArea where X was expected" message, inspect the failing expectation: it's likely an overly-specific tree match, and the spec-compliant fix is to loosen the test matcher, not revert the change.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart
git commit -m "$(cat <<'EOF'
fix(ui): SafeArea(top: false) around dislike-sheet content

showModalBottomSheet(useSafeArea: true) covers top/left/right only;
the sheet's own content must handle the bottom nav-bar inset. Keeps
the existing viewInsets.bottom keyboard padding intact.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

`--no-verify` acceptable if the hook fails on the 0.0.0-unknown glitch.

---

## Task 3: Manual smoke check (optional gate before PR)

**Files:** none.

Only run this if the human has an Android 15 emulator or device readily available. Otherwise skip — the human will verify post-merge per the PR test plan.

- [ ] **Step 1: Launch on Android 15**

Run: `flutter run -d <android-device-id>`

- [ ] **Step 2: Verify each affected surface**

For each, confirm the bottom-anchored action button sits fully above the system nav bar with visible breathing room:

1. Dashboard → Am Klo gewesen? → `speichern`.
2. Dashboard → Mahlzeit tracken → after picking ingredients → `Speichern`.
3. Recommendations → dislike (thumbs-down) any tip → "Was hat dir nicht gefallen?" sheet → `Fertig` and `Empfehlung ausblenden` both visible.
4. Dashboard → Wie geht es dir? → `Stimmung` tab → `speichern`.
5. Same screen, `Bauchgefühl` tab → `weiter`.

If any surface still overlaps, STOP — the fix missed that surface and the plan needs revision.

- [ ] **Step 3: Verify keyboard interaction on the dislike sheet**

Open the dislike sheet, tap the comment text field to raise the keyboard, then dismiss. Confirm:
- With keyboard open: sheet scrolls / buttons sit above the keyboard, no double-padding visible.
- With keyboard closed: buttons sit above the nav bar with breathing room (the new SafeArea inset).

---

## Task 4: Push and open PR against `develop`

- [ ] **Step 1: Push the branch**

```bash
cd /Users/sevi/projects/bellybuddy-system-nav-safearea
git push -u origin feat/system-nav-safearea
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --base develop --title "fix(ui): SafeArea insets for Android 15 system nav bar" --body "$(cat <<'EOF'
## Summary
- `TrackerScreenScaffold` wraps its body in `SafeArea(top: false, …)` — stops the save/weiter buttons on meal, mood, gut-feeling, and toilet trackers from clipping under the system nav bar on Android 15 edge-to-edge
- `_RecommendationDislikeSheetState.build` wraps its `Padding` in `SafeArea(top: false, …)` — `showModalBottomSheet(useSafeArea: true)` handles top/left/right but not bottom, so the sheet content needs its own bottom inset. Keyboard-inset logic (`MediaQuery.viewInsetsOf(context).bottom`) untouched
- No global edge-to-edge opt-out, no UX change to button placement

Spec: `docs/superpowers/specs/2026-04-24-system-nav-safearea-design.md`
Plan: `docs/superpowers/plans/2026-04-24-system-nav-safearea.md`

## Test plan
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (no regressions)
- [ ] Manual smoke on Android 15 emulator/device:
  - [ ] Toilet tracker → `speichern` fully visible above nav bar
  - [ ] Meal tracker → `Speichern` fully visible above nav bar
  - [ ] Mood tracker → `speichern` fully visible above nav bar
  - [ ] Gut-feeling tracker → `weiter` fully visible above nav bar
  - [ ] Dislike sheet → `Fertig` + `Empfehlung ausblenden` fully visible above nav bar
  - [ ] Dislike sheet with keyboard open — content reflows above keyboard, no double-padding when keyboard dismisses

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Do **not** arm auto-merge.

---

## Self-review

### Spec coverage
- **Fix 1 (TrackerScreenScaffold SafeArea wrap)** — Task 1 Step 1. ✓
- **Fix 2 (dislike sheet SafeArea wrap, keep `useSafeArea: true`, keep keyboard inset)** — Task 2 Step 1 with explicit "do not touch" notes for both the `showModalBottomSheet` call and the `viewInsetsOf` expression. ✓
- **Out-of-scope surfaces** — plan does not touch them.
- **No unit tests** — spec explicitly rejects them; plan follows.
- **Manual smoke (five screens)** — Task 3 Step 2 enumerates exactly the five from the spec.
- **`flutter analyze` clean / `dart format` applied** — Task 1 Step 2 + Task 2 Step 2 cover analyze. `dart format` is enforced by the pre-commit hook when it succeeds; the `--no-verify` fallback skips it, but both changes are trivial one-line wraps that a human would naturally format correctly. (If this concerns anyone, run `dart format lib/widgets/common/tracker_screen_scaffold.dart lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart` before committing.)

No spec requirement without a task.

### Placeholder scan
None. Every step has exact commands and complete code; no "TBD"/"TODO"; no "adapt as needed" hand-waving.

### Type consistency
- `SafeArea(top: false, child: …)` identical in both tasks.
- `MediaQuery.viewInsetsOf(context).bottom + AppConstants.spacingMd` in Task 2 is a verbatim copy of the existing expression; not introduced here.
- PR body's test-plan surfaces match Task 3's smoke list.
