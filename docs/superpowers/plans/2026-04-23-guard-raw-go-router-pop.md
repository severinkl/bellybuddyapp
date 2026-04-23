# Guard raw `context.pop()` calls — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Sentry `GoError: There is nothing to pop` crash by guarding all raw `context.pop()` calls against deep-link starts, and prevent regression via a `custom_lint` rule.

**Architecture:** Replace 7 raw `context.pop()` sites with the existing `context.popOrGoDashboard()` helper; add a regression widget test; introduce a local `custom_lint` sub-package whose single rule forbids raw GoRouter `pop()` anywhere in `lib/` except the helper file. Ships as three commits on one branch.

**Tech Stack:** Flutter (Dart SDK ^3.11.1), `go_router: ^17.1.0`, `flutter_riverpod`, `mocktail` for unit tests, `flutter_test` for widget tests, `custom_lint` + `custom_lint_builder` for the new lint rule.

**Branch:** `fix/guard-raw-go-router-pop` (already created off `origin/develop`; the spec commit is already present).

**Spec:** `docs/superpowers/specs/2026-04-23-guard-raw-go-router-pop-design.md`.

---

## Task 1: Add the failing regression widget test

**Why first:** TDD — the test pins what "fixed" means. Must fail before any code change, pass after. If the test passes on `develop`, we've written the wrong test.

**Files:**
- Create: `test/widgets/common/tracker_screen_scaffold_test.dart`

- [ ] **Step 1: Create the test directory if missing**

Run:
```bash
mkdir -p test/widgets/common
```

Expected: no output, directory exists.

- [ ] **Step 2: Write the failing test**

Create `test/widgets/common/tracker_screen_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/widgets/common/tracker_screen_scaffold.dart';

void main() {
  group('TrackerScreenScaffold back-arrow', () {
    testWidgets(
      'on a single-entry GoRouter stack, tapping back does not throw and '
      'navigates to /dashboard (reproduces Sentry 39a1efcd6a344b1382ae5eec48590925)',
      (tester) async {
        final router = GoRouter(
          initialLocation: RoutePaths.mealTracker,
          routes: [
            GoRoute(
              path: RoutePaths.dashboard,
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('DASHBOARD'))),
            ),
            GoRoute(
              path: RoutePaths.mealTracker,
              builder: (_, __) => const TrackerScreenScaffold(
                title: 'Test',
                showSuccess: false,
                successMessage: '',
                body: SizedBox.shrink(),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        // Capture any exception surfaced through FlutterError.onError while
        // we tap the back arrow. A raw context.pop() on a single-entry stack
        // throws GoError synchronously, which the framework reports here.
        final errors = <Object>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.exception);

        try {
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(
          errors,
          isEmpty,
          reason: 'Raw context.pop() throws GoError on a single-entry stack. '
              'Use context.popOrGoDashboard() instead.',
        );
        expect(find.text('DASHBOARD'), findsOneWidget);
      },
    );
  });
}
```

- [ ] **Step 3: Run the test and verify it fails (RED)**

Run:
```bash
flutter test test/widgets/common/tracker_screen_scaffold_test.dart
```

Expected: test FAILS. The failure message should mention `GoError` or "There is nothing to pop" (captured in the `errors` list), and/or `find.text('DASHBOARD')` finds zero widgets.

If the test passes here, the reproduction is wrong and Task 2 won't prove anything. Stop and investigate before continuing.

- [ ] **Step 4: Do NOT commit yet**

The fix commit bundles the test with the 7 call-site changes. Leave the test in the working tree for now.

---

## Task 2: Fix the 7 raw `context.pop()` sites

**Files:**
- Modify: `lib/widgets/common/tracker_screen_scaffold.dart` (line 59)
- Modify: `lib/screens/trackers/meal/meal_tracker_screen.dart` (add import; lines 111, 140, 156, 181)
- Modify: `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart` (line 173; import already present at line 10)
- Modify: `lib/screens/recipes/recipes_screen.dart` (add import; line 19)

- [ ] **Step 1: Fix `tracker_screen_scaffold.dart:59`**

The scaffold already imports `navigation_extensions.dart` (line 4). Only the call site changes.

Find:
```dart
            if (!didPop && context.mounted) context.pop();
```
Replace with:
```dart
            if (!didPop && context.mounted) context.popOrGoDashboard();
```

