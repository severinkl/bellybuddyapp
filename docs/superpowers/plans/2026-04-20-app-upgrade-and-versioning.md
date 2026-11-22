# App Upgrade Enforcement + Automated Versioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a two-threshold upgrade gate in the app (hard block below `minimum_supported_version`; dismissible nudge below `latest_version`) fed by Supabase, plus a semantic-release pipeline on `push: main` that auto-bumps `pubspec.yaml` so the gate has real moving versions to react to.

**Architecture:** A new `app_config` Supabase table stores two version strings. A `FutureProvider<AppConfig>` fetches them on cold start. A pure `compareSemver` helper decides between three states: ok / soft-nudge / hard-gate. Hard-gate routes to a blocking `UpgradeRequiredScreen` via GoRouter; soft-nudge sets a one-shot flag that the dashboard reads to show a dismissible `showDialog` on its first frame. In parallel, a new `release.yml` workflow runs `cycjimmy/semantic-release-action@v4` on every `push: main` to derive a semver bump from conventional-commit prefixes, rewrite `pubspec.yaml`, and push a `v<version>` tag; the existing `deploy.yml` moves to trigger on tag push instead of `push: main`.

**Tech Stack:** Flutter, Riverpod `FutureProvider` / `StateProvider`, GoRouter, `package_info_plus` (new), `url_launcher` (existing), Supabase (existing), `cycjimmy/semantic-release-action@v4`, conventional commits.

---

## File Structure

**New runtime code:**
- `lib/utils/semver.dart` — pure `int compareSemver(String a, String b)`.
- `lib/models/app_config.dart` — plain-Dart `AppConfig({required minimum, required latest})` class.
- `lib/services/app_version_service.dart` — wraps `PackageInfo.fromPlatform()` + `url_launcher` to the right store URL.
- `lib/providers/app_config_provider.dart` — `FutureProvider<AppConfig>` reading from Supabase.
- `lib/providers/upgrade_gate_provider.dart` — two providers: (a) `upgradeDecisionProvider` (Future, merges config + current version into an enum), (b) `softNudgePendingProvider` (`StateProvider<bool>`, consumed by the dashboard).
- `lib/screens/upgrade/upgrade_required_screen.dart` — blocking scaffold.
- `lib/widgets/common/upgrade_available_dialog.dart` — `showDialog`-based modal.

**Modified runtime code:**
- `lib/config/constants.dart` — add `iosAppStoreId`; add helpers `appStoreUrl()` / `playStoreUrl(String packageName)`.
- `lib/router/app_router.dart` — add `/upgrade-required` route.
- `lib/screens/splash/splash_screen.dart` — await the config fetch + apply the decision before `onComplete`.
- `lib/screens/dashboard/dashboard_screen.dart` — read `softNudgePendingProvider` on first frame; show the dialog once, then clear the flag.
- `pubspec.yaml` — add `package_info_plus: ^8.0.0`.

**New infra:**
- `.releaserc.json` — semantic-release config at repo root.
- `.github/workflows/release.yml` — runs on `push: main`, drives semantic-release.

**Modified infra:**
- `.github/workflows/deploy.yml` — trigger swaps from `push: main` to `push: tags: ['v*']`; `workflow_dispatch` retained.
- `CLAUDE.md` — short section on conventional-commits requirement.

**Tests:**
- `test/utils/semver_test.dart`
- `test/services/app_version_service_test.dart`
- `test/providers/app_config_provider_test.dart`
- `test/providers/upgrade_gate_provider_test.dart`
- `test/screens/upgrade/upgrade_required_screen_test.dart`
- `test/widgets/common/upgrade_available_dialog_test.dart`

---

## Task 1: Prereqs — semver helper, app version service, constants, model

