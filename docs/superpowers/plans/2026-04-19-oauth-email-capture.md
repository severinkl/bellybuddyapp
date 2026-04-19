# OAuth Email Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prompt users for a real email during registration when OAuth sign-in returned nothing (Apple second-sign-in) or an Apple relay address (Hide My Email), storing the result in a new nullable `profiles.email` column.

**Architecture:** A new `EmailCaptureStep` (StatelessWidget) is appended to the existing 7-step wizard as a conditional 8th step. After Google/Apple sign-in succeeds, `_RegistrationWizardScreenState` inspects `supabase.auth.currentUser.email` — if null/empty/`@privaterelay.appleid.com`, it shows the new step before calling `_createProfile()` with the captured email. Email+password signups bypass entirely (they already have a real address from the form).

**Tech Stack:** Flutter, Dart, Freezed + json_serializable, Supabase (`supabase_flutter`), Riverpod, `flutter_test` + `mocktail`, `integration_test`.

**Spec:** `docs/superpowers/specs/2026-04-19-oauth-email-capture-design.md`

---

## File Structure

**New files:**
- `supabase/migrations/20260419120000_add_profiles_email.sql` — DB migration (nullable TEXT column).
- `lib/screens/registration/steps/email_capture_step.dart` — stateful widget: headline, body, `TextFormField`, validation, "Weiter" button.
- `test/screens/registration/email_capture_step_test.dart` — widget tests.

**Modified files:**
- `lib/models/user_profile.dart` — add `@JsonKey(name: 'email') String? email` freezed field.
- `lib/screens/registration/registration_wizard_screen.dart` — dynamic `_totalSteps`, `_showEmailCapture` flag, `_capturedEmail`, `_needsEmailCapture(User?)` helper, branching after OAuth sign-in, wire email into `_createProfile()`.
- `test/helpers/fakes.dart` — optional `signInEmail` ctor param on `FakeAuthRepository` that flows into built `User.email`.
- `test/screens/registration/registration_wizard_screen_test.dart` — three new detection-branch test cases.
- `integration_test/registration_flow_test.dart` — one new case: Apple Hide-My-Email end-to-end.

**Untouched (deliberate):**
- `lib/repositories/profile_repository.dart` — `createProfile` already serializes all freezed fields through `toJson`; no strip/merge changes needed.
- `lib/services/auth_service.dart` — email capture is a wizard concern, not an auth-layer concern.
- Edge functions — preferring `profiles.email` is a follow-up PR (out of scope; documented in the spec).

---

## Conventions

- **TDD:** every production-code task starts with a failing test, runs it to confirm failure, then implements, then re-runs.
- **Commit cadence:** one commit per numbered task unless the plan says otherwise. Use `feat:` / `fix:` / `test:` / `docs:` prefixes matching existing repo style.
- **Quality gates:** `dart format .` + `flutter analyze` must pass before every commit (pre-commit hook enforces this).
- **Model changes:** after editing a freezed source file, run `dart run build_runner build --delete-conflicting-outputs`. Regenerated `*.freezed.dart` / `*.g.dart` are gitignored — do not commit them.

---

## Task 1: Supabase migration for `profiles.email`

**Files:**
- Create: `supabase/migrations/20260419120000_add_profiles_email.sql`

- [ ] **Step 1: Write the SQL migration**

Create `supabase/migrations/20260419120000_add_profiles_email.sql`:

```sql
-- Add nullable email column for OAuth email capture. Populated during
-- registration when Apple's "Hide My Email" or a missing-email sign-in
-- means supabase.auth.users.email isn't a usable real address.
-- NULL means "no captured email — use auth.users.email as fallback".
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email TEXT;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260419120000_add_profiles_email.sql
git commit -m "feat(db): add profiles.email column for OAuth email capture

Nullable TEXT column populated by the registration wizard when OAuth
returned no email or an Apple relay address. Apply via Supabase dashboard
SQL editor or \`supabase db push\` before shipping the client build that
depends on it."
```