- [ ] **Step 2: Add import to `lib/screens/trackers/meal/meal_tracker_screen.dart`**

`meal_tracker_screen.dart` currently does NOT import `navigation_extensions.dart`. Add the import. The file already imports `../../../router/route_names.dart` on line 9, so alongside that:

Find:
```dart
import '../../../router/route_names.dart';
```
Replace with:
```dart
import '../../../router/navigation_extensions.dart';
import '../../../router/route_names.dart';
```

- [ ] **Step 3: Replace the 4 raw pops in `meal_tracker_screen.dart`**

Use the Edit tool with `replace_all: false` four times, or manually swap. Exact sites:

- Line 111 — inside `_save()` edit-mode no-op branch:
  ```dart
  if (mounted) context.pop();
  ```
  →
  ```dart
  if (mounted) context.popOrGoDashboard();
  ```

- Line 140 — inside `_save()` edit-mode success branch:
  ```dart
  if (widget.mealId != null && ok) context.pop();
  ```
  →
  ```dart
  if (widget.mealId != null && ok) context.popOrGoDashboard();
  ```

- Line 156 — the meal-not-found AppBar back button:
  ```dart
  onPressed: () => context.pop(),
  ```
  →
  ```dart
  onPressed: () => context.popOrGoDashboard(),
  ```

- Line 181 — inside `PopScope.onPopInvokedWithResult` after confirm-discard:
  ```dart
  context.pop();
  ```
  →
  ```dart
  context.popOrGoDashboard();
  ```

- [ ] **Step 4: Fix `gut_feeling_tracker_screen.dart:173`**

Import already present on line 10 (`import '../../../router/navigation_extensions.dart';`). Only the call site changes.

Find:
```dart
          onPressed: () => context.pop(),
```
Replace with:
```dart
          onPressed: () => context.popOrGoDashboard(),
```

- [ ] **Step 5: Add import and fix `recipes_screen.dart:19`**

Add the import. The file currently imports (in order):
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../widgets/common/mascot_image.dart';
```

Add the navigation_extensions import. Find:
```dart
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
```
Replace with:
```dart
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../router/navigation_extensions.dart';
```

Then change line 19. Find:
```dart
          onPressed: () => context.pop(),
```
Replace with:
```dart
          onPressed: () => context.popOrGoDashboard(),
```

- [ ] **Step 6: Run the regression test and verify it passes (GREEN)**

Run:
```bash
flutter test test/widgets/common/tracker_screen_scaffold_test.dart
```

Expected: PASS. No errors captured, `DASHBOARD` visible.

- [ ] **Step 7: Run the full test suite**

Run:
```bash
flutter test
```

Expected: all existing tests still green. Counts should match the previous baseline plus 1 new passing test. If any pre-existing test flakes on this change, investigate — our change is purely additive to the pop helper at call sites.

- [ ] **Step 8: Run analyzer and formatter**

Run:
```bash
flutter analyze
```

Expected: `No issues found!`.

Run:
```bash
dart format --set-exit-if-changed lib/widgets/common/tracker_screen_scaffold.dart lib/screens/trackers/meal/meal_tracker_screen.dart lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart lib/screens/recipes/recipes_screen.dart test/widgets/common/tracker_screen_scaffold_test.dart
```

Expected: `Formatted 5 files (0 changed)`.

---

## Task 3: Commit 1 — call-site fix + regression test

**Files:** all files changed in Tasks 1–2.

- [ ] **Step 1: Stage only the intended files**

Run:
```bash
git add lib/widgets/common/tracker_screen_scaffold.dart \
        lib/screens/trackers/meal/meal_tracker_screen.dart \
        lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart \
        lib/screens/recipes/recipes_screen.dart \
        test/widgets/common/tracker_screen_scaffold_test.dart
