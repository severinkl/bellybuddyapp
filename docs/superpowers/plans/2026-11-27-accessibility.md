# Barrierefreiheit (accessibility pass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every main screen can be used with VoiceOver/TalkBack, at 200 % text and with reduced motion, its text meets 4.5:1, and guardrail tests keep it that way.

**Architecture:** First, contrast-safe tokens, a few shared widgets (`BbIconTap`, `TapTarget`, `ReducedMotion`, live and selected semantics in the common widgets) and a guardrail harness that runs Flutter's accessibility guidelines and a 2.0× text-scale check over a list of screens, each with its not-yet-passing checks marked pending. Then one task per area fixes its audit findings and clears its pending checks. Last, the gates.

**Tech Stack:** Flutter (`material_ui`), flutter_test accessibility guidelines (`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`), Riverpod, GoRouter, `shimmer`. No new package.

**Spec:** `docs/superpowers/specs/2026-11-27-accessibility-design.md` (branch `docs/plan-accessibility`). Audit references (§2.x) point there.

## Repos and commands

| What | Where / how |
|---|---|
| App repo | `~/projects/bellybuddy`; work in a new worktree `~/projects/bellybuddy/.worktrees/accessibility`, branch `feat/accessibility` from `feat/share-link` (stacked: the shares screens are in scope). `git -C ~/projects/bellybuddy worktree add .worktrees/accessibility -b feat/accessibility feat/share-link` |
| Tests | `flutter test <path>`; the new suite: `flutter test test/accessibility` |
| Gates | `dart format --set-exit-if-changed . && flutter analyze` (zero issues) |
| Commits | the pre-commit hook fails inside worktrees: run the gates by hand, commit with `--no-verify` |
| Devices | no simulator or emulator on the dev box: device behaviour goes to the spec's §9 manual checks |
| Server | none |

## Global Constraints

- All user-facing strings, semantic labels and tooltips German, „du". Use the app's words (vocabulary test: „eintragen", „Klo", „Tipp", „Streak"; never „erfassen", „tracken", „Stuhlgang", „Empfehlung"). The mascot is „Belly Buddy"/„Buddy".
- Colours only as `static const Color` in `AppTheme`; font sizes only `AppTheme.fontSize*`; spacing, radii and sizes only from `AppConstants`. A literal on a line this plan touches moves to a token in the same commit.
- Riverpod, GoRouter, `AppLogger` (never `print()`), `CachedNetworkImage` for network images.
- One shared piece per pattern (spec §4.2). No call-site `Semantics` wrapper where a shared widget exists.
- Every visual change is one listed in spec §4.3. Anything else that would change the look is reported as a concern, not done.
- A pending guardrail check is removed only together with the fix that makes it pass, in the task that owns the screen.
- Wording never reads as diagnosis or treatment.
- Conventional commits. The PR targets `feat/share-link` (the branch this stacks on). Never merge, never arm auto-merge; stop at `gh pr create`.

## Review Focus

1. **A 200 % text user on a 402-pt-wide phone opens each main screen.** Nothing is cut off vertically; long rows wrap or scroll. This is `text_scale_test.dart` per screen (XA3), cleared per area task.
2. **A screen-reader user meets a control that works only by swiping, wheeling or tapping anywhere** (Alternativen dismiss, the registration wheels, the tour). Each gets a named semantics action. Tests in XA7 (`Ausblenden`), XA10 (`onIncrease`/`onDecrease`) and XA4 (`Weiter`).
3. **„Bewegung reduzieren" is on.** No bounce, shimmer, press-scale or entry slide: each widget shows its end state at once. Tests in XA2 (`ReducedMotion`, `PressScaleWrapper`), XA5 (mascot bounce, entry animation) and XA7 (shimmer).
4. **An error or a finished load appears while the user's focus is elsewhere** (wrong password, a failed load, a button that is loading). It is a live region, and the button keeps its name. Tests in XA2 (`BbAuthBanner`, `BbErrorState`, `BbButton`).
5. **The user types into a field that had only a hint.** The field keeps its name after the hint disappears. Tests in XA5, XA6, XA7 and XA9 assert the label with text entered.

---

### Task XA1: Contrast-safe colour tokens

