# App Upgrade Enforcement + Versioning — Design

**Date:** 2026-04-20
**Status:** Approved, ready for implementation plan.

## Goal

Two connected pieces of release plumbing that together make it possible to roll out breaking changes safely:

1. **App-upgrade enforcement** — a two-threshold gate that the Flutter app evaluates on cold start. Below a `minimum_supported_version` the app is blocked until the user updates; between that and `latest_version` the user sees a dismissible nudge on each cold start.
2. **Automated semver on merge-to-main** — replace the static `1.0.0` in `pubspec.yaml` with a semantic-release flow driven by conventional-commit messages. Without this, the upgrade gate has no moving version number to react to.

## Non-goals

- Forcing uninstall/reinstall — impossible from either store.
- Per-platform version thresholds — out of scope (shared versions only).
- App-resume or periodic re-checks — cold-start-only.
- Offline caching of the config — fail open on any fetch failure.
- Rich release notes in the upgrade prompts — just "update now" + store link.

## Part 1 — Upgrade enforcement

### Data model

One Supabase table: `public.app_config`.

```sql
CREATE TABLE public.app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read app_config"
  ON public.app_config FOR SELECT
  TO anon, authenticated
  USING (true);

-- Trigger to keep updated_at fresh
CREATE TRIGGER app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

Two seed rows:

```sql
INSERT INTO public.app_config (key, value) VALUES
  ('minimum_supported_version', '1.0.0'),
  ('latest_version', '1.0.0');
```

Both rows are non-sensitive constants (semver strings like `"1.4.2"`). Writes happen via the Supabase dashboard; there is no client-writable path.

### Client flow

1. App launches; `main.dart` runs Firebase/Supabase init as today.
2. The splash screen becomes the first *visible* UI. Before calling its existing `onComplete` callback, it awaits a one-shot `AppConfig` fetch:
   - If the fetch succeeds, compare installed semver (via `package_info_plus`) to the two thresholds.
   - If the fetch fails (network, Supabase down, parse error), log via `AppLogger` and proceed as if the current version is fine ("fail open").
3. **Decision tree:**
   - `installed < minimum_supported_version` → `context.go('/upgrade-required')` — replaces the stack; no back.
   - `minimum_supported_version ≤ installed < latest_version` → proceed into the app, then show a dismissible `showDialog` once the dashboard first renders. Dialog reappears on the next cold start until the user updates.
   - `installed ≥ latest_version` → proceed; no prompt.
4. Semver comparison ignores the build-number segment (`+N`). Comparison is on the three-part `X.Y.Z` only. Pre-release suffixes are not expected in production and aren't supported in the first version.

### UI copy (German)

- Blocking screen title: "Update erforderlich"
- Blocking body: "Um Belly Buddy weiter zu nutzen, aktualisiere bitte auf die neueste Version."
- Blocking CTA: "Aktualisieren"
- Dialog title: "Update verfügbar"
- Dialog body: "Eine neue Version von Belly Buddy ist im Store verfügbar."
- Dialog actions: "Später" (dismiss) / "Jetzt aktualisieren" (opens store)

### Components

- `lib/providers/app_config_provider.dart` — `FutureProvider<AppConfig>` that reads both rows from Supabase and returns `AppConfig({required String minimum, required String latest})`. Parse errors bubble up as exceptions (caught by the splash).
- `lib/services/app_version_service.dart` — thin service with `Future<String> currentVersion()` (wraps `PackageInfo.fromPlatform()` → `version`) and `Future<void> openStore()` (`url_launcher` to the right store URL per `Platform.isIOS`).
- `lib/utils/semver.dart` — pure `int compareSemver(String a, String b)` helper. Split on `+` first (drop build), then split on `.` into three ints, compare lexicographically.
- `lib/screens/upgrade/upgrade_required_screen.dart` — full-screen scaffold. Reuses the look of `BbErrorState` (mascot, headline, body, single CTA). `PopScope(canPop: false)` so Android back / iOS swipe-back don't escape the gate.
- `lib/widgets/common/upgrade_available_dialog.dart` — `showDialog`-based modal shown on dashboard first-frame when the soft-nudge flag is set.
- `lib/config/constants.dart` — add `iosAppStoreId` constant; helpers `appStoreUrl()` and `playStoreUrl()` that compose URLs from the constant + runtime `PackageInfo.packageName`.
- `lib/router/app_router.dart` — new `GoRoute` for `/upgrade-required`.
- Splash screen — call the config fetch before `onComplete`, then do the decision tree.

### Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  package_info_plus: ^8.0.0
```

`url_launcher` is already in.

### Testing

- `semver_test.dart` — comparison covers equal, a<b, a>b, different-length segments, build-number variations ("1.2.3+5" vs "1.2.3+6" → 0).
- `app_config_provider_test.dart` — happy path (two rows present), missing-row fallback, parse error.
- `app_version_service_test.dart` — asserts the right store URL per `Platform.isIOS` (mock `defaultTargetPlatform`).
- `upgrade_required_screen_test.dart` — renders, back button is absent / swipe is intercepted, CTA triggers store open.
- `upgrade_available_dialog_test.dart` — both actions; dismiss path doesn't call the store.
- One splash-integration test: override `appConfigProvider` with a below-min value, pump `main.dart`-equivalent flow, assert landing on `/upgrade-required` not `/dashboard`.

## Part 2 — Automated semver

### Why

