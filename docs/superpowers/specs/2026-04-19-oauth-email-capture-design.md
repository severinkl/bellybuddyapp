# OAuth Email Capture — Design Spec

**Date:** 2026-04-19
**Status:** Approved design — ready for implementation plan
**Scope:** Capture a real email address during the 7-step registration wizard for users whose OAuth sign-in (Apple or Google) did not return one, or returned an Apple `@privaterelay.appleid.com` relay.

## Motivation

Belly Buddy needs a reliable email address per user for two purposes:

1. **Deliverability** — welcome email, password reset, daily summary, push/email reminders, and the "Für dich" recommendation digest.
2. **Marketing + personal communication** — newsletters and campaigns. Apple relay addresses are technically deliverable but have weaker engagement signals, no identification stability, and can be disabled by the user at any time.

Two OAuth scenarios currently defeat this:

- **Apple "Hide My Email"** — Supabase receives `xxxxx@privaterelay.appleid.com`. Deliverable but not the user's real address.
- **Apple second sign-in** — Apple only returns `email` on the very first sign-in for a given app/Apple-ID pair. If a user deletes + reinstalls the app, Supabase sees an empty `auth.users.email`.

Google uses `signInWithIdToken` and always returns a real email claim in the ID token; no additional handling needed for Google.

## Goals

- Every new user who finishes registration has a trustworthy email on record.
- Zero added friction for users whose OAuth already returned a real address (Google, Apple-first-sign-in-without-hide) or for email+password signup.
- One new column on `profiles`; no auth-system surgery.
- No verification loop — same trust model as the existing email+password flow.

## Non-Goals

- Backfilling existing registered users who have no `profiles.email` yet. (A later PR may add a "complete your profile" banner for them.)
- Editing the captured email from Settings. (Can be added later without schema changes.)
- Email verification (send + confirm). Trust what the user types during active registration.
- Handling the returning-Apple-user-on-new-device case (empty email on second sign-in with an existing `profiles` row). Documented as a known gap; out of scope here.

## User-facing decisions

| Question | Decision |
|---|---|
| Who gets asked? | Only OAuth users whose resulting Supabase email is `null`, empty, or matches `*@privaterelay.appleid.com`. |
| Required? | Optional. Sharing a real email on this step must remain skippable — Apple's Sign in with Apple policy prohibits requiring it. The step shows a secondary "Überspringen" link next to the primary "Weiter" button; tapping it writes `profiles.email = null` and advances to the dashboard. |
| Where is it stored? | New `profiles.email` column. `auth.users.email` stays untouched (remains the OAuth result). |
| Verified? | No. Inline format validation only. |

## Detection logic

After `AuthStep` completes and Supabase has a session, the wizard inspects `supabase.auth.currentUser.email`:

```
_needsEmailCapture(user) =
     user.email == null
  || user.email.isEmpty
  || user.email.endsWith('@privaterelay.appleid.com')
```

If true, the wizard advances to a new final step `EmailCaptureStep` (index 7 in the zero-indexed `PageView`, shown as "8/8" in the progress bar). If false, it skips to `_createProfile()` → dashboard.

The email+password signup flow bypasses this entirely — `_handleEmailSignUp` already has the real email from the form and creates the profile directly, same as today.

## Wizard flow

```
Step 0: BirthYearStep
Step 1: GenderStep
Step 2: HeightWeightStep
Step 3: DietStep
Step 4: SymptomsStep
Step 5: IntolerancesStep
Step 6: AuthStep  (email+password / Google / Apple)
       |
       |-- email+password → _createProfile() → dashboard
       |-- Google → [email detected as real] → _createProfile() → dashboard
       |-- Google → [email missing, rare] → Step 7
       |-- Apple  → [email detected as real] → _createProfile() → dashboard
       |-- Apple  → [empty or relay]        → Step 7
       ↓
Step 7: EmailCaptureStep  (conditional)
       |-- valid email entered + "Weiter" → _createProfile(email: typed) → dashboard
```

`_totalSteps` becomes variable: `7` normally, `8` when the capture step is needed. The progress bar fraction reflects the current total.

