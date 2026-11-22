# Buddy Onboarding (Part 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Buddy-hosted onboarding: animated intro story instead of the welcome carousel, a naming step, the registration wizard re-hosted with Buddy reactions to every answer, a post-auth sequence (streak goal → reminder ask → first meal → gift), and a 30-second „Lerne deinen Buddy kennen" for existing users.

**Architecture:** `WelcomeScreen` becomes the intro story. The wizard (`registration_wizard_screen.dart`) gains a `BuddyNameStep` at index 0 and hosts every step under a shared `BuddyController` that reacts from a const reaction catalog. After auth it persists the name and navigates to a new `/buddy-onboarding` route (`BuddyOnboardingScreen`), whose step list depends on the entry point. A router gate sends logged-in users without a completed Buddy onboarding there (existing users).

**Tech Stack:** Flutter, Riverpod 3, GoRouter 18.

**Spec:** `docs/superpowers/specs/2026-11-22-animated-buddy-design.md` (§7). Depends on Plans 1 and 2 (`buddyProvider`, `StreakGoalPicker`, `BuddyStage`, `BuddyController`, `reactionFor`, `buddyEventsProvider`).

## Global Constraints

- Same worktree/branch/rules as Plans 1–2 (design tokens, `material_ui`, German "du", `AppLogger`, format/analyze clean, tests in CI dirs).
- The health-consent legal text, checkbox and `_healthConsentAt` / `privacyPolicyVersion` handling from PR #78 must stay functionally identical; only its position moves to index 1 and a quiet Buddy line is added above it.
- Existing keys used by tests/integration tests must keep working: `RegistrationWizardScreen.nextButtonKey`, `WelcomeScreen.registrationButtonKey` (now the „Los geht's" button), `WelcomeScreen.signInButtonKey` („Ich habe schon ein Konto"), step title keys. Update `test/helpers/registration_driver.dart` (`advanceToAuthStep`, `acceptRegistrationHealthConsent`) for the new step 0, and `integration_test/registration_flow_test.dart` + `integration_test/tutorial_flow_test.dart` accordingly.
- Router gate order: upgrade gate → auth → health-consent gate → **Buddy onboarding gate** → existing rules.

## Review Focus

1. **App killed mid-onboarding** (after auth, before gift): next launch must land in `/buddy-onboarding` (gate) without repeating auth/profile and without granting the gift twice. Test in Task 5.
2. **User leaves the first-meal step via back/„Später"** or the meal tracker fails to save: onboarding continues, nothing stuck, gift still granted once. Test in Task 4.
3. **Reduced motion through the whole flow**: intro, reactions and gift still readable (bubbles), no animation-dependent waits that never complete. Test in Task 2 and Task 4.
4. **Apple relay / email-capture path** (`_showEmailCapture`): name persisted and navigation to `/buddy-onboarding` happens after the email-capture submit/skip too, not only after email/Google. Test in Task 3.
5. **Existing user who already enabled reminders** (`profile.pushEnabled == true`): the reminder step is skipped; the dashboard opt-in dialog never appears after onboarding (`keyNotificationModalShown` set). Test in Task 5.

---

### Task 1: Reaction catalog

**Files:**
- Create: `lib/config/buddy_reactions.dart`
- Test: `test/config/buddy_reactions_test.dart` → place at `test/utils/buddy_reactions_test.dart` (CI does not run `test/config/`)

**Interfaces:**
- Produces:
  ```dart
  class BuddyLine { const BuddyLine({this.mood, this.action, required this.lines}); final BuddyMood? mood; final BuddyAction? action; final List<String> lines; String pick(Random rnd); }
  const Map<String, BuddyLine> kWizardReactions; // keys below
  BuddyLine? wizardReaction(String key);
  String wizardKey(String step, [String? value]); // e.g. wizardKey('gender', 'weiblich') == 'gender:weiblich'
  ```
- Keys (every one must exist): `name:confirmed`, `consent:intro`, `birthYear:any`, `gender:weiblich|männlich|andere`, `heightWeight:any`, `diet:alles|vegetarisch|vegan`, `symptom:<each of the 5 registration symptom labels>` + `symptom:none`, `intolerance:<each AppConstants.intoleranceOptions>` + `intolerance:none`, `auth:intro`, `step:<birthYear|gender|heightWeight|diet|symptoms|intolerances>` (question intro line shown when the step appears). Lines: 1–3 German variants, ≤ 70 chars, may use `{name}`. Examples: `symptom:Unangenehme Blähungen` → `empathetic`, „Oh, das kenn ich nur zu gut!"; `diet:vegan` → `inLove`, „Ui, ganz viel Grünzeug für mich!"; `intolerance:Laktose` → action `think`, „Notiert! Darauf passen wir zusammen auf."; `birthYear:any` → action `nodYes`, „Perfekt, danke!"; `consent:intro` → mood `happy`, „Bevor du mir von deinem Bauch erzählst, brauch ich kurz dein OK."; `auth:intro` → „Damit ich mir alles merken kann, brauchst du ein Konto.".
- The symptom labels come from `lib/screens/registration/steps/symptoms_step.dart`'s private `_options`: make that list public as `const List<String> kRegistrationSymptoms` in that file and reuse it in the test.

- [ ] **Step 1: Failing test:** every key listed above exists (iterate `kRegistrationSymptoms`, `AppConstants.intoleranceOptions`, gender/diet values); every line non-empty, ≤ 70 chars, no `TODO`; `pick` is deterministic for a seeded `Random`.
- [ ] **Step 2–4:** FAIL → implement → PASS. **Step 5: Commit** `feat(buddy): wizard reaction catalog`

### Task 2: Intro story replaces the welcome carousel

**Files:**
- Modify (rewrite body, keep class + keys): `lib/screens/welcome/welcome_screen.dart`
- Test: `test/screens/welcome/welcome_screen_test.dart` (rewrite)

**Interfaces:**
- Produces: `WelcomeScreen` (`ConsumerStatefulWidget` now) with a `BuddyController(mood: sleepy)` and phases: `asleep` → (tap anywhere on the Buddy area or the hint) `waking` (`play(wakeUp)`, then `wave`) → bubbles 1..3, advanced by tap or automatically after 2.5 s each: „Hi! Ich bin dein Bauch-Buddy.", „Ich helfe dir herauszufinden, was deinem Bauch guttut.", „Lass uns uns kennenlernen!" → then the `BbButton` „Los geht's" (`key: registrationButtonKey`) appears → `context.go(RoutePaths.registration)`. Always visible at the bottom: `TextButton` „Ich habe schon ein Konto" (`key: signInButtonKey`) → `context.go(RoutePaths.auth)`. Asleep hint text: „Tippe, um ihn zu wecken". Static `phaseKey`s for tests: `WelcomeScreen.buddyAreaKey`, `WelcomeScreen.hintKey`.
- Reduced motion: waking skips straight to bubble 1; auto-advance stays (it's text pacing, not motion).
- Remove the 5 s carousel timer and `SmoothPageIndicator` usage from this screen (leave the package; other screens may use it — check with grep, remove the dependency only if unused anywhere).

- [ ] **Step 1: Failing tests:** initial: hint visible, no „Los geht's"; tap `buddyAreaKey` → controller action `wakeUp`; pumping 3 × 2.6 s shows the three bubble texts in order, then `registrationButtonKey` visible; tapping it navigates to `/registration`; `signInButtonKey` visible from the start and navigates to `/auth`; with `disableAnimations: true` the flow still reaches „Los geht's".
- [ ] **Step 2–4:** FAIL → implement → PASS. **Step 5: Commit** `feat(buddy): Buddy intro story replaces the welcome carousel`

### Task 3: Wizard — name step, consent move, Buddy reactions, post-auth handoff

**Files:**
- Create: `lib/screens/registration/steps/buddy_name_step.dart`, `lib/screens/registration/widgets/buddy_step_host.dart`
- Modify: `lib/screens/registration/registration_wizard_screen.dart`, `lib/screens/registration/steps/steps.dart` (export), `lib/screens/registration/steps/health_consent_step.dart` (replace the `MascotImage` with nothing — the host shows the Buddy), each step file only if it renders its own `MascotImage` at the top (remove it; the host provides the Buddy), `test/helpers/registration_driver.dart`
- Test: `test/screens/registration/registration_wizard_screen_test.dart` (extend), `test/screens/registration/buddy_name_step_test.dart`, `integration_test/registration_flow_test.dart` (update steps)

**Interfaces:**
- Produces:
  - `class BuddyNameStep extends StatelessWidget { const BuddyNameStep({super.key, required String value, required ValueChanged<String> onChanged}); static const titleKey = Key('buddy_name_step_title'); static const fieldKey = Key('buddy_name_field'); }` — title „Wie soll ich heißen?", `TextField` prefilled, `maxLength: 20`, `textCapitalization.words`.
  - `class BuddyStepHost extends StatelessWidget { const BuddyStepHost({super.key, required BuddyController controller, required String name, required Widget child}); }` — `BuddyStage` at `AppConstants.buddyWizardSize = 150` height above the step content (scrollable when keyboard open).
- Wizard changes:
  - New fields: `String _buddyName = 'Buddy'`, `late final BuddyController _buddy` (disposed), `final _rnd = Random()`.
  - Indices: `_nameStep = 0`, `_consentStep = 1`, `_birthYearStep = 2`, `_genderStep = 3`, `_heightWeightStep = 4`, `_dietStep = 5`, `_symptomsStep = 6`, `_intolerancesStep = 7`, `_authStep = 8`, `_emailCaptureStep = 9`; `_totalSteps = _showEmailCapture ? 10 : 9`. `_canAdvance`: name step requires `_buddyName.trim().isNotEmpty`; consent/gender/diet unchanged.
  - Reactions: on page change → `_buddy.say(step intro line)`; on each value change → look up `wizardReaction(...)`, apply `mood`/`play(action)`/`say(line with {name})`; leaving the name step → `play(celebrate)` + „{name}! Den Namen mag ich." (`name:confirmed`). Symptoms/intolerances: react to the most recently added item; deselect → no reaction; selecting none and pressing Weiter → `symptom:none` / `intolerance:none`.
  - After auth success, in **every** completion path (email, Google, Apple without capture, email-capture submit, email-capture skip): `await _createProfile()`, then `await ref.read(buddyProvider.notifier).setName(_buddyName)` (errors logged, not blocking), then `context.go(RoutePaths.buddyOnboarding, extra: BuddyOnboardingEntry.afterRegistration)` (route from Task 4) instead of `RoutePaths.dashboard`.
- `registration_driver.dart`: `advanceToAuthStep` now first confirms the name step (taps Weiter), then accepts consent.

- [ ] **Step 1: Failing tests:** step 0 shows `BuddyNameStep.titleKey` with „Buddy" prefilled; clearing the name disables Weiter; step 1 shows the consent title and the Buddy line „Bevor du mir von deinem Bauch erzählst …"; choosing gender „weiblich" makes the Buddy say the catalog line; choosing diet „vegan" sets mood `inLove`; after a fake email sign-up the router lands on `/buddy-onboarding` and `FakeBuddyRepository` holds `name == 'Bauchi'` when typed; same for the email-capture skip path; the consent timestamp/privacy version are still written to the profile (existing assertions keep passing).
- [ ] **Step 2–4:** FAIL → implement → PASS (`flutter test test/screens/registration`).
- [ ] **Step 5: Commit** `feat(buddy): Buddy hosts the registration wizard`

### Task 4: `/buddy-onboarding` sequence

**Files:**
- Create: `lib/screens/buddy/buddy_onboarding_screen.dart`, `lib/screens/buddy/widgets/gift_reveal.dart`
- Modify: `lib/router/route_names.dart` (`RouteNames.buddyOnboarding = 'buddy-onboarding'`, `RoutePaths.buddyOnboarding = '/buddy-onboarding'`), `lib/router/app_router.dart` (route; `extra` → `BuddyOnboardingEntry`, default `gate`)
- Test: `test/screens/buddy/buddy_onboarding_screen_test.dart`, `test/screens/buddy/gift_reveal_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum BuddyOnboardingEntry { afterRegistration, gate }
  enum BuddyOnboardingStep { intro, name, streakGoal, reminder, firstMeal, gift }
  List<BuddyOnboardingStep> buddyOnboardingSteps({required BuddyOnboardingEntry entry, required bool hasRow, required bool remindersAlreadyOn});
  class BuddyOnboardingScreen extends ConsumerStatefulWidget { const BuddyOnboardingScreen({super.key, this.entry = BuddyOnboardingEntry.gate}); }
  class GiftReveal extends StatefulWidget { const GiftReveal({super.key, required VoidCallback onOpened}); } // closed box (drawn, AppTheme colors) → tap → lid pops, ConfettiBurst-like sparkle burst, "🛡 Streak-Saver" card; onOpened fires once
  ```
- Step lists: `afterRegistration` → `[streakGoal, reminder?, firstMeal, gift]`; `gate` → `[intro?, name?, streakGoal, reminder?, gift]` where `intro`+`name` only when `!hasRow`, `reminder` only when `!remindersAlreadyOn` (`remindersAlreadyOn = profile.pushEnabled`).
- Step content (one `BuddyStage` on top, persistent across steps; content below):
  - `intro`: `play(wakeUp)` + „Hi! Ich bin neu hier — dein Bauch-Buddy." → [Weiter].
  - `name`: `BuddyNameStep` → `setName`.
  - `streakGoal`: „Wie viele Tage schaffen wir zusammen?" + `StreakGoalPicker(currentStreak: status.streak)`; if `streakGoalChoices` is empty → skip step; on select → `setStreakGoal(g)`, `play(celebrate)`.
  - `reminder`: „Darf ich dich erinnern, wenn ich Hunger habe?" [Ja, gerne] → same calls as `notification_opt_in_dialog.dart` `_activate` (extract them into a shared `Future<bool> enableReminders(WidgetRef ref)` in `lib/providers/notification_provider.dart` and use it from both places) ; [Später] → no permission request. Both set `AppConstants.keyNotificationModalShown = true`.
  - `firstMeal`: mood `hungry`, „Ich hab Hunger! Was hast du zuletzt gegessen?" [Mahlzeit eintragen] → `await context.push(RoutePaths.mealTracker)`; when it returns, if `buddyEventsProvider` received a meal event since the step started → `say('Mmmh! Danke!')` and advance; else stay with [Später] available. [Später] advances.
  - `gift`: „Ein Geschenk für dich!" + `GiftReveal` → `onOpened` → `completeOnboarding(grantGiftSaver: true)` → text „Ein Streak-Saver! Der rettet unseren Streak, falls du mal einen Tag vergisst." → [Los geht's] → `context.go(RoutePaths.dashboard)`.
- Progress dots at the top; system back on step > 0 goes to the previous step, on step 0 does nothing (`PopScope(canPop: false)`).

- [ ] **Step 1: Failing tests:** `buddyOnboardingSteps` table for all 8 combinations; afterRegistration flow walk: pick 7 → `FakeBuddyRepository` goal 7; reminder „Später" sets the pref and requests no permission (`FakeNotificationRepository`); firstMeal „Später" advances; gift tap → `completeOnboarding` called once (tap twice → still once) and savers +1; final button goes to `/dashboard`; firstMeal with a meal event emitted while pushed → advances automatically after pop; reduced motion: entire walk completes.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** `feat(buddy): post-auth Buddy onboarding sequence`

### Task 5: Gate for existing users + dashboard first-run cleanup

**Files:**
- Create: `lib/providers/buddy_onboarding_gate_provider.dart`
- Modify: `lib/router/app_router.dart` (`_RouterRefreshNotifier` listens to the new provider; redirect rule after the consent gate), `lib/screens/dashboard/dashboard_screen.dart` (remove `showWelcomeModal`; tutorial spotlight runs directly), delete `lib/screens/dashboard/widgets/welcome_modal.dart` and its test
- Test: `test/providers/buddy_onboarding_gate_provider_test.dart`, `test/router/buddy_onboarding_gate_test.dart` (pattern: `test/router/health_consent_gate_test.dart`; note CI doesn't run `test/router/` — also add the core redirect assertions to `test/providers/...` so CI covers the predicate), update `test/screens/dashboard/dashboard_screen_test.dart`, `integration_test/tutorial_flow_test.dart`

**Interfaces:**
- Produces: `final buddyOnboardingRequiredProvider = Provider<bool>(...)` — true iff authenticated && profile `AsyncData` non-null && `profile.isComplete` && `!needsHealthConsent(profile)` && `buddyProvider` is `AsyncData` non-null && (`!status.hasRow` || `status.state.onboardingCompletedAt == null`). Loading/error of `buddyProvider` → false (never block the app on a backend error).
- Redirect (after consent gate): if required and path ∉ {`/buddy-onboarding`, `/registration`, `/meal-tracker`, `/drink-tracker`} → `/buddy-onboarding`; if not required and path == `/buddy-onboarding` → `/dashboard`.

- [ ] **Step 1: Failing tests:** predicate truth table (no profile / incomplete / consent missing / buddy loading / buddy error / no row / row not completed / completed); router: existing user without row lands on `/buddy-onboarding`, completing it lands on `/dashboard`; killed-mid-flow simulation (row with name, no `onboardingCompletedAt`) → gate → steps start at `streakGoal` (no intro/name) and the gift is granted once; while on `/buddy-onboarding`, pushing `/meal-tracker` is not redirected; dashboard first run for a new user shows the spotlight tutorial without the welcome modal; existing user with `pushEnabled == true` never sees the opt-in dialog after onboarding.
- [ ] **Step 2–4:** FAIL → implement → PASS (`flutter test test/providers test/screens test/widgets` and `flutter test test/router`).
- [ ] **Step 5:** Full verification: `dart format --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test` (all).
- [ ] **Step 6: Commit** `feat(buddy): onboarding gate for existing users; drop welcome modal`

### Task 6: End-to-end check on the simulator

**Files:** none (verification + screenshots for the PR description).

- [ ] **Step 1:** `dart run build_runner build --delete-conflicting-outputs`; run the app with `--dart-define=BUDDY_LOCAL_STATE=true` (plus the project's usual `--dart-define-from-file=env.json` if present) on the booted iOS simulator (UI: `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`).
- [ ] **Step 2:** Walk: intro → name → consent → profile → (if a dev backend is reachable) auth → onboarding sequence → dashboard hero → log a drink and a gut feeling → reactions. Capture screenshots with `xcrun simctl io booted screenshot <path>` into the scratchpad. If auth can't be completed against a backend, document exactly which steps were verified on device and which only by widget tests.
- [ ] **Step 3:** Note results for the PR description. No commit.