The app is currently stuck on `version: 1.0.0+1` in `pubspec.yaml` (build number is auto-incremented by CI via `github.run_number`, semver is static). Without an automated bump, the min-version gate from Part 1 has nothing to react to — every installed version reports `1.0.0`.

### Tool + workflow

Adopt **semantic-release** on `push: main` using `cycjimmy/semantic-release-action@v4`. Plugins:

- `@semantic-release/commit-analyzer` — derives bump: `fix:` → patch, `feat:` → minor, `feat!:` or `BREAKING CHANGE:` → major.
- `@semantic-release/release-notes-generator` — generates release notes.
- `@semantic-release/exec` — runs a small shell step that rewrites the `version:` line in `pubspec.yaml` to `${nextRelease.version}+$(current build suffix)`. Keep the `+N` suffix for local development; CI still overrides it at build time.
- `@semantic-release/git` — commits the bumped `pubspec.yaml` back to `main` with message `chore(release): ${nextRelease.version} [skip ci]`. The `[skip ci]` suffix prevents the same release workflow from re-running on its own commit.
- `@semantic-release/github` — creates the `v${nextRelease.version}` tag and a GitHub Release with the notes.

`.releaserc.json` at repo root:

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/exec", {
      "prepareCmd": "sed -i.bak -E 's/^version: [0-9]+\\.[0-9]+\\.[0-9]+\\+/version: ${nextRelease.version}+/' pubspec.yaml && rm pubspec.yaml.bak"
    }],
    ["@semantic-release/git", {
      "assets": ["pubspec.yaml"],
      "message": "chore(release): ${nextRelease.version} [skip ci]"
    }],
    "@semantic-release/github"
  ]
}
```

New workflow `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    branches: [main]
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: true
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - uses: cycjimmy/semantic-release-action@v4
        with:
          extra_plugins: |
            @semantic-release/exec
            @semantic-release/git
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Deploy trigger change

Change `.github/workflows/deploy.yml` trigger from:

```yaml
on:
  push:
    branches: [main]
```

to:

```yaml
on:
  push:
    tags: ['v*']
  workflow_dispatch:
```

Effect: deploys only run when a version tag is pushed (i.e., when `release.yml` produces one), and the deploy always uses a freshly-bumped `pubspec.yaml`. `workflow_dispatch` is preserved for emergency manual redeploys. The deploy job body is unchanged — it continues to pass `--build-number=${{ github.run_number }}` so each deploy artifact still gets a unique monotonic build number that satisfies Play / App Store requirements.

### One-off migration

Before enabling the release workflow, create a starting tag:

```bash
git tag v1.0.0 <current main HEAD>
git push origin v1.0.0
```

Without this, the first `semantic-release` run won't have a reference point.

### CLAUDE.md note

Add a short section to `CLAUDE.md` reminding all commits to use conventional-commit prefixes (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, with `!` or `BREAKING CHANGE:` for majors). Non-conforming commits are silently ignored by `commit-analyzer` and produce no bump — which would mean a merge to main ships nothing.

## How the two parts connect

- Every merge `develop → main` triggers `release.yml` → `pubspec.yaml` gets a fresh semver → tag `v<version>` pushed → `deploy.yml` ships that exact semver to Play Internal + TestFlight.
- `package_info_plus` in the installed app reads that semver at runtime.
- On cold start, the installed semver is compared against the two Supabase rows.
- Maintenance: the Supabase `minimum_supported_version` / `latest_version` rows are updated manually via the dashboard when you want to enforce a minimum or announce a latest.

## Backend task for Lovable

```text
Task: add an app_config table for the client app.

Schema:
- Create table public.app_config with:
  - key TEXT PRIMARY KEY
  - value TEXT NOT NULL
  - updated_at TIMESTAMPTZ NOT NULL DEFAULT now()

RLS:
- Enable RLS on public.app_config.
- Add one policy: SELECT TO anon, authenticated USING (true).
- Do NOT add any INSERT/UPDATE/DELETE policies for clients.

Seed rows:
INSERT INTO public.app_config (key, value) VALUES
  ('minimum_supported_version', '1.0.0'),
  ('latest_version', '1.0.0');

Trigger:
- Add a BEFORE UPDATE trigger that sets updated_at = now().
```

## Risks / open items

- **First release vs starting tag.** If the initial `v1.0.0` tag isn't pushed before enabling the release workflow, the first run fails or produces an unpredictable version. The implementation plan must sequence this: tag first, then merge release.yml.
- **Unused pubspec build number.** We keep the `+N` suffix in `pubspec.yaml` for local dev but CI always overrides via `--build-number`. Consistent with current behavior; noting to avoid confusion.
- **Fail-open on config fetch.** A below-min user whose Supabase call fails will slip past the gate. Acceptable for the MVP — if a hard gate is ever critical, we can add server-side API rejection (out of scope here).
- **Dialog persistence.** Soft-nudge dialog reappears every cold start. If that becomes annoying, a 24h-dismiss with `shared_preferences` is a trivial follow-up.
- **Conventional-commit discipline.** If a merge to main contains only non-conventional commit messages, semantic-release will skip the bump entirely and the merge ships no new version. Mitigation: PR review + CLAUDE.md note.

## Out of scope

- Per-platform thresholds, resume re-checks, offline caching.
- Release-candidate / beta channels.
- Forced-update via Play's immediate in-app-update API (can be added later on top of this foundation).
- Migrating from the existing branch workflow (develop→main stays as-is).