### `EmailCaptureStep` — UI

- Headline: **"Deine E-Mail-Adresse"**
- Body: **"Damit wir dir Empfehlungen, Erinnerungen und die tägliche Zusammenfassung schicken können, brauchen wir deine echte E-Mail-Adresse."**
- Single `TextFormField`:
  - `keyboardType: TextInputType.emailAddress`
  - `autofillHints: [AutofillHints.email]`
  - `autocorrect: false`, `enableSuggestions: false`
  - Inline error text for invalid input
- Validation rules:
  - Non-empty
  - Matches a standard email regex
  - Does **not** end with `@privaterelay.appleid.com` (reject the relay the user might paste in)
- `BbButton` "Weiter" — `onPressed: null` until validation passes
- Secondary "Überspringen" text button below the primary "Weiter" — always enabled (disabled only while a write is in flight). Tapping it writes `profiles.email = null` and navigates to the dashboard. Required by Apple's Sign in with Apple policy.
- No "Zurück" button on this step — going back after a successful sign-in would land the user on an auth step mid-session; the back button is hidden for this final step

## Architecture

```
┌─────────────────────────────────────────────┐
│ RegistrationWizardScreen                    │
│  ├─ _currentStep, _totalSteps (dynamic)      │
│  ├─ _showEmailCapture: bool                  │
│  ├─ _capturedEmail: String?                  │
│  └─ _emailCaptureRequired(User) → bool      │
│                                             │
│ AuthStep (unchanged)                        │
│  └─ onGoogleSignUp / onAppleSignUp           │
│        ↓                                     │
│     wizard checks captureRequired            │
│        ↓                                     │
│     shows EmailCaptureStep OR finalizes     │
│                                             │
│ EmailCaptureStep (new, stateless)           │
│  ├─ value: String?                           │
│  ├─ onChanged: (String) → void               │
│  └─ onSubmit:  () → void                     │
│                                             │
│ UserProfile (freezed, +email field)         │
│                                             │
│ ProfileRepository.createProfile             │
│  └─ writes email to profiles.email           │
└─────────────────────────────────────────────┘
```

**Design consistency note:** `profiles.email` joins the regular editable fields. Unlike `tutorial_seen_at` and `fcm_token` (which are managed by specialized notifiers and stripped from `updateProfile`), `email` can ride along with future profile updates without special handling.

## Data model

### Supabase migration

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email TEXT;
```

- Nullable. Existing rows default to `NULL` — no forced backfill prompt, no data migration.
- No unique constraint. A single real email could legitimately be associated with multiple accounts (edge case; not worth the enforcement complexity).
- RLS: inherits the existing `profiles` row-level policies. No changes needed.

### `UserProfile` freezed model

Add a field to `lib/models/user_profile.dart`:

```dart
@JsonKey(name: 'email') String? email,
```

Regenerate with `dart run build_runner build --delete-conflicting-outputs`.

### Email-sending path (edge functions & services)

Any email-send path that today reads `auth.users.email` should prefer `profiles.email` when set:

```
effective_email = profiles.email IS NOT NULL ? profiles.email : auth.users.email
```

Touched call sites (read-only audit for this PR):

- `send-welcome-email` edge function
- `send-password-reset` edge function
- Any daily-summary / recommendation digest edge functions

If these already receive `email` as a parameter from the Flutter client (as `send-welcome-email` does today via `signUpWithEmail`), the client should pass `profile.email ?? authUser.email`. For server-initiated jobs (scheduled digests), the SQL they use should join `profiles` and prefer `profiles.email`.

**Scope note:** this PR only ships the schema change + the Flutter capture flow. Updating the edge functions and scheduled jobs to prefer `profiles.email` is a follow-up, because those functions live in a separate repo/deployment and have their own review cycle. Until they're updated, new users with a captured `profiles.email` will still receive email at their Apple relay — degraded but not broken.

## Wizard state changes

In `_RegistrationWizardScreenState`:

```dart
// new fields
bool _showEmailCapture = false;
String? _capturedEmail;

// _totalSteps becomes a getter:
int get _totalSteps => _showEmailCapture ? 8 : 7;

