# Barrierefreiheit (accessibility pass) — Design

**Status:** track F3 of the business-plan gap analysis, planned in the autonomous run of 2026-11-26/27. Severin is away; the
controller set the scope (an audit plus a pass over the existing app, app only, verifiable without a simulator). Everything
else below is Claude's call, labelled as such.
**Repo:** app `severinkl/bellybuddyapp`, branch `feat/accessibility`, stacked on `feat/share-link` @ dcbdd15 (the shares
screens are in scope and exist only there). No server change.

## 1. Intent

The business plan promises a „barrierefreie" app, and the European Accessibility Act covers consumer apps with e-commerce
features (a subscription is planned). Nobody has done a systematic pass yet. There have been about fifteen targeted fixes
(German labels for the password eye, the back arrows and scrims; sliders read as „N von 5"; the calendar icons at 3:1; the
care ring and the bottom bar fitting large text; a reduced-motion mode for the Buddy). This pass finds what is still missing,
fixes it with a few shared pieces, and adds guardrail tests so the problems cannot come back unnoticed.

**Success:** on every main screen a VoiceOver/TalkBack user can reach and name every control, hear every value and every
error, and never needs a swipe-only or timed gesture. At 200 % text nothing is cut off vertically. Text meets 4.5:1 contrast
(3:1 for large text and meaningful icons). With „Bewegung reduzieren" on, nothing bounces, shimmers or slides. CI fails when
someone adds an `IconButton` without a tooltip, an unlabelled tap target, a target below 48×48, or low-contrast text on a
screen in the guardrail list.
**Anti-goals:** a redesign; a conformance claim; scattered one-off `Semantics` wrappers that the next feature forgets.

## 2. Audit (`feat/share-link` @ dcbdd15)

Method: a read of `lib/` (376 files), paren-matched scans for each widget pattern, and WCAG 2.x contrast computed from the
`AppTheme` hex values (the formula of `test/config/app_theme_contrast_test.dart`). Counts are what the scans found. A
widget-test run will find more, which is what the guardrails in §4.4 are for.

### 2.1 Tappable widgets without a name or role
- **`IconButton` without `tooltip`: 7 of 28.** `recipes/recipes_screen.dart:28` (add), `recipes/widgets/recipes_search_field.dart:59`
  (clear), `settings/widgets/password_change_section.dart:169, 189, 223` (three eyes), `trackers/drink/widgets/drink_search.dart:170`
  (delete own drink), `widgets/common/ingredient_search.dart:310` (delete own ingredient).
- **`GestureDetector`/`InkWell` around a bare icon, without semantics: 5.** `dashboard/widgets/notification_opt_in_dialog.dart:92`
  (✕), `settings/widgets/reminder_time_picker.dart:111` (✕ remove a time), `trackers/meal/widgets/meal_image_section.dart:272`
  and `:374` (✕ remove photo), `widgets/common/ingredient_search.dart:222` (✕ close search, a `suffixIcon`).
- **Tap layers with no label: 2.** The tour's full-screen advance layer (`tutorial/dashboard_tutorial_overlay.dart:219`, a
  screen-reader user can only „Überspringen", never step through), and the two mascots beside each Bauchgefühl/Stimmung slider
  (`widgets/common/mood_slider_row.dart:39, 65`, nine rows), which duplicate the slider's own action.
