# Getränk eintragen (drinks screen redesign) — Design

**Status:** direction D picked by Severin on 2026-11-27 from mockups (D1 opened, D2 chosen); the rest is Claude's proposal.
**Repo:** app `severinkl/bellybuddyapp` only, branch `feat/drinks-screen` from `origin/develop` @ 1fb777a. No server change,
no new table, no new personal data, no privacy-policy change.
**Mockups (exact copy, sizes and colours; the German strings are the spec):**
`docs/superpowers/specs/assets/2026-11-27-drinks-D1.html` (screen when opened) and `…-D2.html` (a drink and an own amount
chosen). Open them in a browser at 390 × 844.

## 1. Intent

Today's drinks screen is a search field, a row of name pills, four size buttons and „Speichern". Most drink entries are the
same thing again (a glass of water, the morning coffee), yet each takes three taps and some reading. The redesign makes the
usual case one tap („Wie zuletzt" → „Eintragen"), makes choosing visual (tiles with a line icon, vessels that grow with the
amount) and shows the day's drinks as glasses, without a goal.

**Success:** a returning user logs „wie zuletzt" with one tap; anyone else logs a drink with three taps (drink, amount,
button) without the keyboard; the save button says what will be saved.
**Anti-goals:** a daily goal, a progress bar, „noch 1 l bis …" or anything that reads as a target or advice (health-claims
caution); emoji; a server change.

## 2. Decisions

| # | Topic | Decision | Who |
|---|---|---|---|
| 1 | Direction | D: today card with glasses, one-tap row, drink tiles, vessel tiles, time line, named button | Severin |
| 2 | Today card | „Heute getrunken", total big, one small glass per 250 ml, the entry being made as dashed glasses and „+ 400 ml"; no goal | Severin |
| 3 | One-tap row | „Wie zuletzt": the most recent entry (drink + amount), „Eintragen" saves at the chosen time; hidden without history and while a drink is selected | Severin |
| 4 | Tiles | 3 columns, Wasser first, then recent drinks, up to five, plus „Anderes suchen"; selected = 2 px `infoText` border, white fill; tap again deselects | Severin |
| 5 | Vessels | Glas 250 ml, Dose 330 ml, Flasche 500 ml, Große 1 l; disabled with „Wähle zuerst ein Getränk." until a drink is chosen; „Andere Menge" 1–3000 ml | Severin |
| 6 | Button | „400 ml Pfefferminztee eintragen"; appears when a drink is selected, disabled until the amount is valid | Severin |
| 7 | Which entry is „zuletzt" | Latest `tracked_at`, ties by latest `created_at` (the drink the user had last, as the diary orders it). *Cost if wrong: one `order()` line.* | Claude's call |
| 8 | Icons drawn in code | One `CustomPainter` with the mockup's paths transcribed to `Path` calls, not SVG assets. Why: the today card's glasses need partial fills and dashed outlines a static SVG can't do, so the painter exists anyway; colours then come straight from `AppTheme` (selected → `infoText`), paint is synchronous (no asset pop-in, no precache list), and tests read the painter's fields. *Cost if wrong: an hour to move the paths into `assets/images/icons/drinks/*.svg`.* | Claude's call |
| 9 | Icon by name | Pure keyword mapping (§4.4); no data field. *Cost if wrong: a keyword list edit.* | Claude's call |
| 10 | „l", not „L" | `DrinkHelpers.formatAmount` writes „1 l", „1,4 l" as the mockup does, app-wide (the diary uses it too). *Cost if wrong: one character back.* | Claude's call |
| 11 | Total's size | `AppTheme.fontSizeHeadingLG` (24) for the mockup's 26 px; no new font token. *Cost: 2 px.* | Claude's call |
| 12 | No new colours | Mockup hexes map to existing tokens (§4.9); the dashed „Anderes suchen" border uses `mutedForeground` (4.75:1 on the screen) instead of the mockup's `#8A7F78` (2.92:1, below 3:1 for a control's outline). | Claude's call |
| 13 | Search reveal | „Anderes suchen" is a disclosure: tapped, the search field (existing `DrinkSearch`, focused) takes the place of the section heading, the tile reads as expanded; tapped again, the field closes. A drink chosen in search closes it and shows as a selected tile in the fifth slot. | Claude's call |
| 14 | Time line | „Heute, 14:30 · ändern" is a disclosure that shows the existing `DateTimeChips` under it (both pickers, unchanged); it sits at the end of the scrolling content, the button stays fixed at the bottom. *Cost if wrong: moving one widget.* | Claude's call |
| 15 | New users | Without history the tiles fill up (after Wasser) with catalog drinks named in `AppConstants.starterDrinkNames` that exist, in that order; missing names are skipped. *Cost: a list edit.* | Claude's call, names for Severin to confirm |
| 16 | Large text | At a text scale of 1.5 or more the drink and vessel grids use 2 columns, the one-tap row's button moves under its text, and the today card's label and total stack. | Claude's call |
| 17 | Back control | The tracker scaffold's back arrow stays (all trackers share it); the mockup's ✕ is not copied. | Claude's call |
| 18 | Title | „Was hast du getrunken?" without the 💧 (mockup; no emoji). | Claude's call |