---

## Task 2: Add `email` field to `UserProfile` model

**Files:**
- Modify: `lib/models/user_profile.dart`

- [ ] **Step 1: Add the field**

Edit `lib/models/user_profile.dart`. Inside the `@freezed abstract class UserProfile`'s parameter list, add this line immediately below `@JsonKey(name: 'tutorial_seen_at') DateTime? tutorialSeenAt,`:

```dart
    @JsonKey(name: 'email') String? email,
```

The tail of the factory constructor should now read:

```dart
    @JsonKey(name: 'last_inactivity_nudge') DateTime? lastInactivityNudge,
    @JsonKey(name: 'tutorial_seen_at') DateTime? tutorialSeenAt,
    @JsonKey(name: 'email') String? email,
  }) = _UserProfile;
```

- [ ] **Step 2: Regenerate freezed artefacts**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: completes with no errors; the generated `user_profile.freezed.dart` and `user_profile.g.dart` are rewritten.

- [ ] **Step 3: Verify analyzer is clean**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/models/user_profile.dart
git commit -m "feat(model): add email field to UserProfile

Nullable String mapped to profiles.email. Populated by the registration
wizard when OAuth didn't return a usable real address."
```

---

## Task 3: Extend `FakeAuthRepository` with a seedable sign-in email

**Files:**
- Modify: `test/helpers/fakes.dart`

- [ ] **Step 1: Add the `signInEmail` param and thread it through**

Edit `test/helpers/fakes.dart`. Find the `FakeAuthRepository` class (around line 27). Replace the constructor block and the `_buildUserJson` helper with:

```dart
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.signedIn = true,
    this.onSignedIn,
    this.onSignedOut,
    this.shouldFailEmailSignIn = false,
    this.signInErrorMessage = 'Login failed',
    this.signInEmail,
  }) {
    if (signedIn) {
      _currentUser = _buildUser();
      _currentSession = _buildSession();
    }
  }

  bool signedIn;
  void Function(User user)? onSignedIn;
  VoidCallback? onSignedOut;
  bool shouldFailEmailSignIn;
  String signInErrorMessage;

  /// Email the built Supabase [User] reports. Omit / pass null to simulate
  /// Apple second-sign-in (no email). Pass a real address to simulate
  /// Google. Pass an `@privaterelay.appleid.com` address to simulate
  /// Apple's Hide My Email.
  final String? signInEmail;

  final _authStateController = StreamController<AuthState>.broadcast();

  User? _currentUser;
  Session? _currentSession;

  Map<String, dynamic> _buildUserJson() => {
    'id': testUserId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': DateTime.now().toIso8601String(),
    if (signInEmail != null) 'email': signInEmail,
  };
```

(Leave the rest of the class unchanged.)

- [ ] **Step 2: Run the full test suite to confirm no regressions**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`; all pre-existing tests still pass. The new optional parameter has a null default so every existing call site is unaffected.

- [ ] **Step 3: Commit**

```bash
git add test/helpers/fakes.dart
git commit -m "test(helpers): allow FakeAuthRepository to seed a sign-in email

Adds an optional signInEmail constructor param that flows into the
built Supabase User's email field. Enables tests to simulate the three
OAuth outcomes: real email, Apple relay, and empty."
```

---

## Task 4: Write `EmailCaptureStep` widget (TDD)