**Files:**
- Create: `lib/utils/semver.dart`, `test/utils/semver_test.dart`
- Create: `lib/services/app_version_service.dart`, `test/services/app_version_service_test.dart`
- Create: `lib/models/app_config.dart`
- Modify: `lib/config/constants.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add `package_info_plus` to `pubspec.yaml`**

```yaml
dependencies:
  # ... existing ...
  package_info_plus: ^8.0.0
```

Run `flutter pub get`.

- [ ] **Step 2: Write failing tests for `compareSemver`**

Create `test/utils/semver_test.dart`:

```dart
import 'package:belly_buddy/utils/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareSemver', () {
    test('equal versions return 0', () {
      expect(compareSemver('1.2.3', '1.2.3'), 0);
    });

    test('a less than b returns negative', () {
      expect(compareSemver('1.2.3', '1.2.4'), isNegative);
      expect(compareSemver('1.2.3', '1.3.0'), isNegative);
      expect(compareSemver('1.2.3', '2.0.0'), isNegative);
    });

    test('a greater than b returns positive', () {
      expect(compareSemver('1.2.4', '1.2.3'), isPositive);
      expect(compareSemver('1.3.0', '1.2.9'), isPositive);
      expect(compareSemver('2.0.0', '1.99.99'), isPositive);
    });

    test('build-number suffix is ignored', () {
      expect(compareSemver('1.2.3+5', '1.2.3+99'), 0);
      expect(compareSemver('1.2.3+5', '1.2.4+1'), isNegative);
    });

    test('missing segments default to zero', () {
      expect(compareSemver('1', '1.0.0'), 0);
      expect(compareSemver('1.2', '1.2.0'), 0);
      expect(compareSemver('1.2', '1.2.1'), isNegative);
    });
  });
}
```

Run: `flutter test test/utils/semver_test.dart`. Expected: FAIL (helper doesn't exist).

- [ ] **Step 3: Implement `compareSemver`**

Create `lib/utils/semver.dart`:

```dart
/// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
/// Parses three-part semver (X.Y.Z). Build-number suffix (`+N`) and any
/// pre-release suffix (`-rc1`) are stripped before comparing. Missing
/// segments default to zero.
int compareSemver(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final cmp = pa[i].compareTo(pb[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

List<int> _parts(String v) {
  final core = v.split(RegExp(r'[+\-]')).first;
  final segments = core.split('.');
  return [
    _toInt(segments, 0),
    _toInt(segments, 1),
    _toInt(segments, 2),
  ];
}

int _toInt(List<String> segs, int i) {
  if (i >= segs.length) return 0;
  return int.tryParse(segs[i]) ?? 0;
}
```

- [ ] **Step 4: Run semver tests**

Run: `flutter test test/utils/semver_test.dart`. Expected: all pass.

- [ ] **Step 5: Add store URL helpers to `constants.dart`**

In `lib/config/constants.dart`, add near the top-level constants:

```dart
/// App Store numeric ID for Belly Buddy. Update once the app is published.
static const String iosAppStoreId = '0000000000'; // TODO: replace with real ID before shipping

/// Builds the App Store URL for the current app.
static String appStoreUrl() => 'https://apps.apple.com/app/id$iosAppStoreId';

/// Builds the Play Store URL for the given Android package name.
static String playStoreUrl(String packageName) =>
    'https://play.google.com/store/apps/details?id=$packageName';
```

(The placeholder `iosAppStoreId` must be replaced with the real ID before a user-facing release. Surface this as a DONE_WITH_CONCERNS to the controller if unknown.)

- [ ] **Step 6: Write failing tests for `AppVersionService`**

Create `test/services/app_version_service_test.dart`:

```dart
import 'package:belly_buddy/services/app_version_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Belly Buddy',
      packageName: 'com.bellybuddy.belly_buddy',
      version: '1.4.2',
      buildNumber: '17',
      buildSignature: '',
    );
  });

  group('AppVersionService', () {
    test('currentVersion returns the semver portion', () async {
      final v = await AppVersionService().currentVersion();
      expect(v, '1.4.2');
    });

    test('packageName returns the Android package identifier', () async {
      final p = await AppVersionService().packageName();
      expect(p, 'com.bellybuddy.belly_buddy');
    });
  });
}
```

The service's `openStore` path is harder to test without mocking `url_launcher`; skip for this task. The store URL helpers are already covered by their plain construction.

Run the tests. Expected: FAIL (service doesn't exist).

- [ ] **Step 7: Implement `AppVersionService`**

Create `lib/services/app_version_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';

