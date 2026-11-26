# Runde 5: Home polish, fiery flame, sticker icons, quieter Entdecken, recipe photos — Design

**Status:** decisions by Severin 2026-11-25 (after clicking through the round-4 preview). Mockups:
https://claude.ai/artifact/R36P6RbdBwyagNexfnZrph (source `scratchpad/mockups/round5.html`).
**Repos:** app `severinkl/bellybuddyapp` (branch `feat/round5` from `develop` @ 872ced7e) and core `severinkl/bellybuddy-core`
(recipes import + images, from `develop`).

## 1. Intent

Severin tested round 4 on his simulator. Home wastes space at the top, the streak flame is too small to feel alive, the need icons
look like stock emoji, Entdecken shows an example where there's nothing yet, and the recipe collection has no pictures and could be
bigger. This round makes the app feel finished, not add features.

**Success:** Home's Buddy sits higher with a lively flame behind him; the four needs have their own drawn icons everywhere; Entdecken
shows only what the user has; every collection recipe has an appetising picture; the collection grows to about 270 recipes.
**Anti-goals:** a flame that competes with the Buddy or reads as „the Buddy is burning"; pictures that show ingredients the recipe
doesn't contain (a FODMAP app must not show onions on an onion-free dish); losing the Tipps opt-in entirely.

## 2. Decisions (Severin)

| # | Topic | Options shown | Decision |
|---|---|---|---|
| 1 | Home top + flame | A flame behind the Buddy / B glow disc / C flame + number, no chip | **A, „noch etwas feuriger"** |
| 2 | Need icons | C sticker in Buddy style / A line / B duotone | **C** |
| 3 | Entdecken → Tipps without tips | A nothing / B compact row | **A** |
| 4 | Recipe pictures + more recipes | photo look +150 / photo only the 121 / illustration +150 | **Photo look, +≈150 recipes, ≈15 € budget** |
| 5 | „Ich" header | — | remove (his request) |
| 6 | Success-page charging circle | — | slower (his request) |

## 3. Design

### 3.1 Home top (decision 1)
- The reserved speech-bubble slot above the Buddy (`BuddyBubbleSlot`, `AppConstants.buddyBubbleHeight` 76 + gaps) goes. The ring
  and the Buddy move up (≈84 px on a 402×874 screen).
- The Buddy's bubble floats above his head as an overlay only while he talks. It never moves the layout. It must not block taps on
  the top two need bubbles for longer than it's shown, and it must stay on screen at 375×667 with text scale 1.3 (it may overlap
  the streak chip row while shown).
