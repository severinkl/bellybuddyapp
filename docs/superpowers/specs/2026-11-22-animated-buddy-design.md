# Animated Buddy — Onboarding + Core Loop (Design)

> Date: 2026-11-22. Status: draft for approval.
> Supersedes the June approach on `feat/gamification-mock-backend` (unmerged; reuse parts only).
> UI language German; all copy below in German is final-draft copy the user will review.

## 1. Intent

Belly Buddy should *feel alive*, the way BitePal does with its pet raccoon, so that
logging stops being a chore and new users are charmed in their first minute. The June
attempt had no real animation and shallow, bolted-on mechanics. This time the
character itself carries the experience: an animated gut-mascot ("Buddy") that
hosts the onboarding, lives on the dashboard, reacts to everything the user logs,
and is cared for through a streak.

Success = a new user goes through onboarding and smiles at the Buddy; existing users
open the update and immediately "get" their Buddy; logging rate and day-2/day-7
retention go up (measure via existing data: entries per active user per day).

## 2. Goals / non-goals / anti-goals

**Goals (one release, shipped together after the Hetzner go-live):**
1. A production-quality, code-animated Buddy character (part 1 — "Rig").
2. Buddy-first core loop: Buddy hero on the dashboard, mood driven by care, reactions to
   all four trackers, streak + streak savers, persisted in a new `buddy_state` table (part 2 — "Alltag").
3. A story-driven onboarding hosted by the Buddy, plus a short "Lerne deinen Buddy kennen"
   for existing users (part 3 — "Onboarding").

**Non-goals (later releases):** coins, shop/cosmetics, daily/weekly quests, achievements,
meal score, sharing, replacing the static mascot PNGs on other screens (recipes,
recommendations, diary…), server-side (FCM) push copy changes.

**Anti-goals (would be failure even if it "works"):**
- The Buddy never gets sick, dies, cries, or guilt-trips. No hearts/lives that drain.
  A user with a bad gut day must never feel punished by their mascot.
- No dark patterns from BitePal: no fake countdowns, no "Bist du sicher?" sad-pet on skip,
  no paywall.
- The onboarding must not *feel* longer than today; every step stays one tap/answer.
- No janky animation: 60 fps on a mid-range Android; reduced-motion users get a calm,
  static-but-expressive Buddy.

## 3. Constraints

- Flutter 3.50.1, Riverpod (`AsyncNotifier`), GoRouter, Freezed models, repository →
  service → Supabase-compatible client (PostgREST/GoTrue on Hetzner). See `CLAUDE.md`:
  all colors in `AppTheme`, font sizes `AppTheme.fontSize*`, spacing/radii `AppConstants`,
  `AppLogger` not `print`, `flutter analyze` zero issues, `dart format`.
- No new animation dependencies (no Rive/Lottie). Everything is `CustomPainter`.
- Backend schema changes go into **bellybuddy-core** as an Alembic migration
  (`backend/migrations/versions/0008_…`), with RLS like the existing user tables.
  Release ships after the Hetzner go-live, so no Lovable/Supabase-cloud migration.