## 3. Approaches

- **Rework the screen in place, same provider (picked).** `DrinkTrackerNotifier` (a `Notifier` with an explicit `isLoading`,
  not an `AsyncNotifier`) gains the last entry and the search flag; the four existing widget files are rewritten, four small
  ones added. Every behaviour in §5 keeps its code path and most keep their tests.
- **A new screen beside the old one, switched by a flag.** Rejected: no old-app compatibility is needed (app and core ship
  together) and two screens double the accessibility harness for nothing.
- **Convert the provider to `AsyncNotifier` on the way.** Rejected for this track: it changes every test of the provider for
  no user-visible gain; the brief's „AsyncNotifier patterns as in the existing provider" is met by following the existing
  provider's patterns (explicit loading flag, stale-result guard `ref.mounted && same day`).

## 4. Design

### 4.1 Layout (top to bottom)
`TrackerScreenScaffold` (title „Was hast du getrunken?", success as today) → body: a `SingleChildScrollView`
(`AppConstants.paddingLg`, sections `gap12` apart) with **today card**, **one-tap row** (when shown), **„Was?" section**,
**„Wie viel?" section**, **time line**; below the scroll view, fixed and padded as today's „Speichern", the **save button**
(only while a drink is selected). While `isLoading` the body is today's centred `CircularProgressIndicator(color: primary)`.

### 4.2 Today card (`DrinkTodayCard`)
- Fill `AppTheme.card`, radius `radiusRound` (20), padding `spacing20` horizontal / `spacing14` vertical, `gap10` between
  header and glasses.
- Header: label left, total right (a `Wrap` with `spaceBetween`; at scale ≥ 1.5 they stack). Label „Heute getrunken" when
  `isSameDay(trackedAt, now)`, else „Am 26.11. getrunken" (`formatDayMonth`); `fontSizeCaptionLG` w500 `mutedForeground`.
  Total = `formatAmount(dayTotal + pending)` in `fontSizeHeadingLG` w700 `foreground`, tabular figures. While an amount is
  pending (a drink selected and a valid amount): „+ 400 ml" (`'+ ${formatAmount(pending)}'`) before the total,
  `fontSizeBody` w600 `infoText`. Pending is 0 without a selected drink.
- Glasses row (`GlassMeter`): one glass per 250 ml (`AppConstants.drinkGlassMl`), `spacing6` apart, wrapping onto more rows
  (`Wrap`, run spacing `spacing6`), at most `AppConstants.glassMeterMaxGlasses` = 48 (12 l; the total still shows the real
  sum). Fills from `DrinkHelpers.glassFills` (§4.8): drunk share in `buddyWater` with a solid `foreground` outline; pending
  share in `careWaterSoft`; a glass that is only pending gets a dashed `infoText` outline (dash 3, gap 3). 0 ml shows one
  empty outlined glass so the card keeps its height. Fill changes animate over
  `ReducedMotion.duration(context, AppConstants.animNormal)`.
- Semantics: the header is one node, label „Heute getrunken" (or „Am 26.11. getrunken"), value the shown total. The
  glasses row is one image (`Semantics(image: true, label: DrinkHelpers.glassesLabel(drunk, pending))`, children excluded).

