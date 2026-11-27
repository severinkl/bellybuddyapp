# Bewertungs-Abfrage (Rating prompt) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After the day-7 celebration the app requests the stores' native rating dialog once, at a good moment, and „Ich" gets a row that opens the store page.

**Architecture:** A pure rule decides whether a request is allowed; a provider feeds it from existing providers and shared preferences; Home's Buddy hero plays the request as the last cue of its existing queue, so it never stacks with another ask. The native calls sit behind one small provider so tests fake them.

**Tech Stack:** Flutter, Riverpod, shared_preferences, package_info_plus, `in_app_review` (new, current major).

**Spec:** `docs/superpowers/specs/2026-11-26-rating-prompt-design.md` (this repo, branch `feat/rating-prompt`).

## Repo and commands

- Work in `~/projects/bellybuddy/.worktrees/rating-prompt`, branch `feat/rating-prompt` (from `develop` @ 22a9a2b).
- Tests: `flutter test <path>`. Gates: `dart format --set-exit-if-changed . && flutter analyze` (zero issues).
- The repo's pre-commit hook fails inside a worktree (Flutter reports version `0.0.0-unknown` there). Run the two gates by hand before each commit and commit with `--no-verify`; Severin approved this on 2026-11-26.

## Global Constraints

- All user-facing strings are German, „du".
- Colours only as `static const Color` in `AppTheme`; font sizes only `AppTheme.fontSize*`; spacing and radii only from `AppConstants`. No numeric literals for these in widget files; add missing values there first.
- Riverpod; GoRouter; `AppLogger`, never `print()`.
- No question, sheet or text of ours before the native dialog. No routing of users by how they feel about the app.
- A request is recorded as it is made, whether or not the system shows a dialog.
- Frequency: never twice in one app version, and at least 90 days between requests.
- `tracked_at` values are the user's wall clock in the UTC slot: never `toLocal()` them; compare their date fields with `todayProvider`'s day.
- No server change. Conventional commits. PR to `develop`. Never arm auto-merge; stop at `gh pr create`.

## Review Focus

1. **The user logs a „Schlecht" gut feeling, then opens Home on the same day.** No request that day; a request is possible the next day. Tests in Task 1 (rule) and Task 2 (hero).
2. **Another ask is due on the same Home visit** (the day-3 first-tip offer still open after the celebration, or the reminders ask). The other ask plays; the rating request waits for a later visit. Test in Task 2.
3. **The native call throws or reports „not available".** Nothing is shown, the failure is logged, a thrown request is still recorded, „not available" is not recorded. Tests in Task 1 and Task 2.
4. **An app update inside the 90 days, and 90 days without an update.** Neither alone allows a request; both together do. Test in Task 1.
5. **Two accounts on one device.** One account's record never blocks or allows the other's request. Test in Task 1.

---

### Task 1: Rule, record and native launcher

**Files:**
- Create: `lib/services/rating/rating_rules.dart`, `lib/providers/rating_provider.dart`
- Modify: `pubspec.yaml` and `pubspec.lock` (`flutter pub add in_app_review`), `lib/config/constants.dart` (two keys, one number)
- Test: `test/services/rating/rating_rules_test.dart`, `test/providers/rating_provider_test.dart`

**Interfaces — Produces:**

