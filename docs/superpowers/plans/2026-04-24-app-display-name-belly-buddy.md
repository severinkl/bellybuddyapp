# App Display Name → "Belly Buddy" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change the Android launcher label from `belly_buddy` to `Belly Buddy`, and harmonize iOS `CFBundleName` to match (home-screen `CFBundleDisplayName` is already correct).

**Architecture:** Two one-line edits in two platform config files. No Dart, no dependencies, no permissions, no tests.

**Tech Stack:** Android XML manifest, iOS Info.plist.

**Spec:** `docs/superpowers/specs/2026-04-24-app-display-name-belly-buddy-design.md`

**Branch (already created):** `feat/app-display-name-belly-buddy` off `origin/develop`. Currently one commit ahead (the spec doc at `af1e972`). PR target: `develop`.

---

## Pre-flight check

- [ ] **Verify branch + starting state**

```bash
git branch --show-current
```

Expected: `feat/app-display-name-belly-buddy`

```bash
git log --oneline origin/develop..HEAD
```

Expected: exactly one commit — `af1e972 docs(spec): app display name → Belly Buddy`.

If the branch is wrong: `git checkout feat/app-display-name-belly-buddy` and retry. Do not proceed if the log shows commits other than the spec.

---

## File Structure

**Modified (2 files):**
- `android/app/src/main/AndroidManifest.xml` — line 9 only.
- `ios/Runner/Info.plist` — the string value inside the `<key>CFBundleName</key>` pair (was `belly_buddy`, becomes `Belly Buddy`).

**Not touched:**
- `pubspec.yaml` — package name stays `belly_buddy` (Dart identifier, snake_case required).
- `android/app/build.gradle.kts` — `applicationId` unchanged.
- `ios/Runner/Info.plist CFBundleIdentifier`, `CFBundleDisplayName` — unchanged.
- Anything under `lib/` or `test/` — no Dart touched.
- No test files — a display-name string has no unit-test surface.

---

## Task 1: Android — update `android:label`

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` — exactly line 9.

- [ ] **Step 1: Confirm the current line**

```bash
grep -n 'android:label' android/app/src/main/AndroidManifest.xml
```

Expected output:
```
9:        android:label="belly_buddy"
```

- [ ] **Step 2: Edit the label**

Use the Edit tool.

**Find:**
```xml
        android:label="belly_buddy"
```

**Replace with:**
```xml
        android:label="Belly Buddy"