- **Branch (Claude's call):** build on top of `feat/hetzner-backend` (PR #78, open → `develop`),
  because #78 rewrites the same files (registration wizard, router, dashboard) and adds the
  health-consent gate this feature must respect. Rebase onto `develop` once #78 merges;
  PR → `develop` (never auto-merge).

## 4. Approaches considered (decided)

| Approach | Trade-off | Decision |
|---|---|---|
| Rive `.riv` by a commissioned artist | Highest hand-animated quality; needs designer, money, weeks | Rejected — user wants Claude to build it |
| Script-generated `.riv` | Editable later in Rive; barely documented binary, blind debugging | Rejected — too risky |
| Lottie JSON clips | Good for one-shot moments; clunky for an interactive multi-state character | Rejected for the character |
| **Code-drawn Flutter `CustomPainter` rig** | Fully buildable/testable by us, tiny, interactive; body only bends/squashes (no new limb poses) | **Chosen** — validated by the approved spike |

Mascot style: the **flat gut-tube** (`mascot-happy.png`), not the glossy `*-stomach` set.

## 5. Part 1 — The Buddy rig

### 5.1 What the spike proved (branch `spike/buddy-animation`, `lib/spike/`)
- Body traced from `mascot-happy.png` with potrace into three path layers
  (white silhouette → pink fill → black outline), stored as compact Dart path data
  (~14 KB). Paths are **subdivided into ≤45 px cubic pieces once at startup** — required
  so local deformations bend the outline.
- Per frame, every path point goes through a smooth deformation field:
  breathing (stomach swells), jelly sway (travelling wave anchored at the bottom),
  and a "gulp" bulge that travels along a hand-placed gut centerline.
- Global squash/stretch/jump/rotate around the "feet" (bottom centre).
- Face drawn procedurally on top: tilted eye ellipses with 34 px ring, pupils with gaze,
  upper lid (blink/sleepy/sad tilt), lower lid (happy ^^ squint), heart pupils,
  parametric mouth (smile/open/width with tongue), brows, blush, nervous motion-lines.
- Expression = a lerpable parameter vector (`FacePose`); moods are presets; events
  (eat, celebrate, poke) are time-based overrides blended in/out smoothly.
- User verdict: "schaut schon mal super aus".

The spike code is the reference implementation; production code is a clean rewrite
following the rules below (the spike itself stays throwaway).

### 5.2 Production component
Location: `lib/widgets/buddy/` (+ `lib/config/buddy_shape_data.dart` for the generated path
data). The trace scripts (`trace.py`, render/analysis helpers, `requirements.txt`: numpy,
pillow, opencv-python-headless, potracer) currently live in the spike worktree at
`.worktrees/buddy-spike/tool/buddy_trace/`; commit them under `tool/buddy_trace/` so the
path data can be regenerated (`potracer` treats dark pixels as filled — masks are inverted).

- `BuddyController` (`ChangeNotifier`): public API —
  `mood` (setter), `play(BuddyAction)`, `lookAt(Offset)`, `say(String, {Duration})`,
  `reactTo(...)` helpers. Owns time/blink/gaze/blending; no Riverpod inside the rig.
- `AnimatedBuddy` widget: takes a controller, size-agnostic (`BuddyLayout`), tap → poke /
  look-at, pauses its ticker when not visible (`TickerMode`/visibility), exposes
  `Semantics(label: '<Name>, <Stimmung>')`.
- `BuddySpeechBubble`: animated bubble anchored above the Buddy, German text,
  `Semantics(liveRegion: true)`.
- Colors: add to `AppTheme` — `buddyOutline`, `buddyBody`, `buddyTongue`, `buddyBlush`,
  `buddySparkle`, `buddyHeart`, `buddyWater`, `buddyFood`, `buddyFoodLeaf`.

### 5.3 Moods (persistent states)
From the spike: `happy`, `nervous`, `sad`*, `inLove`, `zen`, `energetic`.
New: `hungry` (pleading eyes looking at the user, small tummy-rumble wiggle, mouth "o"),
`sleepy` (heavy lids, slow breath, occasional yawn), `empathetic` (soft brows, small
smile, slight lean — "Ich bin bei dir").
\* `sad` is only used briefly inside the onboarding/empathy reactions, never as a resting state.

### 5.4 Actions (one-shot)
From the spike: `eat`, `celebrate`, `poke`.
New: `wakeUp` (lids open, stretch, blink twice — onboarding), `yawn`, `wave`
(body sway + hello bubble; no arms — the gut "nods" with a squash), `drink` (a blue
wave travels down the gut instead of a lump), `relief` (exhale: squash then long
stretch-release, relaxed lids — toilet entry), `hug` (empathy: squeeze-in + blush),
`nodYes` / `think` (wizard reactions: small vertical bob / eyes up-left + "hmm").
`eat` accepts an optional image (the meal photo thumbnail, circular) as the falling food;
falls back to the drawn apple.

### 5.5 Reduced motion
If `MediaQuery.disableAnimationsOf(context)`: no sway/hop/shake/jump; breathing at
minimal amplitude; actions become a pose cross-fade (e.g. eat → happy squint) with the
speech bubble carrying the meaning. Blink stays (tiny, not vestibular).

## 6. Part 2 — Alltag (core loop)

### 6.1 Dashboard hero
The top of `dashboard_screen.dart` gets a Buddy hero section:
streak chip (🔥 N Tage, plus 🛡 saver count), the animated Buddy, speech bubble, and a
primary "🍎 Füttern" shortcut to the meal tracker. Tracker cards, recommendations, recipes
etc. stay below, unchanged. (Text-sketch from the brainstorm:)

```
┌────────────────────────┐
│ 🔥 5 Tage  🛡1     ⚙   │
│   "Ich hab Hunger!"    │
│      (  BUDDY  )       │
│ [🍎 Füttern]           │
├────────────────────────┤
│ [Mahlzeit] [Getränk]   │
│ [Toilette] [Gefühl]    │
│ Tipps · Rezepte ...    │
└────────────────────────┘
```
The existing spotlight tutorial keys must keep working (add a key for the hero if the
tutorial should mention it — builder's call).

### 6.2 Mood = care, with brief empathy
Resting mood is derived from *today's* logs (local device day), never from symptoms:

| Situation | Mood | Example bubble |
|---|---|---|
| New day, nothing logged, before 10:00 | `sleepy` | „Guten Morgen … *gähn*" |
| Logged something in the last ~5 h | `happy` | „Mir geht's super!" |
| ≥3 of the 4 categories logged today | `energetic` | „Wir sind heute ein Top-Team!" |
| Nothing logged for ≥5 h during the day (10–21 h) | `hungry` | „Ich hab Hunger … fütterst du mich?" |
| Evening, nothing logged today | `hungry` | „Unser Streak wartet noch auf dich!" |
| Streak goal reached / milestone | `inLove` + `celebrate` | „Wir haben's geschafft!" |

Empathy: when the user logs a bad gut feeling (or a painful toilet entry), the Buddy plays
`hug`, shows `empathetic` for that dashboard visit, says e.g. „Oh nein … ich drück dich.
Danke, dass du's eingetragen hast." — then returns to the care-based mood. Logging a bad
day still *counts as care* (it's a log).

### 6.3 Reactions to the four trackers
**Meal (user decision):** the meal tracker keeps its own success screen. The animated
Buddy replaces that screen's current success illustration and plays `eat` with the meal
photo there; the existing „Getränk hinzufügen" and „Als Rezept speichern" actions stay
below it unchanged. In onboarding mode (§7.1 step 8) the same screen returns to the
onboarding instead of the dashboard.

**Drink, toilet, gut feeling:** after a successful save, the tracker returns to the
dashboard (as today) and the hero Buddy plays the reaction + bubble (replaces
`bb_success_overlay` for these saves):

| Tracker | Action | Bubble pool (examples) |
|---|---|---|
| Mahlzeit | `eat` (meal photo as the bite if available) | „Mmmh, lecker!", „Danke fürs Füttern!" |
| Getränk | `drink` | „Ahh, erfrischend!", „Prost! 💧" |
| Toilette | `relief` (+ empathy if painful/abnormal) | „Puh, Erleichterung!" |
| Bauchgefühl gut | `celebrate` (small) | „Juhu, guter Bauchtag!" |
| Bauchgefühl schlecht | `hug` → `empathetic` | „Ich drück dich. Morgen wird's besser." |

If the save extends the streak for the first time today, the streak chip animates
(+1 with a flame pop) after the reaction.

### 6.4 Streak
- A **day counts** if the user has ≥1 entry of any type (meal, drink, toilet, gut feeling)
  whose **`tracked_at`** falls on that local calendar day (user decision: the day the entry
  is *about*, not `created_at`). Backfilling a forgotten day therefore repairs the streak.
- **Existing users keep their full history** (user decision): their real current streak
  shows from day one. When their `buddy_state` row is created, `last_milestone` is set to
  `floor(current_streak / 7) * 7` so no retroactive saver flood; only the onboarding gift
  saver is granted. Streak goals offered are always above the current streak.
- Streak = consecutive counted-or-saved days ending today (or yesterday, if today has
  no entry yet — then the chip shows "noch offen" styling, and the mood logic nudges).
- Computed from existing entry data (no duplicate activity log). Builder's call whether
  this is a client query over the four tables or a Postgres view/RPC in core
  (`user_activity_days`); must use the device's local day boundaries consistently.
- **Streak goal**: chosen in onboarding (7 / 14 / 30 Tage). Reaching it → celebration +
  "Neues Ziel?" sheet (next tier: 14 / 30 / 50 / 100).

### 6.5 Streak savers
- Start gift: 1 saver (onboarding gift moment). Every 7-day milestone (7, 14, 21 …) of
  the current streak earns +1; **max 2 in stock**.
- Applied **automatically**: on streak evaluation, if exactly the missed day(s) between
  the last counted day and today can be covered by stock (1 saver per missed day), they
  are consumed and those dates stored in `saved_days`; the Buddy announces it next open:
  „Puh! Dein Streak-Saver hat uns gestern gerettet 🛡". If stock isn't enough, the streak
  resets to 0 without drama: „Neuer Anlauf — ich bin dabei!".
- **Refund:** if the user later backfills a day that is in `saved_days`, that date is
  removed from `saved_days` and the saver returned to stock (still capped at 2).

### 6.6 Data — `buddy_state` (bellybuddy-core migration)
```
buddy_state
  user_id                 uuid  PK, FK auth.users, on delete cascade
  name                    text  not null default 'Buddy'   (1–20 chars, trimmed)
  streak_goal             int   null                       (7|14|30|50|100)
  savers                  int   not null default 0          (0..2)
  saved_days              date[] not null default '{}'
  last_milestone          int   not null default 0          (highest 7-multiple rewarded)
  onboarding_completed_at timestamptz null
  created_at / updated_at timestamptz
RLS: owner-only select/insert/update (same pattern as profiles).
```
App side: Freezed `BuddyState` model, `BuddyRepository` (interface) +
`SupabaseBuddyRepository` + `LocalBuddyRepository` (SharedPreferences fake used in dev
until the Hetzner backend is live, and in tests), `BuddyService`, a Riverpod
`buddyStateProvider` (`AsyncNotifier`). Pure-Dart `StreakEngine` (reuse/port the June
`streak_engine.dart` where it fits) — fully unit-tested, incl. timezone/day-boundary and
saver edge cases.

### 6.7 Reminders
**Copy change only (Claude's call):** local meal/mood reminder pools
(`lib/services/reminder_copy.dart`) get Buddy-voiced lines using the Buddy's name, e.g.
„🍽️ {name} hat Hunger! Was gab's zu Mittag?", „🥄 {name} wartet aufs Frühstück!".
**No streak numbers and no streak-aware logic**: local reminders repeat daily and their
text is fixed at scheduling time, so „{n}-Tage-Streak" would go stale and fire even after
logging. Real "save your streak" nudges (one-off scheduling, cancel-on-log) are a later
release. Reschedule reminders when the Buddy is renamed. Server-side push copy is out of scope.

## 7. Part 3 — Onboarding

### 7.1 New-user flow
Replaces the welcome carousel and wraps the existing registration wizard.

1. **Intro-Story** (replaces `welcome_screen.dart` carousel). Buddy asleep (`sleepy`,
   „zzZ"), hint „Tippe, um ihn zu wecken". Tap → `wakeUp` → `wave`. Bubbles (tap to
   advance): „Hi! Ich bin dein Bauch-Buddy." → „Ich helfe dir herauszufinden, was deinem
   Bauch guttut." → „Lass uns uns kennenlernen!" → [Los geht's]. A small
   „Ich habe schon ein Konto" link → existing auth route (as today).
2. **Name** — „Wie soll ich heißen?" text field prefilled „Buddy"; on confirm `celebrate`
   (small) + „{Name}! Den Namen mag ich."
3. **Gesundheits-Einwilligung** — the `HealthConsentStep` from PR #78 (user decision: after
   Name, before any health question). Legal text and buttons exactly as in #78; the Buddy
   appears small and quiet above it with one line: „Bevor du mir von deinem Bauch erzählst,
   brauch ich kurz dein OK." No reactions/animations on this step beyond idle.
4. **Profile questions** — existing steps (Geburtsjahr, Geschlecht, Größe/Gewicht,
   Ernährung, Symptome, Unverträglichkeiten), visually re-hosted: Buddy (smaller) above
   the question with a bubble; progress bar stays. The Buddy **reacts to every answer**
   (mood/action + line from a reaction catalog, §7.3).
5. **Anmeldung** — existing `AuthStep` / `EmailCaptureStep` logic unchanged; framed by the
   Buddy: „Damit ich mir alles merken kann, brauchst du ein Konto." On success the locally
   held name is persisted into `buddy_state`.
6. **Streak-Ziel** — „Wie viele Tage schaffen wir zusammen?" 7 „Guter Start" /
   14 „Stark" / 30 „Legendär" (reuse the June commit-sheet idea, restyled).
7. **Reminder-Bitte** — „Darf ich dich erinnern, wenn ich Hunger habe?" [Ja, gerne] /
   [Später]. „Ja" runs the existing notification permission + default reminder setup;
   sets `keyNotificationModalShown` so the dashboard opt-in dialog never appears for them.
8. **Erste Mahlzeit füttern** — „Ich hab Hunger! Was hast du zuletzt gegessen?"
   [Mahlzeit eintragen] opens the real meal tracker; its success screen (§6.3) plays `eat`
   with the meal photo, then returns to the onboarding. [Später] skips without penalty.
9. **Geschenk** — gift box reveal + confetti: „Ein Geschenk für dich: ein Streak-Saver!
   Der rettet unseren Streak, falls du mal einen Tag vergisst." Grants 1 saver, sets
   `onboarding_completed_at` → dashboard, where the existing spotlight tutorial runs.
   The old `welcome_modal.dart` is no longer shown (the intro replaces it).

Wizard data before auth stays local exactly as today (name added to that local state).

### 7.2 Existing users — „Lerne deinen Buddy kennen"
Trigger: logged-in user with a completed profile and no `buddy_state.onboarding_completed_at`.
Gate order (Claude's call): upgrade gate → health-consent gate (both from #78) → Buddy intro.
Full-screen, ~30 s: `wakeUp` + „Hi! Ich bin neu hier — dein Bauch-Buddy." → Name →
Streak-Ziel → Reminder-Bitte (only if reminders aren't already enabled) → Geschenk →
dashboard. No profile questions, no auth, no first-meal step.

### 7.3 Reaction catalog
A const German catalog `lib/config/buddy_reactions.dart`: per wizard step and option →
`(BuddyMood|BuddyAction, line)`, with 1–3 line variants each. Examples:
- Symptom „Blähungen" → `empathetic`, „Oh, das kenn ich nur zu gut!"
- Symptom „Keine" → `celebrate`, „Wow, beneidenswert!"
- Ernährung „vegan" → `inLove`, „Ui, ganz viel Grünzeug für mich!"
- Unverträglichkeit „Laktose" → `think`, „Notiert! Darauf passen wir zusammen auf."
- Geburtsjahr gewählt → `nodYes`, „Perfekt, danke!"
The full catalog is drafted by the builder and reviewed by the user before release.
Tone: warm, a little cheeky, never medical advice, always „du".

## 8. Reuse from the June branch
Port selectively (read before rewriting): `streak_engine.dart` + tests, the streak-commit
sheet concept, `reduced_motion.dart` helper, `confetti_burst.dart` /
`animated_count.dart` if they fit the new visuals. Do NOT port: coins, quests, shop,
achievements, care meters, mock repos' structure where it conflicts with §6.6.

## 9. Testing
- Unit: `FacePose` lerp, action timelines (start/end states), `StreakEngine`
  (gaps, savers, milestones, cap, day boundaries/DST), mood derivation table (§6.2),
  reaction catalog completeness (every wizard option has an entry).
- Widget: dashboard hero renders with `LocalBuddyRepository`; onboarding flow navigates
  all steps; existing-user flow trigger gating; reduced-motion path renders without
  tickers running animations.
- Golden renders of key poses are a **local review tool** (as in the spike), not CI-gated
  (CustomPainter anti-aliasing differs across CI hosts).
- Existing tests for welcome screen, registration wizard, dashboard first-run, and
  notification dialog are updated, not deleted, where behavior intentionally changed.

## 10. Calls made by Claude (user may override)
- Base branch on `feat/hetzner-backend` (§3).
- Reminders: copy-only, name but no streak numbers (§6.7).
- Gate order for existing users: upgrade → consent → Buddy intro (§7.2).
- Existing users' `last_milestone` initialised to the last passed 7-multiple (§6.4).
- Old `welcome_modal.dart` dropped; spotlight tutorial kept after the gift (§7.1).
- Golden renders are local-only, not CI (§9).

## 11. Left to the builder
Exact animation curves/timings and art details of the new moods/actions; component
file split; whether streak days come from a client query or a core view/RPC; where the
hero's tutorial key goes; skeleton/loading state of the hero; drafting the full reaction
catalog and Buddy reminder pools (user reviews copy).