```dart
// constants.dart
static const String keyRatingAskedVersionPrefix = 'rating_asked_version_';
static const String keyRatingAskedOnPrefix = 'rating_asked_on_';   // yyyy-MM-dd
static const int ratingAskMinDays = 90;

// rating_rules.dart (pure, no Flutter imports beyond the models)
bool ratingAskAllowed({
  required String currentVersion,
  required String? askedVersion,
  required DateTime? lastAsk,      // a local calendar day
  required DateTime today,         // a local calendar day
});   // true iff askedVersion != currentVersion AND (lastAsk == null OR today is >= 90 calendar days after lastAsk)

bool hasHardEntryToday(Iterable<GutFeelingEntry> entries, DateTime today);
      // any entry whose trackedAt wall-clock date equals today's date and whose
      // calculateGutFeelingRating(entry).level == GutFeelingRatingLevel.schlecht

// rating_provider.dart
abstract class RatingLauncher {
  Future<bool> isAvailable();
  Future<void> request();            // InAppReview.instance.requestReview()
  Future<void> openStoreListing();   // InAppReview.instance.openStoreListing(appStoreId: AppConstants.iosAppStoreId)
}
final ratingLauncherProvider = Provider<RatingLauncher>(...);   // the in_app_review implementation

/// Rules 1, 2, 3, 5 and 6 of the spec's §4.1 (rule 4 is the hero's queue, Task 2).
final ratingAskDueProvider = FutureProvider.autoDispose<bool>(...);

/// Records a request for the signed-in user: this version, today. Completes once stored.
Future<void> recordRatingAsk(WidgetRef ref);
```

`ratingAskDueProvider` is false while signed out; while `journeyProvider` is null; on the journey unless `journeyRewardsProvider?.patternsFreed == true` and the `patternsUnlocked` announcement is no longer pending; off the journey unless the settled insights are `unlocked`; while `buddyOnboardingRequiredProvider` or `tutorialProvider` is true; when `hasHardEntryToday(entriesProvider's gut feelings, todayProvider)`; when `ratingAskAllowed` is false; when `isAvailable()` is false or throws (logged). Model it on `reminderAskDueProvider` in `lib/providers/notification_provider.dart` (same prefs access, same per-user keys, same use of `todayProvider`).

- [ ] **Step 1: Write the failing tests.**

```dart
// rating_rules_test.dart
test('never asked: allowed')
test('same version: not allowed, even after 400 days')
test('new version after 89 days: not allowed; after 90 days: allowed')
test('90 days are calendar days: asked 1 Sep 23:59, today 30 Nov 00:01 → allowed (90 days), 29 Nov → not')
test('a Schlecht entry today counts; a Mittel one does not; a Schlecht entry yesterday at 23:59 wall clock does not')
test('an entry stored as 2026-11-26T23:30:00Z is on 26 Nov whatever the device zone')   // wall clock, no toLocal()

// rating_provider_test.dart  (ProviderContainer, SharedPreferences.setMockInitialValues, a fake RatingLauncher)
test('due for a journey user once patterns are freed and the celebration was shown')
test('not due while the patternsUnlocked announcement is still pending')
test('due for a user off the journey with unlocked insights; not while insights are locked')
test('not due signed out, with the journey undecided, during the Buddy onboarding, during the tutorial')
test('not due on a day with a Schlecht entry')
test('not due when the launcher is unavailable, or when isAvailable throws')
test('recordRatingAsk stores this version and today under the user id; due is false afterwards')
test('user A\'s record does not affect user B on the same device')
```