```

- [ ] **Step 3: Verify exactly one hit with the new value and no stragglers with the old value**

```bash
grep -n 'android:label' android/app/src/main/AndroidManifest.xml
```

Expected:
```
9:        android:label="Belly Buddy"
```

```bash
grep -rn 'belly_buddy' android/app/src/*/AndroidManifest.xml
```

Expected: **no output** (no remaining occurrences in any manifest variant).

---

## Task 2: iOS — update `CFBundleName`

**Files:**
- Modify: `ios/Runner/Info.plist` — the `<string>` value immediately following `<key>CFBundleName</key>` (around line 18).

- [ ] **Step 1: Confirm the current key/value pair**

```bash
grep -n -A 1 '<key>CFBundleName</key>' ios/Runner/Info.plist
```

Expected output:
```
17:	<key>CFBundleName</key>
18-	<string>belly_buddy</string>
```

- [ ] **Step 2: Edit the value**

Use the Edit tool.

**Find** (this exact two-line block — the `\t` between lines and the `\t` prefixes match the existing indentation):

```
	<key>CFBundleName</key>
	<string>belly_buddy</string>
```

**Replace with:**

```
	<key>CFBundleName</key>
	<string>Belly Buddy</string>
```

If `Edit` reports "not unique" (unlikely — `CFBundleName` appears once), tighten the find-block with one more line of surrounding context on either side.

- [ ] **Step 3: Verify**

```bash
grep -n -A 1 '<key>CFBundleName</key>' ios/Runner/Info.plist
```

Expected:
```
17:	<key>CFBundleName</key>
18-	<string>Belly Buddy</string>
```

Confirm `CFBundleDisplayName` did NOT change:

```bash
grep -n -A 1 '<key>CFBundleDisplayName</key>' ios/Runner/Info.plist
```

Expected:
```
8:	<key>CFBundleDisplayName</key>
9-	<string>Belly Buddy</string>
```

(already "Belly Buddy" from before this PR.)

---

## Task 3: Verification

**Files:** no changes — verification only.

- [ ] **Step 1: Diff sanity**

```bash
git diff --stat
```

Expected: exactly two files changed, one insertion and one deletion each.
```
 android/app/src/main/AndroidManifest.xml | 2 +-
 ios/Runner/Info.plist                    | 2 +-
 2 files changed, 2 insertions(+), 2 deletions(-)
```

```bash
git diff
```

Expected: only the two display-name edits. No whitespace drift, no line-ending changes.

- [ ] **Step 2: Flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!` Exit code 0.

- [ ] **Step 3: Dart format clean**

```bash
dart format --set-exit-if-changed .
```

Expected: `0 changed`. Exit code 0.

- [ ] **Step 4: Flutter tests still pass**

```bash
flutter test
```

Expected: baseline 649/649 pass. Exit code 0. (No code touched; this is a sanity gate for pre-commit parity.)

- [ ] **Step 5: Android debug build — proves manifest parses**

```bash
flutter build apk --debug --dart-define-from-file=env.json
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. If this fails with a "Manifest merger failed" error, the XML edit is malformed — fix and re-run. Do NOT proceed on red.

**If the same pre-existing `SentryFlutterPlugin` cannot-find-symbol error appears**, that is unrelated to this change and was diagnosed in a previous session: delete any stale `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`, run `flutter clean && flutter pub get`, and retry. The file should NOT exist in the source tree on a clean branch.

- [ ] **Step 6: iOS plutil sanity (fast, no simulator/macOS build needed)**

```bash
plutil -lint ios/Runner/Info.plist
```

Expected: `ios/Runner/Info.plist: OK`.

(We skip `flutter build ios` here — it needs a macOS/Xcode toolchain and is slow. `plutil -lint` confirms the plist is well-formed, which is the only thing this edit can break.)

- [ ] **Step 7: Final sanity — no `belly_buddy` appears as a user-visible display name anywhere**

```bash
grep -rn 'belly_buddy' android/ ios/ 2>/dev/null | grep -v 'Generated\|build/\|\.gradle\|DerivedData\|Pods/\|applicationId\|bundle_identifier\|PRODUCT_BUNDLE_IDENTIFIER' | head -20
```

Expected output: ideally empty, OR only identifier-style hits (bundle-id stem `com.bellybuddy.belly_buddy`, the Dart package name in generated files). Visually confirm **no `android:label`, `CFBundleName`, or `CFBundleDisplayName` line still contains `belly_buddy`**. Package-identifier references are fine; display-name references are the bug.

---

## Task 4: Commit

**Files:** commits the two-line change as one atomic unit.

- [ ] **Step 1: Stage both files**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
```

- [ ] **Step 2: Commit with HEREDOC message**

```bash
git commit -m "$(cat <<'EOF'
feat(app): display name → "Belly Buddy"

Android launcher label was "belly_buddy" (the snake_case Dart package
name). Fix via android:label in AndroidManifest.xml.

iOS home-screen label was already "Belly Buddy" via CFBundleDisplayName,
but the internal CFBundleName short name still read "belly_buddy" —
shown in Settings > General > iPhone Storage and Spotlight fallbacks.
Harmonized.

No changes to pubspec name (Dart package id, must stay snake_case),
applicationId, CFBundleIdentifier, entitlements, permissions, or
google-services.json. All of those key on bundle/package ID, not
display name.

Spec: docs/superpowers/specs/2026-04-24-app-display-name-belly-buddy-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

The pre-commit hook runs `dart format` + `flutter analyze`. It should pass — we touched no Dart. Do NOT pass `--no-verify`.

- [ ] **Step 3: Verify the commit**

```bash
git log -1 --stat
```

Expected: two files changed, 1 insertion / 1 deletion each. 

```bash
git log --oneline origin/develop..HEAD
```

Expected: two commits — the spec doc (`af1e972`) and this code commit on top.

---

## Task 5: Push and open PR

**Files:** git/gh operations only. Stop at `gh pr create` — do NOT arm `gh pr merge --auto` (project convention).

- [ ] **Step 1: Push**

```bash
git push -u origin feat/app-display-name-belly-buddy
```

Expected: upstream tracking set, two commits pushed.

- [ ] **Step 2: Open PR against `develop`**

```bash
gh pr create --base develop --title 'feat(app): display name → "Belly Buddy"' --body "$(cat <<'EOF'
## Summary

- **Android (`AndroidManifest.xml:9`):** `android:label="belly_buddy"` → `android:label="Belly Buddy"`. This is the launcher/app-drawer label shown on-device.
- **iOS (`Info.plist` `CFBundleName`):** `belly_buddy` → `Belly Buddy`. Harmonizes the internal short-name with the home-screen `CFBundleDisplayName` (which was already "Belly Buddy"). Surfaces in Settings → General → iPhone Storage and Spotlight fallbacks.

## Scope

- **Two files, one line each.** +2 / -2 in code. Plus the spec doc already committed.
- **No Dart changes.** No new dependencies. No new permissions.
- **`pubspec.yaml:name`, `applicationId`, `CFBundleIdentifier` all unchanged** — every permission / push / Firebase / store-listing interaction keys on the bundle ID, so there is no regression surface.

## Safety analysis

Bundle/package IDs key all of: notifications (APNs, FCM), camera/mic/photo permissions, Firebase app registration, Play Console, App Store Connect, TestFlight, deep-link intent filters, entitlements, `google-services.json`. None of those change.

iOS permission prompts already rendered "Belly Buddy" (via `CFBundleDisplayName`); this PR just makes the internal fallback match.

## Spec

`docs/superpowers/specs/2026-04-24-app-display-name-belly-buddy-design.md`

## Out of scope (intentional)

- Play Console / App Store Connect listing names — separate UI-side fields in each console, not derived from the manifest / plist.
- `res/values/strings.xml` + per-locale `values-xx/` — idiomatic Android pattern for localized names, but the app is single-locale (German) today. Migrate only when a second locale arrives.

## Test plan

- [x] `flutter analyze` — clean
- [x] `dart format --set-exit-if-changed .` — clean
- [x] `flutter test` — 649/649 pass (no code touched; sanity only)
- [x] `flutter build apk --debug` — succeeds (manifest parses)
- [x] `plutil -lint ios/Runner/Info.plist` — OK (plist well-formed)
- [ ] **Post-merge, on device** (Android): fresh install → launcher reads "Belly Buddy"
- [ ] **Post-merge, on device** (iOS): Settings → General → iPhone Storage reads "Belly Buddy"

## Rollback

Revert the two edits. No persisted state, no migration, no data change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed.

- [ ] **Step 3: Print the PR URL for the user**

```bash
gh pr view --json url --jq .url
```

Expected: URL to the newly opened PR. Report this back to the user.

**STOP here.** Do NOT run `gh pr merge`, `gh pr merge --auto`, or any merge variant. The user handles merge timing manually.

---

## Done

Branch has two commits (spec + code), PR is open against `develop`, nothing armed for auto-merge. Post-merge observational checks listed in the PR's test-plan are the real acceptance gate.
