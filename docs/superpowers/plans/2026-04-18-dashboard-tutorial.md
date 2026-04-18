# Dashboard Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a 10-step, spotlight-style coach-mark tour of the Belly Buddy dashboard that runs once automatically for any user whose `profiles.tutorial_seen_at` is null, and can be replayed from Settings.

**Architecture:** A new `DashboardTutorialOverlay` widget is inserted into the app's root `Overlay` after the dashboard finishes loading. It reads target widget rects via shared `GlobalKey`s, paints a dim layer with a cutout (`CustomPainter`), renders a speech-bubble tooltip with a hairline connector line, advances on any tap, and exits early via an "Überspringen" link. A new `TutorialNotifier` (Riverpod) persists the "seen" state to a new `profiles.tutorial_seen_at` Supabase column through the existing `ProfileRepository` / `ProfileService` layers.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), Freezed + json_serializable, Supabase (`supabase_flutter`), GoRouter, `flutter_test` + `mocktail`, `integration_test`.

**Spec:** `docs/superpowers/specs/2026-04-18-dashboard-tutorial-design.md`

---

## File Structure

**New files:**
- `supabase/migrations/20260418120000_add_profiles_tutorial_seen_at.sql` — DB migration.
- `lib/providers/tutorial_provider.dart` — `TutorialNotifier` + `tutorialProvider`.
- `lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart` — shared `GlobalKey`s for the 10 targets.
- `lib/screens/dashboard/widgets/tutorial/tutorial_step.dart` — `TutorialStep` data class.
- `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart` — the 10-step list with German copy.
- `lib/screens/dashboard/widgets/tutorial/spotlight_painter.dart` — `CustomPainter` for dim + cutout.
- `lib/screens/dashboard/widgets/tutorial/tooltip_bubble.dart` — speech-bubble widget.
- `lib/screens/dashboard/widgets/tutorial/connector_line.dart` — `CustomPainter` for hairline connector.
- `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart` — the overlay widget orchestrator.
- `lib/screens/dashboard/widgets/tutorial/show_dashboard_tutorial.dart` — public helper that inserts the overlay into the root `Overlay`.
- `test/providers/tutorial_provider_test.dart` — unit tests.
- `test/screens/dashboard/tutorial_overlay_test.dart` — widget tests.
- `integration_test/tutorial_flow_test.dart` — end-to-end test.

**Modified files:**
- `lib/models/user_profile.dart` — add `tutorialSeenAt` field (+ regenerated `user_profile.freezed.dart` / `user_profile.g.dart`).
- `lib/repositories/profile_repository.dart` — add `updateTutorialSeenAt()` method.
- `lib/screens/dashboard/dashboard_screen.dart` — attach 8 `GlobalKey`s, insert overlay after load.
- `lib/widgets/common/bb_bottom_nav.dart` — attach 2 `GlobalKey`s.
- `lib/screens/settings/settings_screen.dart` — add "Tour neu starten" row.
- `test/helpers/fakes.dart` — extend `FakeProfileRepository` with `updateTutorialSeenAt`.

---

## Conventions used throughout this plan