**Files:**
- Create: `test/screens/registration/email_capture_step_test.dart`
- Create: `lib/screens/registration/steps/email_capture_step.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `test/screens/registration/email_capture_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('EmailCaptureStep', () {
    Future<void> pumpStep(
      WidgetTester tester, {
      required void Function(String) onChanged,
      required VoidCallback onSubmit,
      String? initialValue,
    }) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: EmailCaptureStep(
            value: initialValue,
            onChanged: onChanged,
            onSubmit: onSubmit,
          ),
        ),
      );
    }

    testWidgets('shows headline and body copy', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      expect(find.text('Deine E-Mail-Adresse'), findsOneWidget);
      expect(
        find.textContaining('wir dir Empfehlungen, Erinnerungen'),
        findsOneWidget,
      );
    });

    testWidgets('Weiter button disabled when input is empty', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Weiter button disabled for invalid format', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Weiter button disabled for privaterelay.appleid.com', (
      tester,
    ) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      await tester.enterText(
        find.byType(TextFormField),
        'abc@privaterelay.appleid.com',
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('onChanged fires with the typed value', (tester) async {
      String? captured;
      await pumpStep(
        tester,
        onChanged: (v) => captured = v,
        onSubmit: () {},
      );

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.pump();

      expect(captured, equals('user@example.com'));
    });

    testWidgets('Weiter button enabled for valid email; tap fires onSubmit', (
      tester,
    ) async {
      var submitted = false;
      await pumpStep(
        tester,
        onChanged: (_) {},
        onSubmit: () => submitted = true,
      );

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/screens/registration/email_capture_step_test.dart
```

Expected: compile error — `email_capture_step.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/screens/registration/steps/email_capture_step.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// Wizard step that asks the user for a real email when OAuth didn't give
/// us one (Apple second-sign-in) or gave us an Apple relay address. Pure
/// presentation: the parent wizard owns the captured value and the submit
/// behavior.
class EmailCaptureStep extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  static const emailFieldKey = Key('email_capture_email_field');
  static const submitButtonKey = Key('email_capture_submit_button');

  const EmailCaptureStep({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  State<EmailCaptureStep> createState() => _EmailCaptureStepState();
}

class _EmailCaptureStepState extends State<EmailCaptureStep> {
  late final TextEditingController _controller;
  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final text = _controller.text.trim();
    if (text.isEmpty) return false;
    if (!_emailRegex.hasMatch(text)) return false;
    if (text.endsWith('@privaterelay.appleid.com')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppConstants.gap24,
          const Text(
            'Deine E-Mail-Adresse',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeading,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap16,
          const Text(
            'Damit wir dir Empfehlungen, Erinnerungen und die tägliche '
            'Zusammenfassung schicken können, brauchen wir deine echte '
            'E-Mail-Adresse.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap24,
          TextFormField(
            key: EmailCaptureStep.emailFieldKey,
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'E-Mail-Adresse',
              hintText: 'du@beispiel.de',
            ),
            onChanged: (v) {
              widget.onChanged(v.trim());
              setState(() {}); // rebuild so button enabled state updates
            },
            onFieldSubmitted: (_) {
              if (_isValid) widget.onSubmit();
            },
          ),
          const Spacer(),
          ElevatedButton(
            key: EmailCaptureStep.submitButtonKey,
            onPressed: _isValid ? widget.onSubmit : null,
            child: const Text('Weiter'),
          ),
          AppConstants.gap16,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests — confirm pass**

```bash
flutter test test/screens/registration/email_capture_step_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/screens/registration/steps/email_capture_step.dart test/screens/registration/email_capture_step_test.dart
git commit -m "feat(registration): add EmailCaptureStep widget

Standalone wizard step that collects an email with inline validation:
non-empty, valid format, and not an Apple privaterelay.appleid.com
address. Submit button is disabled until all three pass."
```

---

## Task 5: Wire the step into the registration wizard

**Files:**
- Modify: `lib/screens/registration/registration_wizard_screen.dart`

- [ ] **Step 1: Add imports and state**

Edit `lib/screens/registration/registration_wizard_screen.dart`. Add to the imports block (below the existing `import 'steps/auth_step.dart';`):

```dart
import 'steps/email_capture_step.dart';
```

In `_RegistrationWizardScreenState`, replace the `static const _totalSteps = 7;` line with:

```dart
  // Dynamic: the 8th step is only present for OAuth sign-ins that didn't
  // return a usable real email (Apple Hide-My-Email or empty).
  int get _totalSteps => _showEmailCapture ? 8 : 7;

  bool _showEmailCapture = false;
  String? _capturedEmail;
```

Add this helper method (place it near `_createProfile` to keep related logic together):

```dart
  bool _needsEmailCapture(User? user) {
    final email = user?.email;
    if (email == null || email.isEmpty) return true;
    return email.endsWith('@privaterelay.appleid.com');
  }
```

- [ ] **Step 2: Update `_createProfile` to include the email**

Replace the existing `_createProfile` body with:

```dart
  Future<void> _createProfile() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    final profile = UserProfile(
      birthYear: _birthYear,
      gender: _gender,
      height: _height,
      weight: _weight,
      diet: _diet,
      symptoms: _symptoms,
      intolerances: _intolerances,
      fructoseTriggers: _triggers['Fruktose'] ?? [],
      lactoseTriggers: _triggers['Laktose'] ?? [],
      histaminTriggers: _triggers['Histamin'] ?? [],
      email: _capturedEmail ?? authUser?.email,
    );
    await ref.read(profileProvider.notifier).createProfile(profile);
  }
```

- [ ] **Step 3: Branch after OAuth sign-in**

Replace the bodies of `_handleGoogleSignUp` and `_handleAppleSignUp` with:

```dart
  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      await _finalizeAfterOAuthSignIn();
    } catch (e) {
      _log.error('google sign-up failed', e);
      if (mounted) {
        setState(() => _authError = 'Google-Anmeldung fehlgeschlagen.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleAppleSignUp() async {
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithApple();
      await _finalizeAfterOAuthSignIn();
    } catch (e) {
      _log.error('apple sign-up failed', e);
      if (mounted) {
        setState(() => _authError = 'Apple-Anmeldung fehlgeschlagen.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finalizeAfterOAuthSignIn() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (_needsEmailCapture(user)) {
      setState(() => _showEmailCapture = true);
      _goToStep(7);
      return;
    }
    await _createProfile();
    if (mounted) context.go(RoutePaths.dashboard);
  }
```

- [ ] **Step 4: Handle the email step's submit**

Add a new handler near `_handleAppleSignUp`:

```dart
  Future<void> _handleEmailCaptureSubmit() async {
    if (_capturedEmail == null || _capturedEmail!.isEmpty) return;
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await _createProfile();
      if (mounted) context.go(RoutePaths.dashboard);
    } catch (e) {
      _log.error('profile create after email capture failed', e);
      if (mounted) {
        setState(
          () => _authError = 'Speichern fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
```

- [ ] **Step 5: Add the step to the PageView children**

In the `build` method's `PageView`, add a new child AFTER the existing `AuthStep(...)` child — inside the `children: [...]` list, right before the closing `],`:

```dart
                  if (_showEmailCapture)
                    EmailCaptureStep(
                      value: _capturedEmail,
                      onChanged: (v) => setState(() => _capturedEmail = v),
                      onSubmit: _handleEmailCaptureSubmit,
                    ),
```

- [ ] **Step 6: Hide the "Weiter" and "Zurück" buttons on the email step**

The email step owns its own submit button and must not allow going back into a post-sign-in auth state.

Replace the two conditional button blocks at the bottom of `build`. Find:

```dart
            // Next button (not on last step)
            if (_currentStep < _totalSteps - 1)
              Padding( ... BbButton ... ),
            // Back button (all steps)
            Padding(
              padding: const EdgeInsets.fromLTRB(...),
              child: TextButton.icon(...),
            ),
```

Change the conditions so:
- The "Weiter" button shows only for steps 0–5 (index < 6) — i.e. not on `AuthStep` (existing behaviour) and not on `EmailCaptureStep` (new).
- The "Zurück" button shows only for steps 0–6 (index < 7) — i.e. not on `EmailCaptureStep`.

Specifically, replace the two Padding blocks with:

```dart
            // Next button — only shown on pre-auth pages (not AuthStep, not EmailCaptureStep)
            if (_currentStep < 6)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg,
                ),
                child: BbButton(
                  tapKey: RegistrationWizardScreen.nextButtonKey,
                  label: 'Weiter',
                  icon: Icons.arrow_forward,
                  onPressed: _canAdvance ? _next : null,
                ),
              ),
            // Back button — shown everywhere except on EmailCaptureStep
            if (_currentStep < 7)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingLg,
                  AppConstants.spacingSm,
                  AppConstants.spacingLg,
                  AppConstants.spacingLg,
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: _currentStep == 0
                      ? const Text('Zur Anmeldung')
                      : const Text('Zurück'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.mutedForeground,
                  ),
                  onPressed: () {
                    HapticService.light();
                    FocusManager.instance.primaryFocus?.unfocus();

                    if (_currentStep == 0) {
                      context.go(RoutePaths.auth);
                    } else {
                      _back();
                    }
                  },
                ),
              ),
```

- [ ] **Step 7: Verify analyzer is clean and existing tests still pass**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `No issues found!`; all existing tests pass. (The wizard widget test may need to catch up in Task 6; if only that file fails here, proceed to Task 6 and re-run at the end.)

- [ ] **Step 8: Commit**

```bash
git add lib/screens/registration/registration_wizard_screen.dart
git commit -m "feat(registration): branch into EmailCaptureStep after OAuth sign-in

Inspects supabase.auth.currentUser.email after Google/Apple sign-in; if
null/empty/@privaterelay.appleid.com, advances to the new email capture
step before creating the profile. Email+password signup unaffected — it
already has the real address from the form. The captured email is wired
into UserProfile.email via _createProfile."
```

---

## Task 6: Widget tests for the wizard's detection branch

**Files:**
- Modify: `test/screens/registration/registration_wizard_screen_test.dart`

- [ ] **Step 1: Read the existing test file to understand the pattern**

```bash
flutter test test/screens/registration/registration_wizard_screen_test.dart --list 2>&1 | head -20
```

(The goal is to confirm the file exists and see which tests are there. Do not modify unrelated tests.)

- [ ] **Step 2: Append three new tests**

Open `test/screens/registration/registration_wizard_screen_test.dart` and add the following group INSIDE the existing `void main()` block, after the last `group(...)`. (If the file is small and tests are at the top level instead of in a group, add the three tests at the end of `main()`.)

Imports needed at the top of the file — add if missing:

```dart
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/screens/registration/steps/auth_step.dart';
import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';
```

Tests to append:

```dart
  group('OAuth email capture branch', () {
    Future<void> pumpWizard(
      WidgetTester tester, {
      required FakeAuthRepository authRepo,
      required FakeProfileRepository profileRepo,
    }) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
      );
      await tester.pumpAndSettle();
    }

    Future<void> advanceToAuthStep(WidgetTester tester) async {
      // 6 "Weiter" presses: BirthYear → Gender → HeightWeight → Diet →
      // Symptoms → Intolerances → AuthStep.
      for (var i = 0; i < 6; i++) {
        // Gender (index 1) and Diet (index 3) are mandatory — pick first
        // chip where applicable. The minimal test path picks whatever
        // the existing wizard offers as default; if _canAdvance blocks,
        // this test helper would need to select values. For the three
        // detection-branch tests below we only care about behaviour after
        // AuthStep, so the caller seeds those selections directly via
        // the wizard's public step API if needed.
        await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
      'Google sign-in with a real email skips the email capture step',
      (tester) async {
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: 'real@example.com',
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(
          tester,
          authRepo: authRepo,
          profileRepo: profileRepo,
        );
        await advanceToAuthStep(tester);

        // Tap Google sign-up button (assumes AuthStep exposes a recognisable
        // button; BbSocialButton with Google text works).
        await tester.tap(find.widgetWithText(InkWell, 'Mit Google anmelden'));
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsNothing);
      },
    );

    testWidgets(
      'Apple sign-in with Hide My Email shows the email capture step',
      (tester) async {
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: 'abc@privaterelay.appleid.com',
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(
          tester,
          authRepo: authRepo,
          profileRepo: profileRepo,
        );
        await advanceToAuthStep(tester);

        await tester.tap(find.widgetWithText(InkWell, 'Mit Apple anmelden'));
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsOneWidget);
      },
    );

    testWidgets(
      'Apple sign-in with empty email shows the email capture step',
      (tester) async {
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: null,
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(
          tester,
          authRepo: authRepo,
          profileRepo: profileRepo,
        );
        await advanceToAuthStep(tester);

        await tester.tap(find.widgetWithText(InkWell, 'Mit Apple anmelden'));
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsOneWidget);
      },
    );
  });
```

**If the social-button widget finders don't match** (the tests fail with "no widgets found for Mit Google anmelden" or similar), open `lib/widgets/common/bb_social_button.dart` to find the exact button label; swap the finder accordingly. Common alternatives: `find.byKey(...)`, `find.textContaining('Google')`, `find.ancestor(of: find.text('Google'), matching: find.byType(...))`.

- [ ] **Step 3: Run the tests**

```bash
flutter test test/screens/registration/registration_wizard_screen_test.dart
```

Expected: all tests (including the three new ones) pass. If `advanceToAuthStep` hits a gated step (Gender or Diet required), extend the helper to tap the first chip; document any such extension inline in the test file.

- [ ] **Step 4: Commit**

```bash
dart format .
flutter analyze
git add test/screens/registration/registration_wizard_screen_test.dart
git commit -m "test(registration): cover OAuth email-capture detection branch

Three cases seed FakeAuthRepository with (a) a real Google email,
(b) an Apple privaterelay address, and (c) an empty email. Verifies
that (a) skips EmailCaptureStep while (b) and (c) show it."
```

---

## Task 7: Integration test — end-to-end Apple Hide-My-Email

**Files:**
- Modify: `integration_test/registration_flow_test.dart`

- [ ] **Step 1: Read the existing integration test for its bootstrap pattern**

```bash
head -80 integration_test/registration_flow_test.dart
```

Note the existing `setUp`, `buildTestApp` call, and the selectors used for advancing the wizard. The new case will mirror whatever structure already exists there.

- [ ] **Step 2: Add the new test**

Append to `integration_test/registration_flow_test.dart` inside the existing `void main()` block (after the last existing `testWidgets`):

```dart
  testWidgets(
    'Apple sign-up with Hide My Email captures a real email into the profile',
    (tester) async {
      final profileRepo = FakeProfileRepository();
      final authRepo = FakeAuthRepository(
        signedIn: false,
        signInEmail: 'abc@privaterelay.appleid.com',
      );

      await tester.pumpWidget(
        buildTestApp(
          authenticated: false,
          dynamicAuth: true,
          seedProfile: false,
          profileRepo: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Start registration. Selectors match the existing registration_flow_test
      // happy-path test — adjust if the helper keys differ in your file.
      await tester.tap(find.byKey(WelcomeScreen.registrationButtonKey));
      await tester.pumpAndSettle();

      // Advance through the 7 wizard steps until AuthStep. Use the same
      // helper you already use in this file; if the file-level helper is
      // named differently, rename this call to match.
      await advanceToAuthStepInRegistration(tester);

      // Tap Apple sign-up.
      await tester.tap(find.widgetWithText(InkWell, 'Mit Apple anmelden'));
      await tester.pumpAndSettle();

      // Email capture step is showing.
      expect(find.byType(EmailCaptureStep), findsOneWidget);

      // Type a real email and submit.
      await tester.enterText(
        find.byKey(EmailCaptureStep.emailFieldKey),
        'user@example.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(EmailCaptureStep.submitButtonKey));
      await tester.pumpAndSettle();

      // Dashboard reached.
      expect(find.byKey(BbBottomNav.navHomeKey), findsOneWidget);

      // Profile was written with the captured email.
      expect(profileRepo.lastWrittenEmail, equals('user@example.com'));
    },
  );
```

Add the imports needed at the top of the file (if missing):

```dart
import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';
```

**Note on `profileRepo.lastWrittenEmail`:** `FakeProfileRepository` already stores the last profile via its `createProfile` override (`_profile = profile.copyWith(userId: userId)`), so the test can read it via a new tiny getter. If `FakeProfileRepository` doesn't already expose the last written profile, add this two-liner to `test/helpers/fakes.dart` in the same file edited in Task 3:

```dart
  /// Email on the most recently created/updated profile, for test assertions.
  String? get lastWrittenEmail => _profile?.email;
```

If the file-level helper `advanceToAuthStepInRegistration` does not exist in `integration_test/registration_flow_test.dart`, factor the step-advancing code out of the existing happy-path test into a top-level helper function so both tests can share it — that refactor is part of this task.

- [ ] **Step 3: Run the integration test**

```bash
flutter test integration_test/registration_flow_test.dart
```

Expected: all tests (including the new case) pass. If you don't have a simulator handy, running `flutter test` on the file alone will exercise the non-native code path using the standard test binding — still useful as a smoke check even if the full device run is deferred.

- [ ] **Step 4: Commit**

```bash
dart format .
flutter analyze
git add integration_test/registration_flow_test.dart test/helpers/fakes.dart
git commit -m "test(registration): end-to-end Apple Hide-My-Email capture

Drives the full wizard with an Apple relay sign-in, types a real email on
the new step, and asserts the created profile carries that email."
```

---

## Task 8: Manual smoke on device

**Files:** none — manual.

- [ ] **Step 1: Apply the Supabase migration**

In the Supabase SQL editor (or via `supabase db push`) run the contents of `supabase/migrations/20260419120000_add_profiles_email.sql`.

- [ ] **Step 2: Run the app**

```bash
flutter run -d ios
```

(Or `-d android`.)

- [ ] **Step 3: Walk the three flows**

Using a fresh install each time (or delete the Supabase profile row between runs):

1. **Google sign-up** → wizard should finish on AuthStep → dashboard. No step-8 shown.
2. **Apple sign-up + share email** → same as Google: no step-8.
3. **Apple sign-up + Hide My Email** → step-8 appears. Type `you@example.com`, tap "Weiter". Dashboard loads. In Supabase dashboard, verify the new `profiles` row has `email = 'you@example.com'`.

- [ ] **Step 4: Done — no commit**

If issues surface, open a follow-up task; do not amend this plan.

---

## Self-review

Checked against `docs/superpowers/specs/2026-04-19-oauth-email-capture-design.md`:

- **Migration** → Task 1.
- **UserProfile.email field** → Task 2.
- **Detection logic** (`null | empty | @privaterelay.appleid.com`) → encoded both in Task 5's `_needsEmailCapture` helper and in Task 4's client-side `_isValid` regex.
- **EmailCaptureStep UI** (headline, body, field, validation, no skip, no back) → Task 4 implementation + Task 5's button-visibility conditions.
- **Wizard branching** (Google/Apple → check → step-or-finalize, email+password unchanged) → Task 5.
- **`_createProfile` writes email** → Task 5 Step 2.
- **Dynamic `_totalSteps`** → Task 5 Step 1.
- **Widget tests** (3 branches) → Task 6.
- **Integration test** (Apple relay end-to-end) → Task 7.
- **Manual smoke** → Task 8.
- **No edge-function changes** → explicitly out of scope; documented in spec and preserved in this plan.

No placeholders. Function names consistent (`_needsEmailCapture`, `_finalizeAfterOAuthSignIn`, `_handleEmailCaptureSubmit`, `EmailCaptureStep`, `lastWrittenEmail`). Types align: `UserProfile.email` is `String?` throughout.