```

- [ ] **Step 2: Verify staging**

Run:
```bash
git status
```

Expected: 4 modified `lib/` files + 1 new `test/` file staged; no other changes staged.

- [ ] **Step 3: Commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
fix(router): guard raw context.pop() via popOrGoDashboard at 7 sites

Raw context.pop() throws `GoError: There is nothing to pop` when the app
is launched via a local notification (GoRouter.go replaces the stack with
a single entry). Route all back-button / cancel / success-dismiss pops
through the existing `popOrGoDashboard` helper so they fall back to
`/dashboard` when the stack is single-entry.

Also adds a regression widget test that pins the fix by reproducing the
single-entry-stack scenario on TrackerScreenScaffold.

Refs Sentry 39a1efcd6a344b1382ae5eec48590925.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: one commit added; pre-commit hook (format + analyze) passes.

---

## Task 4: Helper unit test (conditional — only if file is missing)

**Files:**
- Create (if missing): `test/router/navigation_extensions_test.dart`

- [ ] **Step 1: Check whether the helper test file already exists**

Run:
```bash
ls test/router/navigation_extensions_test.dart 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

If `EXISTS`: skip the rest of Task 4 and go to Task 5.

If `MISSING`: proceed to Step 2.

- [ ] **Step 2: Create the test directory**

Run:
```bash
mkdir -p test/router
```

- [ ] **Step 3: Write the helper unit test**

Create `test/router/navigation_extensions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/router/navigation_extensions.dart';
import 'package:belly_buddy/router/route_names.dart';

void main() {
  group('BellyBuddyNavigation.popOrGoDashboard', () {
    testWidgets('pops when the stack has more than one entry', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.dashboard,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (_, __) => const _DashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (_, __) => const _TrackerPage(),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Push the tracker page so the stack has two entries.
      router.push(RoutePaths.mealTracker);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracker-page')), findsOneWidget);

      // Tap the tracker's button, which calls popOrGoDashboard.
      await tester.tap(find.byKey(const Key('tracker-pop-button')));
      await tester.pumpAndSettle();

      // Popped back to dashboard rather than replacing via go.
      expect(find.byKey(const Key('dashboard-page')), findsOneWidget);
    });

    testWidgets('goes to /dashboard when the stack has one entry', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: RoutePaths.mealTracker,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (_, __) => const _DashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (_, __) => const _TrackerPage(),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Stack is single-entry; popOrGoDashboard must fall back to go.
      await tester.tap(find.byKey(const Key('tracker-pop-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-page')), findsOneWidget);
    });
  });
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('dashboard-page'),
      body: Center(child: Text('Dashboard')),
    );
  }
}

class _TrackerPage extends StatelessWidget {
  const _TrackerPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('tracker-page'),
      body: Center(
        child: ElevatedButton(
          key: const Key('tracker-pop-button'),
          onPressed: context.popOrGoDashboard,
          child: const Text('leave'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the helper test**

Run:
```bash
flutter test test/router/navigation_extensions_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Run format + analyze**

Run:
```bash
dart format --set-exit-if-changed test/router/navigation_extensions_test.dart
flutter analyze
```

Expected: format unchanged, analyze clean.

---

## Task 5: Commit 2 — helper unit test (skip if Task 4 skipped)

- [ ] **Step 1: Skip if Task 4 was skipped**

If Task 4's Step 1 reported `EXISTS`, skip the rest of Task 5 and go to Task 6.

- [ ] **Step 2: Stage and commit**

Run:
```bash
git add test/router/navigation_extensions_test.dart
git commit -m "$(cat <<'EOF'
test(router): unit-test popOrGoDashboard helper

Pins the helper's canPop-based branching so future refactors can't
silently change its fallback behavior.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Scaffold the `bellybuddy_lints` package

**Files:**
- Create: `packages/bellybuddy_lints/pubspec.yaml`
- Create: `packages/bellybuddy_lints/analysis_options.yaml`
- Create: `packages/bellybuddy_lints/lib/bellybuddy_lints.dart`
- Create: `packages/bellybuddy_lints/lib/src/no_raw_go_router_pop.dart` (stub)

- [ ] **Step 1: Create the package directory structure**

Run:
```bash
mkdir -p packages/bellybuddy_lints/lib/src
```

- [ ] **Step 2: Create `packages/bellybuddy_lints/pubspec.yaml`**

```yaml
name: bellybuddy_lints
description: Internal custom_lint rules for the Belly Buddy Flutter app.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.11.1