- The streak chip stays top-left and shows the count only („5 Tage"); its own small flame goes.

### 3.2 The flame behind the Buddy (decision 1, „feuriger")
- A large drawn flame sits behind the Buddy inside the ring's centre, under him in z-order, roughly his height at the „brennt"
  stage; the Buddy stays the hero (the flame is behind, slightly transparent at its edges).
- **„Feuriger" than the mockup:** a saturated red → orange → yellow gradient with a bright core, three or more tongues that flicker
  independently (not one wobbling shape), a warm outer glow, and occasional rising sparks from „brennt" up.
- **States** (same rules as today's chip flame, round 4 §5.3): **glimmt** — before today's first entry: small, dim ember that
  breathes; **brennt** — after today's first entry, ignites once (the existing ignite moment) and keeps flickering; **lodert** —
  long streaks (today's tier thresholds): taller, blue core, more sparks. Streak 0: ember only.
- Reduced motion: a still flame per state, no ignite burst.
- Everywhere else the drawn flame appears (streak sheet „Dein Streak", the success page's ignite row, the week row marks) uses the
  same fiercer drawing at its size, so the flame looks the same app-wide.

### 3.3 Sticker icons (decision 2)
- Four drawn icons in the Buddy's style — thick black outline, pastel fills, slight offset shadow like the Buddy's bubble:
  **Essen** plate with fork & knife; **Trinken** water glass (or droplet in a glass); **Bauchgefühl** a small happy pink belly face
  (Buddy-like, not the Buddy himself); **Klo** a toilet-paper roll. Start from the mockup's section-2 option C drawings.
- SVG assets (`flutter_svg` is already a dependency) under `assets/images/icons/needs/`, one per need, used through one widget
  (e.g. `NeedIcon(need, size)`) wherever a need's emoji shows today: the Eintragen sheet tiles, the Home meter bubbles, the success
  page's charging circle, and any other `CareNeed.emoji` use (grep). Semantics: the existing labels; the icon is decorative.
- Emoji stay only where they're text inside a sentence (Buddy lines, reminders), not as icons.

### 3.4 Entdecken → Tipps (decision 3)
- The Tipps section on Entdecken shows only once the user has at least one tip set with tips. Before that — weekly tips off or on —
  it's absent (no example card, no switch, no „kommen am Montag" note).
- The opt-in stays reachable: the day-3 offer (round 4) and Einstellungen (the existing `WeeklyTipsSwitch` with its KI-Dienst
  sentence). Remove the example tip card if nothing else uses it.
- With tips: as today (card + „Neu" pill), and the switch row stays below the card while weekly tips are off (today's behaviour).

### 3.5 Small ones
- **Ich:** no „Ich" app-bar title; the Buddy card moves up.
- **Success page:** the charging circle charges in about 2 s (today `careChargeDuration` 1200 ms) with an ease-out, and anything
  chained after it (ignite, „Tag n") follows the new timing.

### 3.6 More recipes (decision 4, core)
- Grow the collection from 121 to about 270 with the round-4 import pipeline in core (`backend/scripts/` import, cache, AI rewrite of
  the steps in German in our own words, catalog/kritisch check, diet tags, meal types, source link), from the sources already used
  and listed in `scratchpad/recipe-sources.md`: the rest of Reizdarmblog, more Weglasserei, Karlijn's Kitchen (EN→DE), FODMAP
  Everyday, Monash; same quality gates and the same drop rules (e.g. Gemüsebrühe, Zwiebel/Knoblauch, Lauch).
- Balance: today 33 Frühstück / 76 Mittag / 69 Abend / 29 Snack → aim for at least 60 Frühstück and 50 Snack; keep vegetarian/vegan
  shares; no duplicates of existing titles/dishes.
- Delivered as a new data migration (0015) after #11's 0014, never editing 0014.

### 3.7 Recipe pictures (decision 4, core)
- One AI-generated photo per collection recipe (existing 121 + new ones), photo look: top-down, natural daylight, the same light
  wooden table and simple plates/bowls for all, no text, no people/hands, no brand items.
- **Truthful content:** the prompt is built from the recipe's own ingredient list and says to show only those ingredients; a
  check pass (vision model, cheap tier) rejects pictures that show a common FODMAP trigger not in the list (onion, garlic, leek,
  wheat bread/pasta when the recipe is gluten-free, …) and regenerates once; still failing → no picture (placeholder) and listed
  in the report.
- Model: Gemini image generation (the key core already uses). Start with a 5-recipe sample on the cheaper model (Flash Image); use
  Pro only if the sample looks clearly worse and the budget allows.
- Storage: core's public recipe-images bucket (or the existing storage for recipe images), `recipes.image_url` set by the data
  migration/admin script; sized for the app (the app decodes at laid-out size since round 4).
- **Budget:** ≈15 € for this round's AI spend (import ≈ 6 €, pictures + checks ≈ 9–10 €), tracked in a ledger like round 4.
- **Precondition:** Severin enables billing on the Google Cloud project behind the Gemini key (today image generation fails with 429
  RESOURCE_EXHAUSTED in prod). Until then the import runs and the pictures wait.

## 4. Constraints
- App `CLAUDE.md`: tokens only (colours, font sizes, spacing, radii), German UI, `AppLogger`, `CachedNetworkImage` + shimmer.
- Reduced motion everywhere; 375×667 at text scale 1.3 never overflows; Home's tap targets stay ≥ 48 dp.
- Vocabulary (eintragen, Essen, Bauchgefühl, Tipps, Tagebuch); no health claims.
- Core first (migration 0015 + pictures) before the app release; no compatibility shims needed (Severin's rule).
- Entry times are wall clock; nothing in this round touches them.

## 5. Approaches considered
See §2: three flame treatments (A behind-flame chosen, B glow disc — subtle but not readable as a streak, C flame + number without
chip — tidiest but crowds the Buddy), three icon styles (C sticker chosen — on-brand; A line — clean but generic; B duotone), two
empty-Tipps treatments (A nothing chosen; B compact switch row), three recipe options (photo +150 chosen; photo only; illustration —
never misleading but less appetising; the truthfulness check in §3.7 covers the photo risk).

## 6. Left to the builder
Exact SVG paths and colours (from the mockup), flicker timing and spark density within the „feuriger" brief, the bubble overlay's
exact anchor, per-source recipe counts within the balance goals, the image prompt wording and model after the sample, the bucket
layout.

## 7. Stages
1. **App polish** (§3.1–3.5) on `feat/round5`: one PR to `develop`.
2. **Core recipes + pictures** (§3.6–3.7): one core PR to `develop` (pictures may follow in a second PR if billing comes later).
Release like round 4 once both are done (Severin's call).

## Builder-check answers (my calls, marked)
1. **Picture delivery (my call):** pictures are not a migration. One idempotent core admin script (`backend/scripts/recipe_images.py`)
   generates, checks, uploads to the public recipe-images bucket and sets `recipes.image_url` to that environment's absolute public
   URL, by recipe id; it runs locally first (preview) and against prod as a release step after the deploy (vault keys via
   `dotenvx get … --strict`). Re-runs skip recipes that already have a picture of this round.
2. **Enough recipes (my call):** round 4 took only 9 pages each from Monash and FODMAP Everyday and 34 from Karlijn's Kitchen by
   choice; those sources have hundreds more. The ≈150 come from the listed sources; the Frühstück ≥ 60 / Snack ≥ 50 goals are best
   effort, reported if missed. No new sources.
3. **Which recipes get pictures (my call):** every visible collection recipe without a picture, old ones included; an existing
   non-stock picture is kept; hidden recipes are skipped.
4. **Truthfulness check (my call):** the check model lists the foods it sees; a picture is rejected when it shows a food that the
   intolerance table can flag (any rule's allergen/FODMAP group in `app_config.intolerance_rules`, plus onion/garlic/leek/wheat by
   name) and that isn't in the recipe's ingredient list. One regeneration; still failing → placeholder + report. If the budget cap
   is reached mid-run, the script stops; the rest keep placeholders and are listed.
5. **Order (my call):** the import and migration 0015 don't wait for billing; the pictures run as soon as billing is on.
6. **Ledger (my call):** a fresh round-5 spend ledger with a 15 € cap, separate from round 4's.
7. **Flame size/position:** left to the builder (mockup is the visual source; today's tier thresholds stay).

## Decisions log
- 2026-11-25 Severin: A „feuriger"; C stickers; Tipps A (nothing); photo look + ≈150 recipes, ≈15 €.
- 2026-11-25 Severin: „ja passt" — design and my calls approved; release like round 4 right after building (core → prod, then an Android build), waiting for the pictures (no placeholder release).

## Addendum 5b (Severin's click-through of the round-5 preview, 2026-11-26)

Decisions (Severin picked each recommended option):
1. **Streak count as a badge at the flame.** The top-left chip row on Home goes. The count sits as a small badge („🔥 12" with the
   drawn flame, ≥ 48 dp tap target) slightly offset at the flame's lower right, next to the Buddy's feet; tapping it opens „Dein Streak".
   It shows at 0 too (the way into „Dein Streak"). Semantics: „Streak: 12 Tage, Dein Streak öffnen" (with „heute noch offen" while
   today is open, when its flame is an ember too). The chip row's height stays as headroom above the ring for his bubble and the
   flame's tips; the ring doesn't move up (ruling 2026-11-26: moving it would clip a 3-line bubble or draw text below the user's
   text size). Ich keeps its own chip. Any tour step that pointed at the chip points at the badge.
2. **A flame you recognise.** Taller so its tips rise clearly above his head (≈ 1.5× his height), slightly offset to one side, stronger
   (less transparent, less blur). Still behind him, never over the need bubbles; the speech bubble still paints above it. Anti-goal stays:
   it reads as fire behind him, not him burning. Same look on the success page/streak sheet sizes stays as is.
3. **Notifications: ask again.** When notifications are off (OS permission not granted, or all reminders off in the app), the Buddy asks
   again with a short explanation and „Einschalten" — after the 2nd active day, after the first week, then monthly, at most 4 times in
   total, through the existing cue queue (never over another sheet/the tour). „Einschalten" requests the permission, or opens the system
   settings when it was denied for good. Ich shows a row „Erinnerungen sind aus · Einschalten" while they're off. The onboarding step and the
   one-time Home dialog stay as they are.
   Ruling: any two asks are at least 7 days apart. The first offer (onboarding step / one-time Home dialog) and a deliberate switch-off of
   all notifications in Einstellungen store today as the last ask date without counting as an ask; so the first re-ask comes at least 7 days
   after the onboarding offer.
4. **„Beispiel" goes** from the Muster preview label („Das siehst du dann") and the day-6 reward sheet's label; the fictional values stay
   blurred and the „Beobachtung aus deinen Einträgen" note stays.