- **TDD:** every code task starts with a failing test, runs it to confirm failure, then writes the minimal implementation, then re-runs the test.
- **Commit cadence:** commit at the end of each numbered task. Commit messages follow the existing project style (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`).
- **Dart format + analyze:** before each commit, run `dart format .` and `flutter analyze` and ensure zero issues — CI requires both.
- **No Supabase CLI assumed:** the migration file is written by hand; applying it to the remote DB is a separate operation the user performs manually via the Supabase dashboard (noted at the end of Task 1).

---

## Task 1: Add Supabase column for `tutorial_seen_at`

**Files:**
- Create: `supabase/migrations/20260418120000_add_profiles_tutorial_seen_at.sql`

- [ ] **Step 1: Write the SQL migration**

Create `supabase/migrations/20260418120000_add_profiles_tutorial_seen_at.sql`:

```sql
-- Add nullable timestamp column to track when a user first completed
-- (or skipped) the dashboard tutorial. NULL means the tour has not been
-- shown / completed yet. A timestamp means the user has seen it.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS tutorial_seen_at TIMESTAMPTZ;
```

- [ ] **Step 2: Note for the user to apply the migration**

Print (in the commit message body) that the migration must be applied manually via the Supabase dashboard (SQL editor) or `supabase db push` before the app build is deployed. This is required so fetched profiles contain the new column.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260418120000_add_profiles_tutorial_seen_at.sql
git commit -m "feat(db): add profiles.tutorial_seen_at column

Tracks whether a user has completed or skipped the dashboard onboarding tour.
Apply via Supabase dashboard SQL editor or \`supabase db push\` before shipping
the client code that depends on this column."
```

---

## Task 2: Extend `UserProfile` model with `tutorialSeenAt`

**Files:**
- Modify: `lib/models/user_profile.dart`

- [ ] **Step 1: Add the field to the freezed class**

Edit `lib/models/user_profile.dart`. Inside the `@freezed abstract class UserProfile`'s `const factory UserProfile({...})` parameter list, add right below the existing `lastInactivityNudge` field:

```dart
@JsonKey(name: 'tutorial_seen_at') DateTime? tutorialSeenAt,
```

The full signature tail now reads:

```dart
    @JsonKey(name: 'fcm_token') String? fcmToken,
    @JsonKey(name: 'last_inactivity_nudge') DateTime? lastInactivityNudge,
    @JsonKey(name: 'tutorial_seen_at') DateTime? tutorialSeenAt,
  }) = _UserProfile;
```

- [ ] **Step 2: Regenerate freezed + json_serializable artefacts**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: completes with no errors; `lib/models/user_profile.freezed.dart` and `lib/models/user_profile.g.dart` are updated to include the new field. (These files are gitignored per CLAUDE.md.)

- [ ] **Step 3: Verify analyzer is clean**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/models/user_profile.dart
git commit -m "feat(model): add tutorialSeenAt field to UserProfile

Maps to the new profiles.tutorial_seen_at column. Nullable DateTime; null
means the tutorial has not been shown yet."
```

---

## Task 3: Add `ProfileRepository.updateTutorialSeenAt()`

**Files:**
- Modify: `lib/repositories/profile_repository.dart`
- Test: `test/repositories/profile_repository_test.dart` (may or may not exist — check; if it does, extend it, else create)

- [ ] **Step 1: Check whether the repo test file exists**

Run:

```bash
ls test/repositories/profile_repository_test.dart 2>/dev/null && echo EXISTS || echo MISSING
```

If `MISSING`, create a minimal new test file using the helper pattern. If `EXISTS`, append the new test inside its existing `void main()` / `group`.

- [ ] **Step 2: Write the failing test**

Append this block inside `void main()` of `test/repositories/profile_repository_test.dart` (create the file if needed using the scaffold below; otherwise append the `group(...)` block).

**Scaffold (if the file does not exist):**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';

void main() {
  late MockProfileService mockService;
  late MockAuthService mockAuth;
  late ProfileRepository repo;

  setUp(() {
    mockService = MockProfileService();
    mockAuth = MockAuthService();
    repo = ProfileRepository(mockService, mockAuth);
  });

  group('ProfileRepository.updateTutorialSeenAt', () {
    test('writes tutorial_seen_at as ISO-8601 string', () async {
      final ts = DateTime.utc(2026, 4, 18, 12, 0, 0);
      when(
        () => mockService.update(any(), any()),
      ).thenAnswer((_) async {});

      await repo.updateTutorialSeenAt(testUserId, ts);

      verify(
        () => mockService.update(testUserId, {
          'tutorial_seen_at': '2026-04-18T12:00:00.000Z',
        }),
      ).called(1);
    });

    test('writes null to clear the flag', () async {
      when(
        () => mockService.update(any(), any()),
      ).thenAnswer((_) async {});

      await repo.updateTutorialSeenAt(testUserId, null);

      verify(
        () => mockService.update(testUserId, {'tutorial_seen_at': null}),
      ).called(1);
    });
  });
}
```

**If the file already exists:** only append the `group('ProfileRepository.updateTutorialSeenAt', ...)` block above to the existing `void main()`.

- [ ] **Step 3: Run the test to confirm it fails**

```bash
flutter test test/repositories/profile_repository_test.dart
```

Expected: compilation error (`The method 'updateTutorialSeenAt' isn't defined for the type 'ProfileRepository'`).

- [ ] **Step 4: Implement `updateTutorialSeenAt()`**

Edit `lib/repositories/profile_repository.dart`. Add this method inside the `ProfileRepository` class, right after `updateProfile`:

```dart
  Future<void> updateTutorialSeenAt(String userId, DateTime? value) async {
    await _profileService.update(userId, {
      'tutorial_seen_at': value?.toIso8601String(),
    });
  }
```

- [ ] **Step 5: Run the test to confirm it passes**

```bash
flutter test test/repositories/profile_repository_test.dart
```

Expected: both new tests pass.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/repositories/profile_repository.dart test/repositories/profile_repository_test.dart
git commit -m "feat(repo): add updateTutorialSeenAt to ProfileRepository

Writes profiles.tutorial_seen_at via the existing ProfileService.update path."
```

---

## Task 4: Extend `FakeProfileRepository` with `updateTutorialSeenAt`

**Files:**
- Modify: `test/helpers/fakes.dart`

- [ ] **Step 1: Extend the fake**

Edit `test/helpers/fakes.dart`. Replace the existing `FakeProfileRepository` class (around line 174) with this version that also tracks tutorial writes:

```dart
class FakeProfileRepository implements ProfileRepository {
  UserProfile? _profile;
  DateTime? _lastTutorialSeenAt;
  bool _tutorialUpdateCalled = false;

  void seedProfile(UserProfile profile) => _profile = profile;
  DateTime? get lastTutorialSeenAt => _lastTutorialSeenAt;
  bool get tutorialUpdateCalled => _tutorialUpdateCalled;

  @override
  Future<UserProfile?> getProfile(String userId) async => _profile;
  @override
  Future<void> createProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(userId: userId);
  @override
  Future<void> updateProfile(String userId, UserProfile profile) async =>
      _profile = profile.copyWith(userId: userId);
  @override
  Future<void> updateTutorialSeenAt(String userId, DateTime? value) async {
    _tutorialUpdateCalled = true;
    _lastTutorialSeenAt = value;
    _profile = _profile?.copyWith(tutorialSeenAt: value);
  }
}
```

- [ ] **Step 2: Verify the test suite still compiles and passes**

```bash
flutter analyze
flutter test
```

Expected: `No issues found!`; all existing tests still pass.

- [ ] **Step 3: Commit**

```bash
git add test/helpers/fakes.dart
git commit -m "test(helpers): extend FakeProfileRepository with updateTutorialSeenAt

Tracks the last written value for assertions in TutorialNotifier tests."
```

---

## Task 5: Create `TutorialNotifier` provider + unit tests

**Files:**
- Create: `lib/providers/tutorial_provider.dart`
- Create: `test/providers/tutorial_provider_test.dart`

- [ ] **Step 1: Write the failing unit tests**

Create `test/providers/tutorial_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late FakeProfileRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeProfileRepository();
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('TutorialNotifier.shouldShow', () {
    test('returns false when profile has not loaded yet', () {
      final c = makeContainer();
      expect(c.read(tutorialProvider.notifier).shouldShow(), isFalse);
    });

    test('returns true when profile loaded and tutorialSeenAt is null', () async {
      fakeRepo.seedProfile(testUserProfile()); // tutorialSeenAt defaults to null
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      expect(c.read(tutorialProvider.notifier).shouldShow(), isTrue);
    });

    test('returns false when tutorialSeenAt is set', () async {
      fakeRepo.seedProfile(
        testUserProfile().copyWith(tutorialSeenAt: DateTime.utc(2026, 4, 1)),
      );
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      expect(c.read(tutorialProvider.notifier).shouldShow(), isFalse);
    });
  });

  group('TutorialNotifier.markSeen', () {
    test('writes a timestamp via the repo and refreshes the profile', () async {
      fakeRepo.seedProfile(testUserProfile());
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      final before = DateTime.now().toUtc();
      await c.read(tutorialProvider.notifier).markSeen();
      final after = DateTime.now().toUtc();

      expect(fakeRepo.tutorialUpdateCalled, isTrue);
      expect(fakeRepo.lastTutorialSeenAt, isNotNull);
      expect(
        fakeRepo.lastTutorialSeenAt!.isAtSameMomentAs(before) ||
            fakeRepo.lastTutorialSeenAt!.isAfter(before),
        isTrue,
      );
      expect(
        fakeRepo.lastTutorialSeenAt!.isBefore(after) ||
            fakeRepo.lastTutorialSeenAt!.isAtSameMomentAs(after),
        isTrue,
      );
      final profile = c.read(profileProvider).value;
      expect(profile?.tutorialSeenAt, equals(fakeRepo.lastTutorialSeenAt));
    });

    test('is a no-op if no user is signed in', () async {
      final c = makeContainer(userId: null);
      await c.read(tutorialProvider.notifier).markSeen();
      expect(fakeRepo.tutorialUpdateCalled, isFalse);
    });
  });

  group('TutorialNotifier.reset', () {
    test('writes null via the repo and refreshes the profile', () async {
      fakeRepo.seedProfile(
        testUserProfile().copyWith(tutorialSeenAt: DateTime.utc(2026, 4, 1)),
      );
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      await c.read(tutorialProvider.notifier).reset();

      expect(fakeRepo.tutorialUpdateCalled, isTrue);
      expect(fakeRepo.lastTutorialSeenAt, isNull);
      expect(c.read(profileProvider).value?.tutorialSeenAt, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/providers/tutorial_provider_test.dart
```

Expected: compilation error — `tutorial_provider.dart` does not yet exist.

- [ ] **Step 3: Write the provider**

Create `lib/providers/tutorial_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../utils/logger.dart';

/// Action-only notifier for the dashboard onboarding tutorial.
///
/// The "seen" state itself lives on [UserProfile.tutorialSeenAt] and is read
/// via [profileProvider]. This notifier exists only to expose the mutating
/// actions ([markSeen], [reset]) and a convenience query ([shouldShow]).
class TutorialNotifier extends Notifier<void> {
  static const _log = AppLogger('TutorialProvider');

  @override
  void build() {}

  /// Whether the overlay should be displayed for the current profile.
  bool shouldShow() {
    final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
    return profile != null && profile.tutorialSeenAt == null;
  }

  /// Marks the tutorial as seen now. Called on normal completion and on
  /// "Überspringen". Safe to call even if the write fails — we log and
  /// continue so the UI isn't blocked on the network.
  Future<void> markSeen() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateTutorialSeenAt(userId, DateTime.now().toUtc());
      await ref.read(profileProvider.notifier).fetchProfile();
    } catch (e, st) {
      _log.error('markSeen failed', e, st);
    }
  }

  /// Clears the seen-flag so the tutorial runs again on next dashboard open.
  /// Used by the "Tour neu starten" button in Settings.
  Future<void> reset() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref
        .read(profileRepositoryProvider)
        .updateTutorialSeenAt(userId, null);
    await ref.read(profileProvider.notifier).fetchProfile();
  }
}

final tutorialProvider =
    NotifierProvider<TutorialNotifier, void>(TutorialNotifier.new);
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/providers/tutorial_provider_test.dart
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/providers/tutorial_provider.dart test/providers/tutorial_provider_test.dart
git commit -m "feat(provider): add TutorialNotifier for dashboard onboarding tour

Exposes shouldShow(), markSeen(), reset(). Writes via ProfileRepository and
refreshes profileProvider so the cached UserProfile reflects the change."
```

---

## Task 6: Define `TutorialKeys` and `TutorialStep`

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart`
- Create: `lib/screens/dashboard/widgets/tutorial/tutorial_step.dart`

- [ ] **Step 1: Create the shared keys class**

Create `lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Global keys attached to the 10 dashboard elements highlighted in the
/// onboarding tour. Referenced both by the dashboard/bottom-nav widgets
/// (at construction time) and by the tutorial overlay (to resolve each
/// target's render box).
class TutorialKeys {
  TutorialKeys._();

  static final bauchgefuehl  = GlobalKey(debugLabel: 'tutorial.bauchgefuehl');
  static final klo           = GlobalKey(debugLabel: 'tutorial.klo');
  static final essenTracken  = GlobalKey(debugLabel: 'tutorial.essenTracken');
  static final fuerDich      = GlobalKey(debugLabel: 'tutorial.fuerDich');
  static final alternativen  = GlobalKey(debugLabel: 'tutorial.alternativen');
  static final wissen        = GlobalKey(debugLabel: 'tutorial.wissen');
  static final rezepte       = GlobalKey(debugLabel: 'tutorial.rezepte');
  static final tagebuch      = GlobalKey(debugLabel: 'tutorial.tagebuch');
  static final feedback      = GlobalKey(debugLabel: 'tutorial.feedback');
  static final settings      = GlobalKey(debugLabel: 'tutorial.settings');
}
```

- [ ] **Step 2: Create the `TutorialStep` data class**

Create `lib/screens/dashboard/widgets/tutorial/tutorial_step.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../../../config/constants.dart';

/// Whether the tooltip bubble for a step should be anchored above or below
/// its target. The overlay may override this at measure-time if the chosen
/// side has insufficient vertical space.
enum TooltipAnchor { above, below }

/// One step in the dashboard onboarding tour.
class TutorialStep {
  /// Key attached to the element this step highlights.
  final GlobalKey targetKey;

  /// Styled text spans shown in the tooltip bubble. Bold emphasis is baked
  /// into the span list (via TextSpan with FontWeight.w700).
  final List<InlineSpan> richText;

  /// Corner radius used for the spotlight cutout around the target.
  final double targetRadius;

  /// Preferred side to anchor the tooltip bubble on.
  final TooltipAnchor preferredAnchor;

  const TutorialStep({
    required this.targetKey,
    required this.richText,
    this.targetRadius = AppConstants.radiusMd,
    this.preferredAnchor = TooltipAnchor.below,
  });
}
```

- [ ] **Step 3: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart lib/screens/dashboard/widgets/tutorial/tutorial_step.dart
git commit -m "feat(tutorial): add TutorialKeys and TutorialStep scaffolding"
```

---

## Task 7: Define the 10-step German copy list

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart`

- [ ] **Step 1: Write the list**

Create `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import 'tutorial_keys.dart';
import 'tutorial_step.dart';

const _baseStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.foreground,
  height: 1.35,
);

const _boldStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.foreground,
  fontWeight: FontWeight.w700,
  height: 1.35,
);

TextSpan _t(String text) => TextSpan(text: text, style: _baseStyle);
TextSpan _b(String text) => TextSpan(text: text, style: _boldStyle);

/// The 10 tutorial steps, in the fixed order shown by the mockups in
/// `Anleitung Homescreen/` (filenames 1.png–10.png).
final List<TutorialStep> dashboardTutorialSteps = [
  // 1 - Bauchgefühl-Tracker (top-left tracker tile)
  TutorialStep(
    targetKey: TutorialKeys.bauchgefuehl,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t('Tracke deine '),
      _b('Beschwerden und deine Befindlichkeit'),
      _t(
        ' hier, um uns zu helfen, einen Zusammenhang zwischen deiner Ernährung und deinem Wohlbefinden herauszufinden.',
      ),
    ],
  ),
  // 2 - Klo-Tracker (top-right tracker tile)
  TutorialStep(
    targetKey: TutorialKeys.klo,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t(
        "Wann, wie oft und in welcher Form du auf's Klo gehst, ist ebenfalls eine sehr wichtige Information. Hier kannst du ",
      ),
      _b('deinen Stuhlgang tracken'),
      _t('.'),
    ],
  ),
  // 3 - Essen tracken (center FAB in bottom nav)
  TutorialStep(
    targetKey: TutorialKeys.essenTracken,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Tracke '),
      _b('Speisen und Getränke'),
      _t(
        ', die du zu dir nimmst. Je regelmäßiger du das tust, desto besser können wir dir Tipps für mehr Wohlbefinden geben.',
      ),
    ],
  ),
  // 4 - Für dich (top-left feature card)
  TutorialStep(
    targetKey: TutorialKeys.fuerDich,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Hol dir 1 x pro Tag Feedback zu '),
      _b('deinen Speisen und Getränken'),
      _t(
        ' und erfahre, was du in Zukunft anders machen kannst, um dich wohler zu fühlen.',
      ),
    ],
  ),
  // 5 - Alternativen (top-right feature card)
  TutorialStep(
    targetKey: TutorialKeys.alternativen,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Alle besser '),
      _b('verträglichen Lebensmittel-Alternativen'),
      _t(' basierend auf deinen Speisen findest du hier.'),
    ],
  ),
  // 6 - Wissen (bottom-right feature card)
  TutorialStep(
    targetKey: TutorialKeys.wissen,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t(
        'Du willst mehr über die Themen Verdauung, ungeniert Pupsen und Co erfahren? ',
      ),
      _b("Hier geht's zum Blog!"),
    ],
  ),
  // 7 - Rezepte (bottom-left feature card)
  TutorialStep(
    targetKey: TutorialKeys.rezepte,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Auf deine Bedürfnisse angepasste Rezepte findest du (sehr bald) hier.'),
    ],
  ),
  // 8 - Tagebuch (bottom nav, right)
  TutorialStep(
    targetKey: TutorialKeys.tagebuch,
    targetRadius: AppConstants.radiusMd,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Was hast du wann gegessen und wie ist es dir dabei gegangen? Eine '),
      _b('Übersicht'),
      _t(' über alle deine erfassten Daten findest du hier.'),
    ],
  ),
  // 9 - Feedback-Icon (dashboard header, top-right)
  TutorialStep(
    targetKey: TutorialKeys.feedback,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _b('Fragen und Feedback zur App'),
      _t(' kannst du uns hier ganz einfach schicken.'),
    ],
  ),
  // 10 - Einstellungen / Settings-Gear
  TutorialStep(
    targetKey: TutorialKeys.settings,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t('Alle '),
      _b('Einstellungen'),
      _t(' zu deinem Profil kannst du hier einsehen und bearbeiten.'),
    ],
  ),
];
```

- [ ] **Step 2: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart
git commit -m "feat(tutorial): define 10-step German copy for dashboard tour

Copy taken verbatim from the mockups in Anleitung Homescreen/*.png."
```

---

## Task 8: Implement `SpotlightPainter`

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/spotlight_painter.dart`

- [ ] **Step 1: Write the painter**

Create `lib/screens/dashboard/widgets/tutorial/spotlight_painter.dart`:

```dart
import 'package:flutter/material.dart';

/// Paints a semi-transparent dim layer over the whole screen, with a rounded
/// rectangular cutout around [targetRect]. Used as the backdrop of the
/// dashboard onboarding overlay.
class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double targetRadius;
  final Color dimColor;

  const SpotlightPainter({
    required this.targetRect,
    required this.targetRadius,
    this.dimColor = const Color(0x8C000000), // ~55% black
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(0, 0, size.width, size.height);
    final screenPath = Path()..addRect(screen);

    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect, Radius.circular(targetRadius)),
      );

    final cutout = Path.combine(PathOperation.difference, screenPath, holePath);

    canvas.drawPath(cutout, Paint()..color = dimColor);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter old) =>
      old.targetRect != targetRect ||
      old.targetRadius != targetRadius ||
      old.dimColor != dimColor;
}
```

- [ ] **Step 2: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/spotlight_painter.dart
git commit -m "feat(tutorial): add SpotlightPainter for dim-and-cutout backdrop"
```

---

## Task 9: Implement `TooltipBubble`

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/tooltip_bubble.dart`

- [ ] **Step 1: Write the widget**

Create `lib/screens/dashboard/widgets/tutorial/tooltip_bubble.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';

/// Speech-bubble style tooltip used by the onboarding overlay.
///
/// Renders [richText] inside a rounded-rectangle container with a soft shadow.
/// Width is capped at [maxWidth] logical pixels so the bubble never touches
/// the screen edges.
class TooltipBubble extends StatelessWidget {
  final List<InlineSpan> richText;
  final double maxWidth;

  const TooltipBubble({
    super.key,
    required this.richText,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: AppConstants.paddingMd,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(children: richText),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/tooltip_bubble.dart
git commit -m "feat(tutorial): add TooltipBubble speech-bubble widget"
```

---

## Task 10: Implement `ConnectorLine`

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/connector_line.dart`

- [ ] **Step 1: Write the painter**

Create `lib/screens/dashboard/widgets/tutorial/connector_line.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';

/// Paints a single 1.2-logical-pixel straight line from [bubbleAnchor] to
/// [targetAnchor], both expressed in the overlay Stack's coordinate space.
/// Used to draw the hairline connector between the tooltip bubble and the
/// spotlighted element, matching the mockup.
class ConnectorLine extends CustomPainter {
  final Offset bubbleAnchor;
  final Offset targetAnchor;

  const ConnectorLine({
    required this.bubbleAnchor,
    required this.targetAnchor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.foreground
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(bubbleAnchor, targetAnchor, paint);
  }

  @override
  bool shouldRepaint(covariant ConnectorLine old) =>
      old.bubbleAnchor != bubbleAnchor || old.targetAnchor != targetAnchor;
}
```

- [ ] **Step 2: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/connector_line.dart
git commit -m "feat(tutorial): add ConnectorLine hairline painter"
```

---

## Task 11: Implement `DashboardTutorialOverlay` orchestrator

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart`

- [ ] **Step 1: Write the widget**

Create `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import 'connector_line.dart';
import 'spotlight_painter.dart';
import 'tooltip_bubble.dart';
import 'tutorial_step.dart';

/// Full-screen overlay widget driving the 10-step dashboard tour.
///
/// Displayed by inserting it into the root [Overlay] (see
/// `show_dashboard_tutorial.dart`). Tapping anywhere advances a step.
/// Tapping the "Überspringen" link in the top-right finishes immediately.
/// Calls [onFinish] exactly once when the last step is advanced past OR
/// when the user skips.
class DashboardTutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onFinish;

  const DashboardTutorialOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<DashboardTutorialOverlay> createState() =>
      _DashboardTutorialOverlayState();
}

class _DashboardTutorialOverlayState extends State<DashboardTutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Rect? _targetRect;
  bool _finished = false;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppConstants.animFast,
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _measure() {
    final step = widget.steps[_index];
    final ctx = step.targetKey.currentContext;
    if (ctx == null) {
      // Target not yet mounted — skip to next step defensively.
      _advanceInternal();
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      _advanceInternal();
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & box.size;
    });
  }

  void _advance() {
    if (_finished) return;
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _index += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _advanceInternal() {
    // Used when a target key has no render box — avoids getting stuck.
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _index += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    await _fade.reverse();
    if (!mounted) return;
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final rect = _targetRect;
    final safe = MediaQuery.of(context).padding;

    return FadeTransition(
      opacity: _fade,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                // Advance-on-tap layer + dim + cutout painter
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _advance,
                    child: CustomPaint(
                      painter: rect == null
                          ? null
                          : SpotlightPainter(
                              targetRect: rect.inflate(AppConstants.spacingXs),
                              targetRadius: step.targetRadius,
                            ),
                    ),
                  ),
                ),
                // Tooltip bubble + connector
                if (rect != null)
                  ..._buildBubbleAndConnector(
                    step: step,
                    targetRect: rect,
                    screenSize: screenSize,
                    safe: safe,
                  ),
                // "Überspringen" link (must sit above the advance layer)
                Positioned(
                  top: safe.top + AppConstants.spacingSm,
                  right: AppConstants.spacingMd,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _finish,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                        vertical: AppConstants.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.9),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusRound),
                      ),
                      child: const Text(
                        'Überspringen',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBubbleAndConnector({
    required TutorialStep step,
    required Rect targetRect,
    required Size screenSize,
    required EdgeInsets safe,
  }) {
    const horizontalMargin = AppConstants.spacingLg;
    final maxBubbleWidth = screenSize.width - (horizontalMargin * 2);

    // Decide actual anchor based on available space.
    final spaceAbove = targetRect.top - safe.top;
    final spaceBelow = screenSize.height - safe.bottom - targetRect.bottom;
    TooltipAnchor anchor = step.preferredAnchor;
    const minSpaceRequired = 140.0;
    if (anchor == TooltipAnchor.above && spaceAbove < minSpaceRequired) {
      anchor = TooltipAnchor.below;
    } else if (anchor == TooltipAnchor.below && spaceBelow < minSpaceRequired) {
      anchor = TooltipAnchor.above;
    }

    const gap = AppConstants.spacingLg; // spacing between target and bubble
    final bubble = TooltipBubble(richText: step.richText, maxWidth: maxBubbleWidth);

    // Horizontal position: center on target, clamped to screen margins.
    final bubbleWidth = maxBubbleWidth; // upper bound; actual may be smaller
    final bubbleCenterX = targetRect.center.dx
        .clamp(horizontalMargin + bubbleWidth / 2, screenSize.width - horizontalMargin - bubbleWidth / 2);

    // Vertical position of bubble's top edge:
    final bubbleTop = anchor == TooltipAnchor.above
        ? (targetRect.top - gap - _estimatedBubbleHeight)
        : (targetRect.bottom + gap);

    final bubbleRectApprox = Rect.fromLTWH(
      bubbleCenterX - bubbleWidth / 2,
      bubbleTop,
      bubbleWidth,
      _estimatedBubbleHeight,
    );

    // Connector endpoints
    final targetAnchor = Offset(targetRect.center.dx,
        anchor == TooltipAnchor.above ? targetRect.top : targetRect.bottom);
    final bubbleAnchor = Offset(
      bubbleRectApprox.center.dx,
      anchor == TooltipAnchor.above ? bubbleRectApprox.bottom : bubbleRectApprox.top,
    );

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: ConnectorLine(
              bubbleAnchor: bubbleAnchor,
              targetAnchor: targetAnchor,
            ),
          ),
        ),
      ),
      Positioned(
        left: bubbleRectApprox.left,
        top: bubbleRectApprox.top,
        width: bubbleRectApprox.width,
        child: IgnorePointer(child: bubble),
      ),
    ];
  }

  // Rough upper bound — used only for connector-line endpoint math. The
  // actual bubble sizes itself based on its content; the connector just
  // needs a reasonable approximation.
  static const double _estimatedBubbleHeight = 140;
}
```

- [ ] **Step 2: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart
git commit -m "feat(tutorial): add DashboardTutorialOverlay orchestrator widget

Advances on tap, skips via 'Überspringen' link, uses SpotlightPainter +
TooltipBubble + ConnectorLine to render each step. Anchors bubble above or
below the target based on available space."
```

---

## Task 12: Write `showDashboardTutorial` entry-point helper

**Files:**
- Create: `lib/screens/dashboard/widgets/tutorial/show_dashboard_tutorial.dart`

- [ ] **Step 1: Write the helper**

Create `lib/screens/dashboard/widgets/tutorial/show_dashboard_tutorial.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'dashboard_tutorial_overlay.dart';
import 'dashboard_tutorial_steps.dart';

/// Inserts the [DashboardTutorialOverlay] into the root Overlay using the
/// 10 predefined steps. Returns a Future that completes when the user either
/// finishes all steps or taps "Überspringen".
Future<void> showDashboardTutorial(BuildContext context) async {
  final completer = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => DashboardTutorialOverlay(
      steps: dashboardTutorialSteps,
      onFinish: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  return completer.future;
}
```

- [ ] **Step 2: Verify analyzer is clean**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/dashboard/widgets/tutorial/show_dashboard_tutorial.dart
git commit -m "feat(tutorial): add showDashboardTutorial entry-point helper"
```

---

## Task 13: Widget test the overlay (spotlight, advance, skip)

**Files:**
- Create: `test/screens/dashboard/tutorial_overlay_test.dart`

- [ ] **Step 1: Write the widget tests**

Create `test/screens/dashboard/tutorial_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_step.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('DashboardTutorialOverlay', () {
    final keyA = GlobalKey(debugLabel: 'a');
    final keyB = GlobalKey(debugLabel: 'b');

    List<TutorialStep> twoSteps() => [
      TutorialStep(
        targetKey: keyA,
        richText: const [TextSpan(text: 'step a')],
      ),
      TutorialStep(
        targetKey: keyB,
        richText: const [TextSpan(text: 'step b')],
      ),
    ];

    Widget harness({
      required Widget overlay,
    }) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 20, top: 100, width: 80, height: 80,
              child: Container(key: keyA, color: Colors.blue),
            ),
            Positioned(
              left: 20, bottom: 100, width: 80, height: 80,
              child: Container(key: keyB, color: Colors.green),
            ),
            Positioned.fill(child: overlay),
          ],
        ),
      );
    }

    testWidgets('renders the first step\'s bubble text', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('step a'), findsOneWidget);
      expect(find.text('step b'), findsNothing);
      expect(find.text('Überspringen'), findsOneWidget);
      expect(finished, isFalse);
    });

    testWidgets('tapping background advances to the next step', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap near top-left where the advance GestureDetector is unobstructed.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('step b'), findsOneWidget);
      expect(finished, isFalse);
    });

    testWidgets('advancing past the last step calls onFinish', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to step b
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      // Advance past last → finish
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });

    testWidgets('tapping Überspringen finishes immediately', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Überspringen'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the tests**

```bash
flutter test test/screens/dashboard/tutorial_overlay_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 3: Commit**

```bash
dart format .
flutter analyze
git add test/screens/dashboard/tutorial_overlay_test.dart
git commit -m "test(tutorial): widget tests for DashboardTutorialOverlay"
```

---

## Task 14: Attach `GlobalKey`s in `DashboardScreen`

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add the import**

Edit `lib/screens/dashboard/dashboard_screen.dart`. Add this import with the existing tutorial imports (at the bottom of the import block):

```dart
import 'widgets/tutorial/tutorial_keys.dart';
```

- [ ] **Step 2: Attach keys in `_DashboardHeader`**

Replace the two `CircleIconButton` instances in `_DashboardHeader.build` (around line 119–134) with keyed versions:

```dart
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleIconButton(
          key: TutorialKeys.feedback,
          icon: Icons.feedback_outlined,
          size: AppConstants.iconBadgeLg,
          onPressed: () => launchUrl(
            Uri.parse(AppConstants.feedbackFormUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        CircleIconButton(
          key: TutorialKeys.settings,
          icon: Icons.settings,
          size: AppConstants.iconBadgeLg,
          onPressed: () => context.push(RoutePaths.settings),
        ),
      ],
    );
```

- [ ] **Step 3: Attach keys in `_TrackerCards`**

Replace the two `TrackerCard` widgets inside `_TrackerCards.build` (around line 145–161):

```dart
    return Row(
      children: [
        Expanded(
          child: TrackerCard(
            key: TutorialKeys.bauchgefuehl,
            svgPath: AppConstants.logoSvg,
            label: 'Bauchgefühl',
            onTap: () => context.push(RoutePaths.gutFeelingTracker),
          ),
        ),
        const SizedBox(width: AppConstants.spacing12),
        Expanded(
          child: TrackerCard(
            key: TutorialKeys.klo,
            svgPath: AppConstants.toiletPaperSvg,
            label: 'Klo',
            onTap: () => context.push(RoutePaths.toiletTracker),
          ),
        ),
      ],
    );
```

- [ ] **Step 4: Attach keys in `_ForYouSection`**

Replace the four `FeatureCard` widgets inside `_ForYouSection.build` (around line 207–258):

```dart
          Row(
            children: [
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.fuerDich,
                  imageAsset: AppConstants.fuerDichCard,
                  label: 'Für dich',
                  icon: Icons.auto_awesome,
                  iconColor: AppTheme.foreground,
                  hasNew: newRecommendationCount > 0,
                  onTap: () => context.push(RoutePaths.recommendations),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.alternativen,
                  imageAsset: AppConstants.alternativenCard,
                  label: 'Alternativen',
                  icon: Icons.eco,
                  iconColor: AppTheme.foreground,
                  badgeCount: newSuggestionCount,
                  onTap: () => context.push(RoutePaths.ingredientSuggestions),
                ),
              ),
            ],
          ),
          AppConstants.gap12,
          Row(
            children: [
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.rezepte,
                  imageAsset: AppConstants.rezepteCard,
                  label: 'Rezepte',
                  icon: Icons.restaurant_menu,
                  iconColor: AppTheme.foreground,
                  onTap: () => context.push(RoutePaths.recipes),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.wissen,
                  imageAsset: AppConstants.susiPhone,
                  label: 'Wissen',
                  icon: Icons.menu_book,
                  iconColor: AppTheme.foreground,
                  onTap: () => launchUrl(
                    Uri.parse('https://www.myfodmap.at/blog'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
```

- [ ] **Step 5: Verify analyzer is clean**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `No issues found!`; all existing tests still pass. If any widget test broke because of a new `key:` prop, fix by updating the test's expected widget tree — but this is unlikely because `key:` is additive.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(tutorial): attach TutorialKeys to dashboard elements"
```

---

## Task 15: Attach `GlobalKey`s in `BbBottomNav`

**Files:**
- Modify: `lib/widgets/common/bb_bottom_nav.dart`

- [ ] **Step 1: Add the import**

Edit `lib/widgets/common/bb_bottom_nav.dart`. Add with the existing imports:

```dart
import '../../screens/dashboard/widgets/tutorial/tutorial_keys.dart';
```

- [ ] **Step 2: Attach key to the center FAB (inside `_CenterButton`)**

The visible FAB is the circular `Container` inside `_CenterButton`, which is positioned *above* the enclosing 80×64 `SizedBox` via `Positioned(top: -26, ...)`. Attaching the key to the outer widget would give the overlay the wrong rect. Instead, attach the key directly to the inner circular container.

In `_CenterButton.build` (near the bottom of the file, around line 190), replace the inner `Container` (the one with `width: 72, height: 72, shape: BoxShape.circle`) with a keyed version:

```dart
            Positioned(
              top: -26,
              child: Container(
                key: TutorialKeys.essenTracken,
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: AppTheme.primaryForeground,
                  size: 36,
                ),
              ),
            ),
```

- [ ] **Step 3: Attach key to the Tagebuch nav item**

Same approach — wrap the existing `_NavItem` for Tagebuch (around line 69) in a `KeyedSubtree`:

Replace:

```dart
                  // Diary
                  _NavItem(
                    tapKey: navDiaryKey,
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book,
                    label: 'Tagebuch',
                    isActive: currentIndex == 1,
                    onTap: () {
                      HapticService.light();
                      navigationShell.goBranch(1);
                    },
                  ),
```

with:

```dart
                  // Diary
                  KeyedSubtree(
                    key: TutorialKeys.tagebuch,
                    child: _NavItem(
                      tapKey: navDiaryKey,
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book,
                      label: 'Tagebuch',
                      isActive: currentIndex == 1,
                      onTap: () {
                        HapticService.light();
                        navigationShell.goBranch(1);
                      },
                    ),
                  ),
```

- [ ] **Step 4: Verify analyzer is clean + tests pass**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `No issues found!`; all existing tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/common/bb_bottom_nav.dart
git commit -m "feat(tutorial): attach TutorialKeys to bottom nav FAB and Tagebuch"
```

---

## Task 16: Trigger the tutorial from `DashboardScreen`

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add new imports**

Edit `lib/screens/dashboard/dashboard_screen.dart`. Add with the existing imports:

```dart
import '../../providers/tutorial_provider.dart';
import 'widgets/tutorial/show_dashboard_tutorial.dart';
```

- [ ] **Step 2: Change the post-load flow**

Replace the current `initState` method (around line 26–33) with:

```dart
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadData();
      await _maybeShowTutorial();
      if (!mounted) return;
      _maybeShowNotificationModal();
    });
  }

  Future<void> _maybeShowTutorial() async {
    if (!mounted) return;
    final shouldShow = ref.read(tutorialProvider.notifier).shouldShow();
    if (!shouldShow) return;
    await showDashboardTutorial(context);
    if (!mounted) return;
    await ref.read(tutorialProvider.notifier).markSeen();
  }
```

Note: `_maybeShowNotificationModal` stays unchanged; we just now call it *after* the tutorial promise resolves.

- [ ] **Step 3: Verify analyzer is clean + tests pass**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `No issues found!`; all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(dashboard): show tutorial overlay on first dashboard load

Runs after initial data load, before the notification opt-in modal.
Marks tutorial as seen via TutorialNotifier when the overlay closes."
```

---

## Task 17: Add "Tour neu starten" to `SettingsScreen`

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`

- [ ] **Step 1: Convert to `ConsumerWidget` and add the row**

Replace the entire contents of `lib/screens/settings/settings_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/tutorial_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_settings_item.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _restartTutorial(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tour neu starten?'),
        content: const Text(
          'Möchtest du die Einführung erneut starten? Die Tour wird beim nächsten Öffnen des Dashboards angezeigt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Neu starten'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(tutorialProvider.notifier).reset();
      if (!context.mounted) return;
      context.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Konnte die Tour nicht zurücksetzen. Bitte versuche es später erneut.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Einstellungen'),
      ),
      body: Padding(
        padding: AppConstants.paddingLg,
        child: Column(
          children: [
            BbSettingsItem(
              icon: Icons.person_outline,
              title: 'Mein Profil',
              subtitle: 'Persönliche Daten, Ernährung & Symptome',
              onTap: () => context.push(RoutePaths.settingsProfile),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Benachrichtigungen',
              subtitle: 'Push-Benachrichtigungen & Erinnerungen',
              onTap: () => context.push(RoutePaths.settingsNotifications),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.shield_outlined,
              title: 'Konto & Sicherheit',
              subtitle: 'Abmelden, Passwort ändern, Konto verwalten',
              onTap: () => context.push(RoutePaths.settingsAccount),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.feedback_outlined,
              title: 'Feedback geben',
              subtitle: 'Teile uns deine Ideen und Wünsche mit',
              onTap: () => launchUrl(
                Uri.parse(AppConstants.feedbackFormUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.replay_outlined,
              title: 'Tour neu starten',
              subtitle: 'Zeige die Einführung zum Dashboard erneut',
              onTap: () => _restartTutorial(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer is clean + tests pass**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `No issues found!`; all tests pass. If `test/screens/settings/settings_screen_test.dart` exists and breaks due to `ConsumerWidget` conversion, update its tests to use `pumpWithProviders` (the helper from `test/helpers/riverpod_helpers.dart`).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings/settings_screen.dart
git commit -m "feat(settings): add 'Tour neu starten' row to re-run dashboard tour"
```

---

## Task 18: Integration test — first-run tour + replay

**Files:**
- Create: `integration_test/tutorial_flow_test.dart`

- [ ] **Step 1: Write the integration test using the project's `buildTestApp` helper**

The project has a ready-made integration-test bootstrap in `integration_test/helpers/test_app.dart` that returns a `ProviderScope` with all repository fakes wired up, plus a `setNotificationModalShown()` helper that suppresses the notification modal via SharedPreferences. Use both. The existing default inside `buildTestApp` seeds a complete `testUserProfile()` whose `tutorialSeenAt` is `null`, which is exactly what we want for the first-run assertion.

Create `integration_test/tutorial_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-run dashboard tour + replay from settings', (tester) async {
    final profileRepo = FakeProfileRepository()
      ..seedProfile(testUserProfile()); // tutorialSeenAt defaults to null

    await tester.pumpWidget(
      buildTestApp(authenticated: true, seedProfile: false, profileRepo: profileRepo),
    );
    await tester.pumpAndSettle();

    // 1. Tour is visible
    expect(find.text('Überspringen'), findsOneWidget);

    // 2. Advance 10 times by tapping anywhere that is NOT the Überspringen link.
    // Tap well inside the screen but away from the top-right corner.
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
    }

    // 3. Tour finished
    expect(find.text('Überspringen'), findsNothing);

    // 4. Notification opt-in modal appears (title copy from
    //    lib/screens/dashboard/widgets/notification_opt_in_dialog.dart:108)
    expect(find.text('Bleib auf dem Laufenden!'), findsOneWidget);

    // 5. Dismiss notification modal by tapping its close icon.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 6. Verify the repo was written
    expect(profileRepo.lastTutorialSeenAt, isNotNull);

    // 7. Open settings → replay
    await tester.tap(find.byKey(TutorialKeys.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tour neu starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neu starten'));
    await tester.pumpAndSettle();

    // 8. Tour reappears on dashboard
    expect(find.text('Überspringen'), findsOneWidget);
    expect(profileRepo.lastTutorialSeenAt, isNull);
  });
}
```

- [ ] **Step 2: Run the integration test on a simulator**

```bash
flutter test integration_test/tutorial_flow_test.dart
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
dart format .
flutter analyze
git add integration_test/tutorial_flow_test.dart
git commit -m "test(tutorial): integration test for first-run tour + replay flow"
```

---

## Task 19: Manual smoke test

**Files:** none — manual.

- [ ] **Step 1: Apply the Supabase migration**

In the Supabase project SQL editor (or via `supabase db push` if the CLI is set up), execute the contents of `supabase/migrations/20260418120000_add_profiles_tutorial_seen_at.sql`.

- [ ] **Step 2: Launch the iOS simulator**

```bash
flutter run -d ios
```

Or Android: `flutter run -d android`.

- [ ] **Step 3: Walk the smoke flow**

- Sign in as a user whose `tutorial_seen_at` is `NULL` (either new user or a user whose column was just added).
- Confirm the dashboard loads, then the tour appears on step 1 (Bauchgefühl).
- Tap anywhere 10 times, verify each step highlights the correct element and the German copy matches the mockups.
- Verify the notification opt-in modal appears after step 10.
- Dismiss it.
- Open Settings → "Tour neu starten" → confirm.
- Verify the tour replays from step 1.
- Tap "Überspringen" halfway through. Confirm the tour closes and does not reappear on next dashboard load.

- [ ] **Step 4: No commit — done**

If issues are found, open a follow-up task rather than amending this plan.

---

## Self-review notes

This plan was self-reviewed against the spec. Coverage:

- **Database:** Task 1.
- **Model:** Task 2.
- **Repository write:** Task 3 (with TDD) + Task 4 (fake).
- **Provider:** Task 5 (with TDD — `shouldShow`, `markSeen`, `reset`, no-user no-op).
- **Data types:** Task 6 (`TutorialKeys`, `TutorialStep`).
- **Step copy:** Task 7 (all 10 steps verbatim from mockups).
- **Spotlight painter:** Task 8.
- **Tooltip bubble:** Task 9.
- **Connector line:** Task 10.
- **Overlay orchestrator:** Task 11.
- **Public entry point:** Task 12.
- **Widget tests:** Task 13 (renders, advances, finishes, skips).
- **Dashboard wiring:** Task 14.
- **Bottom nav wiring:** Task 15.
- **Orchestration (trigger + notification modal chaining):** Task 16.
- **Settings replay:** Task 17.
- **Integration test (first-run + replay):** Task 18.
- **Manual smoke:** Task 19.

No placeholders, no `TODO`s. Function names used across tasks: `shouldShow`, `markSeen`, `reset`, `updateTutorialSeenAt`, `showDashboardTutorial` — consistent across Tasks 3, 5, 11, 12, 16, 17.