/// Wraps package_info_plus + url_launcher for the upgrade-gate flow.
class AppVersionService {
  AppVersionService();

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<String> packageName() async {
    final info = await PackageInfo.fromPlatform();
    return info.packageName;
  }

  /// Opens the platform-appropriate store page for the app.
  Future<void> openStore() async {
    final url = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConstants.appStoreUrl()
        : AppConstants.playStoreUrl(await packageName());
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
```

- [ ] **Step 8: Run service tests**

Run: `flutter test test/services/app_version_service_test.dart`. Expected: pass.

- [ ] **Step 9: Add `AppConfig` model**

Create `lib/models/app_config.dart`:

```dart
/// Version thresholds read from the Supabase `app_config` table and compared
/// against the installed app's semver.
class AppConfig {
  const AppConfig({required this.minimum, required this.latest});

  /// Clients below this version are blocked with the "Update erforderlich"
  /// screen until they update.
  final String minimum;

  /// Clients below this version (but at or above [minimum]) see a dismissible
  /// "Update verfügbar" nudge on cold start.
  final String latest;
}
```

- [ ] **Step 10: Run `flutter analyze`**

Run: `flutter analyze`. Expected: 0 issues.

- [ ] **Step 11: Commit**

```bash
git add lib/utils/semver.dart \
        test/utils/semver_test.dart \
        lib/services/app_version_service.dart \
        test/services/app_version_service_test.dart \
        lib/models/app_config.dart \
        lib/config/constants.dart \
        pubspec.yaml \
        pubspec.lock
git commit -m "feat(upgrade): semver helper, version service, app config model"
```

---

## Task 2: App-config provider + upgrade-decision provider

**Files:**
- Create: `lib/providers/app_config_provider.dart`
- Create: `lib/providers/upgrade_gate_provider.dart`
- Test: `test/providers/app_config_provider_test.dart`
- Test: `test/providers/upgrade_gate_provider_test.dart`

- [ ] **Step 1: Write failing tests for `appConfigProvider`**

Create `test/providers/app_config_provider_test.dart`:

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/models/app_config.dart';
import 'package:belly_buddy/providers/app_config_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../helpers/fakes.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  group('appConfigProvider', () {
    test('returns AppConfig with both rows parsed', () async {
      final fakeClient = FakeSupabaseClient(appConfigRows: {
        'minimum_supported_version': '1.2.0',
        'latest_version': '1.4.2',
      });
      final container = createContainer(overrides: <Override>[
        supabaseClientProvider.overrideWithValue(fakeClient),
      ]);
      addTearDown(container.dispose);

      final config = await container.read(appConfigProvider.future);
      expect(config.minimum, '1.2.0');
      expect(config.latest, '1.4.2');
    });

    test('throws when a required row is missing', () async {
      final fakeClient = FakeSupabaseClient(appConfigRows: {
        'minimum_supported_version': '1.2.0',
      });
      final container = createContainer(overrides: <Override>[
        supabaseClientProvider.overrideWithValue(fakeClient),
      ]);
      addTearDown(container.dispose);

      expect(
        () => container.read(appConfigProvider.future),
        throwsA(isA<StateError>()),
      );
    });
  });
}
```

Note: `FakeSupabaseClient` with an `appConfigRows` constructor and the `supabaseClientProvider` may need to be added. Check `test/helpers/fakes.dart` and `lib/providers/core_providers.dart` first — use whatever Supabase fake/override pattern already exists (there will be one, since other providers already test against Supabase). Adapt the test to the real pattern if needed.

Run: `flutter test test/providers/app_config_provider_test.dart`. Expected: FAIL (provider doesn't exist).

- [ ] **Step 2: Implement `appConfigProvider`**

Create `lib/providers/app_config_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import 'core_providers.dart';

/// Fetches version thresholds from the Supabase `app_config` table.
///
/// Throws [StateError] if either `minimum_supported_version` or
/// `latest_version` is missing. Callers (the splash in particular) treat a
/// failure as "fail open" — log and proceed as if the version is fine.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('app_config')
      .select('key, value')
      .inFilter('key', ['minimum_supported_version', 'latest_version']);

  final byKey = <String, String>{
    for (final row in rows as List) row['key'] as String: row['value'] as String,
  };
  final minimum = byKey['minimum_supported_version'];
  final latest = byKey['latest_version'];
  if (minimum == null || latest == null) {
    throw StateError(
      'app_config missing required keys: '
      'got ${byKey.keys.toList()}',
    );
  }
  return AppConfig(minimum: minimum, latest: latest);
});
```

- [ ] **Step 3: Run provider tests**

Run: `flutter test test/providers/app_config_provider_test.dart`. Expected: pass.

- [ ] **Step 4: Write failing tests for upgrade-decision logic**

Create `test/providers/upgrade_gate_provider_test.dart`:

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/models/app_config.dart';
import 'package:belly_buddy/providers/app_config_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../helpers/riverpod_helpers.dart';

ProviderContainer _containerWith({
  required AppConfig config,
  required String version,
}) {
  return createContainer(overrides: <Override>[
    appConfigProvider.overrideWith((_) async => config),
    currentVersionProvider.overrideWith((_) async => version),
  ]);
}

void main() {
  group('upgradeDecisionProvider', () {
    test('below minimum → hardGate', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.1.9',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future),
          UpgradeDecision.hardGate);
    });

    test('at minimum, below latest → softNudge', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.2.0',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future),
          UpgradeDecision.softNudge);
    });

    test('between minimum and latest → softNudge', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.4.0',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future),
          UpgradeDecision.softNudge);
    });

    test('at latest → ok', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.5.0',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future),
          UpgradeDecision.ok);
    });

    test('above latest → ok', () async {
      final c = _containerWith(
        config: const AppConfig(minimum: '1.2.0', latest: '1.5.0'),
        version: '1.6.0',
      );
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future),
          UpgradeDecision.ok);
    });

    test('config fetch failure → ok (fail open)', () async {
      final c = createContainer(overrides: <Override>[
        appConfigProvider.overrideWith((_) => Future<AppConfig>.error('boom')),
        currentVersionProvider.overrideWith((_) async => '1.0.0'),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(upgradeDecisionProvider.future),
          UpgradeDecision.ok);
    });
  });
}
```

Run: FAIL (provider doesn't exist).

- [ ] **Step 5: Implement `upgradeDecisionProvider`**

Create `lib/providers/upgrade_gate_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_version_service.dart';
import '../utils/semver.dart';
import 'app_config_provider.dart';

