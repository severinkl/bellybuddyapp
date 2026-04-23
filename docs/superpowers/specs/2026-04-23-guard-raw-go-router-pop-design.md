# Guard raw `context.pop()` calls — spec

**Date:** 2026-04-23
**Related:** Sentry issue `39a1efcd6a344b1382ae5eec48590925` — `GoError: There is nothing to pop`.

## Summary

Replace the 7 raw `context.pop()` call sites in `lib/` with the existing
`context.popOrGoDashboard()` helper, add a regression widget test, and introduce
a `custom_lint` sub-package that bans raw `pop()` everywhere except the helper
itself. Ships as one PR to `develop` in three commits so the call-site fix is
cherry-pickable if the lint package causes CI friction.

## Problem

Sentry is surfacing `GoError: GoError: There is nothing to pop` from
`GoRouterDelegate.pop` in production. The crash fires when a user launches the
app via a local notification (payload route like `/meal-tracker` or
`/gut-feeling-tracker`) and then taps the AppBar back arrow — the GoRouter
stack has only one entry, so `context.pop()` raises.

## Root cause

`lib/main.dart:46` calls `router.go(route)` on notification tap, which
replaces the entire stack with the target route. Subsequent raw `context.pop()`
calls from widgets on that screen have nothing to pop. The primary path is
`lib/widgets/common/tracker_screen_scaffold.dart:59`:

```dart
onPressed: () async {
  final didPop = await Navigator.maybePop(context);
  if (!didPop && context.mounted) context.pop();   // ← crashes here
},
```

Six additional unguarded call sites exist in the meal tracker, gut-feeling
tracker, and recipes screens. The team already built
`BellyBuddyNavigation.popOrGoDashboard()` at
`lib/router/navigation_extensions.dart:11` —
`canPop() ? pop() : go(RoutePaths.dashboard)` — exactly for this case, but
applied it only at success-overlay `onDismissed` paths, not at the back-button
paths.

## Scope

**In scope:**

1. Replace 7 raw `context.pop()` calls with `context.popOrGoDashboard()`.
2. Regression widget test pinning the fix.
3. New local `custom_lint` package + analysis rule `no_raw_go_router_pop`
   that forbids raw GoRouter `pop()` anywhere in `lib/` except
   `lib/router/navigation_extensions.dart`.

**Out of scope (deferred):**

- Allowlisting deep-link routes in `PushNotificationService.extractRoute`
  (defensive, not required to fix the crash).
- Migrating any non-crashing screen to the helper.
- Generalizing the helper to `popOrFallback(String fallback)` — all current
  callers want `/dashboard`.

## Design

### 1. Callsite fix

Mechanical swap at these 7 sites (all currently raw `context.pop()`):

| File | Line |
|---|---|
| `lib/widgets/common/tracker_screen_scaffold.dart` | 59 |
| `lib/screens/trackers/meal/meal_tracker_screen.dart` | 111, 140, 156, 181 |
| `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart` | 173 |
| `lib/screens/recipes/recipes_screen.dart` | 19 |

Each becomes `context.popOrGoDashboard()`. Import of
`../../router/navigation_extensions.dart` (relative path varies per file)
added where missing.

### 2. Helper (unchanged)

`lib/router/navigation_extensions.dart` is not touched. It remains the
only legitimate caller of GoRouter's `pop()`.

### 3. Custom lint package

New sub-package at `packages/bellybuddy_lints/`:

```
packages/bellybuddy_lints/
  pubspec.yaml               # name: bellybuddy_lints, dev-dep on custom_lint_builder
  lib/
    bellybuddy_lints.dart    # exports `PluginBase createPlugin()`
    src/
      no_raw_go_router_pop.dart
  test/
    fixtures/
      fires_on_context_pop.dart
      fires_on_go_router_of_pop.dart
      ignores_navigator_pop.dart
      ignores_helper_call.dart
      ignores_allowlisted_file.dart
    no_raw_go_router_pop_test.dart
```

**Rule:** `no_raw_go_router_pop`, severity `ErrorSeverity.ERROR`.

Fires on any `MethodInvocation` named `pop` where:

- the receiver's static type is `BuildContext` **and** the `pop` method's
  enclosing element is the `GoRouterHelper` extension (from package
  `go_router`), **or**
- the receiver's static type is `GoRouter` (catches
  `GoRouter.of(ctx).pop()`).

Short-circuits when the analyzed file path ends with
`lib/router/navigation_extensions.dart` (the allowlisted file).

**Does not fire** on `Navigator.pop(context)` / `Navigator.of(ctx).pop()` —
those are Material navigator calls and don't throw this error.

