# Sentry AOT Symbol Upload — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `sentry_dart_plugin` into the existing GitHub Actions deploy workflow so every release uploads Dart AOT debug symbols to Sentry, closing the "stack frames show as `<unknown>`" gap that tombstones alone don't fix.

**Architecture:** Edit `.github/workflows/deploy.yml` in two symmetric places — `deploy-android` and `deploy-ios` jobs. In each: append `--split-debug-info=build/symbols --obfuscate` to the existing `flutter build ...` command, then insert a new "Upload Dart AOT symbols to Sentry" step after the build and before the platform-upload step. The plugin reads project/org from the existing `sentry:` block in `pubspec.yaml:97` and the auth token from a new `SENTRY_AUTH_TOKEN` repo secret (user creates that manually, out-of-band).

**Tech Stack:** GitHub Actions, `sentry_dart_plugin ^3.2.1` (already a dev dep, not yet invoked), Flutter 3.41 `--split-debug-info` + `--obfuscate` build flags.

**Spec:** `docs/superpowers/specs/2026-04-24-enable-sentry-tombstones-design.md`

**Branch (already exists):** `feat/sentry-enable-tombstones` — this work stacks on top of the existing commit `be7759b` (tombstone manifest flag) and `654825b` (expanded spec). PR #56 is already open against `develop`; pushing these new commits updates that PR.

---

## Pre-flight check

- [ ] **Verify branch state**

```bash
git branch --show-current
```

Expected: `feat/sentry-enable-tombstones`

```bash
git log --oneline origin/develop..HEAD
```

Expected: two commits — `654825b docs(spec): ...` and `be7759b feat(android): ...`, in that order (newest on top).

If the branch is wrong: `git checkout feat/sentry-enable-tombstones` and retry.

---

## File Structure

**Modified (1 file):**
- `.github/workflows/deploy.yml` — two symmetric edits:
  - `deploy-android` job: `Build AAB` step (line ~104) gets build flags appended; new "Upload Dart AOT symbols to Sentry" step inserted between `Build AAB` (line ~103) and `Upload AAB artifact` (line ~106).
  - `deploy-ios` job: `Build IPA` step (line ~175) gets build flags appended; new "Upload Dart AOT symbols to Sentry" step inserted between `Build IPA` (line ~175) and `Upload to TestFlight` (line ~178).

**Not touched:**
- `pubspec.yaml` — existing `sentry:` block is already correct for this use case.
- `android/app/src/main/AndroidManifest.xml` — already modified in prior commit `be7759b`, not re-touched.
- `.github/workflows/ci.yml` — symbol upload belongs only in `deploy.yml`.
- No test files — CI-workflow changes have no unit-test surface.

---

## Task 1: Expand Android deploy job (build flags + symbol upload)

**Files:**
- Modify: `.github/workflows/deploy.yml` — two hunks in the `deploy-android` job.

- [ ] **Step 1: Append build flags to the `Build AAB` step**

Use the Edit tool:

**Find:**
```yaml
      - name: Build AAB
        run: flutter build appbundle --release --dart-define-from-file=env.json --build-number=${{ github.run_number }}
```

**Replace with:**
```yaml
      - name: Build AAB
        run: flutter build appbundle --release --dart-define-from-file=env.json --build-number=${{ github.run_number }} --split-debug-info=build/symbols --obfuscate
```

- [ ] **Step 2: Insert symbol-upload step after `Build AAB`, before `Upload AAB artifact`**

Use the Edit tool:

**Find:**
```yaml
      - name: Build AAB
        run: flutter build appbundle --release --dart-define-from-file=env.json --build-number=${{ github.run_number }} --split-debug-info=build/symbols --obfuscate

      - name: Upload AAB artifact
```

**Replace with:**
```yaml
      - name: Build AAB
        run: flutter build appbundle --release --dart-define-from-file=env.json --build-number=${{ github.run_number }} --split-debug-info=build/symbols --obfuscate

      - name: Upload Dart AOT symbols to Sentry
        env:
          SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
        run: dart run sentry_dart_plugin

      - name: Upload AAB artifact
```

- [ ] **Step 3: Verify both hunks landed**

```bash
grep -n "split-debug-info=build/symbols --obfuscate" .github/workflows/deploy.yml
```

Expected: **2 hits after Task 2 completes**, but for now (Android only) **1 hit**, line ~104.

```bash
grep -n "Upload Dart AOT symbols to Sentry" .github/workflows/deploy.yml
```

Expected: **2 hits after Task 2 completes**, but for now **1 hit**, line ~106 range.

```bash
git diff .github/workflows/deploy.yml
```

Expected: the diff shows one `flutter build appbundle` line changed (flags appended) and a new 4-line step inserted. No other changes.

---

