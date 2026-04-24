# Enable Sentry tombstone collection + upload Dart AOT symbols — Design

**Date:** 2026-04-24
**Status:** Approved
**Branch:** `feat/sentry-enable-tombstones` → PR #56 against `develop`

## Goal

Make the next Android NDK crash in Sentry actually debuggable. Two gaps to close:

1. **Tombstone collection** — enables Sentry to attach additional thread state, register context, and signal metadata to NDK crash events. Resolves Sentry's "Enable Tombstone Collection" advisory.
2. **Dart AOT symbol upload** — without uploaded symbols, stack frames in `libapp.so` and `libflutter.so` come back as `<unknown>`. Tombstones give us thread state; symbols give us function names. Both are required for a readable stack trace.

## Context

- `sentry_flutter ^9.16.0` (resolved 9.18.0) is wired in `lib/main.dart` with release-only DSN, `sendDefaultPii = true`.
- `pubspec.yaml:97` has a `sentry:` block already half-configured: `upload_debug_symbols: true`, `upload_source_maps: true`, `project: flutter`, `org: belly-buddy-fz`.
- `sentry_dart_plugin: ^3.2.1` is in dev-dependencies but **never invoked anywhere** — neither in CI (`.github/workflows/deploy.yml`) nor in local scripts.
- Current release builds (`deploy-android`, `deploy-ios` jobs) run `flutter build appbundle` / `flutter build ipa` without `--split-debug-info` or `--obfuscate`, so AOT symbols are embedded inside `libapp.so` (inflated binary, imperfect Sentry symbolication).
- No `SENTRY_AUTH_TOKEN` repo secret exists yet.
- The Sentry Android tombstone integration is disabled by default and is toggled via `AndroidManifest.xml` meta-data. Effective on Android 12+ (API 31+); silent no-op below. Current `minSdk` is 24.

## Changes

### 1. Android tombstone flag

Add one `<meta-data>` element inside the `<application>` block of `android/app/src/main/AndroidManifest.xml`, placed between the `.MainActivity` closing `</activity>` and the first `<receiver>`:

```xml
<!-- Sentry: enable tombstone collection for richer NDK crash reports.
     Effective on Android 12+ (API 31); silently no-ops below. -->
<meta-data
    android:name="io.sentry.tombstone.enable"
    android:value="true" />
```

### 2. Build flags — both release build commands

In `.github/workflows/deploy.yml`:

- `deploy-android` → `Build AAB` step: append `--split-debug-info=build/symbols --obfuscate` to the existing `flutter build appbundle` command.
- `deploy-ios` → `Build IPA` step: append `--split-debug-info=build/symbols --obfuscate` to the existing `flutter build ipa` command.

Effect: Dart AOT symbols strip out of `libapp.so` into per-ABI `build/symbols/*.symbols` files. Obfuscation renames Dart class/method identifiers in the compiled output. Binary shrinks by ~5–15 MB per arch.

### 3. Symbol upload steps

Add a new step immediately after each `Build ...` step and before the platform upload step (Google Play / TestFlight):

```yaml
- name: Upload Dart AOT symbols to Sentry
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
  run: dart run sentry_dart_plugin
```

The plugin reads project/org/flags from the existing `sentry:` block in `pubspec.yaml`. The token comes from an env var (the plugin's convention).

### 4. Repository secret — manual, outside this PR

User must create a new internal token at https://belly-buddy-fz.sentry.io/settings/auth-tokens/ with `project:releases` scope and add it as `SENTRY_AUTH_TOKEN` under GitHub Settings → Secrets and variables → Actions.

**The PR can merge without the secret. The next deploy run will fail at the upload step until the secret is added.** Recommended flow: merge → add secret → run `workflow_dispatch` on `main` once to prove the chain works → let normal push-to-main triggers take over.

## What this does NOT change

- **No Dart source changes.** `lib/main.dart` Sentry init stays as-is.
- **No `pubspec.yaml` changes.** The existing `sentry:` block is already correct (`upload_source_maps: true` is unused on mobile but harmless; leave it).
- **No new dependencies.** `sentry_dart_plugin 3.2.1` is already a dev dep.
- **No new Android permissions.**
- **CI workflow (`ci.yml`) is untouched** — symbol upload runs only on `deploy.yml` (triggered by `push: main` and `workflow_dispatch`).

## Out of scope (deliberate)

- **Historical tombstone replay** (`isReportHistoricalTombstones`) — needs a native-Android shim the project doesn't have.
- **Triage of the existing FLUTTER-2 NDK crash.** This PR makes future occurrences readable; it does not retroactively symbolicate past ones.
- **Updating `project: flutter` slug in `pubspec.yaml`** if that doesn't match the actual Sentry project. If wrong, the upload step fails loudly with a clear error — trivial follow-up fix.
- **Sentry release tracking wiring** (explicit `release:` / `dist:` in the plugin config). Current plugin auto-derives release from app version + build number via `flutter build`'s output.

## Verification

| Check | Command / location | Expected |
|---|---|---|
| Manifest parses | `flutter build apk --debug --dart-define-from-file=env.json` | Build succeeds |
| YAML validity | `flutter analyze` + visually inspect `deploy.yml` | No CI complaints |
| Dart unchanged | `flutter test` | 649/649 pass (baseline) |
| Format | `dart format --set-exit-if-changed .` | Clean |
| **Post-merge, one-shot manual:** first `workflow_dispatch` run of `Deploy` | GitHub Actions log for `deploy-android` and `deploy-ios` | "Upload Dart AOT symbols to Sentry" step reports uploaded files |
| **Post-merge, Sentry-side:** | https://belly-buddy-fz.sentry.io/settings/projects/flutter/debug-files/ | New entry appears under Debug Files for each platform/ABI with that release's version |

There is no unit-test surface for either half of this change — a manifest flag and a CI workflow step. The observational checks above are the real acceptance gate.

## Risks

- **First post-merge release fails the upload step if `SENTRY_AUTH_TOKEN` isn't set.** Build artifacts still publish to Play/TestFlight because the upload step runs *before* the publish steps, so a missing-token failure aborts the whole deploy — you get a red CI, not a partial release. Acceptable fail-safe.
- **Obfuscation is a one-way doorway per release.** Any future crash on an already-shipped obfuscated binary whose symbols were never uploaded shows up opaquely. Mitigation: keep `build/symbols/` retained locally for debugging if a release build is ever kicked off manually outside CI (not the normal flow; noted for completeness).
- **Binary-size change is user-visible** (~5–15 MB smaller per arch). Direction is good, but CI builds before/after will differ. No regression alert.
- **Token-scoping mistake.** Using an overly broad Sentry token would grant the CI write access across the whole org. Mitigate by creating the token with `project:releases` scope only.

## Rollback

- Manifest: delete the 5-line `<meta-data>` block. Immediate effect.
- Workflow: revert the `deploy.yml` hunk; keeps future release builds working, just without symbol upload.
- Secret: delete the `SENTRY_AUTH_TOKEN` repo secret. Uploads start failing loudly.

No persisted state on Sentry's side; debug files from prior uploads stay but inert.

## Files touched

- `android/app/src/main/AndroidManifest.xml` — 1 file, ~5 lines inserted.
- `.github/workflows/deploy.yml` — 1 file, ~14 lines modified (2 build-command suffixes, 2 new steps × ~5 lines each).