**Escape hatch:** standard `// ignore: no_raw_go_router_pop` comment — visible
in diffs.

### 4. Root wiring

`pubspec.yaml` (root) — new dev dependencies:

```yaml
dev_dependencies:
  custom_lint: ^X.Y.Z          # exact version chosen in the implementation plan
  bellybuddy_lints:
    path: packages/bellybuddy_lints
```

`analysis_options.yaml` — add the analyzer plugin block; preserve the
existing `analyzer.errors`, `analyzer.exclude`, and `linter.rules` blocks:

```yaml
analyzer:
  plugins:
    - custom_lint
```

### 5. CI

`flutter analyze` does **not** execute `custom_lint` rules — a separate step
is required. Add a `dart run custom_lint` step to the workflow that runs
`flutter analyze`. The implementation plan identifies the exact workflow file
and the insertion point.

## Testing

### A. Regression test (load-bearing)

`test/widgets/common/tracker_screen_scaffold_test.dart`:

- Mount a minimal app wrapping `TrackerScreenScaffold` under a `GoRouter`
  whose `initialLocation` is a tracker route — i.e., a **single-entry stack**
  simulating the notification cold-start.
- Wrap the pump in `runZonedGuarded` (or listen on `FlutterError.onError`) to
  capture any thrown `GoError`.
- Tap the AppBar back arrow.
- Assert: zero errors captured; `GoRouterState.of(context).matchedLocation`
  equals `/dashboard`.

Must fail on `develop` before the fix is applied; pass after.

### B. Helper unit test

`test/router/navigation_extensions_test.dart`:

- `canPop == true` → `pop()` called, `go()` not called.
- `canPop == false` → `pop()` not called, `go('/dashboard')` called.

Add only if the file doesn't already exist.

### C. Lint-rule fixture tests

Inside `packages/bellybuddy_lints/test/`, using `custom_lint`'s test harness:

| Fixture | Expected diagnostics |
|---|---|
| `fires_on_context_pop.dart` — contains `context.pop()` in a screen | 1 |
| `fires_on_go_router_of_pop.dart` — `GoRouter.of(ctx).pop()` | 1 |
| `ignores_navigator_pop.dart` — `Navigator.pop(context)` | 0 |
| `ignores_helper_call.dart` — `context.popOrGoDashboard()` | 0 |
| `ignores_allowlisted_file.dart` — `context.pop()` at the allowlisted path | 0 |

### D. Manual smoke (pre-merge)

1. Cold-start from a meal reminder (trigger via `flutter_local_notifications`
   debug tools). Tap back arrow — lands on `/dashboard`, no crash.
2. Same for gut-feeling tracker.
3. Normal navigation (dashboard → meal tracker → back) works unchanged.

### E. Post-deploy acceptance criterion

Sentry issue `39a1efcd6a344b1382ae5eec48590925` shows zero new events over
48h following deploy to prod.

## Rollout

**Branch:** new branch off `origin/develop`, named
`fix/guard-raw-go-router-pop`. Do **not** reuse `feat/tipps-and-header-polish`
— another agent is working there.

**PR target:** `develop`.

**Commit atomicity:** one PR, three commits:

1. `fix(router): guard raw context.pop() via popOrGoDashboard at 7 sites` +
   the regression widget test.
2. `test(router): unit-test popOrGoDashboard helper` (only if the test file
   doesn't exist).
3. `build(lints): add bellybuddy_lints custom_lint package with
   no_raw_go_router_pop` + `dart run custom_lint` CI step.

Rationale for the split: if `custom_lint` causes CI trouble (analyzer-plugin
isolation, SDK compatibility, etc.), commit 1 is trivially cherry-pickable to
a fast-track branch to stop the Sentry bleed independently.

**Merge gates:**

- `flutter test` green (regression test included).
- `flutter analyze` clean.
- `dart format --set-exit-if-changed` clean.
- `dart run custom_lint` green (zero pre-existing offenders once commit 1 is
  in).

**No auto-merge** (per team preference). Human review, manual merge. After
merge, monitor the Sentry issue for 48h.

## Known risks

- **`custom_lint` isolate flakiness** in CI — mitigated by the commit-ordering
  strategy.
- **`Navigator.maybePop` false-positive** — the scaffold's pre-check calls
  Material's navigator, which must not trip the new rule. Pinned by the
  `ignores_navigator_pop.dart` fixture.
- **`custom_lint` SDK compatibility** — pin a version known to work with the
  repo's current Dart SDK; the implementation plan records the exact version
  against the `pubspec.lock` resolution.