### 4.3 One-tap row (`LastDrinkRow`)
- Shown when `state.lastDrink != null && state.selectedDrink == null`.
- White fill (`AppTheme.background`), radius `radiusRound`, padding `spacingSm` with `spacingMd` left; glyph of the drink
  (26 px, `infoText`), then caption „Wie zuletzt" (`fontSizeCaptionLG`, `mutedForeground`) over „Wasser, 250 ml"
  (`'${drink.name}, ${formatAmount(amountMl)}'`, `fontSizeBodyLG` w600, max 2 lines, ellipsis), then a `BbButton` „Eintragen"
  (pill, `primary`, ≥ 48 high). At scale ≥ 1.5 the button goes under the text at full width.
- Semantics: caption and name merge into one text node („Wie zuletzt, Wasser, 250 ml"); the button is named
  „Wasser, 250 ml eintragen" (`BbButton.semanticLabel`, new), its visible text stays „Eintragen".
- Tap: saves `DrinkEntry(drinkId: lastDrink.drink.id, amountMl: lastDrink.amountMl, trackedAt: state.trackedAt)` through the
  same path as the main button (`EntryLogger.logEntry`, success screen, Buddy reaction, diary refresh, closes with `true`).
  The selection below stays untouched.
- **Which entry:** `DrinkService.fetchLastEntry(userId)` — PostgREST
  `from('drink_entries').select('*, drinks(name)').eq('user_id', userId).order('tracked_at', ascending: false)
  .order('created_at', ascending: false).limit(1).maybeSingle()`, parsed with `DrinkEntry.fromDbRow`. RLS „Users can view
  their own drink entries" already allows it; the explicit `user_id` filter keeps a dietitian account to its own rows. The
  notifier resolves the entry's `drinkId` against `allDrinks`; an unknown drink (deleted, or not visible) hides the row.
  A failing fetch is logged and hides the row; the rest of the screen loads.

### 4.4 Icons (`DrinkIcon`, `DrinkHelpers.iconFor`)
`enum DrinkIcon { glass, hotCup, cup, bottle, carton, can }`. `iconFor(name)` lower-cases the name and returns the first
group whose keyword is a substring, in this order:

| Order | Icon | Keywords |
|---|---|---|
| 1 | `can` (Dose) | `cola`, `energy`, `red bull`, `bier`, `radler`, `spezi`, `tonic`, `ginger ale`, `fanta`, `sprite`, `mezzo` |
| 2 | `bottle` (Flasche) | `saft`, `schorle`, `limo`, `nektar`, `smoothie`, `eistee`, `kombucha`, `sirup` |
| 3 | `cup` (Tasse, Kaffee) | `kaffee`, `espresso`, `cappuccino`, `latte`, `macchiato`, `americano`, `cortado`, `flat white`, `mokka` |
| 4 | `hotCup` (Tasse heiß) | `tee`, `chai`, `mate`, `rooibos`, `kakao`, `brühe` |
| 5 | `carton` (Karton) | `milch`, `drink`, `kefir`, `ayran`, `lassi`, `buttermilch` |
| — | `glass` | everything else (Wasser, Mineralwasser, Wein, …) |

The order settles the overlaps: „Eistee" is a bottle (before `tee`), „Milchkaffee" and „Chai Latte" a cup (before `milch` /
`chai`), „Energy Drink" a can (before `drink`), „Tomatensaft" a bottle (before `mate`).
Glyphs: the mockup's paths, 1.8 px stroke (`AppConstants.drinkGlyphStroke`), round joins, round caps where the mockup has
them, no fill; `glass` = mockup Wasser, `hotCup` = Pfefferminztee (cup with steam), `cup` = Kaffee, `bottle` = Apfelsaft,
`carton` = Hafermilch, `can` = the mockup's Dose vessel scaled into the 24 box. Drawn 28 px in tiles, 26 px in the one-tap
row; colour `foreground`, `infoText` when selected.

### 4.5 „Was?" section (`QuickDrinkGrid`, rewritten)
- Heading „Oder wähle aus" while the one-tap row shows, else „Was?" (`fontSizeSubtitle` w600, `Semantics(header: true)`).
  While search is open, `DrinkSearch` (autofocused) stands where the heading was.