- [ ] **Step 2: Run** `flutter test test/services/rating test/providers/rating_provider_test.dart` — expected: FAIL, files not found.
- [ ] **Step 3: Implement.** Add the package with `flutter pub add in_app_review`; follow its README for native setup and note in the report what, if anything, it required. The launcher implementation is the only file that imports `in_app_review`.
- [ ] **Step 4: Run** the tests and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(rating): rule, record and native launcher`.

### Task 2: The request as a cue of Home's hero

**Files:**
- Modify: `lib/screens/dashboard/widgets/buddy_hero.dart`
- Test: `test/screens/dashboard/widgets/buddy_hero_test.dart`

**Interfaces — Consumes:** `ratingAskDueProvider`, `ratingLauncherProvider`, `recordRatingAsk` (Task 1).

Behaviour, following how `_Cue.remindersAsk` is queued and played in this file (`_queueRemindersAsk`, `_remindersAskQueued`, `_deferSheet`, `_nextCue`):
- A new last cue `_Cue.ratingAsk(null)`. It is queued when `ratingAskDueProvider` says due (listened like `reminderAskDueProvider`, and checked when Home becomes visible), only if no other cue is queued or playing, `buddyOffersProvider` is empty and `reminderAskDueProvider` is not due.
- A per-visit flag: once any cue with `endsInSheet` other than `patternsUnlocked` has played since Home became visible, the rating cue is not queued for the rest of that visit. Leaving and returning to Home resets it.
- When the cue plays it re-checks `ratingAskDueProvider` (it may have waited while Home was covered). Still due: the Buddy plays `BuddyAction.celebrate` with no speech bubble, then the app calls `recordRatingAsk(ref)` and `ratingLauncherProvider.request()`. A throwing `request()` is logged with `AppLogger` and changes nothing else. Not due any more: the cue ends silently and nothing is recorded.
- The cue never opens a sheet or page of ours and never shows text.

- [ ] **Step 1: Write the failing tests** in the style of the reminders-ask tests in `buddy_hero_test.dart` (fake launcher counting `request()` calls):

```dart
testWidgets('back on Home after „Muster frei!": the request is made once and recorded')
testWidgets('nothing is shown before or after the request: no sheet, no bubble text')
testWidgets('the day-3 offer still open after the celebration: the offer plays, no request this visit; next visit with nothing else due: one request')
testWidgets('the reminders ask is due: it plays, no request this visit')
testWidgets('a Schlecht entry logged while the cue waited: no request, nothing recorded')
testWidgets('request() throws: logged, recorded, Home keeps working')
testWidgets('already asked in this version: never queued')
```

- [ ] **Step 2: Run** `flutter test test/screens/dashboard/widgets/buddy_hero_test.dart` — expected: the new tests FAIL.
- [ ] **Step 3: Implement.** `buddy_hero.dart` is large; add only the cue, its queueing and its play method next to their reminders-ask counterparts. If the per-visit flag needs more than a field and two assignments, stop and report it as a concern.
- [ ] **Step 4: Run** `flutter test test/screens/dashboard` and both gates — expected: PASS, the existing hero tests unchanged.
- [ ] **Step 5: Commit** `feat(rating): request a rating after the day-7 celebration`.

### Task 3: „Belly Buddy bewerten" in Ich

**Files:**
- Modify: `lib/screens/me/me_screen.dart`
- Test: `test/screens/me/me_screen_test.dart`

**Interfaces — Consumes:** `ratingLauncherProvider.openStoreListing()`, `appVersionServiceProvider.openStore()`.

- A `BbSettingsItem` with key `MeScreen.rateKey`, icon `Icons.star_outline`, title „Belly Buddy bewerten", subtitle „Sag anderen, wie dir die App gefällt", directly above „Feedback geben". Always shown.
- Tap: `openStoreListing()`; if it throws, `openStore()`; if that throws too, the app's usual error message with the text „Der Store konnte nicht geöffnet werden." Both failures are logged.
- Tapping never calls `recordRatingAsk`.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('the row sits directly above „Feedback geben" with its title and subtitle')
testWidgets('tap opens the store listing through the launcher')
testWidgets('listing fails: the store page opens through AppVersionService')
testWidgets('both fail: „Der Store konnte nicht geöffnet werden." is shown')
testWidgets('tapping does not record a rating request')   // prefs hold no rating_asked_* key afterwards
```

- [ ] **Step 2: Run** `flutter test test/screens/me` — expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/screens/me` and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(rating): „Belly Buddy bewerten" row in Ich`.

### Task 4: Gates, device check, PR

- [ ] **Step 1:** Run `dart format --set-exit-if-changed .`, `flutter analyze` and the full `flutter test`. Expected: all green.
- [ ] **Step 2:** On an iOS simulator debug build with a journey user at day 7: after dismissing „Muster frei!" the system rating sheet appears once on Home; it does not appear again after restarting the app; „Belly Buddy bewerten" opens the store page. Note in the PR that TestFlight builds never show the dialog and Android shows it only for Play-installed builds.
- [ ] **Step 3:** Push `feat/rating-prompt` and open a PR to `develop` titled `feat: ask for a store rating after the first week`, linking the spec. Stop there.