// after a successful Google/Apple sign-in:
final user = Supabase.instance.client.auth.currentUser;
if (_needsEmailCapture(user)) {
  setState(() => _showEmailCapture = true);
  _goToStep(7);
} else {
  await _createProfile();
  if (mounted) context.go(RoutePaths.dashboard);
}

// helper
bool _needsEmailCapture(User? user) {
  final email = user?.email;
  if (email == null || email.isEmpty) return true;
  return email.endsWith('@privaterelay.appleid.com');
}

// _createProfile now sets email:
final profile = UserProfile(
  ...,
  email: _capturedEmail ?? Supabase.instance.client.auth.currentUser?.email,
);
```

## Error handling

- **Invalid email format** — inline error; "Weiter" stays disabled. No SnackBar.
- **`profiles` insert fails** — existing `createProfile` error path (SnackBar on the wizard). User stays on step 7 and can retry.
- **User kills the app between auth success and profile creation** — existing behavior: Supabase has a session, `profiles` has no row, the auth router detects `hasProfile == false` and reroutes back into the wizard on next launch. The email capture step will be shown again because the same detection runs. Slightly annoying for the user (they must type their email again) but correct and idempotent.
- **User types a real email that happens to differ from a later Apple sign-in** — no conflict possible. The profile email is independent of `auth.users.email`.

## Testing strategy

### Unit / logic

- `_needsEmailCapture` is currently a private widget helper. Keep it private; widget tests cover the behavior.

### Widget tests

**`test/screens/registration/email_capture_step_test.dart` (new):**
- Empty input → "Weiter" button disabled.
- Invalid format (no `@`) → disabled + inline error.
- Relay address (`x@privaterelay.appleid.com`) → disabled + inline error.
- Valid address → enabled; tapping "Weiter" fires the submit callback with the typed value.

**`test/screens/registration/registration_wizard_screen_test.dart` (extend):**
- Seed `FakeAuthRepository` so `signInWithGoogle` returns a user with `email: 'real@example.com'` → verify step 7 is NOT shown; dashboard route is pushed.
- Seed so `signInWithApple` returns a user with `email: 'abc@privaterelay.appleid.com'` → verify step 7 IS shown with the email input.
- Seed so `signInWithApple` returns a user with `email: null` → verify step 7 IS shown.

### Integration tests

**Extend `integration_test/registration_flow_test.dart`:**
- New case: Apple sign-up with `Hide My Email` → complete wizard → type `user@example.com` on step 7 → dashboard reached → inspect `FakeProfileRepository.lastCreatedProfile.email == 'user@example.com'`.

`FakeProfileRepository` already tracks its last write via `seedProfile`/`createProfile` mutations — no extension needed.

`FakeAuthRepository` currently returns a hardcoded user ID; extend it with an optional `signInEmail` parameter so integration tests can seed the relay-email scenario.

## File inventory

**New:**
- `supabase/migrations/<timestamp>_add_profiles_email.sql`
- `lib/screens/registration/steps/email_capture_step.dart`
- `test/screens/registration/email_capture_step_test.dart`

**Modified:**
- `lib/models/user_profile.dart` (+ regenerated `.freezed.dart` / `.g.dart`)
- `lib/screens/registration/registration_wizard_screen.dart` (dynamic `_totalSteps`, detection, branching, email wiring in `_createProfile`)
- `test/screens/registration/registration_wizard_screen_test.dart` (three new cases)
- `integration_test/registration_flow_test.dart` (one new case)
- `test/helpers/fakes.dart` (optional `signInEmail` param on `FakeAuthRepository`)

**Untouched** — explicitly:
- `lib/repositories/profile_repository.dart` — no strip, no new method; `createProfile` already writes whatever freezed includes in `toJson()`.
- `lib/services/auth_service.dart` — unchanged. Email capture is a wizard concern, not an auth-layer concern.

## Rollout

- Apply the Supabase migration before shipping the client build.
- No feature flag. Existing users are unaffected (nullable column, detection only runs during fresh registration).
- Edge-function updates to prefer `profiles.email` land in a follow-up PR.

## Open questions

None.