**Files:**
- Modify: `lib/config/app_theme.dart`, `lib/widgets/common/ingredient_search.dart:265`, `lib/widgets/common/bb_auth_banner.dart`, `lib/screens/settings/widgets/settings_profile_screen.dart:176`, `lib/screens/recommendations/widgets/recommendation_card.dart:116`, `lib/screens/recipes/widgets/fit_badge_view.dart`, `lib/screens/trackers/drink/drink_tracker_screen.dart:180,206`, `lib/screens/trackers/meal/meal_tracker_screen.dart:245`, `lib/widgets/common/bb_bottom_nav.dart:256,295`, `lib/screens/trackers/gut_feeling/widgets/mood_tab_selector.dart:64`, `lib/widgets/common/bb_settings_item.dart` (badge)
- Test: `test/config/app_theme_contrast_test.dart`

**Interfaces — Produces** (spec §4.3, values verbatim):

```dart
static const Color mutedForeground = Color(0xFF675E57);   // was 0xFF796F67
static const Color destructive = Color(0xFFC62828);       // was 0xFFEF4444
static const Color primaryText = Color(0xFF56631A);
static const Color successText = Color(0xFF1F6B1F);
static const Color shareActive = successText;
static const Color gutFeelingGoodText = successText;
static const Color gutFeelingNeutralText = Color(0xFF7A5F00);
static const Color infoText = Color(0xFF1D4ED8);
static const Color foregroundInactive = Color.from(alpha: 0.75, red: 0x30 / 255, green: 0x28 / 255, blue: 0x20 / 255);
static const Color badgeFill = Color(0xFFC8325A);
// theme: textButtonTheme foregroundColor: primaryText
```

Uses: `TextButton` theme and „+ Hinzufügen" → `primaryText`. „Gespeichert", „→ Alternative: …" and the `BbAuthBanner` success colour → `successText`. Fit badge text and icon → `gutFeelingGoodText`/`gutFeelingNeutralText`. Drink „(+… ml)", the meal water hint and the selected-drink pill fill → `infoText`. Inactive bar icons and labels and the inactive tab text → `foregroundInactive`. The `BbSettingsItem` „Neu" pill → `badgeFill`.

- [ ] **Step 1: Write the failing tests** in `app_theme_contrast_test.dart` (reuse its `_contrast`; `_over(fg, alpha, bg)` blends for tints):

```dart
test('every text pair has at least 4.5:1')   // table, reason: pair name
//  mutedForeground on background, card, screenBackground, muted, secondary, beige, primarySoft, gutFeelingGoodSoft
//  primaryText on background, card, screenBackground, primary@15% over white
//  destructive on background, card, destructive@10% over white; Colors.white on destructive
//  successText on background, card, successText@10%, gutFeelingGoodSoft
//  gutFeelingNeutralText on gutFeelingNeutralSoft
//  infoText on background, infoText@10%, screenBackground; Colors.white on infoText
//  foregroundInactive over navGradientStart, navGradientEnd, white@60% over screenBackground
//  Colors.white on badgeFill
test('the theme\'s TextButton draws its text in primaryText')   // AppTheme.theme.textButtonTheme.style!.foregroundColor!.resolve({}) == AppTheme.primaryText
test('shareActive and gutFeelingGoodText are successText')
```

- [ ] **Step 2: Run** `flutter test test/config/app_theme_contrast_test.dart`. Expected: FAIL (missing tokens, and `mutedForeground` 3.68 on `screenBackground`).
- [ ] **Step 3: Implement** the tokens, the theme change and the listed uses. The existing 3:1 tests (care colours, calendar icons) must still pass unchanged.
- [ ] **Step 4: Run** `flutter test test/config test/widgets test/screens` and the gates. Expected: PASS. Golden or pixel tests that pin an old colour (`test/helpers/pixels.dart` users) are updated to the token, not the hex.
- [ ] **Step 5: Commit** `fix(a11y): text colours meet 4.5:1 contrast`.

### Task XA2: Shared accessibility pieces

