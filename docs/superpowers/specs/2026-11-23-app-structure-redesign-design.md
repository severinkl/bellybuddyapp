# App-Struktur-Redesign: Navigation, Home, Muster, Entdecken — Design

Status: decided in the brainstorm with Severin on 2026-11-23. This doc needs his approval.
Builds on PR #83 (`feat/buddy-onboarding-polish`), which is not merged yet.
Mockups: "Runde 3 · App-Struktur" at https://claude.ai/artifact/1TXEAjPsD821CgJrKXLG4q (private). The local copy is at
`/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/buddy-mockups.html`.

## 1. Intent: why

Severin, after testing PR #83: "es sind derzeit noch so viele andere actions am dashboard, lass das komplett umwerfen …
überleg dir wirklich die gesamte userstory durch und wie derzeit elemente angeordnet sind".

The audit of the app as it stands on the PR #83 branch found:

- **Home is crowded.** It has about 14 tap targets. Meal logging appears 3 times on that one screen: centre button, ring bubble and next-action button. Today's data appears 3 times: ring, "Heute" list and Tagebuch.
- **Two of the four "Für dich" tiles go nowhere useful.**
  - Tipps are paused, and a dialog says "vorerst keine neuen Empfehlungen".
  - Rezepte "Inspiration" is a placeholder.
  - Wissen opens an external blog.
- **Logging is uneven.** The centre button is labelled "Essen tracken" and logs only meals. Drinks can't be logged from the Tagebuch. Klo has 2 entry points.
- **Naming is inconsistent.** A meal has about 8 different names, and Klo, Tipps, Alternativen, Streak and Tagebuch each have several.
- **No patterns or insights exist anywhere.** The health consent text promises "Muster und FODMAP-Hinweise".
- **Settings are hard to reach.** They are only reachable through the Home gear. Buddy name and streak goal can't be changed there, and the tutorial can't be replayed.

The app's promise is "find out what's good for your gut". The Buddy loop (logging = caring) is the daily habit, and
insights are the reason the habit pays off.

## 2. Goals, non-goals, anti-goals

**Goals**
- Home answers one question: what should I do now, and how is my gut doing? That means one obvious next action and one insight.
- Every log type can be started from one place (the centre plus), on every tab, with the same behaviour.
- Users see honest patterns from their own data once there is enough data.
- Content (tips, alternatives, recipes, knowledge) lives in its own tab and never leads to empty pages.
- The Buddy, the streak, settings and feedback live in their own tab ("Ich").
- One vocabulary across the whole app.

**Non-goals (this project)**
- New tracker capabilities: the notes field, changing the time of drink/Bauchgefühl/Klo entries, delete confirmation or undo in the diary.
- AI FODMAP scoring of meals in the app.
- Recipe "Inspiration" content.
- Paywall or premium.
- Social features.

**Anti-goals**
- No invented statistics, no efficacy claims, and nothing that reads like a diagnosis. Every insight is an observation from the user's own entries, with counts, and carries "kein medizinischer Befund".
- No guilt and no punishing pet. Bad gut days never make the Buddy sick or sad at the user.
- Home must not end up busier than the mockup H2.
- No tile, row or link may lead to an empty, paused or placeholder screen.

## 3. Constraints

- **Repo rules:** follow the repo's `CLAUDE.md`.
  - Colours, font sizes, spacing and radii go only through `AppTheme`/`AppConstants`.
  - German UI.
  - Riverpod AsyncNotifier, GoRouter, `AppLogger`.
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- **Naming:** the mascot is "Belly Buddy". Never "Bauch-Buddy".
- **Layout checks:** reduced motion is respected. Text scale 1.3 and a 375×667 phone must not overflow.
- **Data access:** PostgREST caps responses at 1000 rows (`PGRST_DB_MAX_ROWS`), so multi-day queries paginate.
- **Deep links must keep working.** Notification taps route to `/meal-tracker`, `/gut-feeling-tracker`, `/recommendations`, `/ingredient-suggestions` and `/dashboard`. These routes stay valid (`/dashboard` = Home tab).
- **Gate order is unchanged.** Upgrade gate → auth → health consent → Buddy onboarding gate, including the new `/loading` hold from PR #83.
- **Process per stage ("übliche Routine"):** build via plan → `/simplify` → `/code-review` → fix findings → PR to the stage's base.
  - Integration tests run on a second simulator.
  - Severin tests each stage locally.
  - One release at the end.

