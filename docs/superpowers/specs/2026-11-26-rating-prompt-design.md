# Bewertungs-Abfrage (Rating prompt) — Design

**Status:** decision by Severin 2026-11-26 („after the 7-day reward"); the rest is Claude's proposal, which he saw and left
unchanged. Track E2 of the business-plan gap analysis (overview: https://claude.ai/artifact/YQgbV8TdaVHMR4MK3uBGXb).
**Repo:** app `severinkl/bellybuddyapp`, branch `feat/rating-prompt` from `develop` @ 22a9a2b. No server change.

## 1. Intent

The app is in its first store review. Store ratings decide how it ranks and whether a visitor installs it, and the business
plan's marketing section counts on them („Referral"). Nothing in the app asks for a rating. This adds the stores' own rating
dialog at one good moment, and a row for people who want to rate without being asked.

**Success:** a user who just finished their first week sees the system's rating dialog once, at a moment they feel good about
the app; nobody is asked twice in a short time; anyone can reach the store page from „Ich".
**Anti-goals:** asking while the user feels bad or is busy with something else; a question of our own before the dialog that
filters unhappy users away from the store („review gating", which both stores forbid or discourage); asking again and again.

## 2. Decisions

| # | Topic | Options shown | Decision |
|---|---|---|---|
| 1 | Moment | after the 7-day reward / when the Muster unlock / after the third good day | **After the 7-day reward** (Severin) |
| 2 | Dialog | — | The system's own rating dialog, no question before it (Claude, unchanged) |
| 3 | Never | — | Not during onboarding, not on a day with a „Schlecht" entry, not while the Buddy asks for something else (Claude, unchanged) |
| 4 | Frequency | — | At most once per app version and once every 90 days (Claude, unchanged) |
| 5 | Ich row | — | „Belly Buddy bewerten", opens the store page (Claude, unchanged) |
| 6 | Package | — | One new package for the native dialog (Claude, unchanged) |

**What the code says about decision 1 (Claude's ruling, for Severin to confirm):** in the app, „the 7-day reward" and „the
Muster unlock" are the same event. The journey's day 7 is the first patterns (`_patternsDay = InsightRules.daysNeeded` in
`lib/services/journey/journey_rules.dart`); its reward is `JourneyRewards.patternsFreed`, celebrated by the full-screen
„Muster frei!" (`PatternsUnlockedScreen`, pushed by Home's Buddy cue `patternsUnlocked`). So options 1 and 2 of the question
were one moment. The prompt comes **after that celebration, once the user is back on Home**.

## 3. Approaches

- **The native dialog at a good moment (picked).** `in_app_review`'s `requestReview()` on Home after the day-7 celebration.
  The stores decide whether the dialog really appears (their own quotas), and the user rates without leaving the app.
- **Our own „Gefällt dir Belly Buddy?" first, then the dialog only for „Ja".** Rejected: Apple requires the system prompt for
  in-app rating requests and Google's in-app review guidance says not to ask an opinion question before it; it is gating.
- **Ask on app start after N launches.** Rejected: it ignores how the user feels that day and interrupts whatever they came
  to do. A gut-health app must not ask for stars on a bad day.

## 4. Design

### 4.1 When the prompt is due
All of these hold, checked when Home is visible and nothing covers it:

1. **The first patterns are unlocked and celebrated.**
   - Journey users (`journeyProvider == true`): `journeyRewardsProvider.patternsFreed` is true **and** the
     `BuddyAnnouncement.patternsUnlocked` announcement was already shown (its flag is set; it is no longer pending).
   - Users off the journey (`journeyProvider == false`, accounts older than the journey): their insights are unlocked
     (`insightsProvider` settled, `unlocked`). They never get a day-7 celebration, so for them the moment is simply the next
     Home visit that passes the other rules. (Claude's ruling: otherwise today's testers would never be asked.)
   - While the journey is undecided (`null`): not due.
2. **Not during onboarding:** `buddyOnboardingRequiredProvider` is false and the Home tutorial is not running
   (`tutorialProvider` false).
3. **Not on a hard day:** none of today's gut-feeling entries is „Schlecht", i.e. no entry of the local day
   (`todayProvider`, `tracked_at` as wall clock) has `calculateGutFeelingRating(entry).level == GutFeelingRatingLevel.schlecht`
   (a gut score of 4 or 5). A day without gut-feeling entries passes.
4. **The Buddy asks for nothing else:** no cue is playing or queued in Home's hero, `buddyOffersProvider` is empty, and
   `reminderAskDueProvider` is not true. The rating request is itself a cue of Home's hero queue, queued last, so it can
   never open over a sheet. If any other cue that ends in a sheet (an offer, a day's reward, the reminders ask, a reached
   goal) played during this Home visit, the request waits for a later visit. The one exception is the „Muster frei!"
   celebration itself: coming back from it is exactly the moment.
5. **Frequency:** never asked in this app version before, and the last request is at least 90 days ago
   (`package_info_plus` version string; local calendar days).
6. **The dialog is available** (`InAppReview.isAvailable()`).

### 4.2 What happens
- The Buddy plays a short happy animation and says nothing. No sheet, no text of ours.
- The app calls the native request once and records the request (version and day) **as it is made**, whether or not the
  system shows the dialog: the stores do not tell the app, and their own quotas apply on top.
- A failing request is logged and still recorded, so a broken store service cannot make the app ask on every visit.
- The record lives in shared preferences per user and device, like the reminder-ask counters:
  `rating_asked_version_<userId>` and `rating_asked_on_<userId>` (`yyyy-MM-dd`).

### 4.3 The Ich row
- „Belly Buddy bewerten", subtitle „Sag anderen, wie dir die App gefällt", icon a star outline, directly above „Feedback
  geben". Always shown.
- It opens the app's store page for writing a review (`openStoreListing`, with `AppConstants.iosAppStoreId` on iOS); if that
  fails, the existing `AppVersionService.openStore()`; if that fails too, the message „Der Store konnte nicht geöffnet
  werden."
- Tapping it does not count as a request and does not change the frequency rule.

## 5. Non-goals
- No rating UI, star widget or question of our own.
- No routing of unhappy users to the feedback form instead of the store.
- No server change, no analytics event, no remote switch.
- No prompt anywhere but Home.

## 6. Left to the builder
- How the hero learns that the celebration announcement was shown (a small read on `BuddyNotifier`, or the rule expressed
  through the pending announcements), as long as rule 1 holds.
- Whether the due check is one provider or a pure rule plus a thin provider, as long as the rule is unit-tested without
  widgets.
- The `in_app_review` version (`flutter pub add in_app_review`, current major) and any native setup its README asks for.

## 7. Notes for testing on devices
- iOS shows the dialog in debug builds every time, never in TestFlight builds, and in App Store builds at most three times a
  year per user.
- Android shows it only for builds installed from Play (internal test track counts), with Play's own quota.
