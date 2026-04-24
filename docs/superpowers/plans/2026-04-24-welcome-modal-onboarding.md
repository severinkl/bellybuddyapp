# Welcome Modal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-dashboard-visit welcome modal that precedes the spotlight tour. Gated on the same `tutorialSeenAt == null` signal. Single CTA, no close icon.

**Architecture:** New stateless widget `lib/screens/dashboard/widgets/welcome_modal.dart` mirroring `notification_opt_in_dialog.dart`'s pattern, plus a two-line insert in `dashboard_screen.dart:_maybeShowTutorial()`.

**Tech Stack:** Flutter (Dart 3.11), Material `AlertDialog`, existing `AppTheme` / `AppConstants` / `MascotImage`. No new dependencies.

**Branch:** `feat/welcome-modal` (already created off `origin/develop`; spec doc is commit `cd65fc8`).

**Spec:** `docs/superpowers/specs/2026-04-24-welcome-modal-onboarding-design.md`

---

## Task 1: Create the welcome modal widget

**Files:**
- Create: `lib/screens/dashboard/widgets/welcome_modal.dart`

- [ ] **Step 1: Write the widget file**

```dart
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/mascot_image.dart';

/// Shows the one-time onboarding welcome modal. Dismisses when the user
/// taps "Los geht's"; callers `await` the returned future and then trigger
/// the next tutorial stage (the dashboard spotlight tour).
///
/// Gated upstream by `TutorialNotifier.shouldShow()` — this helper does
/// not check or write any persistence of its own.
Future<void> showWelcomeModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WelcomeModal(),
  );
}

class _WelcomeModal extends StatelessWidget {
  const _WelcomeModal();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      contentPadding: AppConstants.paddingLg,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: AppConstants.mascotSizeMd,
            height: AppConstants.mascotSizeMd,
          ),
          AppConstants.gap16,
          const Text(
            'Willkommen bei Belly Buddy!',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap12,
          const Text(
            'Finde heraus, welche Lebensmittel deine Verdauungsprobleme '
            'auslösen – und was dir wirklich guttut.\n\n'
            'Tracke dein Essen und dein Wohlbefinden regelmäßig, erhalte '
            'persönliches Feedback und entdecke passende Alternativen. '
            'So verstehst du deinen Körper besser und triffst im Alltag '
            'leichter die richtigen Entscheidungen 💛',
            style: TextStyle(fontSize: AppTheme.fontSizeBody),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap24,
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: const Text("Los geht's"),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles and analyses clean**

```bash
flutter analyze lib/screens/dashboard/widgets/welcome_modal.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Verify format**

```bash
dart format --set-exit-if-changed lib/screens/dashboard/widgets/welcome_modal.dart
```

Expected: `Formatted 1 file (0 changed)`.

---

## Task 2: Write the widget test

**Files:**
- Create: `test/screens/dashboard/widgets/welcome_modal_test.dart`

- [ ] **Step 1: Ensure the test directory exists**

```bash
mkdir -p test/screens/dashboard/widgets
```

- [ ] **Step 2: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/welcome_modal.dart';

void main() {
  group('showWelcomeModal', () {
    testWidgets(
      'renders the welcome title + body and "Los geht\'s" CTA dismisses it',
      (tester) async {
        late Future<void> sheetFuture;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      sheetFuture = showWelcomeModal(ctx);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Title + a body substring (the full two-paragraph string is long).
        expect(find.text('Willkommen bei Belly Buddy!'), findsOneWidget);
        expect(
          find.textContaining('Verdauungsprobleme'),
          findsOneWidget,
        );
        expect(find.text("Los geht's"), findsOneWidget);

        await tester.tap(find.text("Los geht's"));
        await tester.pumpAndSettle();

        // Modal is gone and the awaited future resolved.
        expect(find.text('Willkommen bei Belly Buddy!'), findsNothing);
        await sheetFuture;
      },
    );
  });
}
```

- [ ] **Step 3: Run the test**

```bash
flutter test test/screens/dashboard/widgets/welcome_modal_test.dart
```

Expected: `+1: All tests passed!`.

- [ ] **Step 4: Run the full suite to confirm no regressions**

```bash
flutter test
```

Expected: baseline + 1 passing test.

- [ ] **Step 5: Format + analyze**

```bash
dart format --set-exit-if-changed test/screens/dashboard/widgets/welcome_modal_test.dart
flutter analyze
```

Expected: both clean.

---

## Task 3: Wire the modal into the dashboard

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart` — `_maybeShowTutorial()` method.