## 4. Approaches considered (decided in the brainstorm)

| Decision | Options considered | Chosen |
|---|---|---|
| Home's job | Buddy + Heute + 1 Erkenntnis; only Buddy & care; insights first | **Buddy + Heute + 1 Erkenntnis**: care loop for the daily habit, insight as the payoff. Insights-first is empty in week 1; care-only hides the value one tab away. |
| Navigation | 3 tabs + plus; 4 tabs + plus with a Muster tab; stay at 2 tabs | **Tabs Home · Tagebuch · (+) · Entdecken · Ich**: 3 content tabs + plus were chosen, then "Ich" replaced a Home menu so the plus sits centred. |
| Plus button | chooser for all 4 types; meals direct + long-press | **Chooser for all 4**: same everywhere, fixes drinks and Klo. |
| Insights v1 | good/hard days + "Fällt mir auf"; trends only; AI weekly review | **Good/hard days + "Fällt mir auf"**, computed in-app over 30 days. |
| Entdecken content | only what works; show all marked as paused/soon; restart tips | **Restart tips**: Tipps + Alternativen + Meine Rezepte + Wissen ("Inspiration" hidden). |
| How tips arrive | weekly automatic (core job); on demand; admin panel as before | **Weekly automatic** from a core worker job. |
| Home layout | H1 Buddy-Bühne (Heute row); H2 ring stays; H3 card stack | **H2 ring stays**: the PR #83 ring as a display around the Buddy. |
| Menu vs tab | 4th tab "Ich"; menu top-right on Home | **4th tab "Ich"**. |
| Insight rules | "Schlecht" = hard with a 24 h window; same day | **"Schlecht" = hard, 24 h before**. |
| Wissen categories | only "Gesund verdauen" + "Rezepte"; everything | **Everything, with a category filter**. |
| Build/release | 3 stages, 1 release; 3 stages, 3 releases; one big PR | **3 stages with their own PRs, one release at the end**. |

## 5. Design

### 5.1 Navigation
- **Bottom bar:** five slots: **Home · Tagebuch · (+) · Entdecken · Ich**.
  - The plus is the raised centre button. It is labelled "Eintragen", replacing "Essen tracken".
  - The four tabs are `StatefulShellRoute` branches. Existing paths stay as they are: `/dashboard` = Home, `/diary` = Tagebuch. New: `/discover` = Entdecken, `/me` = Ich.
- **Edge swipe between tabs:** *(my call)* removed. With 4 tabs it is ambiguous, and it conflicts with the Tagebuch's day swipe.
- **Settings screen:** it moves under Ich. `/settings` and its children stay as pushed routes, opened from Ich.
- **Onboarding gate:** it keeps intercepting the shell roots. All four tab roots count.