dependencies:
  analyzer: ^7.0.0
  analyzer_plugin: ^0.13.0
  custom_lint_builder: ^0.8.0

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.0
```

If `flutter pub get` in the next step fails because `custom_lint_builder: ^0.8.0` doesn't resolve, run `cd packages/bellybuddy_lints && dart pub add custom_lint_builder` to let pub pick the latest compatible version, then paste the resolved version into `pubspec.yaml`. Do the same for `analyzer` / `analyzer_plugin` if they don't resolve — those are transitive deps of `custom_lint_builder`, pin the resolved versions.

- [ ] **Step 3: Create `packages/bellybuddy_lints/analysis_options.yaml`**

```yaml
include: package:lints/recommended.yaml
```

- [ ] **Step 4: Create the plugin entry point — `packages/bellybuddy_lints/lib/bellybuddy_lints.dart`**

```dart
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_raw_go_router_pop.dart';

PluginBase createPlugin() => _BellyBuddyLintsPlugin();

class _BellyBuddyLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const NoRawGoRouterPop(),
      ];
}
```

- [ ] **Step 5: Create a stub rule at `packages/bellybuddy_lints/lib/src/no_raw_go_router_pop.dart`**

This stub compiles but does not fire — the real logic lands in Task 7. Creating it now lets Task 6 end with a clean `pub get`.

```dart
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoRawGoRouterPop extends DartLintRule {
  const NoRawGoRouterPop() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_go_router_pop',
    problemMessage:
        'Use context.popOrGoDashboard() instead of raw GoRouter pop — raw '
        'pop throws GoError on single-entry stacks (deep-link start).',
    correctionMessage:
        'Replace with context.popOrGoDashboard() from '
        'lib/router/navigation_extensions.dart.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Stub — filled in by Task 7.
  }
}
```

- [ ] **Step 6: Resolve dependencies**

Run:
```bash
cd packages/bellybuddy_lints && flutter pub get && cd ../..
```

Expected: `Got dependencies!` with no errors. If resolution fails, follow the fallback in Step 2.

- [ ] **Step 7: Do not commit yet**

All of Task 6–11 lands in Commit 3 together.

---

## Task 7: Implement the `no_raw_go_router_pop` rule

**Files:**
- Modify: `packages/bellybuddy_lints/lib/src/no_raw_go_router_pop.dart`

- [ ] **Step 1: Replace the stub `run` method with the real detection logic**

The rule fires on any `MethodInvocation` named `pop` where the receiver's static type is `BuildContext` (and the `pop` method comes from the `go_router` extension `GoRouterHelper`) or `GoRouter`. It short-circuits for the single allowlisted file path.

Open `packages/bellybuddy_lints/lib/src/no_raw_go_router_pop.dart` and replace the entire file with:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoRawGoRouterPop extends DartLintRule {
  const NoRawGoRouterPop() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_go_router_pop',
    problemMessage:
        'Use context.popOrGoDashboard() instead of raw GoRouter pop — raw '
        'pop throws GoError on single-entry stacks (deep-link start).',
    correctionMessage:
        'Replace with context.popOrGoDashboard() from '
        'lib/router/navigation_extensions.dart.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  static const _allowlistedPathSuffix = 'lib/router/navigation_extensions.dart';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Short-circuit for the single legitimate caller.
    if (resolver.path.replaceAll(r'\', '/').endsWith(_allowlistedPathSuffix)) {
      return;
    }

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'pop') return;

      final target = node.realTarget;
      if (target == null) return;

      final targetType = target.staticType;
      if (targetType == null) return;

      final targetTypeName = targetType.getDisplayString();

      // Case 1: GoRouter.of(ctx).pop() — receiver is a GoRouter.
      if (targetTypeName == 'GoRouter') {
        reporter.atNode(node, _code);
        return;
      }

      // Case 2: context.pop() — receiver is a BuildContext AND the pop
      // method is from the go_router GoRouterHelper extension (not some
      // unrelated extension method also called pop).
      if (targetTypeName == 'BuildContext') {
        final element = node.methodName.staticElement;
        final library = element?.library;
        final libraryUri = library?.source.uri.toString() ?? '';
        if (libraryUri.contains('package:go_router/')) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}
```

- [ ] **Step 2: Static-check the package**

Run:
```bash
cd packages/bellybuddy_lints && dart analyze && cd ../..
```

Expected: no issues.

---

## Task 8: Fixture example project for integration testing

