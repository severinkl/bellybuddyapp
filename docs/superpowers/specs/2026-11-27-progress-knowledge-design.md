# Dein Verlauf + Wissen „Für dich" (Progress view, matched knowledge) — Design

**Status:** direction from the controller (tracks B5 and B6 of the business-plan gap analysis); every decision not
given there is Claude's call, labelled below with what it costs if wrong.
**Repo:** app `severinkl/bellybuddyapp` only, branch `feat/progress-knowledge` from `origin/develop`. **No core change**
(see §2.1). Track id `PR` (`PRA` app tasks). Plan: `docs/superpowers/plans/2026-11-27-progress-knowledge.md`.

## 1. Intent

The business plan promises two things the app does not do yet:

1. **„Wie es dir über die Wochen geht"**: the user sees their own course. Today the app has the 30-day „Muster" calendar
   (behind Home's insight card, and the paid part once the paywall is on), the Buddy's streak and the diary one day at a
   time. Nothing shows twelve weeks at a glance, how the four symptoms move, or how regularly the user logs.
2. **Wissen that fits the user**: today „Entdecken" lists the newest three myfodmap.at articles and „Wissen" lists them
   all, the same for everyone.

**Success:** from „Ich" a user opens „Dein Verlauf" and sees, for the last 12 weeks, every day as good / mittel / schwer /
eingetragen / leer (shape and colour), per week „5 gute Tage, 1 schwerer" and how many days they logged, their current
and longest streak, and once there is enough data a small bar trend per symptom. In Entdecken and Wissen, up to three
articles that fit what they logged or told the app come first, each with one careful line why.
**Anti-goals:** a score, a grade or a comparison that blames („weniger eingetragen als letzte Woche"); a number from too
little data; anything that reads like a diagnosis; a new chart dependency; a per-day request; new personal data on the
server.

## 2. Decisions

| # | Topic | Decision | Whose (cost if wrong) |
|---|---|---|---|
| 1 | Primary entry | A row „Dein Verlauf" in „Ich", directly below „Streak & Ziel"; a secondary link at the bottom of the Muster page | Claude (a tab users visit less than Home; a Home link is one more row later) |
| 2 | Free or paid | **Free** with the paywall on: it is the user's own diary shown differently; „Muster" stays the paid analysis. The route is not wrapped by `plusAccessProvider` | controller default, kept (if Severin wants it paid: one gate on the route + the Ich row) |
| 3 | Window | 12 Monday-to-Sunday weeks, the current one included (up to 84 days), one fetch of four tables, recomputed after an entry write or a new day | Claude (12 weeks of rows for heavy loggers is a few thousand rows paged; fine) |
| 4 | Day class | Exactly the Muster's: mean of the day's gut-feeling scores (worst gut symptom). The private helper becomes a shared public function; the engine and its shared vectors stay unchanged | brief |
| 5 | Word for hard days | „schwer", as in the Muster legend, the columns and the dietitian view — not „schwierig" | Claude (copy-only change) |
| 6 | Enough data | A week's symptom means need ≥ 3 gut-feeling entries on ≥ 2 days; the trend shows once ≥ 2 weeks have means | Claude (thresholds are constants in `ProgressRules`) |
| 7 | Comparisons | Only one positive comparison is ever said („Letzte Woche hattest du mehr gute Tage als die Woche davor."); nothing is said when it went the other way | Claude |
| 8 | Chart | Custom-painted bars, no package (the app has no chart package) | brief |
| 9 | Longest streak | Longest run of counted days (any entry or a saved day) inside the window, shown as at least the current streak | Claude (a run longer than 12 weeks shows as the current one, which is right) |
| 10 | Matching runs | In the app; deterministic keyword scoring; no server, no LLM | brief |
| 11 | Matching signals | Muster „Fällt mir auf" items, profile intolerances, profile symptoms, this week's high symptoms / stress / Klo consistency; opened articles excluded | Claude |
| 12 | Muster signal and the paywall | The Muster signal is a parameter (`includePatterns`) so the subscription track can turn it off for locked users (otherwise the reason line leaks the paid result); `true` until that track wires it | Claude (the seam is one line) |
| 13 | Read state | Local only: shared preferences per user and device, the last 50 opened links | Claude (read state does not follow the user to a new phone) |
| 14 | „Für dich" placement | Entdecken's Wissen section shows the picks first (with their reason) and fills up to 3 with the newest; Wissen shows a „Für dich" block above the list while „Alle" is selected | Claude |
| 15 | Teaser | The parser reads the feed's `<description>` as `teaser` (shown nowhere new; only matched against) | Claude (needed: titles alone match almost nothing) |

### 2.1 What the code says against the brief (Claude's ruling)

- **There is no knowledge table or sync job in core.** The app fetches `https://www.myfodmap.at/blog-feed.xml` itself
  (`KnowledgeFeedService`), parses it (`knowledge_feed_parser.dart`) and caches it in shared preferences for 6 h. So the
  track is app-only and „matching on the server" is not an option worth building.
- **The articles carry no usable tags.** One `category` per item and only three in the live feed (checked 2026-11-26:
  20 items — 13 „Gesund verdauen", 5 „Rezepte", 2 „Persönliches"). The items do have a teaser (`<description>`), which
  the parser drops today. Hence the keyword map against title + teaser (§4.2).
- **The feed is small (20 articles), so „Für dich" will often be empty or hold one article.** Realistic hits in today's
  feed: Verstopfung („Reizdarm Typ: Verstopfung"), Durchfall („Durchfall bei Läufer"), Stress („Einfache
  Stressbewältigung bei Reizdarm", „Darm-Hirn-Achse …"), Gluten (the „glutenfrei" recipes). Ingredient hits from the
  Muster will be rare. That is fine: the fallback is today's order.
- **„Durchschnittlich" is banned** by `test/utils/vocabulary_test.dart`; the trend says „im Schnitt".

## 3. Approaches considered

- **A „Verlauf" tab inside the Muster page.** Rejected: Muster is reached only from Home's card and becomes paid; the
  progress view is meant to be free and findable.
- **Tagebuch as the entry.** Rejected: its app bar is the day pager and the page is one day; a twelve-week view does not
  belong to a day.
- **„Ich" row + Muster link (picked).** „Ich" is the stable place for the user's own things (Streak & Ziel, Teilen); the
  Muster link catches users who are already looking at patterns.
- **Reuse the insights provider's 30-day source.** Rejected: 30 days is not „über die Wochen", and widening it would
  change the mirrored engine and its vectors shared with core.
- **A chart package (fl_chart).** Rejected: four rows of twelve bars are a few lines of `CustomPainter`.
- **Server-side matching / read state.** Rejected: the feed lives in the app; read state on the server would be new
  personal data for no gain.

## 4. Design

### 4.1 Dein Verlauf

**Route** `/progress` (`RouteNames.progress = 'progress'`, `RoutePaths.progress = '/progress'`), a pushed page like
`/patterns`; opened without a page below, back goes to `/me`.

**Entries.** „Ich": a `BbSettingsItem` „Dein Verlauf", subtitle „Wie es dir über die Wochen geht", icon
`Icons.calendar_view_week_outlined`, directly after „Streak & Ziel" (always shown, signed in). Muster page: a text link
„Deinen Verlauf über 12 Wochen ansehen ›" under the footer, locked or unlocked.

**Data.** One `ProgressSource` per load: all gut-feeling entries (`*`), toilet entries (`tracked_at, stool_type`), and
`tracked_at` of meals and drinks since the window's first Monday, paged like `fetchInsightSource`, four queries in
parallel. `progressProvider` (AsyncNotifier) watches `currentUserIdProvider`, `entriesRevisionProvider` and
`todayProvider`, so it reloads after a write or at midnight and keeps showing the previous value while it reloads
(screens read `.value`). The Buddy's `savedDays` come from `buddyProvider` for the longest streak.

**Computation** (pure, `computeProgress(source, now:, savedDays:)`, every threshold in `ProgressRules`):
- Window: Monday of the current local week minus 11 weeks, to the end of today. Days after today in the current week
  are `future` (shown blank, never counted).
- Per day: `dayClass` by the shared `dayClassOf` (§2 #4), `active` = any entry of any table that day. Days are the
  wall-clock date of `tracked_at` (never `toLocal()`).
- Per week: counts of good / medium / hard days, `activeDays`, `elapsedDays` (7, or up to today), gut-feeling entry
  count, and `means` (bloating, gas, cramps, fullness, each the mean of the week's entries, 1–5) only with ≥ 3 entries on
  ≥ 2 days; otherwise `null`.
- Totals over the window: good / medium / hard, active days of elapsed days, the longest run of counted days (active or
  saved).
- `recent` (for §4.2): the last 7 local days, today included: symptom means and stress mean (entries with `stress`) with
  ≥ 3 entries; Klo entries, hard ones (`stool_type` 1–2) and loose ones (4–5).

**Page, top to bottom** (signed-in user with some entries):
1. Header line (muted): „Die letzten 12 Wochen".
2. Three count tiles, each icon + number + label, reusing `dayClassLook` (icon and fill): „34 gute Tage", „12 mittlere",
   „6 schwere" (singular „1 guter Tag", „1 mittlerer", „1 schwerer").
3. The positive line, only when it holds (last complete week has more good days than the one before, both with ≥ 3
   rated days): „Letzte Woche hattest du mehr gute Tage als die Woche davor."
4. Two streak tiles: „Aktueller Streak" with „$n Tage" / „1 Tag" / „Startet mit deinem nächsten Eintrag" (0), and
   „Längster Streak" with the same number forms and the sub-label „in den letzten 12 Wochen". The longest shows
   `max(progress.longestStreak, buddy streak)`; the current is `BuddyStatus.streak`, the same number as Home.
5. „Eingetragen an 61 von 84 Tagen" (elapsed days of the window).
6. **The weeks**, newest first, 12 rows. Each row: the week label („Diese Woche", else „17.–23. Nov", across months
   „27. Okt – 2. Nov"), seven day cells, and one line under them: the counts („5 gute Tage, 1 schwerer"; first part with
   the noun, the rest adjective only, zero classes left out; „Kein Bauchgefühl eingetragen" when none) and „· an 6 von 7
   Tagen eingetragen" („· heute eingetragen" / „· heute noch nichts eingetragen" for a current week on its first day).
   Cells: a class's fill and icon (`dayClassLook`); an active day without gut feeling an outlined cell with a small
   dot (`Icons.circle`, `AppTheme.mutedForeground`); a day without entries an outlined empty cell; a future day nothing.
   Never colour alone: every class has its own icon; to a screen reader each cell reads „18. Nov: gut", „18. Nov:
   eingetragen, ohne Bauchgefühl", „18. Nov: kein Eintrag". Legend under the weeks: the three class icons with
   „gut / mittel / schwer", the dot „ohne Bauchgefühl", the outline „kein Eintrag".
7. **Beschwerden pro Woche** (section label), only when ≥ 2 weeks have means: four rows, one per symptom (the labels of
   `AppConstants.gutFeelingSymptoms`: Blähbauch, Blähungen, Krämpfe, Völlegefühl), each 12 bars oldest left to newest
   right, height = mean on the 1–5 scale, `AppTheme.progressTrendBar`; a week without means a hollow small circle on the
   baseline (`AppTheme.border`). Caption: „Im Schnitt pro Woche, 1 = gar nicht, 5 = sehr stark. Niedrige Balken heißen
   weniger Beschwerden. ○ = zu wenig Einträge." To a screen reader each row reads „Blähbauch: diese Woche im Schnitt
   2,3 von 5; vor 12 Wochen 3,1" — the newest week with means and the oldest week with means, one decimal, German comma,
   „zu wenig Einträge" where a mean is missing. Below the threshold the section shows the line „Wie sich deine
   Beschwerden entwickeln, zeige ich dir, sobald zwei Wochen genug Bauchgefühl-Einträge haben (mindestens 3 pro
   Woche)."
8. Footer: `InsightCopy.footer` and `InsightCopy.dayDefinitions` (same wording as the Muster page).

**Empty state** (no entry at all in the window): the Buddy (`AppConstants.mascotClueless` or the existing happy asset),
title „Dein Verlauf füllt sich bald", body „Trag dein Bauchgefühl ein – dann siehst du hier Woche für Woche, wie es dir
geht.", button „Bauchgefühl eintragen" → `RoutePaths.gutFeelingTracker`.
**Sparse**: any entries: the full page; weeks show what they have; the trend section shows its line until it has two
weeks.
**Loading / error**: `BbLoadingState`; `BbErrorState` „Dein Verlauf konnte nicht geladen werden." with „Nochmal
versuchen". Pull to refresh reloads.

**Colours.** New token `AppTheme.progressTrendBar = primary` (an alias, like `careGutSoft`). Everything else reuses the
gut-feeling tokens through `dayClassLook`.

### 4.2 Wissen „Für dich"

**Article model.** `KnowledgeArticle` gains `String? teaser` (the item's `<description>`, entities decoded, trimmed,
null when empty). `toJson` writes it; `fromJson` accepts a cached copy without it (the v1 cache key stays; a fresh fetch
within 6 h fills it).

**Read state.** `knowledgeOpenedProvider` (AsyncNotifier<Set<String>>): the signed-in user's opened article links from
shared preferences `knowledge_opened_<userId>` (string list, newest last, at most 50). Every article tap in Entdecken and
Wissen calls `markOpened(link)` before opening it. Signed out: empty.

**Signals** (built from what the app holds; each signal = keywords + weight + reason):

| Signal | Source | Keywords | Weight | Reason line |
|---|---|---|---|---|
| Muster item, literal | `insights.unlocked`, `noticed` not `uncertain`, first 3 | the item's name, whole word | 5 | „Weil {Name} bei dir auffällt" |
| Muster item, via group | same item; its name has a word starting with a group prefix (§ map) | the group's article keywords | 4 | „Weil {Name} bei dir auffällt" |
| This week: symptom | `progress.recent` mean ≥ 3.0 (≥ 3 entries) per symptom | symptom keywords | 4 | „Weil du diese Woche öfter {Symptom} eingetragen hast" |
| This week: stress | `recent` stress mean ≥ 3.0 (≥ 3 values) | stress keywords | 4 | „Weil du diese Woche öfter gestresst warst" |
| This week: Klo hard | ≥ 2 hard and hard ≥ half of the week's Klo entries | Verstopfung keywords | 4 | „Weil es beim Klo diese Woche öfter hart war" |
| This week: Klo loose | ≥ 2 loose and loose ≥ half | Durchfall keywords | 4 | „Weil es beim Klo diese Woche öfter weich war" |
| Intolerance | `profile.intolerances` | intolerance keywords | 3 | „Weil du {Intoleranz} angegeben hast" |
| Profile symptom | `profile.symptoms` | symptom keywords | 2 | „Weil du {Symptom} angegeben hast" |

**Scoring.** An article's text is its title + teaser. A signal matches when any of its keywords occurs at a word start
(case-insensitive, Unicode letters; literal Muster names as whole words). Muster signals never match articles whose
category is „Rezepte" (a hard-day ingredient must not lead to a recipe with it). Score = sum of the weights of the
distinct matching signals; the reason is that of the highest-weight matching signal (ties: table order). Candidates:
articles with score > 0 not in the opened set. Order: score desc, then newest, then link. At most 3.

**Fallback.** No candidate → no „Für dich" anywhere; Entdecken shows the newest 3 as today; Wissen unchanged.

**Keyword map** `lib/services/knowledge/knowledge_keywords.dart`, one file, tested. No disease names (no „SIBO", „Leaky
Gut", „Zöliakie"), so a match never suggests a condition:
- Intolerances (profile values of `AppConstants.intoleranceOptions`): Laktose → laktose, milchzucker; Gluten → gluten;
  Weizen → weizen, gluten; Fruktose → fruktose, fructose, fruchtzucker; Histamin → histamin; Sorbit → sorbit,
  zuckeralkohol; Nüsse → nuss, nüsse; Eier → eier; Soja → soja.
- Symptoms (profile values of `kSymptomOptions` and the four tracker symptoms): Durchfall → durchfall; Verstopfung →
  verstopf; Blähungen → blähung; Blähbauch → blähbauch, blähung; Völlegefühl → völlegefühl; Bauchschmerzen →
  bauchschmerz; Krämpfe → krampf, krämpf; Sodbrennen → sodbrennen; Übelkeit → übelkeit; Stress → stress, darm-hirn.
- Ingredient groups (word-start prefixes of a Muster item's name → intolerance key): Laktose ← milch, joghurt, sahne,
  käse, quark, topfen; Gluten ← brot, nudel, pasta, weizen, dinkel, semmel, brötchen; Fruktose ← apfel, birne, honig,
  mango. („Hafermilch" does not start a word with „milch", so it is no Laktose hit.)

**UI.**
- Entdecken's Wissen section: the picks first, each tile with its reason as a second line in `AppTheme.captionMutedStyle`
  instead of the „Kategorie · Datum" line; then the newest non-picked articles up to 3 in all.
- Wissen page: with „Alle" selected and picks present, a label „Für dich", the caption „Ausgewählt nach deinen Einträgen
  und Angaben.", the pick tiles with reasons, then a label „Alle Artikel" and the list without the picks. Any other chip:
  unchanged.
- A tile's semantics read the reason after the title.

**Seam for the paywall.** `forYouProvider` passes `includePatterns: true`; the subscription track replaces it with
„Plus access is open". Knowledge stays free.

## 5. Privacy policy text

None. No new data leaves the device or is stored on the server: the progress view reads existing entries, matching runs
on the device, and the opened-articles list stays in local storage.

## 6. Non-goals

- No new content, no LLM, no server ranking, no analytics on taps.
- No diet signal (the feed has no vegan/vegetarian articles worth ranking).
- No editing from the progress view, no export, no sharing of it (the dietitian view has its own course strip).
- No change to the 30-day insights engine's behaviour or its shared vectors.
- No Home entry for the progress view.

## 7. Left to the builder

- Cell and tile sizes (add `AppConstants` values), the exact Buddy asset of the empty state, the week-label helper (use
  `kMonthShortNames`).
- Whether `forYouProvider` is a `Provider` over the other providers' `.value`s or a small notifier, as long as it
  shows nothing until the feed and the profile have values, and the pure scorer is tested without widgets.
- How the legend is shared with the Muster calendar (extracting its private `_Legend` is fine).

## 8. Needs from Severin

- Nothing blocking. Confirm „Dein Verlauf" stays free with the paywall on (decision 2).

## 9. Manual checks for Severin (device)

- Ich → Dein Verlauf with a real account: the weeks match the diary; today's entry shows after logging and coming back.
- VoiceOver / TalkBack read the day cells and the trend rows as specified.
- Entdecken with Verstopfung in the profile: „Reizdarm Typ: Verstopfung" first with „Weil du Verstopfung angegeben
  hast"; after opening it, it leaves „Für dich" on the next visit.
- The page scrolls smoothly with 12 weeks on a small phone (iPhone SE size).