## Task 2: Expand iOS deploy job (build flags + symbol upload)

**Files:**
- Modify: `.github/workflows/deploy.yml` — two hunks in the `deploy-ios` job.

- [ ] **Step 1: Append build flags to the `Build IPA` step**

Use the Edit tool:

**Find:**
```yaml
      - name: Build IPA
        run: flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }}
```

**Replace with:**
```yaml
      - name: Build IPA
        run: flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }} --split-debug-info=build/symbols --obfuscate
```

- [ ] **Step 2: Insert symbol-upload step after `Build IPA`, before `Upload to TestFlight`**

Use the Edit tool:

**Find:**
```yaml
      - name: Build IPA
        run: flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }} --split-debug-info=build/symbols --obfuscate

      - name: Upload to TestFlight
```

**Replace with:**
```yaml
      - name: Build IPA
        run: flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist --build-number=${{ github.run_number }} --split-debug-info=build/symbols --obfuscate

      - name: Upload Dart AOT symbols to Sentry
        env:
          SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
        run: dart run sentry_dart_plugin

      - name: Upload to TestFlight
```

- [ ] **Step 3: Verify both hunks landed**

```bash
grep -n "split-debug-info=build/symbols --obfuscate" .github/workflows/deploy.yml
```

Expected: **exactly 2 hits** — one in `deploy-android`, one in `deploy-ios`.

```bash
grep -n "Upload Dart AOT symbols to Sentry" .github/workflows/deploy.yml
```

Expected: **exactly 2 hits**.

```bash
grep -c "dart run sentry_dart_plugin" .github/workflows/deploy.yml
```

Expected: `2`.

---

## Task 3: Verification

**Files:** no file changes — verification only.

- [ ] **Step 1: YAML syntax sanity**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))"
```

Expected: no output, exit code 0. If this prints a `yaml.YAMLError`, the file is malformed — fix and re-run.

- [ ] **Step 2: Flutter analyzer clean (unaffected by YAML, but hook gate)**

```bash
flutter analyze
```

Expected: `No issues found!` Exit code 0.

- [ ] **Step 3: Format clean**

```bash
dart format --set-exit-if-changed .
```

Expected: `Formatted N files (0 changed) in ...`. Exit code 0.

- [ ] **Step 4: Tests still pass**

```bash
flutter test
```

Expected: 649/649 pass. Exit code 0. (No Dart code touched — this is a sanity gate in case something unexpected regressed.)

- [ ] **Step 5: Confirm no unintended files changed**

```bash
git status
```

Expected: only `.github/workflows/deploy.yml` listed as modified. Nothing else.

```bash
git diff --stat
```

Expected: `.github/workflows/deploy.yml | ~14 +++++++++---`. Roughly 10 insertions, 2 deletions.

- [ ] **Step 6: Inspect the full diff one more time**

```bash
git diff .github/workflows/deploy.yml
```

Verify: two build-command lines changed (flags appended), two new steps inserted. No other workflow edits, no job reordering, no deletions of existing steps.

---

## Task 4: Commit

**Files:** commits the deploy.yml change.

- [ ] **Step 1: Stage**

```bash
git add .github/workflows/deploy.yml
```

- [ ] **Step 2: Commit with HEREDOC message**

```bash
git commit -m "$(cat <<'EOF'
feat(ci): upload Dart AOT symbols to Sentry on release

Adds --split-debug-info + --obfuscate to both deploy-android and
deploy-ios build commands so Dart AOT symbols strip out of
libapp.so into build/symbols/. A new "Upload Dart AOT symbols to
Sentry" step runs dart run sentry_dart_plugin after each build
(before the Play/TestFlight upload) to push those symbols to
belly-buddy-fz/flutter on Sentry.

Required: add SENTRY_AUTH_TOKEN repo secret (project:releases
scope) before the next deploy — without it, the upload step
fails the workflow. That is the desired fail-safe: we prefer a
red CI over a silent release with opaque crashes.

Paired with the tombstone manifest flag in the previous commit,
this makes future NDK crashes in Sentry actually debuggable
(FLUTTER-2 and friends).

Spec: docs/superpowers/specs/2026-04-24-enable-sentry-tombstones-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: pre-commit hook runs `dart format` + `flutter analyze` and passes. Commit lands on `feat/sentry-enable-tombstones`. Do NOT pass `--no-verify`.

- [ ] **Step 3: Verify the commit**

```bash
git log -1 --stat
```

Expected: one file changed (`.github/workflows/deploy.yml`), ~10 insertions, ~2 deletions.

```bash
git log --oneline origin/develop..HEAD
```

Expected: three commits on the branch — newest is the CI commit, then the spec-expansion commit `654825b`, then the manifest commit `be7759b`.

---

## Task 5: Push and update PR metadata