### 5.2 Plus sheet ("Eintragen")
- **Contents:** a modal bottom sheet with 4 large buttons: **Essen**, **Trinken**, **Bauchgefühl**, **Klo** (same icons/emoji as today's ring).
  - It is headed by the target day/time: "Heute · 12:40", or in the Tagebuch "Für Mi, 18. Nov".
  - The type that Home's next action suggests is visually highlighted.
- **From Home:** the trackers open with "now".
- **From the Tagebuch:** the trackers open with the shown day preselected, and the current time of day if that day is today. Otherwise the time is 12:00 *(my call)*. Each tracker already has date/time chips; pass the initial date in.
- **Tagebuch empty state:** the Bauchgefühl/Klo cards are replaced by a short Buddy line pointing to the plus *(my call)*.

### 5.3 Home (variant H2)
From top to bottom (see the mockup H2, three states):
1. **Streak chip** ("🔥 n Tage"), top left. Tapping it opens the existing "Dein Streak" sheet: week row, goal, savers, "Ziel ändern" with select + "Ziel festlegen".
   - The week row moves off Home and lives only in that sheet *(my call, matches the mockup)*.
   - There is no feedback or settings icon on Home any more.
2. **Speech bubble + Buddy inside the care ring (from PR #83):**
   - The ring segments and the four counters (Essen n/3, Trinken n/6, Bauchgefühl ✓/–, Klo n×) are **display only**. They are not separate buttons.
   - **Tapping the ring area** opens the Tagebuch on today *(my call: the numbers must not look tappable and then do nothing)*.
   - Tapping the Buddy keeps doing what it does today (he talks).
   - The glow highlights the suggested need.
3. **One next-action button** (from `nextCareAction`): "🍳 Frühstück eintragen", "💧 Trinken eintragen", "🙂 Bauchgefühl eintragen" and so on.
   - When everything is done, the fallback label is "Essen eintragen", no longer "Füttern".
   - It opens the tracker directly.
4. **Insight card** (§5.5): locked progress or the strongest observation. Tapping it opens the Muster page.
5. **Tips row, only when an unseen weekly tip set exists:** "✨ Neue Tipps · Woche 47 · 3 Tipps ›". It opens the Tipps.
   - The Buddy announces them once via the existing announcement queue: "Neue Tipps sind da! ✨".
6. **Removed from Home:**
   - the four need bubbles as buttons
   - the "Heute" list and its diary link
   - the "Für dich erstellt" tiles
   - the feedback and settings icons
   - the dashboard notification opt-in dialog stays as is; it already shares the "offered" flag with the onboarding reminder step.

Tap targets: chip, Buddy, ring → Tagebuch, button, insight card (plus the tips row on tips days), plus the bottom bar.

### 5.4 Tagebuch
- **Unchanged** except for the plus context (§5.2) and the empty state.
- **Vocabulary fixes:** §5.9.

### 5.5 Insights: insight card + Muster page (`/patterns`, pushed route)

**Data.** The last 30 local calendar days, including today:
- meal entries (`tracked_at`, `ingredients`)
- gut-feeling entries (`tracked_at` plus all rating fields)
- for the unlock rule only, the distinct days with any entry (the streak engine already has activity days)

Fetch with pagination. Recompute after any entry write; the entries reload mechanism from PR #83 already fires on writes. Cache for the session.

**Classification.** Uses the existing `calculateGutFeelingRating`:
- **hard ("schwer")** = level `schlecht` (average > 3.5, higher = worse).
- **good ("gut")** = levels `spiGut` or `gut` (average ≤ 2.5).
- **medium** = `durchschnittlich`.

The brainstorm question said "Schnitt ≤ 2 von 5". That was a wording slip about the scale's direction. The decision is "the existing Schlecht category".

A **day's class** comes from the average rating of that day's gut-feeling entries, mapped with the same thresholds. Days without a gut-feeling entry are "kein Eintrag".

**Unlock.** At least **7 distinct days with any entry** in the window **and at least 3 gut-feeling entries** in the window.
- The locked card shows both progress bars, e.g. "Tage mit Einträgen 2 von 7" and "Bauchgefühl-Einträge 1 von 3".
- It also shows a Buddy line, e.g. "Noch 5 Tage, dann zeig ich dir erste Muster."

**"Fällt mir auf"** (ingredients before hard days):
- **Window per hard day:** the 24 hours before the **first hard entry** of that day. Same for good days, with the first good entry.
- **Matching:** an ingredient "was there" if any meal whose `tracked_at` falls in the window lists it. Ingredient names are compared trimmed and case-insensitively.
- **Counts:** for each ingredient, `hard = number of hard days it was there`, `good = number of good days it was there`, against `H = #hard days` and `G = #good days`.
- **Section threshold:** the section appears only when `H ≥ 3`.
- **Shown:**
  - Ingredients with `hard ≥ 3` and `hard/H ≥ 0.5` and `hard/H − (G > 0 ? good/G : 0) ≥ 0.25`.
  - Sorted by `hard`, then by the gap; at most 5.
  - Each row reads "Zwiebel · an 4 von 5 schweren Tagen dabei · an guten Tagen: 1 von 6".
  - *(my call on the exact thresholds; they implement "deutlich häufiger" and the builder may tune them only with Severin)*
- **Weak observations:** up to 3 ingredients with `hard == 2` that pass the rate rules, marked "noch unsicher".
- **Nothing passes:** "Noch fällt mir nichts Eindeutiges auf – trag weiter ein, dann sehe ich mehr."

**Good and hard days.** Two columns: "Deine guten Tage" and "Deine schweren Tage" (counts).
- **Column threshold (Severin):** a column appears only when there are **at least 3 days** of its class in the window. Otherwise it shows "Noch zu wenige gute/schwere Tage".
- **"oft dabei":** an ingredient qualifies when it was there (same 24 h windows) on **at least 2** of those days **and on at least half of them**.
- **Display:** at most 5 per column, each with its count, e.g. "an 3 von 4 guten Tagen".
- **Precedence:** the mockup's example "Kaffee … schwach" is illustrative; these rules win.

**Muster page.**
- A 30-day calendar coloured gut / mittel / schwer / kein Eintrag (shapes or labels as well, not colour alone).
- The good/hard columns and the "Fällt mir auf" list.
- The fixed line "Beobachtung aus deinen Einträgen, kein medizinischer Befund."
- Locked state: the progress bars plus a blurred preview, as in the mockup.

**Home insight card picks:**
1. The top "Fällt mir auf" item.
2. Otherwise the good-days summary, using the same thresholds as the good-days column: "An guten Tagen gab's oft Haferflocken, Reis und Karotte".
3. Otherwise the "noch nichts Eindeutiges" line.

The card always shows "kein Befund".

**Logic location.** A pure, unit-tested function (e.g. `lib/services/insights/`) from entries + now to an insights result. A provider owns loading and caching.

### 5.6 Entdecken tab (`/discover`)
Sections, in order:
1. **Tipps:**
   - A card for the newest recommendation set: "Neu · Woche 47" while unseen, plus summary and item count. It opens the existing recommendations screen, renamed **"Tipps"** in the UI.
   - The **pause notice dialog is removed**.
   - **Opt-in (Severin, privacy):** weekly tips are off by default.
     - While off, the Tipps card shows a switch **"Wöchentliche Tipps"** with one sentence: "Dafür schicke ich deine Mahlzeiten und dein Bauchgefühl der letzten Woche an unseren KI-Dienst." Turning it on is the user *requesting* recommendations, as the privacy policy already describes, so there is no policy change and no re-consent.
     - The same switch is in Settings → Benachrichtigungen. It is separate from the push toggle "Empfehlungen & Tipps", which only controls the push.
     - The Buddy offers it once, after the insights unlock (day 7), via the announcement queue.
     - Previously generated recommendations stay visible regardless.
   - Empty state when on: "Deine ersten Tipps kommen am Montag, wenn du diese Woche mindestens 5 Mahlzeiten einträgst."
2. **Alternativen:** a preview of the newest 3 plus "Alle ›" (the existing screen, titled **"Alternativen"**).
3. **Meine Rezepte:** a preview plus "+" (the existing chooser). The "Meine Rezepte | Inspiration" toggle is removed, so only own recipes remain.
4. **Wissen:**
   - The myfodmap blog articles in the app, from the Wix RSS feed `https://www.myfodmap.at/blog-feed.xml`, with **all categories**.
   - A category filter row: "Alle" plus the categories found in the feed.
   - Each article shows title, category, date and image if present. Tapping opens it in the **in-app browser** (`url_launcher` `LaunchMode.inAppBrowserView`).
   - The feed is cached for 6 hours *(my call)*, with loading and error states, and the last successful copy is shown offline.
   - XML parsing: use the small `xml` package if needed *(builder may decide; justify any new dependency)*.

**Badge.** The Entdecken tab shows a dot while an unseen tip set or new alternatives exist.

### 5.7 Weekly tips (bellybuddy-core)
- **Worker job.** A new schedule in `backend/app/worker.py` (APScheduler, Europe/Vienna, with a Sentry cron monitor like the existing jobs) runs **Mondays 08:00** *(my call)*.
- **Opt-in column:** a new profile column `weekly_tips_enabled boolean not null default false` (core migration 0009, owner-updatable like the other profile settings). The app reads and writes it.
- **Eligible users** meet all of these:
  - `weekly_tips_enabled = true`;
  - health consent for the **current** privacy policy version;
  - at least 5 meal entries in the previous 7 days.
- **Idempotent:** skip a user who already has a recommendation created in the current ISO week.
- **Generation** reuses `app.domain.recommendation_core`: the same FODMAP data path and prompts as `diet-recommendations`.
  - The prompts hard-code "letzte 3 Tage", and gut entries are fetched for 3 days. *(My call:)* make the window a parameter. The weekly job uses **7 days** for meals and gut-feeling entries; `diet-recommendations` and the admin endpoints keep 3.
  - The input is built server-side from the profile's intolerances and diet.
  - The prompt's first-tips greeting ("Speisen … zu tracken") is aligned with the vocabulary ("eintragen").
  - Results are saved like today.
- **Go-live *(my call)*:** the job ships **disabled** (kill switch default off). Severin enables it after the app release has spread, so the Monday push never sends old-app users into the old pause dialog.
- **Push.**
  - Only for users with `push_enabled`: the "Empfehlungen & Tipps" toggle.
  - Copy in the Buddy voice, e.g. "Neue Tipps von deinem Belly Buddy ✨".
  - Route: the Tipps screen (`/recommendations`) *(the existing push route `/dashboard` changes)*.
  - Uses the existing throttle.
- **Kill switch.** A setting/env flag disables the job. The admin endpoints stay unchanged.
- **Tests and deploy.** Unit tests plus a DB test for eligibility and idempotency. Deploy via the normal core PR → develop → main → `deploy-prod`.

### 5.8 Ich tab (`/me`)
- **Buddy header:** the Buddy (small, animated), his name with **"Umbenennen"** (validated like onboarding, saved via `buddyProvider`), and the streak chip.
- **List:**
  - **Streak & Ziel** opens the "Dein Streak" sheet.
  - **Einstellungen** pushes the existing settings screen: Profil, Benachrichtigungen, Konto & Sicherheit, Datenschutz.
  - **Tutorial wiederholen** resets the tutorial flag, switches to Home and starts it.
  - **Feedback geben** opens the external form, as today.
  - **App version** is shown in small print.
- **Clean-up:** Feedback is removed from the Settings screen, since it now lives in Ich.

### 5.9 Vocabulary (applied app-wide: UI strings, tutorial, notification copy, semantics)

| Concept | Use | Replace |
|---|---|---|
| verb | **eintragen** | tracken, erfassen; "Füttern" only in the Buddy's bubble |
| types | **Essen, Trinken, Bauchgefühl, Klo** | Mahlzeit (as an action), Speisen, Getränk tracken/hinzufügen, Toilettengang, Stuhlgang, Toiletten-Einträge |
| buttons | **Speichern, Weiter** (capitalised) | speichern, weiter |
| streak | **Streak** | Serie |
| history | **Tagebuch** | Logbuch, Essens-Tagebuch, Ernährungstagebuch |
| tips | **Tipps** | Empfehlungen (UI), "Feedback zu deinen Speisen" |
| alternatives | **Alternativen** | Zutaten-Vorschläge |
| home | **Home** | Dashboard (UI text) |

Legal and consent texts change only where they name app sections, and only to match the new names; no change in meaning. Tracker titles may keep their playful style ("Am Klo 💩 gewesen?").

### 5.10 Tutorial
- **Spotlight steps** are rewritten for the new layout:
  1. Buddy + ring
  2. next-action button
  3. plus ("hier trägst du alles ein")
  4. insight card
  5. Tagebuch tab
  6. Entdecken tab
  7. Ich tab
- **Corrections:** the false claims go ("Speisen und Getränke" on the old button; Tipps "1 x pro Tag").
- **Replay:** it can be replayed from Ich.

## 6. Stages (each: plan → build → `/simplify` → `/code-review` → fixes → PR; Severin tests locally)

- **Stage 1: Navigation & Home** (app; branch `feat/app-structure`, stacked on PR #83).
  - Covers: §5.1, 5.2, 5.3 (insight card in **locked state only**, fed by activity days + gut-feeling count), 5.4, 5.6 as a **hub of the existing screens** (Tipps without the pause dialog, Alternativen, Meine Rezepte without Inspiration, Wissen as an external link for now), 5.8, 5.9, 5.10.
  - The tips row on Home comes in Stage 3.
- **Stage 2: Insights** (app, stacked on Stage 1): §5.5 complete, including the unlocked card states and the Muster page.
- **Stage 3: Entdecken complete** (app, stacked on Stage 2, plus a core PR to develop):
  - Wissen RSS in-app (§5.6.4).
  - The weekly-tips opt-in switch and the Buddy's offer (§5.6.1).
  - The tips row and Buddy announcement on Home (§5.3.5).
  - The Entdecken badge.
  - In core: the `weekly_tips_enabled` migration 0009 and the weekly tips job (§5.7), shipped disabled.
- **Release:** together after Stage 3.
  - Deploy order: core first (0008 `buddy_state`, 0009 `weekly_tips_enabled`, job disabled), then the app.
  - Severin enables the job after the app release has spread.

## 7. Left to the builder
- File and widget structure, provider shapes, and how to pass the initial date into trackers.
- Exact spacing and animation details within the mockups; the RSS parsing approach; cache details.
- Test design (unit tests for the insights function and eligibility; widget tests for Home/Plus/Ich/Entdecken; integration tests updated for the new nav).
- Must be decided **with Severin, not alone:** the insight thresholds, any change to the decided vocabulary, and anything that adds tap targets to Home.
