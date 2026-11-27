# Tagesrückblick und Ergebnis nach dem Essen (Daily review, after-meal nudge) — Design

**Status:** direction by the controller for Severin (away) on 2026-11-26; every other call is Claude's, labelled below.
Tracks B1 („sanfter Tagesrückblick") and B2 („Push, nachdem eine Mahlzeit ausgewertet wurde") of the business-plan gap
analysis. **Repos:** app `bellybuddyapp` and core `bellybuddy-core`, branch `feat/daily-review` in each, stacked on the
stage-1 branch `feat/share-link` (core needs its migration 0016 as the parent).

## 1. Intent

The business plan promises „tägliche, leichte Korrekturen statt Verbote": the app should not correct people at mealtimes but
look back with them once a day, kindly, and hand them **one** easy thing to try tomorrow („Statt Zwiebel könntest du morgen
das Grün der Frühlingszwiebel probieren"). Today the app's help is weekly (the LLM tips) or buried (Alternativen in Entdecken,
never refreshed after a meal, never mentioned at the meal).

**Success:** on an evening after logging meals, Home shows a short review in the Buddy's voice: what the day looked like in
the user's own entries, one alternative taken from that day's flagged ingredients, and one tap („Probiere ich") that keeps it
where the user finds it again. After logging a meal, the user learns quietly — on the success screen if the analysis is quick
enough, in the diary entry always — which ingredients could be hard, with a link to their alternatives.
**Anti-goals:** a push at every meal; a verdict on the day („gut gemacht", „das war zu viel"); a ban; any wording that reads
as diagnosis or cause („Zwiebel ist dein Auslöser"); a new LLM call per day; another sheet stacked on the Buddy's asks.

## 2. Decisions

| # | Topic | Decision | Whose |
|---|---|---|---|
| 1 | Form | A card on Home under the Buddy, from a set time (default 19:30) on days with ≥ 1 meal; three parts: the day, one alternative, „Probiere ich" | Controller (Severin's delegate) |
| 2 | Which alternative | Deterministic, from that day's suggestion groups; no LLM call | Controller |
| 3 | Push per meal (B2) | **Not built.** In-app quiet result on the success screen and in the diary entry instead | Claude's call — see §2.1 |
| 4 | Day without a flagged ingredient | The card still shows (the day part plus one neutral line), never „nichts gefunden" | Claude's call: cost if wrong — a card some find empty; dropping the line later is one condition |
| 5 | Missed review | It carries over to the next morning until 11:00 („Dein Rückblick auf gestern"), then lapses; no copy in Entdecken | Claude's call: cost if wrong — morning-only users still miss it; the rule is one pure function to widen |
| 6 | „Probiere ich" storage | Server table `alternative_choices` (per user, PostgREST + RLS), also holding „Passt nicht für mich" | Claude's call: cost if wrong — a table; local storage would lose the list on reinstall and a second device |
| 7 | Where „Probiere ich" is found again | A section „Probiere ich" at the top of the Alternativen screen (Entdecken › Alternativen › Alle) | Claude's call |
| 8 | Rejecting an alternative | „Passt nicht für mich" on the card: that replacement is never picked again for that ingredient; the next candidate shows | Claude's call: the brief assumed a rejection exists; the code has none (§4.2) |
| 9 | Review time and evening notice | Two profile columns: `daily_review_time` (default '19:30', settable 16:00–23:30) and `daily_review_reminder` (default **off**); a one-shot local notification only on days with a meal | Controller (off by default); storage and one-shot: Claude's call |
| 10 | Buddy cue | One speech line (no sheet) once per review day, after every other cue except the rating request | Claude's call: cost if wrong — one line too many; removable without touching the card |
| 11 | Free vs. paid | The card is free; only the alternative line is the paid part once the subscription switch is on (soft upsell). Seam only, no gating here | Controller |
| 12 | Active guided test (Insights v2) | An extras slot `dailyReviewExtrasProvider` (empty list) rendered between the day and the alternative | Controller (named extension point) |

### 2.1 Push per meal: not built, and why (Claude's call)
- **Tone.** The product's rule is „never correct at mealtimes". A push seconds after a meal saying „Zwiebel könnte dir zu
  schaffen machen" is exactly that, on the lock screen, possibly in company.
- **Timing.** The analysis (`refresh-ingredient-suggestions`, one Claude call per meal) finishes while the user is usually
  still in the app; a push would arrive on top of the success screen or seconds after leaving it.
- **What is left of B2** is the useful part: the result, quietly, where the user looks — the success screen (if it arrives
  while that is up), the meal in the Tagebuch (always), Entdecken (now refreshed), and the evening review.
- **Cost if wrong:** users who would want an immediate heads-up don't get one. `app/push.py` and the refresh route are
  unchanged, so a later opt-in push is one call after `refresh_meals` plus a profile switch.

## 3. Approaches

- **Home card computed on the device from data the app already loads (picked).** Today's meals and gut feelings
  (`entriesProvider`), the suggestion groups with their meals and replacements (`ingredientSuggestionProvider`), and the
  user's choices. No server job, no LLM call, works the moment Home opens; the evening notice is a local notification.
- **A nightly server job writing a review row per user, sent by push.** Rejected: a push at 19:30 for everyone is the nagging
  the product rules out; the job would duplicate the app's wall-clock day logic in Python and add a table for something
  derived; and it costs a deploy for every copy change.
- **Folding the review into the weekly tips (LLM).** Rejected: weekly, not daily; adds LLM cost and latency; and the tips
  have an opt-in the review should not need.
- **A sheet the Buddy opens in the evening.** Rejected: it would stack with his other asks (journey reward, reminders ask,
  first-tip offer, rating request). A card on Home never covers anything; the Buddy only points to it with one line.

## 4. Design

### 4.1 When the card shows (the review window)
- Inputs: now (`minuteProvider`, device local time), the review time `T` (`profile.dailyReviewTime`, minutes since
  midnight), the closed day (prefs `daily_review_closed_<userId>`, `yyyy-MM-dd`).
- **Today's review** from today at `T` until midnight, unless today is closed.
- **Yesterday's review** from midnight until 11:00 (`AppConstants.dailyReviewCarryOverHour = 11`), while today's window
  has not started and yesterday is not closed.
- Only if that day has ≥ 1 meal (wall-clock date of `tracked_at` equals the day — never `toLocal()`). Today's come from
  `entriesProvider` (only when its `day` is today), yesterday's from `diaryEntriesProvider(yesterday)`.
- Not while signed out or while the Buddy onboarding is required. During Home's tour it is simply there (static).
- Closing: an „×" (tooltip „Schließen") writes the review's day as closed. Nothing else closes it.

### 4.2 The alternative (deterministic)
What the code has: `ingredient_suggestions` rows exist **per meal and flagged ingredient** (each with an LLM help text and
1–3 replacements from the catalog); the app groups them by ingredient (`IngredientSuggestionGroup` with `meals` and
`replacements`). Dismissing a group in Alternativen sets `dismissed_at` on its rows; dismissed rows are never fetched.
There is **no per-replacement rejection** in the code. A meal without flagged ingredients is never marked analysed, so „no
flagged ingredient" and „not analysed yet" look the same to the app (decision 4's neutral line covers both).

Pick (`pickAlternative`):
1. Candidate groups: those with at least one meal of the review day (by meal id) and at least one replacement.
2. Order: most meals in the 14 wall-clock days ending with the review day (`AppConstants.dailyReviewRecentDays = 14`),
   then latest meal first, then ingredient name ignoring case.
3. In that order, the first group with a replacement that has **no choice row** for (ingredient, replacement) — neither
   „Probiere ich" nor „Passt nicht für mich" — gives the pick: its first such replacement in the group's order. The order of
   replacements becomes stable: `fetchReplacements` orders by `created_at`.
4. None: no alternative (neutral line).

Home refreshes the suggestions (`fetchSuggestions()`, coalesced) when the card first shows on a visit, so the last meal's
analysis is in if it finished.

### 4.3 What the card says (German, the Buddy's voice; `DailyReviewCopy`)
- Title: today „Dein Tagesrückblick 🌙"; yesterday „Dein Rückblick auf gestern 🌙".
- **The day:** „Heute hast du 1 Mahlzeit eingetragen." / „Heute hast du 3 Mahlzeiten eingetragen." (yesterday: „Gestern
  hast du …"). Then, if gut feelings exist that day, the latest one's level: „Dein Bauchgefühl zuletzt: Gut." — for
  „Schlecht" followed by „Ich bin für dich da. 💛". None, and today: „Magst du noch dein Bauchgefühl eintragen?" with the
  text button „Bauchgefühl eintragen" (opens the gut-feeling tracker); yesterday: nothing.
- **Extras** (`dailyReviewExtrasProvider`, empty now): one line each, optionally tappable.
- **The alternative:** „Statt {Zutat} könntest du morgen {Alternative} probieren." (yesterday: „… heute …"). With ≥ 2 recent
  meals, a caption: „{Zutat} war in {n} deiner Mahlzeiten der letzten zwei Wochen." Buttons: „Probiere ich" (primary) and
  „Passt nicht für mich" (text).
  - After „Probiere ich": „Gemerkt! Du findest es unter Entdecken › Alternativen." with „Ansehen" (opens Alternativen).
  - After „Passt nicht für mich": the next pick replaces the line at once, or the neutral line.
  - A failed write: SnackBar „Das hat nicht geklappt. Versuch es später noch einmal.", the line as before.
- **Neutral line** (no pick): today „Für morgen hab ich keine Alternative für dich. Genieß deinen Abend!"; yesterday „Für
  heute hab ich keine Alternative für dich."
- **Locked** (subscription seam on, a pick exists): „Für morgen hätte ich eine Alternative für dich." and, only when the
  subscription track provides a route, a button „Mehr erfahren". The ingredient is not named.
- Never: praise or blame for the day, „zu viel", „solltest", a cause („wegen"), „Diagnose", „Auslöser".

### 4.4 „Probiere ich" and „Passt nicht für mich" (`alternative_choices`)
- Columns: `id`, `user_id` (FK auth.users, cascade), `ingredient_id` and `replacement_ingredient_id` (FK ingredients,
  cascade), `choice` (`'try'` | `'skip'`), `created_at`; unique (user, ingredient, replacement). Owner-only RLS for
  select/insert/update/delete; `authenticated` gets select, insert, update (choice), delete; `anon` nothing. Deleted with the
  account (`delete-account` table list).
- The app upserts on the unique key (a „Passt nicht" can become „Probiere ich" from the list later only by removing it — not
  built; see non-goals).
- **Alternativen screen:** a section „Probiere ich" above the search, only with ≥ 1 `try` row: one row per item „{Alternative}
  statt {Zutat}", newest first, each with a remove icon (tooltip „Nicht mehr merken") that deletes the row. `skip` rows are
  not listed.

### 4.5 The Buddy's line (priority)
- A new hero cue `dailyReview` (no announcement, no sheet), queued when Home is visible, the card is showing and the line was
  not said for this review day (prefs `daily_review_said_<userId>` = the review day). Line: „Magst du kurz auf deinen Tag
  schauen? Er wartet gleich unter mir. 🌙", held like an announcement line.
- **Priority (queue order):** welcome → a log's follow-up → the Buddy's announcements (streak, goal, „Neue Tipps", the
  weekly-tips and first-tip offers, a day's reward, „Muster frei!") → the reminders ask → guided-test hints (Insights v2, in
  whatever form that track adds) → **the review line** → the rating request (rating track, always last).
- Like the reminders ask, it is skipped for this visit when another cue of the running queue ended in a sheet or page; it
  comes on a later visit of the same review window. It is marked said only when it plays.
- It never opens anything; the card is already on screen.

### 4.6 Settings and the evening notice
- Profile: `daily_review_time` text `HH:MM` (default '19:30'), `daily_review_reminder` boolean (default false). The app
  clamps the time to 16:00–23:30. `anyNotificationOn` includes the reminder; `withNotifications(true)` leaves it as it is (it
  stays opt-in), `withNotifications(false)` turns it off. **`daily_summary_enabled` is the Bauchgefühl reminder, not this.**
- Benachrichtigungen screen: a section „Tagesrückblick" (icon `Icons.nightlight_outlined`) under „Erinnerungen":
  - „Ab" with the time; tap opens the system time picker (24 h). Never greyed (it rules the card). Caption „Ab dieser Uhrzeit
    zeigt dir Home deinen Rückblick auf den Tag."
  - Switch „Erinnerung am Abend", greyed like the others while notifications are not allowed. Caption „Ich sag dir Bescheid,
    wenn er da ist – nur an Tagen mit eingetragener Mahlzeit."
- Scheduling: a one-shot local notification (id 3000, Android channel `daily_review` „Tagesrückblick", payload the Home
  path) at today's `T`, scheduled while: the switch is on, today has ≥ 1 meal, now < `T`, today is not closed. Otherwise
  cancelled. Re-evaluated when the profile, today's meals or the day change. Body: „🌙 Dein Tagesrückblick ist da." —
  with the Buddy's name „🌙 {Name} hat auf deinen Tag geschaut. Dein Tagesrückblick ist da."

### 4.7 After a meal (B2 gaps)
What the code does today: `save()` fires `refresh-ingredient-suggestions` and forgets it; nothing refetches the suggestions
until sign-in or a pull in Entdecken; the success screen and the diary meal say nothing about flagged ingredients. So B2 is
**not** covered; the gaps:
1. The refresh is awaited in the background; when it completes (any `created`), `ingredientSuggestionProvider` is fetched
   again. Errors are logged only.
2. The saved meal's id is kept in the tracker state (`savedMealId`).
3. **Success screen:** if groups for that meal arrive while it is up, a quiet line appears above „Trinken eintragen": one
   ingredient „Zwiebel könnte deinem Bauch zu schaffen machen.", two „Zwiebel und Knoblauch könnten …", more „Zwiebel,
   Knoblauch und 2 weitere könnten …", with „Alternativen ansehen ›" (opens Alternativen). No spinner, no placeholder.
4. **Diary meal detail:** the same line under „Zutaten" whenever the meal has groups.
5. Edit mode: no success screen; the diary line updates after the refetch.

### 4.8 Seams for other tracks
- **Subscription:** `dailyReviewAlternativeLockedProvider` (`Provider<bool>`, false) and `dailyReviewUpsellRouteProvider`
  (`Provider<String?>`, null). The subscription track replaces their bodies with its Alternativen gate and paywall route.
  The B2 line stays free (it names ingredients only); its link goes to Alternativen, which that track gates.
- **Insights v2:** `dailyReviewExtrasProvider` (`Provider<List<DailyReviewLine>>`, empty). A guided test adds e.g. „Tag 3 von
  5 ohne Zwiebel". If a test should keep an ingredient out of the pick, that track adds the parameter to `pickAlternative`.

## 5. Privacy policy text
New personal data: the choices (health-related, derived from the diary). The review itself is built on the device, sends
nothing to Anthropic; the time and the switch are notification settings the policy already names. Paragraph for section 2
(„Welche Daten wir verarbeiten"), after the diary bullet:

> **Tagesrückblick und „Probiere ich“:** Wenn du im Tagesrückblick „Probiere ich“ oder „Passt nicht für mich“ antippst,
> speichern wir diese Auswahl (welche Alternative zu welcher Zutat) in deinem Konto. So findest du deine Ideen unter
> „Alternativen“ wieder, und wir zeigen dir eine Alternative, die nicht zu dir passt, nicht noch einmal. Den Tagesrückblick
> selbst stellt die App auf deinem Gerät aus deinen Einträgen zusammen; dafür wird nichts an Anthropic gesendet. Die Uhrzeit
> deines Rückblicks und ob wir dich daran erinnern sollen, speichern wir mit deinen Benachrichtigungs-Einstellungen. Deine
> Auswahl kannst du unter „Alternativen“ jederzeit entfernen; mit deinem Konto wird sie gelöscht.

No version bump in this track (the controller's shared policy task).

## 6. Non-goals
- No server push per meal, no server job for the review, no LLM call.
- No „Probiere ich" toggle in the suggestion detail sheet; no list of „Passt nicht" items or undo for them.
- No check whether the user later ate the alternative; no streak or reward for it.
- No review in Entdecken, no history of past reviews.
- No „Probiere ich" in the dietitian share.

## 7. Left to the builder
- The card's exact layout (a `BbCard` with the Buddy's small face or none), as long as the texts and order of §4.3 hold.
- Whether the window rule and the pick live in one file or two, as long as both are pure and unit-tested.
- How the hero reads „the card is showing" (the window provider directly is fine).

## 8. Needs from Severin
- Sign-off of the German copy in §4.3, §4.6, §4.7 for tone and health-claims (in particular „könnte deinem Bauch zu schaffen
  machen").
- The policy paragraph in §5, merged into the shared policy bump.

## 9. Manual checks for Severin (device)
- With the reminder on and a meal logged before 19:30, the notice arrives at 19:30 (iOS and Android); on a day without a meal,
  none; after switching it off, none.
- At 19:30 with Home open, the card appears without a restart; the Buddy says his line once.
- The next morning before 11:00 the card shows „Dein Rückblick auf gestern"; after 11:00 it is gone.
- After logging a meal with onion on the production backend, how long until the success-screen line appears (if at all
  before leaving), and that the diary entry shows it afterwards.