The test harness: a minimal sub-project at `packages/bellybuddy_lints/example/` whose `lib/` contains fixture Dart files annotated with `// expect_lint: no_raw_go_router_pop` comments. `custom_lint` reads those annotations and fails if diagnostics don't match.

**Files:**
- Create: `packages/bellybuddy_lints/example/pubspec.yaml`
- Create: `packages/bellybuddy_lints/example/analysis_options.yaml`
- Create: `packages/bellybuddy_lints/example/lib/fires_on_context_pop.dart`
- Create: `packages/bellybuddy_lints/example/lib/fires_on_go_router_of_pop.dart`
- Create: `packages/bellybuddy_lints/example/lib/ignores_navigator_pop.dart`
- Create: `packages/bellybuddy_lints/example/lib/ignores_helper_call.dart`
- Create: `packages/bellybuddy_lints/example/lib/router/navigation_extensions.dart` (mirrors the real allowlist path)

- [ ] **Step 1: Create the example directory tree**

Run:
```bash
mkdir -p packages/bellybuddy_lints/example/lib/router
```

- [ ] **Step 2: Create `packages/bellybuddy_lints/example/pubspec.yaml`**

```yaml
name: bellybuddy_lints_example
description: Fixture project exercising bellybuddy_lints rules.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.11.1
  flutter: ">=3.35.0"

dependencies:
  flutter:
    sdk: flutter
  go_router: ^17.1.0

dev_dependencies:
  bellybuddy_lints:
    path: ..
  custom_lint: ^0.8.0
```

If `custom_lint: ^0.8.0` does not resolve, use `dart pub add --dev custom_lint` inside the example directory and paste the resolved version.

- [ ] **Step 3: Create `packages/bellybuddy_lints/example/analysis_options.yaml`**

```yaml
analyzer:
  plugins:
    - custom_lint
```

- [ ] **Step 4: Create `fires_on_context_pop.dart`**

`packages/bellybuddy_lints/example/lib/fires_on_context_pop.dart`:

```dart
// Expected: 1 diagnostic — context.pop() must fire the rule.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void leave(BuildContext context) {
  // expect_lint: no_raw_go_router_pop
  context.pop();
}
```

- [ ] **Step 5: Create `fires_on_go_router_of_pop.dart`**

`packages/bellybuddy_lints/example/lib/fires_on_go_router_of_pop.dart`:

```dart
// Expected: 1 diagnostic — GoRouter.of(context).pop() must fire the rule.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void leave(BuildContext context) {
  // expect_lint: no_raw_go_router_pop
  GoRouter.of(context).pop();
}
```

- [ ] **Step 6: Create `ignores_navigator_pop.dart`**

`packages/bellybuddy_lints/example/lib/ignores_navigator_pop.dart`:

```dart
// Expected: 0 diagnostics — Navigator.pop(context) is the Material navigator
// and does not throw "There is nothing to pop"; the rule must ignore it.
import 'package:flutter/material.dart';

void leaveMaterial(BuildContext context) {
  Navigator.pop(context);
  Navigator.of(context).pop();
}
```

- [ ] **Step 7: Create `ignores_helper_call.dart`**

`packages/bellybuddy_lints/example/lib/ignores_helper_call.dart`:

```dart
// Expected: 0 diagnostics — the helper call is what we recommend.
import 'package:flutter/widgets.dart';

import 'router/navigation_extensions.dart';

void leave(BuildContext context) {
  context.popOrGoDashboard();
}
```

- [ ] **Step 8: Create a minimal `router/navigation_extensions.dart` inside the example**

The rule allowlists any file whose path ends with `lib/router/navigation_extensions.dart`. We give the example its own file with that same suffix so we can verify the allowlist works. Inside that file, raw `pop()` must NOT fire.

`packages/bellybuddy_lints/example/lib/router/navigation_extensions.dart`:

```dart
// Expected: 0 diagnostics — this is the allowlisted file. Raw pop() here
// is legitimate and must not trip the rule.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension ExampleNavigation on BuildContext {
  void popOrGoDashboard() {
    if (canPop()) {
      pop();
    } else {
      go('/dashboard');
    }
  }
}
```

- [ ] **Step 9: Resolve example dependencies**

Run:
```bash
cd packages/bellybuddy_lints/example && flutter pub get && cd ../../..
```