- [ ] **Step 1: Add the import**

Find the dashboard's widgets-import block (around line 17-19):

```dart
import 'widgets/tutorial/show_dashboard_tutorial.dart';
import 'widgets/tutorial/tutorial_keys.dart';
```

Add a line alphabetically adjacent:

```dart
import 'widgets/tutorial/show_dashboard_tutorial.dart';
import 'widgets/tutorial/tutorial_keys.dart';
import 'widgets/welcome_modal.dart';
```

(Use whatever exact alphabetical order the file already follows; `welcome_modal.dart` is a sibling of `feature_card.dart` and `notification_opt_in_dialog.dart`, all under `widgets/`. Place it where the alphabet puts it in the current file's sort.)

- [ ] **Step 2: Insert the welcome-modal await inside `_maybeShowTutorial`**

**Find:**

```dart
  Future<void> _maybeShowTutorial() async {
    if (!mounted) return;
    final shouldShow = ref.read(tutorialProvider.notifier).shouldShow();
    if (!shouldShow) return;
    final handle = showDashboardTutorial(context);
    _tutorialHandle = handle;
    await handle.future;
    _tutorialHandle = null;
    if (!mounted) return;
    await ref.read(tutorialProvider.notifier).markSeen();
  }
```

**Replace with:**

```dart
  Future<void> _maybeShowTutorial() async {
    if (!mounted) return;
    final shouldShow = ref.read(tutorialProvider.notifier).shouldShow();
    if (!shouldShow) return;
    // Welcome modal is the first stage of the tutorial. Dismissing it
    // (tap "Los geht's") falls through to the spotlight tour, and
    // tutorialSeenAt is only persisted at the end of the spotlight.
    await showWelcomeModal(context);
    if (!mounted) return;
    final handle = showDashboardTutorial(context);
    _tutorialHandle = handle;
    await handle.future;
    _tutorialHandle = null;
    if (!mounted) return;
    await ref.read(tutorialProvider.notifier).markSeen();
  }
```

- [ ] **Step 3: Run analyze + format**

```bash
flutter analyze
dart format --set-exit-if-changed lib/screens/dashboard/dashboard_screen.dart
```

Expected: both clean.

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```

Expected: all tests pass. If any dashboard test now fails because it was pumping the dashboard and asserting on tutorial/spotlight frames, the welcome modal now sits in front of those frames — that test needs updating, but that's a failure to *address*, not ignore. Do not make the test pass by reverting the production change.

If `test/screens/dashboard/dashboard_screen_test.dart` or similar fails on a timing / expectation shift, surface the failure and stop; we'll handle test updates as a Task 3b before committing.

---

## Task 4: Commit

**Files:** commits the three-file change as one atomic unit (no intermediate commit for the widget-only step, because the widget has no behaviour until Task 3 wires it up).

- [ ] **Step 1: Stage all three files**

```bash
git add lib/screens/dashboard/widgets/welcome_modal.dart \
        test/screens/dashboard/widgets/welcome_modal_test.dart \
        lib/screens/dashboard/dashboard_screen.dart
```

- [ ] **Step 2: Verify staging**

```bash
git status
```

Expected: exactly two new files + one modified file.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(onboarding): welcome modal as first stage of the tutorial

First-dashboard-visit modal with the Belly Buddy value proposition.
Gated by the existing tutorialSeenAt == null signal via
TutorialNotifier.shouldShow(), so it shares the single "tutorial seen"
persistence with the spotlight tour. Sequenced before the spotlight:
welcome modal → spotlight → notifications opt-in.

Single CTA "Los geht's", no close icon, barrierDismissible: false.
tutorialSeenAt is only persisted at the end of the spotlight, so users
who close the app between modal and spotlight see the welcome modal
again on next launch (intentional — tutorial isn't "seen" yet).

Spec: docs/superpowers/specs/2026-04-24-welcome-modal-onboarding-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

The pre-commit hook runs `dart format` + `flutter analyze`. Expect ✅.

- [ ] **Step 4: Verify**

```bash
git log -1 --stat
git log --oneline origin/develop..HEAD
```

Expected: one code commit on top of the spec commit.

---

## Task 5: Push and open PR

- [ ] **Step 1: Push**

```bash
git push -u origin feat/welcome-modal
```

- [ ] **Step 2: Open PR against develop**

```bash
gh pr create --base develop --title "feat(onboarding): welcome modal as first stage of the tutorial" --body "$(cat <<'EOF'
## Summary

Adds a one-time welcome modal on first dashboard visit, sequenced before the existing spotlight tutorial. Gated on the same `tutorialSeenAt == null` signal via `TutorialNotifier.shouldShow()`, so the modal and the spotlight share a single "tutorial seen" persistence — dismiss the modal, complete the spotlight, and the whole flow is marked done atomically.

On first dashboard visit the sequence becomes:

1. **Welcome modal** (new)
2. Spotlight tour (existing)
3. Notification opt-in modal (existing)

## Copy

- Title: `Willkommen bei Belly Buddy!`
- Body (two paragraphs): "Finde heraus, welche Lebensmittel deine Verdauungsprobleme auslösen – und was dir wirklich guttut." + "Tracke dein Essen und dein Wohlbefinden regelmäßig, erhalte persönliches Feedback und entdecke passende Alternativen. So verstehst du deinen Körper besser und triffst im Alltag leichter die richtigen Entscheidungen 💛"
- CTA: `Los geht's`

## Scope

- **New:** `lib/screens/dashboard/widgets/welcome_modal.dart` (+\~60) and a widget test.
- **Modified:** 3-line insert in `_maybeShowTutorial` in `dashboard_screen.dart`.
- **Untouched:** `TutorialNotifier`, `UserProfile`, notifications modal, backend.
- No new dependencies, no new permissions, no backend changes.

## Spec

`docs/superpowers/specs/2026-04-24-welcome-modal-onboarding-design.md`

## Test plan

- [x] \`flutter analyze\` — clean
- [x] \`dart format --set-exit-if-changed\` — clean
- [x] \`flutter test\` — full suite + new widget test green
- [ ] Manual: fresh signup → first dashboard visit shows welcome modal → tap Los geht's → spotlight starts → complete spotlight → no modal on next launch
- [ ] Manual: fresh signup → welcome modal → swipe-down / force-close the app → relaunch → welcome modal shows again (spotlight didn't complete, tutorial still not "seen")

## Rollback

Revert the one code commit. No persisted state, no migration.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Do NOT** arm `--auto` merge. Stop at `gh pr create` and hand back to the user.

---

## Self-review

All spec requirements map to tasks:

- Spec "Copy" → Task 1 Step 1 (the widget's `Text` children).
- Spec "UX / Trigger / Order" → Task 3 (wiring in `_maybeShowTutorial`).
- Spec "Single CTA, no close icon, barrierDismissible: false" → Task 1 Step 1 (helper + widget body).
- Spec "Persistence rides on tutorialSeenAt" → Task 3 (no new SharedPreferences key).
- Spec "Layout matches notifications modal" → Task 1 Step 1 (AlertDialog + MascotImage + AppTheme / AppConstants).
- Spec "Testing §1 widget test" → Task 2.
- Spec "Rollback: revert two commits" → slightly stricter in plan (one commit); still revert-one-commit.

No placeholders; all Dart literals match the spec verbatim.