- Tiles: `DrinkHelpers.tileDrinks(quickDrinks, selectedDrink)` (≤ 5) then „Anderes suchen". 3 columns (2 at scale ≥ 1.5),
  `spacingSm` gaps; each row's tiles share the tallest tile's height. Tile: min height `AppConstants.drinkTileMinHeight` = 84
  (grows with text), radius `radiusLg`, padding `spacingXs`, `card` fill with a 2 px transparent border; glyph 28, `gap6`,
  name `fontSizeCaptionLG` w500, centred, max 2 lines, ellipsis. Selected: `background` (white) fill, 2 px `infoText` border,
  glyph `infoText`, name w600. Border/fill change animates over `ReducedMotion.duration(context, animFast)`.
- „Anderes suchen": transparent fill, dashed 2 px `mutedForeground` outline (`DashedBorderPainter`), search glyph
  (`Icons.search`, `iconSizeMd`), same text style.
- Semantics: each drink tile a `BbTapArea(label: name, selected:, exclusive: true)` — a one-of group; „Anderes suchen" a
  `BbTapArea(label: 'Anderes suchen', expanded: isSearchOpen)`. The ellipsis never shortens the spoken name.
- Taps: a drink tile → `HapticService.selection()`, `toggleDrink` (tapping the selected tile deselects and clears the amount,
  as today). „Anderes suchen" → `openSearch()` / `closeSearch()`.