enum UpgradeDecision { ok, softNudge, hardGate }

/// Installed app semver. Overridable in tests.
final currentVersionProvider = FutureProvider<String>((_) async {
  return AppVersionService().currentVersion();
});

/// Merges [appConfigProvider] and [currentVersionProvider] into a single
/// decision. On any failure in the config fetch we fail open to keep the
/// app usable for offline / flaky-network users.
final upgradeDecisionProvider = FutureProvider<UpgradeDecision>((ref) async {
  late final String version;
  try {
    version = await ref.watch(currentVersionProvider.future);
  } catch (_) {
    return UpgradeDecision.ok;
  }

  try {
    final config = await ref.watch(appConfigProvider.future);
    if (compareSemver(version, config.minimum) < 0) {
      return UpgradeDecision.hardGate;
    }
    if (compareSemver(version, config.latest) < 0) {
      return UpgradeDecision.softNudge;
    }
    return UpgradeDecision.ok;
  } catch (_) {
    return UpgradeDecision.ok;
  }
});

/// One-shot flag flipped true by the splash when the decision is
/// [UpgradeDecision.softNudge]. The dashboard reads this on first frame,
/// shows the dialog, then resets it to false.
final softNudgePendingProvider = StateProvider<bool>((_) => false);
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/providers/upgrade_gate_provider_test.dart`. Expected: pass. Run the full suite too — `flutter test` — confirm no regressions.

- [ ] **Step 7: Run `flutter analyze` and commit**

```bash
git add lib/providers/app_config_provider.dart \
        test/providers/app_config_provider_test.dart \
        lib/providers/upgrade_gate_provider.dart \
        test/providers/upgrade_gate_provider_test.dart \
        test/helpers/fakes.dart