Expected: `Got dependencies!`.

- [ ] **Step 10: Run `custom_lint` in the example to verify the rule behaves as expected**

Run:
```bash
cd packages/bellybuddy_lints/example && dart run custom_lint && cd ../../..
```

Expected: exit code 0. Because `expect_lint` annotations exactly match the rule's diagnostics, the runner reports success.

If it fails:
- If a fixture expected a diagnostic but got none → the rule under-fires; revisit Task 7.
- If a fixture didn't expect a diagnostic but got one → the rule over-fires; revisit Task 7.

---

## Task 9: Wire `bellybuddy_lints` + `custom_lint` into the root project

**Files:**
- Modify: `pubspec.yaml` (root)
- Modify: `analysis_options.yaml` (root)

- [ ] **Step 1: Add dev dependencies to root `pubspec.yaml`**

Open root `pubspec.yaml`. Find the `dev_dependencies:` block (line starting with `dev_dependencies:`). Add two entries, preserving whatever else is already there:

```yaml
dev_dependencies:
  # ...existing entries preserved...
  custom_lint: ^0.8.0
  bellybuddy_lints:
    path: packages/bellybuddy_lints
```

If `custom_lint: ^0.8.0` doesn't resolve against the Dart SDK in `pubspec.lock`, run `flutter pub add --dev custom_lint` to let pub pick the latest compatible version.

- [ ] **Step 2: Enable the plugin in root `analysis_options.yaml`**

Open root `analysis_options.yaml`. Preserve the existing `include:`, `analyzer.errors`, `analyzer.exclude`, and `linter.rules` blocks. Insert a `plugins:` list under `analyzer:`. If `analyzer:` already has other keys, add `plugins:` alongside them.

The resulting `analyzer:` block should read:

```yaml
analyzer:
  plugins:
    - custom_lint
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.freezed.dart"
    - "**/*.g.dart"
```

(Keep the `include:` line above and the `linter:` block below exactly as they are.)

- [ ] **Step 3: Resolve root dependencies**

Run:
```bash
flutter pub get
```

Expected: `Got dependencies!`.

- [ ] **Step 4: Run `dart run custom_lint` at the repo root**

Run:
```bash
dart run custom_lint
```

Expected: exit code 0 with no diagnostics. The call-site fix from Commit 1 already eliminated every offender, so there should be zero pre-existing issues. If any diagnostics appear, they're either:
- A missed call site → swap to `popOrGoDashboard()`.
- A false positive on Material `Navigator.pop` → re-check the rule's type-name discriminator in Task 7.

Do not proceed until this runs clean.

---

## Task 10: Add the `dart run custom_lint` step to CI

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add the custom_lint step to the quality job**

Open `.github/workflows/ci.yml`. Find the `quality` job's `flutter analyze` step:

```yaml
      - run: flutter analyze
```

Insert a new step immediately after it:

```yaml
      - run: flutter analyze

      - name: Run custom_lint
        run: dart run custom_lint
```

Leave all other jobs (`unit-tests`, `widget-tests`, etc.) and steps untouched.

- [ ] **Step 2: Visually verify the yaml indentation**

Run:
```bash
grep -n -B1 -A2 'custom_lint' .github/workflows/ci.yml
```

Expected: the new step sits inside the `steps:` list of the `quality` job, with two-space indentation matching its neighbors.

---

## Task 11: Commit 3 — custom_lint package, wiring, and CI step

- [ ] **Step 1: Run all pre-commit gates locally**

Run each of these and confirm green before staging:

```bash
dart format --set-exit-if-changed packages/bellybuddy_lints/lib/bellybuddy_lints.dart packages/bellybuddy_lints/lib/src/no_raw_go_router_pop.dart
flutter analyze
dart run custom_lint
flutter test
```

Expected:
- `dart format`: `Formatted 2 files (0 changed)`.
- `flutter analyze`: `No issues found!`.
- `dart run custom_lint`: exit 0.
- `flutter test`: all tests pass.

- [ ] **Step 2: Stage all Task 6–10 files**

Run:
```bash
git add packages/bellybuddy_lints \
        pubspec.yaml pubspec.lock \
        analysis_options.yaml \
        .github/workflows/ci.yml
```

Verify nothing unexpected is staged:

```bash
git status
```