- **Custom buttons with text but no button role or selected state: 11 widgets.** `BbBottomNav` tabs and the „Eintragen"
  button (`bb_bottom_nav.dart:241, 313`), `BbSettingsItem` (every Ich and Einstellungen row, via `PressScaleWrapper`),
  `DiaryEntryCard` (`diary_entry_card.dart:84`, a `GestureDetector` around a non-tappable `BbCard`), `MoodTabSelector`
  (Bauchgefühl/Stimmung), `DateTimeChips` (the date and time read as a bare „26.11.2026"), `SelectableItemGrid`,
  `BbSelectionButton`, `DietSelector`, `QuickDrinkGrid`, `DrinkSizeSelector`. (`BbFilterChip`, `CircleIconButton`, `BbCard(onTap)`,
  the care ring and the streak badge already do this right.)

### 2.2 Images
- **`MascotImage`** (13 uses) renders `Image.asset` with no `semanticLabel` and no `excludeFromSemantics`. VoiceOver can
  stop on an unnamed „Bild" in empty states, the success page, the opt-in dialog, the Tipps header and the 404 page. All 13 are
  decorative (text next to each says the same).
- **Network images:** 9 `CachedNetworkImage`. `RecipeImage` and the knowledge tile handle semantics already. `SignedPathImage`,
  `MealImage`, `MealThumbnail` and the two Alternativen images don't. All are decorative next to their title, except the meal
  photo in the Tagebuch detail sheet, which is content.
- **SVG:** 4 uses. `NeedIcon` is already excluded. The diary card's icon and the splash logo aren't.
- **The Buddy** (`AnimatedBuddy`) is already labelled „<Name>, <Stimmung>" and its bubble is a live region. Nothing to do.

### 2.3 Tap targets below 48×48 (Android's guideline; iOS's is 44)
`CircleIconButton` 44 (the Tagebuch's day arrows). `AppConstants.minTapTarget` is 44 („Apple's 44 pt") and is used by the
tour's „Überspringen". The meal photo ✕ is 40. The ingredient search ✕ is 32. The reminder-time ✕ is about 24. The opt-in
dialog ✕ is 24. The date/time chips are about 40 tall. The Bauchgefühl/Stimmung tabs are about 38. „Bearbeiten" in the tip feedback is
`Size(0,0)` + `shrinkWrap` (`recommendation_feedback_view.dart:140`). „Passwort vergessen?" is `Size.zero` + `shrinkWrap`
(`password_change_section.dart:269`). The 1–5 scales are Material `Slider`s, so their targets are fine, and so is the Klo scale (also a `BbSlider`,
not chips). `BbFilterChip` gets Material's padded 48.

### 2.4 Text scaling
- **No global clamp:** `MaterialApp.router` in `lib/app.dart` sets no `textScaler`. Good.
- **Deliberate shrinking:** the care ring's four labels share a scale that drops below the user's when „Bauchgefühl" doesn't fit
  (`care_ring.dart:132`). The bar labels and „Überspringen" use `FittedBox(scaleDown)`. These are known trade-offs from
  earlier rounds, kept (Claude's call: their semantics carry the full text; redoing Home's ring is a redesign).
- **Important text cut to one line:** the Tagebuch card's subtitle (`diary_entry_card.dart:105`), Alternativen's „Stattdessen: …"
  (`discover_alternatives_section.dart:99`). The other 14 `maxLines: 1` are titles with a detail page behind them.
- **Tested so far only up to 1.3×** (8 screen tests). Nothing has been tried at 2.0×.

### 2.5 Contrast (WCAG 2.x, from `AppTheme` hex values)

| Pair (where) | Ratio | Needs |
|---|---|---|
| `mutedForeground` #796F67 on `screenBackground` #F2D9DD (tracker screens: slider end labels, hints) | 3.68 | 4.5 |
| `mutedForeground` on `muted` #E8E4DF / `secondary` #EFEBE6 / `beige` #F5EFE7 / `gutFeelingGoodSoft` / `primarySoft` | 3.87 / 4.13 / 4.29 / 4.33 / 4.48 | 4.5 |
| `primary` #B5CC47 as text: the theme's `TextButton` foreground (≈20 `TextButton`s without their own colour), „+ Hinzufügen" (`ingredient_search.dart:265`) | 1.80 on white, 1.35 on `screenBackground` | 4.5 |
| `destructive` #EF4444 as text (error banner, „✓ Wird berücksichtigt", share/delete warnings) / white on it (delete buttons) | 3.76 white, 3.29 on its 10 % tint | 4.5 |
| `success` #22C55E as text („Gespeichert", „→ Alternative: …", success banner) | 2.28 | 4.5 |
| `info` #3B82F6 as text (drink tracker „(+250 ml)", meal tracker water hint) / white on it (selected-drink pill) | 3.68 / 3.27 on tint | 4.5 |
| Fit badge text: `gutFeelingGoodIcon` on its soft tint / `gutFeelingNeutralIcon` on its tint (11–12 px) | 3.82 / 3.69 | 4.5 |
| Inactive bottom-bar labels: `foreground` at 60 % on `navGradientStart` #FFB5C1 / `navGradientEnd` | 3.32 / 3.60 | 4.5 |
| Inactive Bauchgefühl/Stimmung tab: `foreground` at 60 % on its white-60 % track | 3.86 | 4.5 |
| White „Neu" badge on `navBadge` #E8456F (Ich rows, 11 px bold) | 3.81 | 4.5 |
| Passing for reference: `foreground` on everything (≥ 8.06); `mutedForeground` on white 4.90 and on card 4.59; `primaryForegroundMuted` on primary 5.12; `shareActive` on card 6.17; `notificationMuted` 4.56 | | |

Exempt as decorative (an icon next to text that says the same): `primary` icons on the settings rows and the consent list,
`success`'s white check on the success page, the 45 % placeholder monogram on recipe tints (2.5).
**Colour alone:** the Muster calendar and day columns already pair each class with an icon (59be18e). Fit badges carry a
label and an icon. The gut-feeling slider's colour has its value spoken. The drink pill and the tab selector carry text. Nothing
found that carries information by colour alone.

### 2.6 Custom controls
Sliders (`BbSlider`) are good: labelled, „N von 5" / „Fest, 2 von 5", and the iOS orphan bug is fixed. The care ring speaks
each need's value. The streak badge, week row and insight progress row speak. **Missing:** `BbScrollPicker` (birth year,
height, weight in registration) is a `ListWheelScrollView` with no value and no increase/decrease, so a screen-reader user
cannot set it. `BbProgressBar` (streak sheet, insight progress) has no value of its own (its rows speak, so it gets excluded).

### 2.7 Motion
Respected already: the Buddy (calm mode), streak flame, care ring pulse, journey dots, success overlay, log success hero,
streak pop, speech bubble typewriter, welcome, onboarding, Muster frei!, and 2 of 5 shimmers. **Ignored:** the mascot bounce
in `MoodSliderRow` (9 per tracker screen), the Bauchgefühl tracker's entry animation (`gut_feeling_tracker_screen.dart:70`),
`PressScaleWrapper` (every settings row), `MoodTabSelector`'s animated switch, the tour's fade, and the shimmers in
`suggestion_card.dart`, `suggestion_detail_modal.dart` and `meal_image_section.dart`. (The splash keeps its 1 s fade, which
isn't motion across the screen.)

### 2.8 Forms, headings, live regions
- **Fields with only a hint (the name goes once the user types) or no name at all: 10.** Meal title sheet, drink detail amount
  (no hint, no label: a bare number field), drink custom amount, drink search, ingredient search, recipe step field, recipes
  search, collection search, Alternativen search, the editable app-bar title. (`share_create_screen.dart` already shows the
  pattern: `Semantics(label:, textField: true)` around the field.)
- **Errors not announced:** `BbAuthBanner` (login, registration, email capture) is plain text, not a live region. The same
  goes for `BbLoadingState`/`BbErrorState` messages. `BbButton` drops its label while loading (only a spinner is left).
  Snackbars are live regions already (Flutter's `SnackBar`).
- **Headings:** 8 explicit `header: true`. Screens with an `AppBar` get their title as heading and route name from Flutter.
  Home (`dashboard_screen.dart`, no app bar, no title) has no heading and no route name.
- **Focus order in sheets and dialogs:** nothing out of order found by reading. The guardrail traversal check covers it from now on.

### 2.9 Blockers for screen-reader users
- **Swipe-only:** dismissing an Alternativen card (`suggestion_card.dart:25`, a `Dismissible` with no other way to do it).
- **Wheel-only:** `BbScrollPicker` (§2.6), which blocks registration outright for a screen-reader user.
- **Tap-anywhere-only:** the tour's step advance (§2.1).
- **Timed:** the Buddy's cue lines leave after 4 s (`buddy_hero.dart:155`). They're live regions, so they get announced,
  but a slow listener loses the next one. The no-hero success overlay auto-closes after 1.5 s (a confirmation, also spoken).
  The Tagebuch's day swipe has „Vorheriger/Nächster Tag" buttons too, so that one is fine.

## 3. Decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Scope | All main screens incl. shares; app only; no new features (controller) |
| 2 | Labels | German, „du", short verb-first names („Foto entfernen", „Suche löschen"); a value is a value, not part of the label (Claude's call; wrong costs a relabel) |
| 3 | Decorative vs. meaningful | Every mascot and list image is decorative (excluded); the meal photo in the Tagebuch detail is content („Foto: <Titel>"); the Buddy keeps his label (Claude's call) |
| 4 | Contrast fix | Darken five tokens and add five text tokens; fills and decorative icons keep their colours (Claude's call; **visual change: needs Severin's eye**, §4.3) |
| 5 | Tap target floor | 48×48 everywhere (`AppConstants.minTapTarget` 44 → 48) (Claude's call; wrong costs a few px) |
| 6 | Fields | No visible floating labels; a semantics label on each field, as in `share_create_screen.dart` (Claude's call; wrong costs a later visual pass) |
| 7 | Swipe-only dismiss | A custom semantics action „Ausblenden", no new visible button (Claude's call) |
| 8 | Timed Buddy lines | Held twice as long (8 s) when a screen reader is on (`MediaQuery.accessibleNavigationOf`) (Claude's call; wrong costs a slower Home for screen-reader users only) |
| 9 | Care ring / bar label shrink | Kept (Claude's call, §2.4) |
| 10 | Branch | Stacked on `feat/share-link`, PR targets it (Claude's call: the shares screens are in scope) |

## 4. Design

### 4.1 Principles
One shared piece per pattern, in `lib/widgets/common/` or `lib/utils/`, which is what the static test enforces. Fix the widget
once, not each call site. Decorative means `ExcludeSemantics`/`excludeFromSemantics`. Meaningful means a German label. A
control has a role (`button`, `selected`, `textField`, `slider`-like increase/decrease) as well as a name. Nothing visible
changes unless §4.3 lists it.

### 4.2 Shared pieces
- **`BbIconTap`** (`lib/widgets/common/bb_icon_tap.dart`): an icon you tap, `required String semanticLabel`, a 48×48 hit area
  around any icon size, `button: true`, enabled from `onTap`. It replaces the five raw icon `GestureDetector`s.
- **`TapTarget`** (`lib/widgets/common/tap_target.dart`): pads its child's hit area up to `AppConstants.minTapTarget` without
  changing what is drawn. Used for the chips, tabs and text links of §2.3.
- **`ReducedMotion`** (`lib/utils/reduced_motion.dart`): `ReducedMotion.of(context)` and `ReducedMotion.duration(context, d)`
  (zero when reduced), plus `ReducedMotion.shimmer(context, child)`, which shows the static placeholder base when reduced. It
  wraps `MediaQuery.maybeDisableAnimationsOf`. The places that already do this keep their own code.
- **`MascotImage`** gets `String? semanticLabel`. Null means `excludeFromSemantics: true`.
- **Live text:** `BbAuthBanner`, `BbLoadingState`'s and `BbErrorState`'s message become `Semantics(liveRegion: true)`. `BbButton`
  keeps its label in semantics while loading, with the value „lädt".
- **Selection role:** `SelectableItemGrid`, `BbSelectionButton`, `DietSelector`, `QuickDrinkGrid`, `DrinkSizeSelector`,
  `MoodTabSelector`, bottom-bar tabs: `Semantics(button: true, selected: …)`. Pressed-scale rows (`PressScaleWrapper`) take
  `semanticsButton: true`.
- **Adjustable picker:** `BbScrollPicker` gets `required String semanticLabel` and exposes `value`, `increasedValue`,
  `decreasedValue`, `onIncrease`, `onDecrease` with the wheel itself excluded.
- **Static rule test** (`test/accessibility/static_rules_test.dart`), modelled on the vocabulary test: it fails on `IconButton(`
  without `tooltip:` inside its parentheses; on `GestureDetector(`/`InkWell(` whose `child:` is directly an `Icon(`; on
  `Image.asset(` outside `MascotImage` and `reminder_preview.dart`; on `MaterialTapTargetSize.shrinkWrap` and on
  `minimumSize: Size.zero` / `Size(0, 0)`; and on `foreground.withValues(alpha: 0.6)`. Every exception goes in a commented
  allowlist with a reason.

### 4.3 Colour tokens (visual change: needs Severin's eye)

| Token | Now | New | Result |
|---|---|---|---|
| `mutedForeground` (changed) | #796F67 | **#675E57** | 4.75 on `screenBackground`, 5.01 on `muted`, 5.34 on `secondary`, 5.54 on `beige`, 6.33 on white |
| `destructive` (changed) | #EF4444 | **#C62828** | 5.62 on white, 4.81 on its own 10 % tint, 5.62 white-on |
| `primaryText` (new) | — | **#56631A** (the lime's olive) | 6.57 white, 6.15 card, 4.93 `screenBackground`, 6.03 on lime 15 %; the theme's `TextButton` foreground and „+ Hinzufügen" |
| `successText` (new; `shareActive` becomes an alias) | — | **#1F6B1F** | 6.60 white, 5.69 on its 10 % tint, 5.82 on `gutFeelingGoodSoft`; „Gespeichert", „→ Alternative", success banner, fit badge „Passt zu dir" |
| `gutFeelingNeutralText` (new) | — | **#7A5F00** | 5.50 on `gutFeelingNeutralSoft`; the other fit badges |
| `infoText` (new) | — | **#1D4ED8** | 6.70 white, 5.96 on 10 % tint, 5.02 `screenBackground`; drink/meal water texts and the selected-drink pill (white on it 6.70) |
| `foregroundInactive` (new) | `foreground` @ 60 % | `foreground` @ **75 %** (`Color.from`, like `placeholderGlyph`) | 4.78 / 5.41 on the bar gradient, 6.05 on the tab track |
| `badgeFill` (new) | `navBadge` #E8456F | **#C8325A** | white on it 5.17; the „Neu" pill only (the bar's news dot keeps `navBadge`, 3.81 as an icon) |

`primary`, `info`, `success`, `navBadge` and the gut-feeling colours keep their values as fills and icons. Other visual
changes: `CircleIconButton` 44 → 48. The date/time chips, the Bauchgefühl/Stimmung tabs and the meal photo ✕ (40 → 48) get
slightly taller hit areas, drawn where the hit area is visible. The Tagebuch card subtitle and „Stattdessen: …" go to 2 lines. The
small ✕s, „Bearbeiten" and „Passwort vergessen?" get invisible 48 px hit areas (a row may grow by a few px).

### 4.4 Guardrail tests
- **Screen list** (`test/accessibility/a11y_screens.dart`): one `A11yScreen` per route of `RoutePaths`, signed in through
  `baseOverrides` and pumped by `AppTestHost` (gains `textScale`) on a 402×874 view. Its seeds come from `test/helpers/fixtures.dart`:
  Home, Tagebuch with one entry of each kind, Entdecken, Tipps, Alternativen, Rezepte, a collection recipe, the recipe editor,
  Wissen, Muster (locked and unlocked), Muster frei!, Ich, Einstellungen and its three subpages, Freigaben and „Neue Freigabe",
  the four trackers, Welcome, Auth, Registration (first step), Health consent, Buddy onboarding, Upgrade required. Each entry
  has `pending`, a set of the checks it doesn't pass yet, each with the task id that clears it.
- **Guidelines** (`screen_guidelines_test.dart`): for each screen and each of `androidTapTargetGuideline`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`, it runs `expectLater(tester, meetsGuideline(g))`, skipped
  while pending.
- **Text scale** (`text_scale_test.dart`): each screen at `textScale: 2.0` collects Flutter errors (`collectFlutterErrors`)
  and expects `verticalOverflows(errors)` empty (horizontal overflows are test-font noise, as `layout_checks.dart` notes).
- **Tokens:** `app_theme_contrast_test.dart` gains a table of every text pair from §4.3 asserting ≥ 4.5.
- The screens of later tracks (portal, subscription, daily review, guided tests, Akuthilfe, barcode) are covered from the day
  they are added to the screen list. Each track's plan should add its routes there.

## 5. Non-goals and scope honesty
- **No conformance claim.** This pass makes the app much better for screen-reader, large-text, low-vision and reduced-motion
  users. It doesn't establish conformance with WCAG 2.1/2.2 AA or EN 301 549, which would need a formal check against every
  criterion on real devices.
- **No testing by affected users.** Nobody with a screen reader, low vision or a motor impairment has used the app for this.
- **Not checked by any test:** VoiceOver/TalkBack reading order across a whole flow, Switch Control / keyboard access, iOS
  Dynamic Type above 200 %, high-contrast and colour-inversion modes, captions (there's no media), and the push notification texts.
- **The dietitian website (`bellybuddy-connect`) and the admin SPA are separate** and not covered.
- No redesign of the care ring, the bottom bar or Home's layout. No dark mode.

## 6. Left to the builder
- The exact semantics mechanism for field labels, as long as the test finds the field's node by its label.
- Whether `TapTarget` is a widget or a `BoxConstraints` helper, as long as the guideline tests pass.
- Which screens fail a guideline on the first harness run: the task that owns a screen clears its pending checks or reports
  the leftover as a concern. A pending check is never deleted without its fix.

## 7. Privacy policy text
None. No new data, processor or purpose.

## 8. Needs from Severin
- **Look at the colour changes of §4.3** on a device (muted text, olive text buttons, deeper red, darker badge and water blue).
  If one is too heavy, name it and the plan's XA1 adjusts the value within the same contrast floor.
- **Accessibility statement („Erklärung zur Barrierefreiheit") text and a formal check before any conformance claim:**
  the EAA expects a statement (what's accessible, what isn't, a contact for feedback) for the store listing and the website. Its
  wording, and whether to commission an audit (e.g. against EN 301 549 / BITV), is a legal and business call.
- Whether the store listings may say „barrierefrei" before that audit. Claude's advice: no, say „mit VoiceOver/TalkBack und
  großer Schrift nutzbar" at most.

## 9. Manual checks for Severin (device, after the PR)
1. VoiceOver (iPhone) and TalkBack (Android): sign up from Welcome to Home, including setting birth year, height and weight
   with the swipe-up/down gesture. Every control is spoken with its name and role.
2. Log one entry of each kind. The success message is spoken. On the Bauchgefühl screen the mascots are skipped and each
   slider reads „Krämpfe, 3 von 5".
3. Home: the tour can be stepped with „Weiter" and closed with „Überspringen". The Buddy's lines are read in full.
4. Alternativen: „Ausblenden" appears in the actions rotor (iOS) / actions menu (TalkBack).
5. Settings → text size at maximum (iOS „Größerer Text" on, slider right; Android font size max + display size max): Home,
   Tagebuch, each tracker, Ich. Nothing is cut off, everything scrolls.
6. „Bewegung reduzieren" / „Animationen entfernen" on: no bounce on the Bauchgefühl mascots, no shimmer, no press-scale on
   the settings rows.
7. Snackbars („Passwort geändert!") and the login error banner are read aloud on iOS too. If VoiceOver stays silent, report
   it: a follow-up adds `SemanticsService.sendAnnouncement` on iOS.
8. The new colours of §4.3 in daylight.

## 10. Decisions after the first review (Severin, 2026-11-27)
- **Success overlay (`BbSuccessOverlay`, every tracker's success page and „Muster frei!"), 2026-11-27:** the tap-anywhere
  layer and the action pill's tap-absorber have no semantics node; the page's one named way out for screen readers is the
  „Tippen zum Fortfahren" hint, now a button named „Schließen" with a 48 px hit area. The title is a heading. The page
  scrolls when its texts need more than the screen (200 % text); the illustration then gets at least 160 px, otherwise the
  height left over as before. „Muster frei!" now runs all guardrail checks.
- **Welcome hint pulse, 2026-11-27:** „Tippe, um ihn zu wecken" breathes between 90 % and 100 % opacity (was 45 %), so it
  never drops below 4.5:1 (about 5.0:1 at its low point on white). Under reduced motion it stays at 100 %.
- **Search fields, 2026-11-27:** the label names the field, the placeholder gives an example in one form („z. B. …"), so a
  screen reader reads the name once: Rezeptsammlung „Rezept oder Zutat suchen" / „z. B. Porridge oder Banane", Meine Rezepte
  „Rezept suchen" / „z. B. Porridge", Getränk „Getränk suchen" / „z. B. Pfefferminztee", Zutat „Zutat suchen" /
  „z. B. Haferflocken", Alternativen „Alternativen suchen" / „z. B. Zwiebel". The visible placeholders change (old: the
  label again, „Suchen..." on Alternativen).