- `DrinkSearch` keeps everything: inline suggestions, drag-safe list, „„X" hinzufügen" create row with its snackbars,
  delete of own drinks („Getränk löschen") with its snackbar. Selecting or creating closes the search.

### 4.6 „Wie viel?" section (`DrinkSizeSelector`, rewritten)
- Heading „Wie viel?" (`header`), `foreground`, or `mutedForeground` while no drink is selected.
- Four vessel tiles from `DrinkVessel.values` (Glas 250, Dose 330, Flasche 500, Große 1000; the ml equal
  `AppConstants.drinkSizes`), 4 columns (2 at scale ≥ 1.5), `spacingSm` gaps, min height
  `AppConstants.vesselTileMinHeight` = 96, content bottom-aligned: vessel glyph at its mockup size (22×28, 20×34, 18×40,
  24×46), `gap4`, name (`fontSizeCaption`, `mutedForeground`), amount (`formatAmount`, `fontSizeBody` w600). Selected as the
  drink tiles (white, 2 px `infoText` border, glyph `infoText`).
- Disabled (no drink): `onTap` null, glyph `mutedForeground`, amount text `mutedForeground`; no `Opacity` on text (contrast
  stays ≥ 4.5:1). Under the tiles „Wähle zuerst ein Getränk." (`fontSizeCaptionLG`, `mutedForeground`), excluded from
  semantics because every tile says it: `BbTapArea(label: 'Glas, 250 ml', hint: 'Wähle zuerst ein Getränk.', exclusive:
  true, selected: false)`, disabled. `BbTapArea` gains `hint`.
- With a drink: tiles enabled, the hint gone, and below them the „Andere Menge" row: visible label „Andere Menge"
  (`fontSizeBody` w500, excluded from semantics) and a pill field (white, 2 px `infoText` border while it has text, else
  `border`) with the digits right-aligned and „ml" inside as suffix. Same rules as today: digits only, at most 5, valid
  1–3000, error „Bitte gib 1 bis 3000 ml ein.", a vessel tap clears it, typing clears the vessel; field name for assistive
  tech „Andere Menge in ml" (`BbLabeledField`), `scrollPadding: fieldWithHintScrollPadding`.

### 4.7 Time line (`DrinkTimeLine`) and save button
- Centred line: clock glyph (`Icons.access_time`, `iconSizeSm`), `'${DrinkHelpers.timeLabel(trackedAt, now)} · ändern'`
  (`fontSizeBody` w600). `timeLabel` = `formatRecentDayTime` with the first letter upper-cased: „Heute, 14:30",
  „Gestern, 14:30", „26. Nov., 14:30". Tap toggles the existing `DateTimeChips(value: trackedAt, onChanged: setTrackedAt)`
  below it (`AnimatedSize`, `ReducedMotion.duration(context, animDisclosure)`). Semantics: `BbTapArea(label: 'Zeitpunkt',
  value: '<formatDateWeekdayLong>, <formatTime>', expanded:)`. A changed day reloads the total (unchanged `setTrackedAt`).
- Wall clock: `trackedAt` is never `toLocal()`ed or `astimezone`d anywhere; pickers build plain local `DateTime`s as today.
- Save button: shown iff `selectedDrink != null`; `BbButton(label: DrinkHelpers.saveLabel(drink, selectedAmount),
  isLoading: isSaving, onPressed: selectedAmount == null ? null : _save)`. `saveLabel` → „400 ml Pfefferminztee eintragen",
  without an amount „Pfefferminztee eintragen". Long names wrap.

### 4.8 Pure helpers (`DrinkHelpers`)
- `glassFills(int drunkMl, int pendingMl) → List<GlassFill>`; `GlassFill = ({double drunk, double pending})`, shares of one
  glass (0–1). Glass *i* spans `[250 i, 250 (i+1))`; `drunk = clamp(drunkMl − 250 i, 0, 250) / 250`;
  `pending = clamp(drunkMl + pendingMl − 250 i, 0, 250) / 250 − drunk`; count `max(1, ceil(total / 250))`, capped at 48.
- `glassesLabel(int drunkMl, int pendingMl)`: „Nichts eingetragen" / „1 Glas zu 250 ml getrunken" /
  „4 Gläser zu je 250 ml getrunken" / „4 Gläser zu je 250 ml und 100 ml getrunken" / „100 ml getrunken", plus
  „, dazu kommen 400 ml" while pending.
- `tileDrinks(List<Drink> quick, Drink? selected, {int count = 5})`: Wasser (name `wasser`, case-insensitive) first, then
  the rest in order, without duplicates, at most `count`; a selected drink not among them replaces the last.
- `iconFor`, `saveLabel`, `timeLabel` as above; `formatAmount` now „l".
- `buildQuickDrinks` gains the starter fill (decision 15) for fewer than 5 drinks:
  `AppConstants.starterDrinkNames = ['Wasser', 'Kaffee', 'Pfefferminztee', 'Schwarzer Tee', 'Apfelsaftschorle']`.

### 4.9 Colours, sizes, contrast
Mockup → token: `#F2D9DD` `screenBackground`; `#F9F7F4` `card`; `#FFFFFF` `background`; `#302820` `foreground`;
`#675E57` `mutedForeground`; `#4A423C` → `mutedForeground` (5.92:1 on card); `#1D4ED8` `infoText`; `#6EC6F0` `buddyWater`;
`#DCEBFB` → `careWaterSoft` (`#E2F0FA`); `#B5CC47` `primary`; `#8A7F78` → `mutedForeground`. No new colour token.
Text pairs: foreground on card 13.5:1, on white 14.5:1, on primary 8.1:1; mutedForeground on card 5.9:1, on screen
4.75:1, on white 6.4:1; infoText on card 6.3:1, on white 6.7:1. New `AppConstants`: `drinkTileMinHeight 84`,
`vesselTileMinHeight 96`, `drinkTileIconSize 28`, `drinkRowIconSize 26`, `drinkGlyphStroke 1.8`, `drinkGlassMl 250`,
`glassMeterMaxGlasses 48`, `glassMeterGlassSize Size(22, 28)`, `drinkTileCount 5`, `dashLengthSm 3`, `dashGapSm 3`,
`drinkGridLargeTextScale 1.5`, `starterDrinkNames`.

## 5. Every existing behaviour and state, and where it goes

| Today | After |
|---|---|
| `reset(trackedAt:)` + `loadDrinks()` + `loadDayTotal()` post-frame on open; `initialTrackedAt` seeded verbatim | Same; `loadDrinks` also loads the last entry |
| Loading spinner while `isLoading` | Same |
| Load failure: logged, empty lists, no message | Same (only „Anderes suchen" and search's create row show); not changed in this track |
| Day total for `trackedAt`'s day; stale result dropped; reload on day change | Same, feeds the today card |
| „Heute: " / „Am 22.11.: " + total + „(+250 ml)" | „Heute getrunken" / „Am 22.11. getrunken", big total incl. pending, „+ 250 ml", glasses |
| `DateTimeChips` always visible | Behind the time line („· ändern"), same chips and pickers |
| Search field always visible, inline suggestions, drag-safe, create row + snackbars, delete own drink + snackbar | Revealed by „Anderes suchen"; all of it unchanged inside |
| „Ausgewählt: X" chip with ✕ „Auswahl entfernen" | Gone: the selected tile shows it; tapping it again deselects |
| Quick pills, „Wähle aus deinen letzten Getränken" / „Häufige Getränke" | Tiles, „Oder wähle aus" / „Was?"; without history the starter fill |
| No user: first 11 drinks | Same list, tiles show the first five |
| Size buttons only with a drink | Vessels always shown, disabled with the hint until a drink is chosen |
| Custom amount: digits, 5 chars, 1–3000, error text, preset clears it, „Andere Menge in ml" | Same rules and names; visible label „Andere Menge", „ml" suffix |
| „Speichern" fixed at the bottom, disabled until drink + amount, spinner while saving | Named button, shown with a drink, disabled until amount; spinner |
| `save()`: uuid entry, `addDrinkEntry`, reload total, invalidate diary day, success; error rethrown → `saveWithFeedback` snackbar | Same, shared by `saveLast()` |
| Success: „Getränk gespeichert!", `LogSuccessHero`, Buddy event only when stored | Same for both buttons |
| Closing the success pops `true` (meal success screen then closes) or goes Home | Same for both buttons |
| Opened from Home ring, log sheet, meal tracker button, meal success „Trinken eintragen" (`extra: trackedAt`) | Unchanged routes |
| Diary editing | Uses `DrinkDetailSheet`, not this screen: untouched |
| Haptics: selection on drink/size/search pick, light on buttons | Same, plus selection on vessel tiles |
| Keyboard: amount hint fully visible above the button on a 393×852 phone | Same test, the button's new label |
| Title „Was hast du getrunken? 💧" | „Was hast du getrunken?" |

## 6. Accessibility
- Tap targets ≥ 48 px (tiles ≥ 84, vessels ≥ 96, buttons 48, time line `BbTapArea` with `TapTarget`).
- Semantics as in §4.2–4.7; section headings are headers; drink tiles and vessel tiles are each a one-of group.
- 200 % text: everything scrolls; tiles grow; grids drop to 2 columns; no vertical overflow (harness).
- Reduced motion: all animations use `ReducedMotion.duration`.
- Harness: „Getränk" (with a last entry, the D1 state) stays and „Getränk (ohne Verlauf)" is added, both with no pending
  check; the D2 state (drink + amount chosen, search open) is checked in the screen's own test with the same guidelines.

## 7. Non-goals
No goal, reminder or advice in the card. No server, schema, RLS or policy change. No icon field on drinks. No change to the
diary's drink sheet. No provider rewrite to `AsyncNotifier`. No new error UI for a failed load.

## 8. Left to the builder
Exact `Path` transcriptions (keep the mockup's look); whether the glass fill animates with `TweenAnimationBuilder` or
`AnimatedContainer`; widget-private structure inside each file.

## 9. Needs from Severin
- Confirm the starter names (decision 15) exist in the catalog under these exact names, or name the five a new user should
  see.

## 10. Manual checks for Severin (device; no simulator on the build machine)
1. iPhone and Android, a user with history: the screen opens with „Wie zuletzt"; „Eintragen" saves at the shown time, the
   Buddy reacts, the diary shows the entry.
2. Pick a tile and „Flasche": the button reads „500 ml … eintragen", the card shows „+ 500 ml" and two dashed glasses.
3. Type 400 in „Andere Menge" with the number pad open: the field and its error (try 99999) stay visible above the button.
4. „Anderes suchen" → search „Mate" → „„Mate" hinzufügen": it becomes the selected fifth tile.
5. „· ändern" → pick yesterday: the card says „Am 26.11. getrunken" with that day's total.
6. VoiceOver / TalkBack: the glasses row is one image with its sentence; tiles say „ausgewählt"; disabled vessels say
   „Wähle zuerst ein Getränk."; the one-tap button says „Wasser, 250 ml eintragen".
7. Largest system text: nothing cut, grids in two columns, the one-tap button under its text.
8. Reduce Motion on: no fill or border animation.
9. From the meal success screen „Trinken eintragen" → save: both success screens close.