**Files:** no file changes — git/gh operations only.

- [ ] **Step 1: Push to existing upstream**

```bash
git push origin feat/sentry-enable-tombstones
```

Expected: commits pushed successfully. PR #56 on GitHub automatically picks up the new commits.

- [ ] **Step 2: Update PR title to reflect expanded scope**

```bash
gh pr edit 56 --title "feat(sentry): enable tombstones + upload Dart AOT symbols on release"
```

Expected: `https://github.com/severinkl/bellybuddyapp/pull/56` printed, title updated.

- [ ] **Step 3: Update PR body**

```bash
gh pr edit 56 --body "$(cat <<'EOF'
## Summary

Makes future Android NDK crashes in Sentry actually debuggable by closing two gaps:

1. **Tombstone collection** — `<meta-data android:name="io.sentry.tombstone.enable" android:value="true" />` added to `android/app/src/main/AndroidManifest.xml`. Attaches thread state / register context / signal metadata to NDK crash events on Android 12+ (API 31); silent no-op below.
2. **Dart AOT symbol upload** — `.github/workflows/deploy.yml` now builds release artifacts with `--split-debug-info=build/symbols --obfuscate`, and runs `dart run sentry_dart_plugin` after each build (before the Play / TestFlight upload) to push `libapp.so` symbols to Sentry.

Tombstones alone give thread state + signal metadata. Symbol upload gives function names. Both matter — without symbols, stack frames in `libapp.so` come back as `<unknown>` even with tombstones on.

## Required: manual prerequisite before next deploy

Add `SENTRY_AUTH_TOKEN` as a repo secret (GitHub Settings → Secrets and variables → Actions):

1. Create a new internal token at https://belly-buddy-fz.sentry.io/settings/auth-tokens/ with `project:releases` scope.
2. Save it as `SENTRY_AUTH_TOKEN`.

The PR merges fine without the secret. The **next** deploy run will fail at the upload step until the secret is present — that is the intended fail-safe (no silent releases with opaque crashes).

## Scope

- **Change:** `android/app/src/main/AndroidManifest.xml` (+5 lines) + `.github/workflows/deploy.yml` (~10 insertions, ~2 edits).
- **No Dart changes.** No new dependencies. No new Android permissions.
- **Reach:** tombstones effective on Android 12+, symbol upload on every release on both platforms.
- **Privacy:** `options.sendDefaultPii = true` already set in `lib/main.dart:67`; no posture change.

## Spec

`docs/superpowers/specs/2026-04-24-enable-sentry-tombstones-design.md`

## Out of scope (intentional)

- `isReportHistoricalTombstones` (prior-session exit-reason replay) — would need a native shim.
- Triage of existing NDK crashes (e.g. FLUTTER-2) — future-proofing only; historical events stay opaque.
- Updating `project: flutter` slug in `pubspec.yaml` if it doesn't match the real Sentry project. If wrong, the upload step fails loudly on the first deploy — trivial follow-up.

## Test plan

- [x] `flutter analyze` — clean
- [x] `dart format --set-exit-if-changed .` — clean
- [x] `flutter test` — 649/649 pass
- [x] YAML syntax validated locally (`python3 -c 'import yaml; yaml.safe_load(...)'`)
- [ ] Manual post-merge: add `SENTRY_AUTH_TOKEN` secret, trigger one `workflow_dispatch` run of Deploy, verify both `deploy-android` and `deploy-ios` show the upload step succeeding
- [ ] Post-deploy: check https://belly-buddy-fz.sentry.io/settings/projects/flutter/debug-files/ — new entries for the release's version/ABI appear
- [ ] Long-term (next NDK crash, days to weeks): stack frames show real function names instead of `<unknown>`, with tombstone context attached

## Rollback

- Manifest tombstone flag: delete the 5-line `<meta-data>` block. Immediate.
- Symbol upload: revert the `deploy.yml` hunk; future releases stop uploading symbols but continue publishing.
- Delete the `SENTRY_AUTH_TOKEN` secret to revoke.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR body updated, gh prints the PR URL.

- [ ] **Step 4: Print PR URL for the user**

```bash
gh pr view 56 --json url --jq .url
```

Expected: `https://github.com/severinkl/bellybuddyapp/pull/56`. Report this to the user along with a reminder that the `SENTRY_AUTH_TOKEN` secret is still required before the next deploy.

**STOP here.** Do NOT run `gh pr merge`, `gh pr merge --auto`, or any merge variant. The user handles merge timing manually.

---

## Done

Branch has three commits, PR #56 is updated with the new title, expanded body, and the new CI commit. Nothing armed for auto-merge. Remind the user that **`SENTRY_AUTH_TOKEN` must be added as a repo secret before the next deploy run** or the workflow will fail at the upload step.