Expected: the four root files + the new `packages/bellybuddy_lints/` tree. Note that `pubspec.lock` is included because `flutter pub get` updated it when the new dev deps landed. If `pubspec.lock` is gitignored in this repo, drop it from the `git add` line.

- [ ] **Step 3: Commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
build(lints): add bellybuddy_lints custom_lint package with no_raw_go_router_pop

Adds a local `packages/bellybuddy_lints/` custom_lint sub-package with
one rule — `no_raw_go_router_pop` — that forbids raw GoRouter `pop()`
anywhere in `lib/` except `lib/router/navigation_extensions.dart`. The
rule fires on `context.pop()` (go_router extension) and
`GoRouter.of(ctx).pop()`; it ignores Material's `Navigator.pop(context)`.

Wires the plugin into the root `analysis_options.yaml` and adds a
`dart run custom_lint` step to the CI `quality` job so regressions are
caught at PR time. Fixture files under `example/lib/` pin the rule's
positive and negative cases; running `dart run custom_lint` in the
example directory exercises them via `expect_lint` annotations.

Refs Sentry 39a1efcd6a344b1382ae5eec48590925.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Push and open the PR

- [ ] **Step 1: Push the branch**

Run:
```bash
git push -u origin fix/guard-raw-go-router-pop
```

- [ ] **Step 2: Open the PR**

Run:
```bash
gh pr create --base develop --title "fix(router): guard raw context.pop() against deep-link crashes" --body "$(cat <<'EOF'
## Summary
- Replaces 7 raw `context.pop()` call sites with `context.popOrGoDashboard()` so the app can't crash with `GoError: There is nothing to pop` when a screen is reached as the GoRouter stack root (deep-link start from a local notification).
- Adds a regression widget test that pins the fix.
- Introduces a local `packages/bellybuddy_lints/` custom_lint package with one rule — `no_raw_go_router_pop` — that prevents regressions anywhere in `lib/` except `lib/router/navigation_extensions.dart`. Wires the plugin into CI.

## Related
- Sentry issue: `39a1efcd6a344b1382ae5eec48590925`
- Spec: `docs/superpowers/specs/2026-04-23-guard-raw-go-router-pop-design.md`

## Test plan
- [x] `flutter test` — regression widget test included, full suite green
- [x] `flutter analyze` — clean
- [x] `dart format --set-exit-if-changed` — clean
- [x] `dart run custom_lint` — clean at repo root; fixture project under `packages/bellybuddy_lints/example/` passes
- [ ] Manual: cold-start the app from a meal-reminder notification → tap back arrow → lands on `/dashboard` without crash
- [ ] Manual: cold-start from a gut-feeling reminder → back arrow → `/dashboard`
- [ ] Manual: normal dashboard → meal tracker → back still works unchanged
- [ ] Post-deploy: confirm the Sentry issue shows zero new events over 48h

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Do **not** arm `--auto` — team policy requires human merge.

---

## Self-Review

All spec requirements map to tasks:

- Spec §1 "Callsite fix" → Tasks 1–3.
- Spec §2 "Helper unchanged" → no task needed (negative requirement).
- Spec §3 "Custom lint package" → Tasks 6–8.
- Spec §4 "Root wiring" → Task 9.
- Spec §5 "CI step" → Task 10.
- Spec Testing §A "Regression test" → Task 1.
- Spec Testing §B "Helper unit test" → Tasks 4–5.
- Spec Testing §C "Lint-rule fixture tests" → Task 8.
- Spec Testing §D "Manual smoke" → PR test plan checklist in Task 12.
- Spec Testing §E "Post-deploy acceptance" → PR test plan checklist.
- Spec Rollout "3 commits" → Tasks 3, 5, 11.
- Spec Rollout "Merge gates" → Task 11 Step 1.
- Spec Rollout "No auto-merge" → Task 12 Step 2 note.

No placeholders: every step has concrete commands and expected output. Version numbers are either concrete (`^0.8.0`) or flagged with a fallback (`flutter pub add --dev custom_lint`). Method signatures are consistent: `context.popOrGoDashboard()` everywhere, `NoRawGoRouterPop` class in both the plugin entry and the rule file, `no_raw_go_router_pop` as the `LintCode.name` and `expect_lint:` annotation value.