git commit -m "feat(upgrade): app config provider and upgrade decision logic"
```

---

## Task 3: UI components — screen, dialog, route

**Files:**
- Create: `lib/screens/upgrade/upgrade_required_screen.dart`, `test/screens/upgrade/upgrade_required_screen_test.dart`
- Create: `lib/widgets/common/upgrade_available_dialog.dart`, `test/widgets/common/upgrade_available_dialog_test.dart`
- Modify: `lib/router/route_names.dart`, `lib/router/app_router.dart`

- [ ] **Step 1: Add route constants**

In `lib/router/route_names.dart`:

```dart
class RouteNames {
  // ... existing ...
  static const String upgradeRequired = 'upgrade-required';
}

class RoutePaths {
  // ... existing ...
  static const String upgradeRequired = '/upgrade-required';
}
```

- [ ] **Step 2: Write failing test for the screen**

Create `test/screens/upgrade/upgrade_required_screen_test.dart`:

```dart
import 'package:belly_buddy/screens/upgrade/upgrade_required_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the required elements', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UpgradeRequiredScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update erforderlich'), findsOneWidget);
    expect(find.text('Aktualisieren'), findsOneWidget);
  });

  testWidgets('has no back affordance (PopScope blocks pops)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UpgradeRequiredScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar leading back button should not be present.
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    // PopScope is in the tree and configured to block.
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
```

Run: FAIL.

- [ ] **Step 3: Implement the screen**

Create `lib/screens/upgrade/upgrade_required_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/app_version_service.dart';
import '../../widgets/common/bb_button.dart';

class UpgradeRequiredScreen extends ConsumerWidget {
  const UpgradeRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.screenBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppConstants.mascotSad, height: 160),
                AppConstants.gap24,
                const Text(
                  'Update erforderlich',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeHeadingLG,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap12,
                const Text(
                  'Um Belly Buddy weiter zu nutzen, aktualisiere bitte '
                  'auf die neueste Version.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                AppConstants.gap24,
                BbButton(
                  label: 'Aktualisieren',
                  onPressed: () => AppVersionService().openStore(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Register the route**

In `lib/router/app_router.dart`, add to the routes list:

```dart
GoRoute(
  path: RoutePaths.upgradeRequired,
  name: RouteNames.upgradeRequired,
  builder: (_, _) => const UpgradeRequiredScreen(),
),
```

- [ ] **Step 5: Run screen tests**

Run: `flutter test test/screens/upgrade/upgrade_required_screen_test.dart`. Expected: pass.

- [ ] **Step 6: Write failing test for the dialog**

Create `test/widgets/common/upgrade_available_dialog_test.dart`:

```dart
import 'package:belly_buddy/widgets/common/upgrade_available_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showUpgradeAvailableDialog(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders title, body, and both actions', (tester) async {
    await pumpHost(tester);

    expect(find.text('Update verfügbar'), findsOneWidget);
    expect(find.text('Eine neue Version von Belly Buddy ist im Store verfügbar.'),
        findsOneWidget);
    expect(find.text('Später'), findsOneWidget);
    expect(find.text('Jetzt aktualisieren'), findsOneWidget);
  });

  testWidgets('Später closes the dialog without launching the store',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();

    expect(find.text('Update verfügbar'), findsNothing);
  });
}
```

Run: FAIL.

- [ ] **Step 7: Implement the dialog**

Create `lib/widgets/common/upgrade_available_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/app_version_service.dart';

/// Dismissible modal shown on cold start when the installed version is
/// below `latest_version` but at or above `minimum_supported_version`.
Future<void> showUpgradeAvailableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Update verfügbar'),
      content: const Text(
        'Eine neue Version von Belly Buddy ist im Store verfügbar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Später'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          onPressed: () {
            Navigator.of(ctx).pop();
            AppVersionService().openStore();
          },
          child: const Text('Jetzt aktualisieren'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 8: Run dialog tests + analyze**

Run: `flutter test test/widgets/common/upgrade_available_dialog_test.dart`. Expected: pass.
Run: `flutter analyze`. Expected: 0 issues.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/upgrade/upgrade_required_screen.dart \
        test/screens/upgrade/upgrade_required_screen_test.dart \
        lib/widgets/common/upgrade_available_dialog.dart \
        test/widgets/common/upgrade_available_dialog_test.dart \
        lib/router/route_names.dart \
        lib/router/app_router.dart
git commit -m "feat(upgrade): upgrade-required screen, dialog, and route"
```

---

## Task 4: Splash + dashboard integration

**Files:**
- Modify: `lib/screens/splash/splash_screen.dart`
- Modify: `lib/app.dart` (splash owns navigation via the root navigator; if the splash can't access GoRouter directly, move the decision into `BellyBuddyApp`'s builder)
- Modify: `lib/screens/dashboard/dashboard_screen.dart`
- Test: `test/screens/splash/splash_upgrade_integration_test.dart` (create)

- [ ] **Step 1: Decide where the decision logic lives**

Read the current `lib/screens/splash/splash_screen.dart` and `lib/app.dart` in full. The splash is an overlay in `app.dart:155-169`'s `Stack`, with an `onComplete` callback that flips `_showSplash`. Two integration options:

- **Option A — splash awaits inside itself.** Splash becomes a `ConsumerStatefulWidget`, reads `upgradeDecisionProvider.future` in `initState`, applies the decision (via the GoRouter it can reach via `context.go` once the decision resolves), then calls `onComplete` to hide itself. Reachable because GoRouter is mounted before the splash overlay paints.
- **Option B — decision in `BellyBuddyApp`.** The app widget reads the provider; it passes a ready-to-apply callback into the splash which the splash calls just before `onComplete`.

**Pick Option A** — keeps the splash self-contained and doesn't expand `BellyBuddyApp`.

- [ ] **Step 2: Convert `SplashScreen` to `ConsumerStatefulWidget` and add the decision hook**

In `lib/screens/splash/splash_screen.dart`, change the class to `ConsumerStatefulWidget` (and `ConsumerState<SplashScreen>`). In `initState`, after the existing setup, add:

```dart
_awaitUpgradeDecision();
```

And add the method:

```dart
Future<void> _awaitUpgradeDecision() async {
  final decision = await ref.read(upgradeDecisionProvider.future);
  if (!mounted) return;
  switch (decision) {
    case UpgradeDecision.hardGate:
      GoRouter.of(context).go(RoutePaths.upgradeRequired);
      break;
    case UpgradeDecision.softNudge:
      ref.read(softNudgePendingProvider.notifier).state = true;
      break;
    case UpgradeDecision.ok:
      break;
  }
}
```

Add the imports: `package:flutter_riverpod/flutter_riverpod.dart`, `package:go_router/go_router.dart`, `../../providers/upgrade_gate_provider.dart`, `../../router/route_names.dart`.

**Important:** the existing splash logic continues to call `widget.onComplete()` after the minimum delay + fade — don't disturb that. The decision is applied in parallel; for `hardGate`, `context.go` replaces the router's stack, so when `onComplete` hides the splash overlay, the user lands on the upgrade screen instead of the dashboard.

- [ ] **Step 3: Show the dialog on dashboard first frame**

In `lib/screens/dashboard/dashboard_screen.dart`, add a one-shot `addPostFrameCallback` (or a `ref.listen` on `softNudgePendingProvider`) that:

1. Reads `softNudgePendingProvider`.
2. If true, calls `showUpgradeAvailableDialog(context)`, then sets the flag back to false so a hot reload or rebuild doesn't re-trigger.

The dashboard is already a `ConsumerStatefulWidget` (or similar — check first). If it's a `ConsumerWidget`, convert to stateful to get a reliable first-frame hook.

Concretely, in the dashboard's `initState`:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (ref.read(softNudgePendingProvider)) {
      ref.read(softNudgePendingProvider.notifier).state = false;
      showUpgradeAvailableDialog(context);
    }
  });
}
```

- [ ] **Step 4: Write an integration test**

Create `test/screens/splash/splash_upgrade_integration_test.dart`. Pump a pared-down `MaterialApp.router` with the real router + the splash overlay, override `upgradeDecisionProvider` to `hardGate`, pump past the splash's min delay, and assert the user lands on `/upgrade-required`. Second case: override to `softNudge`, assert the dashboard receives `softNudgePending = true`.

Use `tester.pumpAndSettle(const Duration(seconds: 2))` or explicit `tester.pump(splashConfig.minDelay + animation + fade)` to advance past the splash.

- [ ] **Step 5: Run the integration test + full suite**

Run: `flutter test test/screens/splash/splash_upgrade_integration_test.dart` — expected pass. Then `flutter test` — full suite green.

- [ ] **Step 6: Run analyze + commit**

```bash
git add lib/screens/splash/splash_screen.dart \
        lib/screens/dashboard/dashboard_screen.dart \
        test/screens/splash/splash_upgrade_integration_test.dart
git commit -m "feat(upgrade): wire upgrade gate into splash + dashboard"
```

---

## Task 5: Semantic-release pipeline

**Files:**
- Create: `.releaserc.json`
- Create: `.github/workflows/release.yml`
- Modify: `.github/workflows/deploy.yml`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Create `.releaserc.json`**

Create the file at the repo root with this exact content:

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    [
      "@semantic-release/exec",
      {
        "prepareCmd": "sed -i.bak -E 's/^version: [0-9]+\\.[0-9]+\\.[0-9]+\\+/version: ${nextRelease.version}+/' pubspec.yaml && rm pubspec.yaml.bak"
      }
    ],
    [
      "@semantic-release/git",
      {
        "assets": ["pubspec.yaml"],
        "message": "chore(release): ${nextRelease.version} [skip ci]"
      }
    ],
    "@semantic-release/github"
  ]
}
```

- [ ] **Step 2: Create `.github/workflows/release.yml`**

```yaml
name: Release

on:
  push:
    branches: [main]

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  release:
    runs-on: ubuntu-latest
    timeout-minutes: 10
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
        with:
          node-version: 20
      - name: Run semantic-release
        uses: cycjimmy/semantic-release-action@v4
        with:
          extra_plugins: |
            @semantic-release/exec
            @semantic-release/git
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 3: Change the deploy trigger**

In `.github/workflows/deploy.yml`, replace:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

with:

```yaml
on:
  push:
    tags: ['v*']
  workflow_dispatch:
```

No other changes to `deploy.yml` — the existing jobs (quality, test, deploy-android, deploy-ios) run as they do today, just triggered by tag-push instead of branch-push. `github.run_number` continues to produce unique build numbers.

- [ ] **Step 4: Update `CLAUDE.md`**

Append a section to `CLAUDE.md`:

```markdown
## Release versioning

Releases are cut automatically on every merge to `main` via `.github/workflows/release.yml` (semantic-release). The bump is derived from the commit messages merged in that PR:

- `fix:` → patch
- `feat:` → minor
- `feat!:` or a commit body containing `BREAKING CHANGE:` → major

Non-conventional commit messages are silently ignored by the analyzer — a merge to `main` composed entirely of such commits produces no bump and no release. Use conventional-commit prefixes (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`) for every commit.

The release workflow tags `v<version>` and commits the bumped `pubspec.yaml` back to `main`. The deploy workflow (`deploy.yml`) triggers on those tag pushes — never directly on `push: main`.

### One-off migration (already done)

Before `release.yml` ran for the first time, a baseline tag `v1.0.0` was pushed on `main` so semantic-release had a reference point.
```

- [ ] **Step 5: Push the baseline tag**

Before the release workflow can run for the first time, create and push the baseline tag. The implementer MUST NOT push this tag themselves — this is a one-time setup step the user runs locally:

```bash
# Confirm current main HEAD
git fetch origin
git log origin/main -1 --oneline

# Create and push the tag
git tag v1.0.0 origin/main
git push origin v1.0.0
```

Flag this as a required user step in the DONE report so the controller surfaces it.

- [ ] **Step 6: Commit**

```bash
git add .releaserc.json \
        .github/workflows/release.yml \
        .github/workflows/deploy.yml \
        CLAUDE.md
git commit -m "chore: automated semver via semantic-release on main"
```

---

## Task 6: Manual smoke test (user performs)

- [ ] Apply the backend task to Lovable (the prompt from the spec). Confirm the `app_config` table exists with the two seed rows.
- [ ] Push the one-off `v1.0.0` baseline tag (Task 5 Step 5).
- [ ] Merge this PR to `develop`, then merge `develop → main`. Observe:
  - `release.yml` runs, computes a bump (likely `1.0.1` if the merged commits are all `fix:`), rewrites `pubspec.yaml`, tags `v1.0.1`, pushes.
  - `deploy.yml` runs on the tag push, builds + uploads to Play Internal + TestFlight.
  - Install that build on a test device. Verify the installed version matches.
- [ ] On the test device: launch → splash → dashboard. No nudge (installed == latest).
- [ ] In Supabase dashboard, bump `latest_version` to `1.0.2`. Cold-start the app again: "Update verfügbar" dialog appears; "Später" dismisses; re-cold-start shows it again.
- [ ] In Supabase, bump `minimum_supported_version` to `1.0.2`. Cold-start: "Update erforderlich" screen, no back button.
- [ ] Reset Supabase values to `1.0.1` / `1.0.1` so tests don't stay in a blocked state.

---

## Risks / rollback

- **First `release.yml` run fails:** usually the missing baseline tag. Push `v1.0.0` and re-trigger via `workflow_dispatch` on the same commit (the release workflow supports it — add `workflow_dispatch:` under `on:` if you want a manual re-trigger path; optional).
- **Deploy trigger breaks manual redeploys:** `workflow_dispatch` is preserved — manual runs still work from the Actions tab.
- **Placeholder `iosAppStoreId`:** the constant is a placeholder until the real ID is known. The upgrade-required CTA will open a broken App Store URL until that is replaced. The implementer should flag this as DONE_WITH_CONCERNS and leave a clear `TODO` comment at the constant.
- **Conventional-commit drift:** if future merges to main contain only non-conventional commits, no release is cut. Mitigation: document in `CLAUDE.md` (Task 5 Step 4); add a future follow-up to enforce via a commitlint CI check if this becomes a problem.