**Files:**
- Create: `lib/widgets/common/bb_icon_tap.dart`, `lib/widgets/common/tap_target.dart`, `lib/utils/reduced_motion.dart`
- Modify: `lib/config/constants.dart` (`minTapTarget` 44 → 48; comment „Android's 48 dp; covers Apple's 44 pt"), `lib/widgets/common/mascot_image.dart`, `circle_icon_button.dart` (default size `AppConstants.iconBadgeLg`), `bb_auth_banner.dart`, `bb_async_state.dart`, `bb_button.dart`, `press_scale_wrapper.dart`, `bb_settings_item.dart`, `selectable_item_grid.dart`, `bb_selection_button.dart`, `bb_progress_bar.dart`
- Test: `test/widgets/common/a11y_pieces_test.dart`

**Interfaces — Produces:**

```dart
class BbIconTap extends StatelessWidget {
  const BbIconTap({super.key, this.tapKey, required this.icon, required this.semanticLabel,
      required this.onTap, this.iconSize = AppConstants.iconSizeMd, this.color});
  // Semantics(button: true, enabled: onTap != null, label: semanticLabel), hit area ≥ minTapTarget square,
  // icon centred and drawn at iconSize; ExcludeSemantics around the Icon.
}
class TapTarget extends StatelessWidget {
  const TapTarget({super.key, required this.child, this.alignment = Alignment.center});
  // ConstrainedBox(minWidth/minHeight: AppConstants.minTapTarget) with the child aligned; draws nothing itself.
}
abstract final class ReducedMotion {
  static bool of(BuildContext context);                       // MediaQuery.maybeDisableAnimationsOf(context) ?? false
  static Duration duration(BuildContext context, Duration d); // Duration.zero when of(context)
  static Widget shimmer(BuildContext context, {required Color baseColor, required Color highlightColor, required Widget child});
      // Shimmer.fromColors when animating; ColoredBox(baseColor) around child when reduced
}
// MascotImage: final String? semanticLabel; null → Image.asset(excludeFromSemantics: true)
// PressScaleWrapper: final bool semanticsButton (default true) → Semantics(button: true); no scale when ReducedMotion.of
// BbAuthBanner, BbLoadingState/BbErrorState message: Semantics(liveRegion: true, container: true)
// BbButton while isLoading: Semantics(label: label, value: 'lädt', button: true, enabled: false), spinner excluded
// SelectableItemGrid item, BbSelectionButton: Semantics(button: true, selected: isSelected, inMutuallyExclusiveGroup: single-choice)
// BbProgressBar: ExcludeSemantics (its row speaks)
```

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('BbIconTap is a named button with a 48×48 hit area for an 16 px icon')   // getSize ≥ Size(48,48); getSemantics hasAction tap, label 'Foto entfernen', isButton
testWidgets('BbIconTap without onTap is a disabled button')
testWidgets('TapTarget lifts a 20 px chip to 48 high without drawing more')
testWidgets('ReducedMotion.duration is zero with disableAnimations, unchanged without')
testWidgets('ReducedMotion.shimmer shows no Shimmer with disableAnimations')
testWidgets('MascotImage without a label adds no semantics node; with one it is an image named so')
testWidgets('BbAuthBanner is a live region with its text')
testWidgets('BbErrorState message is a live region')
testWidgets('a loading BbButton still reads „Speichern", value „lädt"')
testWidgets('a BbSettingsItem is a button named by its title; no scale with disableAnimations')
testWidgets('a selected SelectableItemGrid item is selected to assistive tech; the others are not')
testWidgets('CircleIconButton is 48 × 48 by default')
```

- [ ] **Step 2: Run** `flutter test test/widgets/common/a11y_pieces_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** `tutorial/dashboard_tutorial_overlay.dart`'s use of `minTapTarget` grows with the constant. That's expected.
- [ ] **Step 4: Run** `flutter test test/widgets test/screens/me test/screens/diary` and the gates. Expected: PASS (update the existing tests that pin 44 to the constant).
- [ ] **Step 5: Commit** `feat(a11y): shared pieces for icon taps, tap targets, reduced motion and live text`.

### Task XA3: Guardrail harness and static rules

**Files:**
- Create: `test/accessibility/a11y_screens.dart`, `test/accessibility/screen_guidelines_test.dart`, `test/accessibility/text_scale_test.dart`, `test/accessibility/static_rules_test.dart`
- Modify: `test/helpers/app_host.dart` (`AppTestHost({bool followAuth = false, double textScale = 1})` passes it to `germanRouterApp`)

**Interfaces — Produces:**

```dart
enum A11yCheck { androidTapTarget, iosTapTarget, labeledTapTarget, textContrast, textScale200 }
class A11yScreen {
  const A11yScreen(this.name, this.path, {this.seed = const [], this.pending = const {}});
  final String name;                        // German screen name, e.g. 'Tagebuch'
  final String path;                        // a RoutePaths value with ids filled in
  final List<Override> seed;                // added after baseOverrides(...)
  final Map<A11yCheck, String> pending;     // check → owning task id, e.g. {A11yCheck.textContrast: 'XA5'}
}
const a11yScreens = <A11yScreen>[...];      // spec §4.4 list, every RoutePaths route except loading/not-found
Future<void> pumpA11yScreen(WidgetTester tester, A11yScreen s, {double textScale = 1});
    // 402×874 view, dpr 1, padding top 62 / bottom 34; ProviderContainer.test(overrides: [...baseOverrides(), ...s.seed]);
    // AppTestHost(textScale:); router.go(s.path); pumpAndSettle
```

Seeds: Tagebuch with one meal, drink, Bauchgefühl and Klo entry today (`testEntryQueryResult`), Muster locked (3 days) and unlocked (`InsightRules.daysNeeded` days), a collection recipe and an own recipe from the `FakeRecipeRepository`/`FakeUserRecipeRepository`, one active share (`test/helpers/share_fakes.dart`), one tip set. Signed-out screens (Welcome, Auth, Registration) use `FakeAuthRepository` signed out.

- [ ] **Step 1: Write the harness and the tests:**

```dart
// screen_guidelines_test.dart
for (final s in a11yScreens) for (final (check, guideline) in [
    (A11yCheck.androidTapTarget, androidTapTargetGuideline), (A11yCheck.iosTapTarget, iOSTapTargetGuideline),
    (A11yCheck.labeledTapTarget, labeledTapTargetGuideline), (A11yCheck.textContrast, textContrastGuideline)])
  testWidgets('${s.name}: ${check.name}', skip: s.pending[check] != null, (tester) async {
    final handle = tester.ensureSemantics();
    await pumpA11yScreen(tester, s);
    await expectLater(tester, meetsGuideline(guideline));
    handle.dispose();
  });
// text_scale_test.dart
testWidgets('${s.name}: no vertical overflow at 200 % text', skip: s.pending[A11yCheck.textScale200] != null, ...)
    // errors = await collectFlutterErrors(() => pumpA11yScreen(tester, s, textScale: 2)); expect(verticalOverflows(errors), isEmpty)
test('every pending check names a task XA4–XA10')   // guards against orphaned skips
test('every RoutePaths route except loading is in a11yScreens')   // new routes from other tracks must join
// static_rules_test.dart (paren-matched scan of lib/, comments stripped, as vocabulary_test does)
test('every IconButton has a tooltip')
test('no GestureDetector or InkWell whose child is directly an Icon (use BbIconTap)')
test('Image.asset only in MascotImage and reminder_preview.dart')
test('no MaterialTapTargetSize.shrinkWrap, minimumSize: Size.zero or Size(0, 0)')
test('no foreground.withValues(alpha: 0.6) (use foregroundInactive)')
// each with a commented allowlist `const _allowed = {'path:line-anchor': 'reason'}`, empty unless a reason exists
```

- [ ] **Step 2: Run** `flutter test test/accessibility`. Record every failing (screen, check) and enter it in `pending` with its owning area task: Home/Buddy XA4, trackers XA5, Tagebuch XA6, Entdecken XA7, Muster XA8, Ich/Einstellungen/Freigaben XA9, auth/onboarding/consent XA10. The static rules fail with the audit's lists (spec §2.1, §2.3). Put today's offenders in each rule's allowlist with the owning task id as the reason (e.g. `'lib/screens/recipes/recipes_screen.dart:IconButton#1': 'XA7'`), so the rules pass and catch every new offender from now on. Each area task deletes its own entries. The orphan test also checks that every allowlist reason that looks like a task id names XA4–XA10.
- [ ] **Step 3: Run** `flutter test test/accessibility`. Expected: PASS, with the skips listed in the output.
- [ ] **Step 4: Commit** `test(a11y): guideline, text-scale and static guardrails over the main screens`.

### Task XA4: Home and Buddy

**Fixes (spec §2.1, §2.3, §2.7, §2.8, §2.9):** the tour's advance layer has no label (`dashboard_tutorial_overlay.dart:219`); the tour fade ignores reduced motion; the opt-in dialog ✕ is a 24 px unlabelled `GestureDetector` (`notification_opt_in_dialog.dart:92`); the bottom-bar tabs and „Eintragen" have no button/selected role (`bb_bottom_nav.dart:241, 313`); Home has no heading or route name; the Buddy's cue lines leave after 4 s even with a screen reader on (`buddy_hero.dart:155`).

**Files:**
- Modify: `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart`, `lib/screens/dashboard/widgets/notification_opt_in_dialog.dart`, `lib/widgets/common/bb_bottom_nav.dart`, `lib/screens/dashboard/dashboard_screen.dart`, `lib/screens/dashboard/widgets/buddy_hero.dart`
- Test: `test/screens/dashboard/tutorial_overlay_test.dart`, `test/screens/dashboard/dashboard_screen_test.dart`, `test/widgets/common/bb_bottom_nav_test.dart`, `test/screens/dashboard/widgets/buddy_hero_test.dart`, `test/accessibility/a11y_screens.dart` (clear XA4 entries)

Labels: tour layer `Semantics(button: true, label: 'Weiter', onTap: _advance)` (last step: 'Fertig'); the opt-in ✕ is `BbIconTap(semanticLabel: 'Schließen')`; tabs `Semantics(button: true, selected: isActive, label: <tab label>)`, with the news dot adding the value 'neu'; the centre button `Semantics(button: true, label: 'Eintragen')`; Home gets `Semantics(header: true, namesRoute: true, label: 'Home')` around its first child (no visible text). Cue line hold: `_cueLineDuration * (MediaQuery.accessibleNavigationOf(context) ? 2 : 1)`.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('the tour can be stepped with the „Weiter" action and closed with „Überspringen"')   // tester.semantics.tap(find.semantics.byLabel('Weiter'))
testWidgets('the tour shows without fading with disableAnimations')
testWidgets('the opt-in dialog\'s ✕ is „Schließen", 48 × 48')
testWidgets('the active tab is selected to assistive tech, the others are not; „Eintragen" is a button')
testWidgets('Home names its route „Home" and has a heading')
testWidgets('with accessibleNavigation a cue line stays 8 s, without it 4 s')
```

- [ ] **Step 2: Run** these tests. Expected: FAIL.
- [ ] **Step 3: Implement**, and remove the XA4 entries from `a11yScreens` pending and from the static-rule allowlists.
- [ ] **Step 4: Run** `flutter test test/screens/dashboard test/widgets test/accessibility` and the gates. Expected: PASS. A Home check still failing goes into the report as a concern, with what fails.
- [ ] **Step 5: Commit** `fix(a11y): Home, the tour, the bottom bar and the Buddy's lines for screen readers`.

### Task XA5: Trackers (Essen, Trinken, Bauchgefühl, Klo)

**Fixes:** the meal photo ✕ ×2 (`meal_image_section.dart:272, 374`, 40 px, unlabelled); the meal shimmer ignores reduced motion; the meal title field is hint-only (`meal_title_sheet.dart:116`); the drink search field, the custom-amount field (`drink_size_selector.dart:82`) and the own-drink delete `IconButton` (`drink_search.dart:170`, no tooltip); `QuickDrinkGrid`/`DrinkSizeSelector` have no selected state; the mood mascots duplicate the sliders (`mood_slider_row.dart:39, 65`) and their bounce ignores reduced motion; the Bauchgefühl entry animation (`gut_feeling_tracker_screen.dart:70`); `MoodTabSelector` has no tab role and is 38 px tall; `DateTimeChips` (all four trackers) read a bare date and are 40 px tall.

**Files:**
- Modify: `lib/screens/trackers/meal/widgets/meal_image_section.dart`, `meal_title_sheet.dart`, `lib/screens/trackers/drink/widgets/drink_search.dart`, `drink_size_selector.dart`, `quick_drink_grid.dart`, `lib/widgets/common/mood_slider_row.dart`, `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart`, `widgets/mood_tab_selector.dart`, `lib/widgets/common/date_time_chips.dart`
- Test: the matching files under `test/screens/trackers/`, `test/widgets/mood_slider_row_test.dart`, `test/widgets/date_time_chips_test.dart`, `test/accessibility/a11y_screens.dart`

Labels: 'Foto entfernen'; meal title field 'Name der Mahlzeit'; drink search 'Getränk suchen'; custom amount 'Andere Menge in ml'; delete tooltip 'Getränk löschen'; a grid item `selected:` true for the chosen drink and size; tabs `Semantics(button: true, selected:, label: 'Bauchgefühl' | 'Stimmung')`, in a `TapTarget`, inactive text `foregroundInactive` (XA1); the mascots `ExcludeSemantics` (the slider is the control), with the bounce `ReducedMotion.duration`; date chip `Semantics(button: true, label: 'Datum', value: 'Donnerstag, 26. November 2026')` and `label: 'Uhrzeit', value: '14:30'`, in a `TapTarget`. The Klo scale is already right (`BbSlider`): no change.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('the photo\'s ✕ is „Foto entfernen", 48 × 48, and removes the photo')
testWidgets('the meal title field keeps the name „Name der Mahlzeit" with text entered')
testWidgets('the custom amount field keeps „Andere Menge in ml" with „300" entered')
testWidgets('the chosen quick drink and size are selected to assistive tech')
testWidgets('Bauchgefühl: the mascots are not in the semantics tree; each row is one slider „Krämpfe, 3 von 5"')
testWidgets('with disableAnimations the mascot does not scale and the screen enters without animating')
testWidgets('the tabs are selected/unselected buttons, each ≥ 48 high')
testWidgets('date and time chips read „Datum, Donnerstag, 26. November 2026" and „Uhrzeit, 14:30", each ≥ 48 high')
```

- [ ] **Step 2: Run** `flutter test test/screens/trackers test/widgets`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement**, and clear the XA5 pending entries and allowlist lines.
- [ ] **Step 4: Run** `flutter test test/screens/trackers test/widgets test/accessibility` and the gates. Expected: PASS.
- [ ] **Step 5: Commit** `fix(a11y): trackers named, sized and calm for screen readers and reduced motion`.

### Task XA6: Tagebuch

**Fixes:** `DiaryEntryCard` is a `GestureDetector` around a non-tappable `BbCard` (`diary_entry_card.dart:84`), so it has no button role; its subtitle is cut to one line (`:105`); the day arrows are 44 (fixed by XA2's default, asserted here); the drink detail amount field has no name (`drink_detail.dart:36`); the meal photo in the detail sheet is unnamed; `MealThumbnail`/`MealImage` add an unnamed image node; the card's SVG icon; the literal `SizedBox(width: 12)` on the touched line.

**Files:**
- Modify: `lib/screens/diary/widgets/diary_entry_card.dart`, `detail_sheets/drink_detail.dart`, `detail_sheets/meal_detail.dart`, `meal_image.dart`, `meal_thumbnail.dart`
- Test: `test/screens/diary/diary_screen_test.dart`, `test/screens/diary/widgets/detail_sheets/meal_detail_sheet_test.dart`, `detail_sheet_actions_test.dart`, `test/accessibility/a11y_screens.dart`

Labels: the card is `BbCard(onTap:)` (its text names it); the subtitle `maxLines: 2`; the amount field 'Menge in ml'; the detail photo `Semantics(image: true, label: 'Foto: <Titel>')`; thumbnails, `MealImage` in lists and the card's SVG are excluded.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('an entry card is a button named by its title and subtitle')
testWidgets('a long subtitle shows on two lines')
testWidgets('the day arrows are 48 × 48 „Vorheriger Tag" / „Nächster Tag"')
testWidgets('the drink amount field is „Menge in ml" with „250" entered')
testWidgets('the meal detail photo reads „Foto: Pasta mit Tomaten"; the list thumbnail adds no node')
```

- [ ] **Step 2: Run** `flutter test test/screens/diary`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement**, and clear XA6 pending.
- [ ] **Step 4: Run** `flutter test test/screens/diary test/router/tracker_semantics_test.dart test/accessibility` and the gates. Expected: PASS (the iOS orphan test in `tracker_semantics_test.dart` unchanged).
- [ ] **Step 5: Commit** `fix(a11y): Tagebuch cards, fields and photos for screen readers`.

### Task XA7: Entdecken (Tipps, Alternativen, Rezepte, Wissen)

**Fixes:** Alternativen cards can only be dismissed by swiping (`suggestion_card.dart:25`); „Stattdessen: …" is cut to one line (`discover_alternatives_section.dart:99`); the Alternativen search is hint-only (`ingredient_suggestions_screen.dart:93`); shimmer in `suggestion_card.dart` and `suggestion_detail_modal.dart`; the tip feedback „Bearbeiten" is a zero-size target (`recommendation_feedback_view.dart:140`); `recipes_screen.dart:28` (add) and `recipes_search_field.dart:59` (clear) have no tooltip; the recipe search, collection search and step fields are hint-only; the ingredient search ✕ (`ingredient_search.dart:222`) and the own-ingredient delete (`:310`, no tooltip) need fixing too (shared with the meal tracker and the recipe editor).

**Files:**
- Modify: `lib/screens/ingredient_suggestions/widgets/suggestion_card.dart`, `suggestion_detail_modal.dart`, `ingredient_suggestions_screen.dart`, `lib/screens/discover/widgets/discover_alternatives_section.dart`, `lib/screens/recommendations/widgets/recommendation_feedback_view.dart`, `lib/screens/recipes/recipes_screen.dart`, `widgets/recipes_search_field.dart`, `collection_screen.dart`, `widgets/recipe_steps_editor.dart`, `lib/widgets/common/ingredient_search.dart`
- Test: the matching files under `test/screens/ingredient_suggestions/`, `test/screens/discover/`, `test/screens/recommendations/`, `test/screens/recipes/`, `test/widgets/common/ingredient_search_test.dart`, `test/accessibility/a11y_screens.dart`

Labels: Alternativen card `customSemanticsActions: {CustomSemanticsAction(label: 'Ausblenden'): onDismiss}`; „Stattdessen" `maxLines: 2`; search 'Alternativen suchen'; shimmer through `ReducedMotion.shimmer`; „Bearbeiten" in a `TapTarget` with default `TextButton` sizing (the shrink-wrap goes); tooltips 'Rezept hinzufügen' and 'Suche löschen'; recipe search 'Rezept suchen'; collection search 'Rezept oder Zutat suchen'; step field 'Schritt <n>'; ingredient search ✕ `BbIconTap(semanticLabel: 'Suche schließen')`; delete tooltip 'Zutat löschen'.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('an Alternativen card offers „Ausblenden", which dismisses it like a swipe')   // tester.semantics.performCustomAction
testWidgets('„Stattdessen: …" shows on two lines')
testWidgets('with disableAnimations the Alternativen placeholders do not shimmer')
testWidgets('the tip feedback „Bearbeiten" is at least 48 high')
testWidgets('the recipe search keeps „Rezept suchen" with text entered; its clear button is „Suche löschen"')
testWidgets('a step field is „Schritt 2"')
testWidgets('the ingredient search ✕ is „Suche schließen", 48 × 48; an own ingredient\'s delete is „Zutat löschen"')
```

- [ ] **Step 2: Run** the listed test folders. Expected: the new tests FAIL.
- [ ] **Step 3: Implement**, and clear XA7 pending and allowlist lines.
- [ ] **Step 4: Run** `flutter test test/screens/discover test/screens/recipes test/screens/recommendations test/screens/ingredient_suggestions test/widgets/common test/screens/cross_screen_ingredient_autocomplete_test.dart test/accessibility` and the gates. Expected: PASS.
- [ ] **Step 5: Commit** `fix(a11y): Entdecken without swipe-only actions, with named fields and calm placeholders`.

### Task XA8: Muster

**Fixes:** the audit found no Muster-specific defect. The calendar's icons, per-day labels, heading and reduced motion were done in earlier rounds (59be18e, `patterns_unlocked.dart:26`, `patterns_unlocked_screen.dart:41`). This task turns on the Muster, Muster (gesperrt) and Muster frei! guardrails and fixes only what they report, inside `lib/screens/patterns/`.

**Files:**
- Modify: `lib/screens/patterns/**` only as the guardrails require
- Test: `test/screens/patterns/patterns_screen_test.dart`, `test/accessibility/a11y_screens.dart`

- [ ] **Step 1: Write the failing test:**

```dart
testWidgets('each calendar day reads its date and class, e.g. „Montag, 23. November: guter Tag"')   // pins the current InsightCopy.daySemantics output
testWidgets('Muster frei! names its route and its heading')
```

- [ ] **Step 2: Run** `flutter test test/screens/patterns test/accessibility`. Expected: the new tests pass or fail; the XA8 pending checks fail when un-skipped.
- [ ] **Step 3: Fix** what the un-skipped checks report and clear XA8 pending. A fix outside `lib/screens/patterns/` is reported as a concern.
- [ ] **Step 4: Run** `flutter test test/screens/patterns test/accessibility` and the gates. Expected: PASS.
- [ ] **Step 5: Commit** `test(a11y): Muster under the accessibility guardrails`.

### Task XA9: Ich, Einstellungen, Freigaben

**Fixes:** the three password eyes have no tooltip (`password_change_section.dart:169, 189, 223`); „Passwort vergessen?" is shrink-wrapped to `Size.zero` (`:269`); the reminder-time ✕ is about 24 px and unlabelled (`reminder_time_picker.dart:111`); the reminder-time chips have no selected state; `DietSelector` has no selected state; the height and weight fields in the profile (`settings_profile_screen.dart:368`) need names if their decoration has no `labelText`; „Gespeichert" is a status that isn't announced (`:176`); Ich's rows get their button role from XA2 (asserted here); the Freigaben screens run under the guardrails.

**Files:**
- Modify: `lib/screens/settings/widgets/password_change_section.dart`, `reminder_time_picker.dart`, `diet_selector.dart`, `settings_profile_screen.dart`, `lib/screens/shares/**` only as the guardrails require
- Test: `test/screens/settings/*.dart`, `test/screens/me/me_screen_test.dart`, `test/screens/shares/*.dart`, `test/accessibility/a11y_screens.dart`

Labels: tooltips 'Passwort anzeigen' / 'Passwort verbergen' (as `BbPasswordField`); „Passwort vergessen?" in a `TapTarget`, the shrink-wrap gone; ✕ `BbIconTap(semanticLabel: 'Uhrzeit <HH:mm> entfernen')`; diet options `selected:`; fields 'Größe in cm', 'Gewicht in kg'; „Gespeichert" `Semantics(liveRegion: true)`.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('each password eye says „Passwort anzeigen", then „Passwort verbergen"')
testWidgets('„Passwort vergessen?" is at least 48 high')
testWidgets('the ✕ of a reminder time is „Uhrzeit 08:00 entfernen", 48 × 48')
testWidgets('the chosen diet is selected to assistive tech')
testWidgets('the height field keeps „Größe in cm" with „172" entered; „Gespeichert" is a live region')
testWidgets('every Ich row is a button named by its title')
```

- [ ] **Step 2: Run** `flutter test test/screens/settings test/screens/me test/screens/shares`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement**, and clear XA9 pending (Ich, Einstellungen ×4, Freigaben, Neue Freigabe).
- [ ] **Step 4: Run** the same folders plus `test/accessibility` and the gates. Expected: PASS.
- [ ] **Step 5: Commit** `fix(a11y): Ich, Einstellungen and Freigaben for screen readers`.

### Task XA10: Auth, registration, consent, Buddy onboarding

**Fixes:** `BbScrollPicker` (birth year, height, weight) is wheel-only with no value (`bb_scroll_picker.dart:79`, used in `birth_year_step.dart`, `height_weight_step.dart`), which blocks registration for screen-reader users; the error banners are live regions from XA2 (asserted on the real screens here); `SelectableItemGrid`/`BbSelectionButton` (gender, diet, symptoms, intolerances steps) are selected from XA2 (asserted here); the Welcome, Auth, Registration, Health consent, Buddy onboarding and Upgrade guardrails get turned on.

**Files:**
- Modify: `lib/widgets/common/bb_scroll_picker.dart`, `lib/screens/registration/steps/birth_year_step.dart`, `height_weight_step.dart`; other files under `lib/screens/{auth,registration,health_consent,welcome,buddy,upgrade}/` only as the guardrails require
- Test: `test/widgets/common/bb_scroll_picker_test.dart` (create), `test/screens/registration/registration_wizard_screen_test.dart`, `test/screens/auth/auth_screen_test.dart`, `test/accessibility/a11y_screens.dart`

**Interfaces:** `BbScrollPicker({..., required String semanticLabel})`. Its semantics are `Semantics(label: semanticLabel, value: labelBuilder(current), increasedValue:, decreasedValue:, onIncrease: next item, onDecrease: previous item)` around `ExcludeSemantics(wheel)`. Each step animates the wheel to the item (zero duration under `ReducedMotion`) and calls `onChanged`. Labels: 'Geburtsjahr', 'Größe', 'Gewicht'. Values as the wheel shows them (e.g. '1990', '172 cm', '68 kg').

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('the picker reads „Geburtsjahr, 1990"; increase sets 1991 and calls onChanged; at the last item there is no increase')
testWidgets('the height and weight steps can be completed with increase/decrease alone')   // drive via tester.semantics.performAction
testWidgets('a wrong password puts „E-Mail oder Passwort ist falsch." in a live region')
testWidgets('the selected gender option is selected to assistive tech')
```

- [ ] **Step 2: Run** `flutter test test/widgets/common/bb_scroll_picker_test.dart test/screens/registration test/screens/auth`. Expected: FAIL.
- [ ] **Step 3: Implement**, and clear XA10 pending.
- [ ] **Step 4: Run** `flutter test test/widgets test/screens/registration test/screens/auth test/screens/health_consent test/screens/welcome test/screens/buddy test/screens/upgrade test/accessibility` and the gates. Expected: PASS.
- [ ] **Step 5: Commit** `fix(a11y): registration wheels, auth errors and onboarding for screen readers`.

### Task XA11: Gates and PR

- [ ] **Step 1:** Check `test/accessibility/a11y_screens.dart`. Every `pending` map should be empty and every static-rule allowlist entry should have a reason that is not a task id. If any remain, list them in the PR body under „Offen", each with what fails.
- [ ] **Step 2:** Run `dart format --set-exit-if-changed .`, `flutter analyze` and the full `flutter test`. Expected: all green.
- [ ] **Step 3:** Write the PR body: the audit counts (spec §2), the visual changes (spec §4.3, each one), what the pass does not achieve (spec §5), and the manual checks for Severin (spec §9).
- [ ] **Step 4:** After the owner's routine (simplify → code review → fix findings), push `feat/accessibility` and open a PR to `feat/share-link`, titled `fix: accessibility pass — screen readers, large text, contrast, reduced motion`. Stop there.
