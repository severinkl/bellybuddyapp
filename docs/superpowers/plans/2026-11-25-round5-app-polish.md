# Runde 5 Stage 1: App polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On Home the Buddy sits higher, his bubble only floats over his head while he talks, and a fiery flame burns behind him. The four needs get drawn sticker icons everywhere. Entdecken shows Tipps only once there are tips. Ich loses its header, and the success page's charging circle takes about 2 s.

**Architecture:**
- **Icons:** seven SVG assets under `assets/images/icons/needs/`: one per need, plus three more Bauchgefühl mouths so Home can still mirror the latest level. They are drawn through one widget, `NeedIcon`, which replaces every `CareNeed.emoji` use. `CareNeed.emoji` and `GutFeelingRatingLevel.face` go.
- **Flame:** `FlamePainter` gets a new drawing: no outline, at least three gradient tongues that flicker on their own clocks, a bright core, a glow, and sparks from „brennt" up. The ember becomes a low glow. `StreakFlame`'s API stays, so „Dein Streak", the week row and the success page get the new drawing for free.
- **Home:** `CareRing` gets two slots:
  - `behindBuddy`: the streak flame, inside the Buddy's square and under him;
  - `overBuddy`: his speech bubble, painted over everything with its bottom on his head, never taking a tap.
  The reserved `BuddyBubbleSlot` and its gap leave the hero, so the ring sits right under the chip row. The chip shows only the count.
- **Success page:** the charge lasts 2 s. The ignite row's flame stays an ember until the circle is full, then ignites, and „Tag n" fades in.
- **Entdecken:** the Tipps section exists only while the loaded tips hold a set with tips. The example card goes. The off-journey weekly-tips offer now leads to Einstellungen › Benachrichtigungen, where the switch lives.

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3.5, GoRouter 18, `flutter_svg` 2.5 (already a dependency), mocktail, integration_test. No new dependencies, no Freezed model changes, no backend changes.

**Spec:** `docs/superpowers/specs/2026-11-25-round5-polish-recipes-design.md` (approved 2026-11-25). This plan implements **Stage 1** (§7): §3.1–3.5 under the §4 constraints. §3.6–3.7 (recipes, pictures) are core's plan.

**Visual sources:**
- Mockups: `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/round5.html`, with source `round5.src.html` next to it; published as https://claude.ai/artifact/R36P6RbdBwyagNexfnZrph.
  - Section 1, option A: the flame behind the Buddy. The spec asks for it **fierier** than the mockup's soft 50 % flame.
  - Section 2, option C: the sticker icons. Their markup is copied into Task 1 in case the scratchpad is cleared.
- Today's app: screenshots `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/images/23.png`–`28.png`.
- Where the mockup and the spec differ, the spec wins.

## Global Constraints

From spec §4 and the repo's `CLAUDE.md`:
- **Tokens only:** colours, font sizes, spacing and radii come from `AppTheme`/`AppConstants`; add a token there first. Colours *inside SVG assets* are asset data, not widget code (see the Decisions).
- **Copy and conventions:**
  - German UI;
  - `AppLogger`, never `print`;
  - `CachedNetworkImage` + shimmer for network images (none are added here).
- **Reduced motion everywhere:**
  - the flame is still per state, with no ignite burst;
  - the charge shows its end level at once;
  - the bubble pops in without animation.
- **Layout:** a 375×667 screen at text scale 1.3 never overflows. Home's tap targets stay ≥ 48 dp.
- **Vocabulary:**
  - use eintragen, Essen, Bauchgefühl, Tipps, Tagebuch;
  - no health claims;
  - „Belly Buddy" is never translated;
  - `test/utils/vocabulary_test.dart` stays green with no new exemptions.
- **Entry times are wall clock.** Nothing here touches them. Never `toLocal()` a `tracked_at`.
- **Scope:** app only. Core (§3.6–3.7) is untouched.

Execution rules for this repo:
- **Once, before Task 1**, in `/Users/sevi/projects/bellybuddy/.worktrees/round5`: run `flutter pub get && dart run build_runner build --delete-conflicting-outputs`. The worktree is fresh, and the generated `*.freezed.dart`/`*.g.dart` files are gitignored.
- **Tests:**
  - prefix every `flutter test` with `TZ=Europe/Vienna`, as CI does;
  - pin the clock (`buddyClockProvider`/`buddyTodayProvider`) as the existing tests do.
- **Test seams:**
  - The root `test/flutter_test_config.dart` holds the Buddies, the ring's glow and the flame's ambient motion still.
  - A test that needs them sets `AnimatedBuddy.tickerEnabled` or `StreakFlame.ambientEnabled` to true before pumping. Its tear-down calls `disableAmbientAnimationsForTests`; `tickBuddiesInTests()` does both for a group.
  - While anything ticks, pump fixed durations, never `pumpAndSettle`.
  - One-shot animations (ignite, charge, fade) settle.
- **Commits:**
  - Run `dart format .` and `flutter analyze` first; analyze must report 0 issues.
  - Then `git commit --no-verify`, with a conventional prefix and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - **Never push.**
- **Never run `flutter clean`.**
- **Simulators:**
  - Integration tests run **only** on the iPhone Air `CB1F6232-482F-408F-ADF4-89FDA602E6A8`, one file at a time. Shut the simulator down afterwards.
  - **Never** use `55746DB2…` (Severin's live session) or `7A26EDD4…`.
  - `env.json` is gitignored and missing in the worktree. Copy it from `/Users/sevi/projects/bellybuddy/env.json`, never commit it.

## Review Focus

1. **The bubble over his head, and the hero that moved.**
   - At 375×667 with text scale 1.3, a four-line line stays inside the hero: scaled down if it must, never cut off at the screen top.
   - The ring never moves while he talks.
   - A tap where the bubble covers Essen, Trinken or the chip still opens it.
   - The tour's first hole still frames the whole hero, including the room the bubble may take above the ring.

   Pinned in:
   - Task 5: `overBuddy: on his head, over the bubbles, never a tap target`, `a four-line line stays inside the hero at 375×667, text scale 1.3`, `while he talks, Essen and Trinken still open under his bubble`, the spotlight test's room check;
   - Task 4: streak_chip_test's `its tap area is at least 48 dp tall`.
2. **The flame against the Buddy.**
   - It stays inside his square and under him: never over a need bubble or the chip, never behind the ring's bubbles, never taking his tap.
   - „lodert" may rise over his head, but nothing leaves the square.
   - It must read as fire *behind* him, not as „the Buddy is burning".

   Pinned in Task 4 (hero: `the flame burns behind the Buddy, inside his square, under him`; ring: `behindBuddy: bottom-centred in the Buddy's square, under him`, whose tap lands on the Buddy) and checked by eye in Task 9's visual check.
3. **Ember or ignite across days.**
   - A cold start after today's first entry shows the flame lit, without a burst.
   - At midnight, lit turns to ember without a burst.
   - Today's first entry, logged while Home is covered, ignites once when Home shows again.
   - No status (loading, error) means no flame, so its arrival never fakes an ignite.
   - Streak 0 is an ember.

   Pinned in Task 4's hero tests and Task 3's `lit → ember: no burst` / `a flame lit from the start does not burst`.
4. **Icons at small sizes and in the success circle.**
   - Every SVG is plain: no CSS, no filters, nothing outside the viewBox.
   - Each compiles, and is drawn at its laid-out size (24 dp in the button up to 60 dp in the circle), never as a scaled bitmap.
   - The success circle shows the logged need's icon.
   - The icons are precached, so neither the Eintragen sheet nor the success page pops them in late.
   - Home's Bauchgefühl still mirrors the latest level.

   Pinned in Task 1 (`every icon is a plain SVG flutter_svg compiles`, `drawn at its laid-out size, decorative`, `precache fills…`) and Task 2 (the circle's, tiles' and bubbles' `NeedIcon` checks), and checked by eye in Task 9.
5. **Entdecken while loading or offline.**
   - No Tipps section flashes in while the first load runs, or after it failed.
   - A refresh, loading or failed, keeps the card when tips were already loaded.
   - A newest set without tips still shows the section when an older set has tips.

   Pinned in Task 7.

## Decisions (spec gaps ruled in this plan)

1. **The bubble never takes a tap.** The overlay is `IgnorePointer`, so it never blocks Essen, Trinken or the chip, even while shown. That is stricter than §3.1 asks. On Home, a tap no longer completes the typewriter early (it ends within 1.2 s anyway).
2. **Bubble geometry:**
   - The bottom sits on the top of his head (`BuddyLayout(square).origin.dy`), centred on the ring, the tail on his face as today.
   - It is at most `buddyBubbleOverlayMaxWidth` = 200 wide (the mockup's 196).
   - It may rise over the chip row to the hero's top. A taller one is scaled down to fit, as the old slot did.
3. **The ring moves up by the slot and its gap** (76 + 8 = the spec's ≈84 px): the ring's top is the hero's top plus the chip row (`iconBadgeLg`).
4. **The flame lives in the Buddy's square.**
   - Its box is as tall as his square, bottom-aligned; its base is at his feet.
   - At rest, all of the drawing stays inside its 100×120 box: glow, sparks and „lodert"'s taller tongues. So it can never reach under a need bubble or the chip.
   - At the 7–29-day tier it is about his height. „lodert" rises over his head.
5. **One drawing everywhere, without the black outline** of round 4's flame.
   - The glow is drawn only from 40 dp up. At the 20 dp week mark and the 32 dp ignite row it would only smudge.
   - The tier thresholds stay. „lodert" (30+) is taller than wide: 1.06 × 1.18.
6. **Streak 0 shows the ember.** `FlameLook.off` and `AppTheme.streakEmberOff` go.
7. **The ember is low:** its tier squashed to 0.8 × 0.4, as in the mockup's „Glut zu seinen Füßen". It uses the ember colours and breathes, with no glow and no sparks.
8. **The chip loses its flame everywhere.** It is one widget on Home and Ich. Its tap area becomes ≥ 48 dp tall, with the pill drawn centred in it. It was about 34 dp tall, below §4's 48.
9. **Home's Bauchgefühl keeps mirroring the latest level.** Round 4 fixed „no party after a hard day", so the belly sticker comes in four mouths: sehr gut, gut (the default and the need's icon), mittel, schlecht. The tiles, the success circle and the button use the plain belly.
10. **The next-action button leads with a `NeedIcon` and its label drops the emoji,** as in the mockup.
    - The Essen sticker stands for every meal, so 🍳🍝🍎🍲 leave the button. They stay in reminders and Buddy lines, where they are text in a sentence.
    - `BbButton` gets a `leading` widget.
11. **No thin-outline variant.** The smallest icon is the button's 24 dp, where the mockup says the thick outline still works. Icons are sized in dp and do not grow with the text scale. They are precached on the splash.
12. **SVG colours are asset data.** Each hex is copied from the mockup's sticker variables or the matching `AppTheme` value. No Dart code references them, so they need no `AppTheme` token.
13. **The ignite is chained after the charge.**
    - On the success page the flame is an ember while the circle charges (2 s, `Curves.easeOut`). It ignites when the circle is full, and „Tag n" fades in with it.
    - Without a circle (Klo) it ignites at once.
    - Under reduced motion all of it shows at once.
14. **Entdecken shows the Tipps section when the loaded value has a set with tips.** This includes a value kept during a refresh.
    - While the first load runs, or after it failed, the section is absent: no „Laden…", no error line.
    - The section and the card take the loaded list.
15. **The off-journey weekly-tips offer leads to Einstellungen.**
    - Without tips, Entdecken no longer has the switch. So „Zu den Tipps" would land on nothing.
    - The button now reads „Zu den Einstellungen" and pushes `/settings/notifications`. Its body says „In den Einstellungen kannst du sie einschalten."
    - The first-tip offer's body drops „unter Entdecken". Switching off is only possible in Einstellungen, since Entdecken shows the switch only while the tips are off.
16. **Ich drops its `AppBar` entirely; its body sits in a `SafeArea`, as Home's does.** The „🔥" in the „Streak & Ziel" subtitle stays: it is text, not a need icon.
17. **`ExampleTipCard` is deleted, with its test.** Nothing else uses it.

## File Structure

| File | Change | Task |
|---|---|---|
| `assets/images/icons/needs/*.svg` (7) | create: the sticker icons | 1 |
| `pubspec.yaml` | add the `assets/images/icons/needs/` directory (asset directories are not recursive) | 1 |
| `lib/widgets/buddy/need_icon.dart` | create: `NeedIcon` | 1 |
| `lib/screens/splash/splash_screen.dart` | precache the icons | 1 |
| `lib/screens/dashboard/widgets/care_ring.dart` | icons (2); `behindBuddy` + `buddyKey` (4); `overBuddy` (5) | 2, 4, 5 |
| `lib/widgets/log_sheet/log_sheet.dart` | tile icon | 2 |
| `lib/widgets/buddy/log_success_hero.dart` | circle icon (2); 2 s charge, chained ignite (6) | 2, 6 |
| `lib/widgets/common/bb_button.dart` | `leading` | 2 |
| `lib/services/buddy/buddy_copy.dart` | `careButton` without emoji | 2 |
| `lib/services/buddy/daily_care.dart`, `lib/utils/gut_feeling_rating.dart` | drop `emoji` / `face` | 2 |
| `lib/widgets/buddy/streak_flame.dart` | the fiery drawing | 3 |
| `lib/widgets/buddy/streak_chip.dart` | count only, ≥ 48 dp tap area | 4 |
| `lib/screens/dashboard/widgets/buddy_hero.dart` | button icon (2); flame (4); bubble overlay, no slot (5); offer → Einstellungen (7) | 2, 4, 5, 7 |
| `lib/config/app_theme.dart`, `lib/config/constants.dart` | tokens (each task adds what it uses) | 2–6 |
| `lib/screens/discover/discover_screen.dart`, `widgets/discover_tips_section.dart`, `widgets/discover_tips_card.dart` | Tipps only with tips | 7 |
| `lib/screens/discover/widgets/example_tip_card.dart` | delete | 7 |
| `lib/screens/dashboard/widgets/weekly_tips_offer_sheet.dart`, `first_tip_offer_sheet.dart` | copy, destination | 7 |
| `lib/screens/me/me_screen.dart` | no header | 8 |
| `integration_test/home_motivation_flow_test.dart`, `discover_flow_test.dart` | follow the changes | 4, 7 |

---

### Task 1: The sticker icons and `NeedIcon`

**Files:**
- Create: `assets/images/icons/needs/food.svg`, `drink.svg`, `gut_feeling.svg`, `gut_feeling_sehr_gut.svg`, `gut_feeling_mittel.svg`, `gut_feeling_schlecht.svg`, `toilet.svg`
- Modify: `pubspec.yaml`: under `flutter: assets:`, add `- assets/images/icons/needs/`
- Create: `lib/widgets/buddy/need_icon.dart`
- Modify: `lib/screens/splash/splash_screen.dart` (`_preloadAndWait`)
- Test: `test/widgets/buddy/need_icon_test.dart`

**Interfaces:**
- Consumes: `CareNeed` (`lib/services/buddy/daily_care.dart`) and `GutFeelingRatingLevel` (`lib/utils/gut_feeling_rating.dart`; values `spiGut`, `gut`, `mittel`, `schlecht`).
- Produces:
  ```dart
  /// A need's sticker icon (decorative: no semantics), drawn at [size] × [size].
  class NeedIcon extends StatelessWidget {
    const NeedIcon(this.need, {super.key, required this.size, this.gutFeeling});
    final CareNeed need;
    final double size;
    /// Bauchgefühl only: the mouth of how the belly felt; null (or any other
    /// need) draws the plain icon.
    final GutFeelingRatingLevel? gutFeeling;
    static String assetFor(CareNeed need, {GutFeelingRatingLevel? gutFeeling});
    /// All seven asset paths.
    static const List<String> assets;
    /// Loads and compiles all seven into flutter_svg's cache.
    static Future<void> precache();
  }
  ```

**The drawings.** Start from the mockup's option C. Its markup is below as the mockup wrote it: CSS classes, `viewBox="0 0 64 64"`.

```js
var GLASS = 'M14 10H50L46.2 53.5A4.5 4.5 0 0 1 41.7 57.6H22.3A4.5 4.5 0 0 1 17.8 53.5Z';
var WAVE = 'M10 30C16 26.5 22 33.5 32 30S46 26.5 54 30';
var BELLY = 'M23 5L23 15C23 19 20 21 16 24C10 28 7.5 35 8.5 42C10 52 19 58 31 58C45 58 56 50 56 38C56 26 47 19 38 20C33 20.5 30 18.5 30 14L30 5Z';
food:  '<rect class="o fcut2" x="4.5" y="22" width="5" height="34" rx="2.5"/><path class="o fcut" d="M2.5 7H11.5V20.5A4.5 4.5 0 0 1 2.5 20.5Z"/><path class="o3 nf" d="M5.5 7.5V15.5M8.5 7.5V15.5"/><rect class="o fcut2" x="53.5" y="29" width="8" height="27" rx="3"/><path class="o fcut" d="M53.5 7C59 9 61.5 15 61.5 23V31H53.5Z"/><circle class="o fw" cx="33" cy="33" r="17"/><circle class="o2 ffood" cx="33" cy="33" r="11"/><path class="hl" d="M26 28.5A8.5 8.5 0 0 1 30.5 25"/>'
water: '<path class="fglass" d="GLASS"/><g clip-path="url(#cpGlass /* = GLASS */)"><path class="fwater" d="WAVE V62H10Z"/><path class="o2 nf" d="WAVE"/></g><circle class="o3 fw" cx="38" cy="44" r="2.6"/><circle class="o3 fw" cx="29.5" cy="50" r="1.8"/><path class="hl" d="M20.5 15L22.6 44"/><path class="o nf" d="GLASS"/>'
gut:   '<path class="o fbody" d="BELLY"/><path class="hl" d="M13.5 36C14 31.5 16.5 28 20 26"/><ellipse class="fblush" cx="18.5" cy="45" rx="3.4" ry="2.1"/><ellipse class="fblush" cx="46" cy="44.5" rx="3.4" ry="2.1"/><circle class="o2 fw" cx="25" cy="35.5" r="6.3"/><circle class="o2 fw" cx="40" cy="35" r="6.3"/><circle class="fk" cx="26.2" cy="36.6" r="2.9"/><circle class="fk" cx="41.2" cy="36.1" r="2.9"/><circle class="fw" cx="25.3" cy="35.4" r="1"/><circle class="fw" cx="40.3" cy="34.9" r="1"/><path class="o2 nf" d="M27.5 46Q32.5 51 37.5 46"/>'
loo:   '<path class="fw" d="M15 15V49A17 6.5 0 0 0 49 49V15Z"/><path class="fshade" d="M41 20.6C45 19.8 47.6 18.4 49 16.6V49C47.6 50.8 45 52.2 41 53Z"/><path class="o nf" d="M15 15V49A17 6.5 0 0 0 49 49V15"/><ellipse class="o fw" cx="32" cy="15" rx="17" ry="6.5"/><ellipse class="o2 fcore" cx="32" cy="15" rx="6" ry="2.4"/><path class="o fw" d="M21 38C26 39.6 38 39.6 43 38V60l-2.75-1.8-2.75 1.8-2.75-1.8-2.75 1.8-2.75-1.8-2.75 1.8-2.75-1.8-2.75 1.8Z"/><path class="o3 nf" stroke-dasharray="2 2.6" d="M22.5 50H41.5"/>'
```

Translate each class into presentation attributes. flutter_svg ignores `<style>` and CSS classes.

| Class | Attributes |
|---|---|
| `o` | `stroke="#0D0D0F" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"` |
| `o2` | as `o`, `stroke-width="2.5"` |
| `o3` | `stroke="#0D0D0F" stroke-width="1.8" stroke-linecap="round"` |
| `nf` | `fill="none"` |
| `hl` | `fill="none" stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round" stroke-opacity="0.9"` |
| `fw` / `fk` | `fill="#FFFFFF"` / `fill="#0D0D0F"` |
| `fcut` / `fcut2` / `ffood` | `#FFE3A3` / `#F6CD7A` / `#FFD0A6` |
| `fglass` / `fwater` | `#F4FAFD` / `#A9D8F5` |
| `fbody` / `fblush` | `#FFABB6` / `#FF7F95` with `fill-opacity="0.85"` |
| `fshade` / `fcore` | `#F2E4D6` / `#D9C3A8` |

Then add what the spec asks beyond the mockup:
- **Offset shadow, as on the Buddy's bubble:** behind the drawing, a copy of each icon's outer silhouette, shifted about (2, 2.5) and filled with `#FFABB6` (`AppTheme.buddyBody`). Give it a stroke of the same colour and width as the outline, so it is as wide as the outlined shape.
- **Fit:** nothing touches the viewBox edge, because flutter_svg clips to it. Wrap the drawing and its shadow in one `<g transform="translate(…) scale(…)">`, so the outlines and the shadow keep ≥ 1 unit inside `0 0 64 64`.
- **Bauchgefühl mouths:** these replace the `gut` smile (`M27.5 46Q32.5 51 37.5 46`) and must read like 😊 🙂 😐 😕.
  - `gut_feeling_sehr_gut.svg`: a wide open smile.
  - `gut_feeling.svg` (gut, and the need's icon): the mockup's smile.
  - `gut_feeling_mittel.svg`: a straight line.
  - `gut_feeling_schlecht.svg`: a slight, uneven downturn.
  - Eyes and blush stay. No tears, no frown lines: the face mirrors the answer and never judges.
- **Allowed elements:** only `path`, `rect`, `circle`, `ellipse`, `g` and `clipPath`/`defs`. The glass may keep its `clip-path`.

- [ ] **Step 1: Write the failing tests** in `test/widgets/buddy/need_icon_test.dart`:
  ```dart
  const dir = 'assets/images/icons/needs';
  test('one asset per need; Bauchgefühl per level', () {
    expect(NeedIcon.assetFor(CareNeed.food), '$dir/food.svg');
    expect(NeedIcon.assetFor(CareNeed.drink), '$dir/drink.svg');
    expect(NeedIcon.assetFor(CareNeed.toilet), '$dir/toilet.svg');
    expect(NeedIcon.assetFor(CareNeed.gutFeeling), '$dir/gut_feeling.svg');
    expect(NeedIcon.assetFor(CareNeed.gutFeeling, gutFeeling: GutFeelingRatingLevel.gut), '$dir/gut_feeling.svg');
    expect(NeedIcon.assetFor(CareNeed.gutFeeling, gutFeeling: GutFeelingRatingLevel.spiGut), '$dir/gut_feeling_sehr_gut.svg');
    expect(NeedIcon.assetFor(CareNeed.gutFeeling, gutFeeling: GutFeelingRatingLevel.mittel), '$dir/gut_feeling_mittel.svg');
    expect(NeedIcon.assetFor(CareNeed.gutFeeling, gutFeeling: GutFeelingRatingLevel.schlecht), '$dir/gut_feeling_schlecht.svg');
    expect(NeedIcon.assetFor(CareNeed.food, gutFeeling: GutFeelingRatingLevel.schlecht), '$dir/food.svg');
    expect(NeedIcon.assets.toSet(), hasLength(7));
  });
  ```
  - `testWidgets('every icon is a plain SVG flutter_svg compiles')`: for each of `NeedIcon.assets`, read the file with `File(path).readAsStringSync()`.
    - The text contains `viewBox="0 0 64 64"`.
    - It contains none of `<style`, `class=`, `var(`, `filter`, `<text`, `<image`.
    - `await tester.runAsync(() => SvgAssetLoader(path).loadBytes(null))` has `lengthInBytes > 0`. This also proves the asset directory is declared.
  - `testWidgets('drawn at its laid-out size, decorative')`: pump `NeedIcon(CareNeed.drink, size: 24)`.
    - `tester.getSize(find.byType(NeedIcon))` is `const Size(24, 24)`.
    - The `SvgPicture` below has `width == 24`, `height == 24` and `excludeFromSemantics == true`.
  - `testWidgets('precache fills flutter_svg\'s cache with all seven')`: `svg.cache.clear(); await tester.runAsync(NeedIcon.precache); expect(svg.cache.count, 7);`
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/widgets/buddy/need_icon_test.dart`. Expected: FAIL (`NeedIcon` undefined).
- [ ] **Step 3: Draw the seven SVGs and implement `NeedIcon`.**
  - Build: `SvgPicture.asset(assetFor(need, gutFeeling: gutFeeling), width: size, height: size, excludeFromSemantics: true)`.
  - `precache`: `Future.wait(assets.map((a) => SvgAssetLoader(a).loadBytes(null)))`. This is the cache key `SvgPicture.asset` uses under the root bundle and default theme.
  - In `SplashScreen._preloadAndWait`, while `widget.preloadImages`, add `NeedIcon.precache().catchError((_) {})` to the futures.
- [ ] **Step 4: Run** the test again. Expected: PASS.
- [ ] **Step 5: Look at them.** Add a throwaway golden test to the scratchpad check (Task 9 Step 2 describes it), or open each SVG in a browser. Check the four needs at 24, 40 and 60 px and the four mouths at 36 px. Fix anything clipped or muddy.
- [ ] **Step 6: Commit:** `feat(icons): sticker icons for the four needs, drawn by NeedIcon`.

---

### Task 2: One icon everywhere a need's emoji was

**Files:**
- Modify:
  - `lib/screens/dashboard/widgets/care_ring.dart` (`_NeedBubble`)
  - `lib/widgets/log_sheet/log_sheet.dart` (`_LogOption`)
  - `lib/widgets/buddy/log_success_hero.dart` (`ChargingMeter`)
  - `lib/widgets/common/bb_button.dart`
  - `lib/services/buddy/buddy_copy.dart` (`careButton`)
  - `lib/screens/dashboard/widgets/buddy_hero.dart` (the next-action button)
  - `lib/services/buddy/daily_care.dart` (drop `emoji`)
  - `lib/utils/gut_feeling_rating.dart` (drop `face`)
  - `lib/config/app_theme.dart` (drop `fontSizeChargeIcon`)
  - `lib/config/constants.dart`: add `logSheetIconSize = 40.0` and `careButtonIconSize = 24.0`
- Test:
  - `test/screens/dashboard/widgets/care_ring_test.dart`
  - `test/widgets/log_sheet/log_sheet_test.dart`
  - `test/widgets/buddy/log_success_hero_test.dart`
  - `test/services/buddy/buddy_copy_test.dart`
  - Create: `test/widgets/common/bb_button_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart` and `test/screens/dashboard/dashboard_screen_test.dart` (button texts)

**Interfaces:**
- Consumes: `NeedIcon` (Task 1).
- Produces:
  - `BbButton({…, Widget? leading})`: `leading` is drawn before the label, `AppConstants.spacingSm` apart, the label `Flexible` as with `icon`. Assert that at most one of `icon` and `leading` is set.
  - `BuddyCopy.careButton(CareAction)` returns:
    - `'Frühstück eintragen'`, `'Mittagessen eintragen'`, `'Snack eintragen'`, `'Abendessen eintragen'`;
    - `CareNeed.drink.logLabel` (`'Trinken eintragen'`), `CareNeed.gutFeeling.logLabel`, `CareNeed.food.logLabel` (feed).
  - `CareNeed` is `food('Essen')`, … with only `label` and `logLabel`.
  - `GutFeelingRatingLevel` keeps only `label`.

- [ ] **Step 1: Write the failing tests.**
  - `care_ring_test`: `each bubble shows its need's sticker icon at the meter's icon size`. For every need, the `NeedIcon` under `meterOf(need)` has `.need == need` and `.size == tester.getSize(meterOf(need)).width * AppConstants.careMeterIconShare`. This replaces the `find.text(need.emoji)` loop.
  - `care_ring_test`: rewrite `Bauchgefühl shows today's latest level, not always a smile`. For each level, the Bauchgefühl `NeedIcon.gutFeeling == level`. The four `NeedIcon.assetFor(…)` paths are distinct, and the semantics value stays `'zuletzt vor 6 Std, ${level.label}'`. With no entry, `gutFeeling` is null.
  - `log_sheet_test`: `each option shows its need's sticker icon`.
    - The `NeedIcon` under `LogSheet.optionKey(need)` has that `need` and `size == AppConstants.logSheetIconSize`.
    - With semantics on, `find.bySemanticsLabel(RegExp('^${need.label}\$'))` finds one node per need, so no emoji is read out with the label.
  - `log_success_hero_test`: in `the circle charges…`, replace `find.text(CareNeed.drink.emoji)`. The `NeedIcon` under `ChargingMeter` has `need == CareNeed.drink` and `size == tester.getSize(find.byType(NeedMeter)).width * AppConstants.careMeterIconShare`.
  - `buddy_copy_test`:
    - `careButton(feed) == 'Essen eintragen'`, `(drink) == 'Trinken eintragen'`, `(gutFeeling) == 'Bauchgefühl eintragen'`, `(lunch) == 'Mittagessen eintragen'`;
    - every action's label matches `RegExp(r'^[\p{L} ]+$', unicode: true)`, so no emoji is left.
  - `bb_button_test`: `leading sits before the label`. In `BbButton(label: 'Los', leading: const SizedBox(key: Key('lead'), width: 24, height: 24), onPressed: …)`, the leading's right edge ≤ the text's left, and a tap calls `onPressed`.
  - `buddy_hero_test`:
    - in `renders the Buddy in the care ring and the next action`: `find.text('Mittagessen eintragen')`, plus a `NeedIcon` with `need == CareNeed.food` under `find.byKey(BuddyHero.actionKey)`;
    - in `lunch logged → he asks for a drink, Trinken glows`: the `NeedIcon` there is `CareNeed.drink`;
    - every other `'🍳/🍝/🍎/🍲/💧 … eintragen'` literal in this file loses its emoji;
    - in `dashboard_screen_test`, `'🍝 Mittagessen eintragen'` becomes `'Mittagessen eintragen'`.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/screens/dashboard test/widgets test/services/buddy/buddy_copy_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `_NeedBubble` gets `GutFeelingRatingLevel? gutFeeling` in place of `emoji`. `CareRing` passes `care.gutFeelingLevel` for Bauchgefühl only, and the bubble builds `NeedIcon(need, size: meterSize * AppConstants.careMeterIconShare, gutFeeling: gutFeeling)`.
  - `_LogOption` draws `NeedIcon(need, size: AppConstants.logSheetIconSize)` above the label.
  - `ChargingMeter` draws `NeedIcon(need, size: size * AppConstants.careMeterIconShare)`. `NeedMeter` already fits a child into that square.
  - The hero's `BbButton` gets `leading: NeedIcon(action.need ?? CareNeed.food, size: AppConstants.careButtonIconSize)`.
  - Then delete `CareNeed.emoji`, `GutFeelingRatingLevel.face` and `AppTheme.fontSizeChargeIcon`. `flutter analyze` finds any use left.
- [ ] **Step 4: Run** the tests from Step 2, then the full `TZ=Europe/Vienna flutter test`. Expected: PASS. Other tests that matched the emoji texts are fixed the same way.
- [ ] **Step 5: Commit:** `feat(icons): the sticker icons replace the need emoji on Home, in Eintragen and on the success page`.

---

### Task 3: The fiery flame

**Files:**
- Modify: `lib/widgets/buddy/streak_flame.dart`
- Modify: `lib/config/app_theme.dart`
  - add `streakFlameRed = Color(0xFFE5391F)`, `streakFlameBright = Color(0xFFFFF1B8)` and `streakFlameGlow = Color(0x66FF8C3C)`;
  - keep `streakFlame` (orange), `streakFlameCore` (yellow), `streakFlameHot` (blue), `streakEmber` and `streakEmberCore`;
  - remove `streakEmberOff`;
  - the values are starting points, tuned in Task 9's visual check.
- Modify: `lib/config/constants.dart`
  - add `streakFlameFlicker = <Duration>[Duration(milliseconds: 1300), Duration(milliseconds: 1700), Duration(milliseconds: 1100)]`, one period per tongue, pairwise different;
  - add `streakFlameGlowMinHeight = 40.0`;
  - remove `streakFlameWobble`;
  - keep `streakFlameIgnite`, `streakFlameBreath` and `streakFlameSparks`.
- Modify: `test/helpers/ambient_animations.dart` (doc wording only: the flames „flicker")
- Test: `test/widgets/buddy/streak_flame_test.dart` (rewrite its painter checks)

**Interfaces:**
- Produces. `StreakFlame`'s constructor, `.mark`, `tierOf`, `ambientEnabled` and the ignite rules are unchanged.
  ```dart
  enum FlameTier {
    small(0.62, 0.62), medium(0.8, 0.8), large(1.0, 1.0), blazing(1.06, 1.18);
    const FlameTier(this.scaleX, this.scaleY);
    final double scaleX, scaleY;
  }
  enum FlameLook { ember, lit }            // StreakFlame.look: lit ? lit : ember (streak 0 too)

  class FlamePainter extends CustomPainter {
    FlamePainter({required this.look, required this.tier, this.ignite, this.clock});
    static const double aspectRatio = 100 / 120;
    static const Size emberSquash = Size(0.8, 0.4);
    static int get tongueCount;            // AppConstants.streakFlameFlicker.length (≥ 3)
    double? get burst;                     // as today
    Size get bodyScale;                    // tier × (ember: emberSquash) × the ignite's pop
    List<double> get flicker;              // tongueCount values in −1..1; all 0 without a clock or as an ember
    double? get rise;                      // the sparks' phase 0..1 for any lit flame; null without a clock
    int get sparkCount;                    // ember 0, lit 2, lit blazing 5
    bool get hotCore;                      // lit && blazing
    bool showsGlow(Size size);             // lit && size.height >= AppConstants.streakFlameGlowMinHeight
  }
  ```

**The drawing.** It lives in a 100×120 box with its base at (50, 114), and has no outline. Back to front:
1. **Glow** (`showsGlow`): a soft radial gradient from `streakFlameGlow` to the same colour at alpha 0, centred near (50, 76), inside the box.
2. **Tongues:** `tongueCount` of them.
   - A tall centre tongue with its tip near y 20 at scale 1, and side tongues lower: tips near (30, 48) and (71, 40). They share a rounded base between x ≈ 14 and 86.
   - Each tongue gets a vertical gradient: `streakFlameCore` at the bottom, `streakFlame` around the middle, `streakFlameRed` at the tip with alpha around 0.25. This is the „slightly transparent at its edges".
   - Tongue *i* sways about the base with its own period `streakFlameFlicker[i]` and a phase offset. Its y-scale moves by about ±6 % and its skew by about ±3°. So they never move as one shape.
3. **Bright core:** an inner teardrop going from `streakFlameBright` to `streakFlameCore`, swaying with the centre tongue.
4. **Hot core** (`hotCore`): a small `streakFlameHot` drop at the base.
5. **Sparks** (`sparkCount`): small `streakFlameCore`/`streakFlameBright` dots rising from the tongue tips, each visible for only part of its `streakFlameSparks` cycle, so the sparks are occasional.
6. **Ignite burst:** today's dots, without outlines.

The ember uses the same tongues scaled by `bodyScale` in `streakEmber` → `streakEmberCore`, with no glow, core or sparks; it breathes through today's `FadeTransition`. At rest, everything stays inside the box at every tier, sparks included. Only the ignite's pop may briefly exceed it. „Flicker timing and spark density" are the builder's, within the brief (spec §6).

- [ ] **Step 1: Write the failing tests.** These replace the `_fillsPath`, `_fillsCircle` and `_scalesBody` checks. Read the painter through the existing `_painter(t)`.
  - `tiers by streak`: the thresholds are unchanged. Add `lodert is taller than wide; the others keep their shape`: `FlameTier.blazing.scaleY > FlameTier.blazing.scaleX`, and the other tiers have `scaleX == scaleY`.
  - `looks: lit once today counts, else an ember, also at streak 0`: `_flame(streak: 0, lit: false)` → `FlameLook.ember`.
  - `the ember is low: its tier squashed to 0.8 × 0.4, without sparks, hot core or glow`. At streak 5, unlit: `bodyScale == Size(0.8 * 0.8, 0.8 * 0.4)`, `sparkCount == 0`, `hotCore` false, `showsGlow(const Size(100, 120))` false, and every `flicker` value 0.
  - `brennt: at least three tongues and sparks, no hot core`. At streak 7, lit: `FlamePainter.tongueCount >= 3`, `sparkCount == 2`, `hotCore` false, and `bodyScale == const Size(1, 1)`.
  - `lodert: a hot core and more sparks`. At streak 30: `hotCore` true and `sparkCount > 2`.
  - `the glow from 40 dp up, only when lit`: lit, `showsGlow(Size(33.3, 39.9))` false and `showsGlow(Size(33.4, 40))` true.
  - `size keeps the 100:120 shape`, unchanged.
  - The ignite tests keep their behaviour; only the scale checks move to `bodyScale`.
    - `ember → lit plays one burst…`, `lit → ember: no burst`, `igniteOnMount bursts once…`, `a flame lit from the start does not burst` and `an ignite while hidden plays once visible` stay as they are.
    - `the ignite starts at the ember's size, without a full-size frame`: at `burst == 0`, `bodyScale == Size(0.8 * 0.8, 0.8 * 0.4)`.
  - `reduced motion: lit at once, no burst, no flicker`: every `flicker` value 0 and `binding.hasScheduledFrame` false. The ember's `_breath(t) == 1`.
  - `ambient`:
    - `off in tests: still`, as today, with `flicker` all 0;
    - `on: the tongues flicker independently`: lit at streak 5; after `pump(300 ms)`, `flicker.toSet().length >= 2` and not all 0; after `pump(250 ms)`, the list differs;
    - `the ember breathes`: as today;
    - `sparks rise from brennt up`: lit at streak 5, `rise` is non-null and changes between two pumps;
    - `the mark stays still`: as today, `flicker` all 0.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/widgets/buddy/streak_flame_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement the new tokens and `FlamePainter`.**
  - `_LiveFlame` keeps its controllers. The ambient ticker drives `flicker` and `rise` for a lit flame; the breath drives the ember.
  - `shouldRepaint` compares `look`, `tier`, `ignite` and `clock`, as today.
  - Remove `FlameLook.off` and `wobble`.
- [ ] **Step 4: Run** the test again, then `TZ=Europe/Vienna flutter test test/screens/dashboard/widgets/streak_sheet_test.dart test/widgets/buddy test/screens/buddy`. Expected: PASS. „Dein Streak", the week row and the onboarding's streak moment use the new drawing unchanged.
- [ ] **Step 5: Commit:** `feat(streak): a fierier flame: flickering tongues, a bright core, glow and sparks`.

---

### Task 4: The flame behind the Buddy, and the chip shows only the count

**Files:**
- Modify: `lib/screens/dashboard/widgets/care_ring.dart`
  - add `final Widget? behindBuddy`;
  - add `static const buddyKey = Key('care_ring_buddy')` on the Buddy's `SizedBox.square`.
- Modify: `lib/screens/dashboard/widgets/buddy_hero.dart`
- Modify: `lib/widgets/buddy/streak_chip.dart`
- Modify: `lib/config/constants.dart`: add `homeTapTarget = 48.0`; remove `streakFlameChipHeight`.
- Test:
  - `test/screens/dashboard/widgets/care_ring_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart`
  - `test/widgets/buddy/streak_chip_test.dart`
  - `integration_test/home_motivation_flow_test.dart`

**Interfaces:**
- Consumes: `StreakFlame`, `FlamePainter.burst`, `FlameLook` (Task 3).
- Produces:
  - `CareRing({…, Widget? behindBuddy})`. `behindBuddy` is drawn bottom-centred in the Buddy's square, under him, inside `IgnorePointer`.
  - The hero passes `StreakFlame(streak: status.streak, lit: status.todayCounted, height: buddySide)`, only while `status != null`.
  - `StreakChip` has the same constructor, no flame, and a hit area at least `AppConstants.homeTapTarget` tall.

- [ ] **Step 1: Write the failing tests.**
  - `care_ring_test`: `behindBuddy: bottom-centred in the Buddy's square, under him`.
    - Pump with `behindBuddy: const SizedBox(key: Key('behind'), width: 50, height: 80)`; extend the `pump` helper with `behindBuddy`.
    - `behind.bottom == square.bottom` and `behind.center.dx == square.center.dx`, where `square = tester.getRect(find.byKey(CareRing.buddyKey))`.
    - In tree order (`find.descendant(of: find.byKey(CareRing.buddyKey), matching: find.byWidgetPredicate((w) => w.key == const Key('behind') || w.key == const Key('buddy_double')))`), `behind` comes first, so it is painted under him.
    - A tap at `behind`'s centre lands on the Buddy: `buddyTapsLog` has one tap.
  - `streak_chip_test`:
    - replace `the flame replaces the emoji` and `the flame grows with the text scale` with `shows the count only: no flame`: `find.byType(StreakFlame)` finds nothing, and `'5 Tage'` shows;
    - add `its tap area is at least 48 dp tall`: `tester.getSize(find.byType(StreakChip)).height >= AppConstants.homeTapTarget`, and a tap 2 dp inside its top-left corner calls `onTap`.
  - `buddy_hero_test`: add a helper `FlamePainter homeFlame(tester)`. It reads the `CustomPaint` under the `StreakFlame` within `find.byType(CareRing)`. Then:
    - `the flame burns behind the Buddy, inside his square, under him`:
      - the flame's rect is within `find.byKey(CareRing.buddyKey)`'s rect, ±0.01;
      - its height equals the square's height, and its bottom the square's bottom;
      - it intersects no `CareRing.needKey(need)` rect;
      - in tree order the `StreakFlame` precedes the `AnimatedBuddy`.
    - `glimmt before today's first entry, brennt after; streak 0 an ember`: `_status(streak: 5, todayCounted: false)` → `ember`; `todayCounted: true` → `lit`; `streak: 0` → `ember`.
    - `today's first entry ignites it once`: start unlit, `buddy.push(_status(…todayCounted: true))`, `pump()`, `pump(150 ms)`. Then `homeFlame(tester).burst > 0`, and after `pump(1 s)` it is null.
    - `opened after today's first entry: lit from the first frame, no burst`: pump with `todayCounted: true` from the start, then `pump(150 ms)`. `burst` is null.
    - `midnight: lit turns to an ember without a burst`: start lit, push `todayCounted: false`, `pump()`, `pump(150 ms)`. The look is `ember` and `burst` is null.
    - `an entry while Home is covered ignites it once Home shows again`:
      - `visible.value = false`, push lit, `pump(1 s)`: `burst` is null;
      - `visible.value = true`, `pump()`, `pump(150 ms)`: `burst > 0`.
    - Extend `buddyProvider error → no StreakChip, Buddy still shown` with `find.byType(StreakFlame)` finding nothing.
  - `integration_test/home_motivation_flow_test.dart`: `_chipFlame` becomes `_homeFlame`, using `find.descendant(of: find.byType(CareRing), matching: find.byType(StreakFlame))`. The flow's expectations (`ember` → `lit`) stay.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/screens/dashboard/widgets test/widgets/buddy/streak_chip_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - **`CareRing`:** the Buddy's `SizedBox.square` (now keyed) holds a `Stack(fit: StackFit.expand)` with:
    1. `IgnorePointer(child: Align(alignment: Alignment.bottomCenter, child: behindBuddy))`, when set;
    2. `buddy`.
  - **`BuddyHero.build`:** pass the flame as above.
  - **`StreakChip`:**
    - Drop the `StreakFlame` and its spacer.
    - Wrap the pill so the `GestureDetector`'s child is at least `homeTapTarget` tall, the pill centred and the width shrink-wrapped: `ConstrainedBox(minHeight)` + `Align(widthFactor: 1)`.
    - Semantics, muted look, Tooltip and pop are unchanged.
    - Update the class doc.
- [ ] **Step 4: Run** the tests from Step 2, then `TZ=Europe/Vienna flutter test test/screens`. Expected: PASS, including `me_screen_test`'s 375×667 at 1.3 with the taller chip.
- [ ] **Step 5: Commit:** `feat(home): the streak flame burns behind the Buddy; the chip shows the count`.

---

### Task 5: His bubble floats over his head; the ring moves up

**Files:**
- Modify: `lib/screens/dashboard/widgets/care_ring.dart`: add `overBuddy` and `overBuddyRoom`
- Modify: `lib/screens/dashboard/widgets/buddy_hero.dart`
  - drop `BuddyBubbleSlot` and the `gap8` under the chip row;
  - pass the bubble as `overBuddy`.
- Modify: `lib/config/constants.dart`: add `buddyBubbleOverlayMaxWidth = 200.0`
- Test:
  - `test/screens/dashboard/widgets/care_ring_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart` (the tour spotlight)

**Interfaces:**
- Consumes: `CareRing.buddyKey` and `behindBuddy` (Task 4); `BuddyLayout` (`lib/widgets/buddy/buddy_geometry.dart`); `BuddyStage.faceShift`, `BuddySpeechBubble` and `BuddyBubbleTail`.
- Produces: `CareRing({…, Widget? overBuddy, double overBuddyRoom = 0})`.
  - `overBuddy` is painted over everything in the ring, the bubbles included, inside `IgnorePointer`.
  - Its constraints are loose: up to the ring's width, and up to the head's top plus `overBuddyRoom` in height.
  - It is centred on the ring, with its bottom edge on the Buddy's head. The head is at `square.top + BuddyLayout(square.size).origin.dy`, where the square is his, centred in the ring.
  - It may extend up to `overBuddyRoom` above the ring.
  - Use a `Stack(clipBehavior: Clip.none)` around the existing `Row`, plus a `Positioned.fill` holding a `CustomSingleChildLayout`. Its delegate gets the Buddy's side and the room. The square's width is `min(side, ring width − 2 × (careNeedWidth + 2 × careNeedGlow))`, its height `side`, its top `(ring height − side) / 2`.
  - `BuddyBubbleSlot` stays in `buddy_stage.dart`; `BuddyStage` still uses it.

- [ ] **Step 1: Write the failing tests.**
  - `care_ring_test`: extend `pump` with `overBuddy`/`overBuddyRoom`.
    - `overBuddy: on his head, over the bubbles, never a tap target`:
      - with `overBuddy: const SizedBox(key: Key('over'), width: 300, height: 60)`, `over.bottom` is within 0.01 of `square.top + BuddyLayout(square.size).origin.dy`;
      - `over.center.dx` is within 0.01 of the ring's centre;
      - in tree order under `CareRing`, Trinken's bubble (`CareRing.needKey(CareNeed.drink)`) precedes `over`;
      - `final overlap = over.intersect(bubble(tester, CareNeed.food)); expect(overlap.isEmpty, isFalse);`, then a tap at `overlap.center` leaves `tapped == [CareNeed.food]`.
    - `a taller overBuddy is fitted into the room above the ring`: with `overBuddyRoom: 48` and `overBuddy: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomCenter, child: SizedBox(key: Key('tall'), width: 100, height: 1000))`, the fitted child's top is ≥ the ring's top − 48 − 0.01, and its bottom is still on the head.
  - `buddy_hero_test`:
    - `no reserved bubble slot: the ring sits right under the chip row, and never moves while he talks`:
      - `ring.top - hero.top == AppConstants.iconBadgeLg`, where `hero = tester.getRect(find.byType(BuddyHero))`;
      - `controller(tester).say('Hallo, schön dich zu sehen!')`, `tick`: the ring's rect is unchanged.
    - `his bubble floats over his head while he talks, then is gone`:
      - while he talks, the `BuddySpeechBubble` rect has its bottom within 0.5 of the head's top, its top ≥ `hero.top`, and its width ≤ `AppConstants.buddyBubbleOverlayMaxWidth`;
      - after `advance(tester, const Duration(seconds: 4))`, its size is empty.
    - `a four-line line stays inside the hero at 375×667, text scale 1.3`:
      - view `Size(375, 667)` at dpr 1, text scale 1.3; say a line of about 140 characters, `tick` and `pump(1300 ms)`;
      - the bubble's top is ≥ `hero.top` − 0.01, its bottom within 0.5 of the head;
      - `tester.takeException()` is null.
    - `while he talks, Essen and Trinken still open under his bubble`:
      - view 345×852, the hero's width on a 393-wide phone (the harness has no side padding). There the centre column is narrower than the 200-wide bubble, so it overlaps both top bubbles. Say the long line, `tick`;
      - for `CareNeed.food` → `RoutePaths.mealTracker` and `CareNeed.drink` → `RoutePaths.drinkTracker`, the overlap of the bubble and that need's bubble is not empty;
      - a tap at its centre, then `pump()` and `pump(500 ms)`, gives `location() == path`; then `router.go(RoutePaths.dashboard)` and `pump(500 ms)`.
  - `dashboard_screen_test`: in the tour spotlight test, keep `hole == hero.inflate(spacingXs)` and the ring check. Add `expect(hole.top, lessThanOrEqualTo(ring.top - AppConstants.iconBadgeLg))`, so the room the bubble may take is inside the first hole on both phones.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/screens/dashboard`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - **`CareRing`:** the `Stack` and delegate as in Interfaces.
  - **`BuddyHero`:** the column becomes chip row (`SizedBox(height: AppConstants.iconBadgeLg)`) → `CareRing` → `gap12` → button. It passes `overBuddyRoom: AppConstants.iconBadgeLg` and:
    ```dart
    overBuddy: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomCenter,
      child: BuddySpeechBubble(
        controller: _buddy,
        maxWidth: math.min(AppConstants.buddyBubbleOverlayMaxWidth, width),
        tail: BuddyBubbleTail.down(shift: BuddyStage.faceShift(Size.square(buddySide))),
      ),
    ),
    ```
  - Update `BuddyHero`'s class doc: the bubble floats over his head and never moves the layout.
- [ ] **Step 4: Run** `TZ=Europe/Vienna flutter test test/screens/dashboard test/screens/buddy test/widgets/buddy`. Expected: PASS. This includes `fits 375×667 at text scale 1.3 with the row`, the 390×844 phone and the tour tests.
- [ ] **Step 5: Commit:** `feat(home): the Buddy's bubble floats over his head; the ring moves up`.

---

### Task 6: The charge takes about 2 s; the ignite follows it

**Files:**
- Modify: `lib/config/constants.dart`: set `careChargeDuration = Duration(milliseconds: 2000)`; add `static const Curve careChargeCurve = Curves.easeOut`
- Modify: `lib/widgets/buddy/log_success_hero.dart`
- Test:
  - `test/widgets/buddy/log_success_hero_test.dart`
  - any tracker test that pumps the old 1.2 s or 1300 ms charge: `grep -rn "1300\|1200" test/screens/trackers test/widgets/buddy`

**Interfaces:**
- Consumes: `ChargingMeter` (Task 2's icon) and `StreakFlame` (Task 3).
- Produces:
  - `ChargingMeter` uses `careChargeDuration` and `careChargeCurve`.
  - `LogSuccessHero` becomes a `StatefulWidget` with the same constructor and the same `igniteKey`.

- [ ] **Step 1: Write the failing tests** in `log_success_hero_test`:
  - `the circle charges from the old level to the new in about 2 s, easing out`: from 0.4 to 1.0.
    - At start: `closeTo(0.4, 0.005)`.
    - After `pump(1000 ms)`: between 0.4 and 1.0, and above `0.4 + 0.6 * 0.5`, because ease-out is past half-way at half-time.
    - After `pump(1000 ms)`: exactly 1.0.
  - `today's first entry: the flame ignites when the circle is full, „Tag 5" with it`:
    - at mount, the row's `StreakFlame.lit` is false, `look` is `ember`, and the `AnimatedOpacity` above `find.text('Tag 5')` has opacity 0;
    - after `pump(AppConstants.careChargeDuration - const Duration(milliseconds: 1))`, it is still unlit;
    - after `pump(2 ms)`, `pump()` and `pump(150 ms)`: `lit` is true, `_flamePainter(tester).burst > 0`, and the opacity is 1;
    - after `pumpAndSettle()`: `burst` is null.
  - `no circle (Klo): it ignites at once`: `LogMoment(kind: EntryKind.toilet, ignitesDay: 3)`, `pump(150 ms)`. `lit` is true, `burst > 0`, and the opacity is 1.
  - `reduced motion`: `the flame is lit at once, without the burst`. Add that the `'Tag 5'` opacity is 1, and keep `hasScheduledFrame` false.
  - `the calm page…` and the slot-layout tests are unchanged, except their pumps: 1300 ms becomes `AppConstants.careChargeDuration + const Duration(milliseconds: 100)`.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/widgets/buddy/log_success_hero_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `_LogSuccessHeroState` holds `bool _charged`.
    - It starts true when there is no circle, no ignite row, or animations are off (`MediaQuery.disableAnimationsOf`, read in `didChangeDependencies` once).
    - Otherwise a `Timer(AppConstants.careChargeDuration, …)` sets it true; cancel it in `dispose`.
  - The ignite row's flame is `StreakFlame(streak: day, lit: _charged, height: …, igniteOnMount: _charged)`: lit from mount ignites on mount, and lit later ignites through `didUpdateWidget`.
  - `'Tag $day'` sits in `AnimatedOpacity(opacity: _charged ? 1 : 0, duration: calm ? Duration.zero : AppConstants.animNormal)`. The row keeps its size, so nothing jumps.
  - Update the class docs: „charging in about 2 s", „the flame ignites once the circle is full".
- [ ] **Step 4: Run** the test, then `TZ=Europe/Vienna flutter test test/screens/trackers test/widgets`. Expected: PASS.
- [ ] **Step 5: Commit:** `feat(success): the circle charges in 2 s and the flame ignites once it is full`.

---

### Task 7: Entdecken shows Tipps only once there are tips

**Files:**
- Modify: `lib/screens/discover/widgets/discover_tips_section.dart`
- Modify: `lib/screens/discover/widgets/discover_tips_card.dart`
- Modify: `lib/screens/discover/discover_screen.dart`
- Delete: `lib/screens/discover/widgets/example_tip_card.dart`, `test/screens/discover/widgets/example_tip_card_test.dart`
- Modify: `lib/screens/dashboard/widgets/weekly_tips_offer_sheet.dart`, `lib/screens/dashboard/widgets/first_tip_offer_sheet.dart` and `lib/screens/dashboard/widgets/buddy_hero.dart` (`_offerWeeklyTips`)
- Test:
  - `test/screens/discover/widgets/discover_tips_section_test.dart`
  - `test/screens/discover/discover_screen_test.dart`
  - `test/screens/dashboard/widgets/weekly_tips_offer_sheet_test.dart`
  - `test/screens/dashboard/widgets/first_tip_offer_sheet_test.dart`
  - `test/screens/dashboard/widgets/buddy_hero_test.dart`
  - `integration_test/discover_flow_test.dart`
  - `integration_test/home_motivation_flow_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class DiscoverTipsSection extends StatelessWidget {
    const DiscoverTipsSection({super.key, required this.sets, required this.weeklyTips, required this.onOpen});
    /// Whether Entdecken shows the section: the loaded value (also one kept
    /// while refreshing) has a set with tips.
    static bool showsFor(AsyncValue<List<Recommendation>> tips);
    static const optInKey = Key('discover_weekly_tips');
    final List<Recommendation> sets;     // newest first
    final bool? weeklyTips;
    final VoidCallback onOpen;
  }
  class DiscoverTipsCard … ({super.key, required List<Recommendation> sets, required VoidCallback onTap})
  ```
  - The section shows the card, then, only while `weeklyTips == false`, `gap12` + `BbCard(key: optInKey, child: WeeklyTipsSwitch())`.
  - The card shows `sets.first` exactly as today, „Neu" included. Its pending and empty branches go. `DiscoverNote.pending` stays: other sections use it.
  - `emptyWhileOn` and `_optInWithExample` go.
- New copy:
  - `WeeklyTipsOfferSheet.body` is `'In den Einstellungen kannst du sie einschalten. ${WeeklyTipsSwitch.sentence}'`, and the primary button reads `'Zu den Einstellungen'`.
  - `FirstTipOfferSheet.body` ends with `'Ausschalten kannst du sie jederzeit in den Einstellungen.'`.
- The hero's `_offerWeeklyTips` does `if (open) unawaited(context.push(RoutePaths.settingsNotifications));` in place of `context.go(RoutePaths.discover)`. The push covers Home (`_onRoute`), so the next cue waits as before.

- [ ] **Step 1: Write the failing tests.**
  - `discover_tips_section_test`: replace the state matrix.
    - `test('showsFor: only a loaded value with a set with tips')`:
      - false: `AsyncLoading()`, `AsyncError(…, StackTrace.empty)`, `AsyncData([])`, and `AsyncData([a set with recommendations: []])`;
      - true: `AsyncData([newest without tips, older with tips])` and `AsyncData([testRecommendation(…)])`.
    - The widget matrix: with `sets: [testRecommendation(…)]`:
      - `weeklyTips: false` → the card, then the opt-in below it (`getBottomLeft(card).dy < getTopLeft(optIn).dy`);
      - `true` or `null` → the card only;
      - none of them has an `ExampleTipCard` (the type is gone) or a „Montag" text.
  - `discover_screen_test`:
    - `no tips, weekly tips off: no Tipps section at all`: no `'Tipps'` section title, no `DiscoverScreen.tipsKey`, no `optInKey`; Alternativen is the first section.
    - `no tips, weekly tips on: no Tipps section, no note`: the same, and `find.textContaining('Montag')` finds nothing.
    - `the first load still running: no Tipps section, nothing flashes`:
      - give `pump` an optional `Future<List<Recommendation>> Function()? fetchTips`, used for the mocktail stub of `recommendations.fetchByUserId` in place of `tips`;
      - stub it with a `Completer`'s future, then `pump()`: no `'Tipps'` title, and no `'Laden…'` or `DiscoverScreen.tipsKey`;
      - complete it with a set with tips and `pumpAndSettle`: the section and card show.
    - `a failed first load: no Tipps section, no error line`: `fetchTips: () => Future.error(Exception('offline'))`; no `'Tipps'` title and no `textContaining('konnten nicht geladen werden')` for Tipps.
    - `with tips and weekly tips off: switching on drops the switch, the card stays`.
    - `four sections in order` runs with tips (Tipps, Alternativen, Rezepte, Wissen). Add `without tips: Alternativen, Rezepte, Wissen`.
    - Delete `weekly tips off: the example above the switch`, `on: no example`, `turning it on shows when the first tips come` and `no tips`. Adapt `off, no tips: only the opt-in` and `on, no tips: when the first tips come` into the two tests above.
    - Keep `a newest set without tips is never „Neu"…` and `a failed refresh (offline resume) keeps the set card…` green. They are the pins for „refresh keeps the card".
  - `weekly_tips_offer_sheet_test` and `first_tip_offer_sheet_test`: the new body literals and `'Zu den Einstellungen'`.
  - `buddy_hero_test`: `weeklyTipsOffer → wave, then the sheet; „Zu den Einstellungen" opens the notification settings`, with `location() == RoutePaths.settingsNotifications` and `homeCoveredProvider` true. Add `RoutePaths.settingsNotifications` to the harness's `stubRoutes`.
  - Integration:
    - `discover_flow_test`:
      - the offer case becomes `„Zu den Einstellungen" opens the notification settings with the switch`: `find.byType(SettingsNotificationsScreen)`, the `WeeklyTipsSwitch.switchKey` tile found after `ensureVisible`, and its value still false;
      - the opt-in case becomes `no tips: Entdecken has no Tipps; Einstellungen turns the weekly tips on`: Entdecken has no `optInKey` and no `'Tipps'` section; via Ich › Einstellungen › Benachrichtigungen, switching on writes `[true]`.
    - `home_motivation_flow_test`: `Tipps preview…` becomes `Entdecken without tips: no Tipps section, weekly tips off or on`.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/screens/discover test/screens/dashboard`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - **`DiscoverScreen`:**
    ```dart
    if (DiscoverTipsSection.showsFor(tips)) ...[
      DiscoverSection(title: 'Tipps', child: DiscoverTipsSection(sets: tips.value!, weeklyTips: weeklyTips, onOpen: …)),
      AppConstants.gap24,
    ],
    ```
    Update its class doc.
  - Delete the example card and its test.
  - Apply the copy and the push.
  - Grep for `ExampleTipCard` and `emptyWhileOn`: nothing may be left.
- [ ] **Step 4: Run** `TZ=Europe/Vienna flutter test test/screens test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit:** `feat(discover): Tipps show up once there are tips; the offer leads to Einstellungen`.

---

### Task 8: Ich without its header

**Files:**
- Modify: `lib/screens/me/me_screen.dart`
- Test: `test/screens/me/me_screen_test.dart`

**Interfaces:** none new.

- [ ] **Step 1: Write the failing test.** Give `pump` a `FakeViewPadding padding` parameter, defaulting to none. Then add `no „Ich" header: the Buddy card starts at the top, below the status bar`:
  - `find.byType(AppBar)` and `find.text('Ich')` find nothing;
  - `tester.getRect(find.byType(AnimatedBuddy)).top < kToolbarHeight`, where the app bar used to end;
  - with `padding: const FakeViewPadding(top: 59)`, the Buddy's top is ≥ 59.
- [ ] **Step 2: Run** `TZ=Europe/Vienna flutter test test/screens/me/me_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement:** remove the `appBar`, and wrap the `SingleChildScrollView` in `SafeArea`, as Home does. Update the class doc.
- [ ] **Step 4: Run** the test file. Expected: PASS, including `text scale 1.3 on a small phone: no overflow`.
- [ ] **Step 5: Commit:** `feat(me): Ich without its header; the Buddy card moves up`.

---

### Task 9: Visual check, integration flows and the branch check

**Files:**
- Modify only what the checks turn up: flame tokens, SVG details, sizes.
- The throwaway visual test is never committed.

- [ ] **Step 1: Run** `dart format .`, `flutter analyze` (0 issues) and the full `TZ=Europe/Vienna flutter test`. Expected: all pass.
- [ ] **Step 2: Visual check (throwaway).**
  - Create `test/zz_visual/round5_visual_test.dart`. It renders `matchesGoldenFile` PNGs, with `await tester.runAsync(NeedIcon.precache)` before pumping, of:
    1. `BuddyHero` on a 393×852 view at streak 5 unlit (glimmt), 5 lit (brennt), 42 lit (lodert), and 0;
    2. `StreakFlame` lit and as an ember at heights 20, 32, 72 and 190;
    3. the four `NeedIcon`s at 24, 40 and 60, and the four Bauchgefühl mouths at 36;
    4. `LogSuccessHero` for a drink that ignites day 5, at its end.
  - Run `TZ=Europe/Vienna flutter test test/zz_visual --update-goldens` and open every PNG with the Read tool. Text renders as boxes in tests; judge only the drawings.
  - Check that:
    - the Buddy stays the hero;
    - the flame reads as fire behind him, never on him;
    - the tongues are distinct;
    - the ember is a low glow at his feet;
    - „lodert" is taller, with the blue core;
    - nothing is clipped at the box or viewBox edges;
    - the 24 dp icons are crisp, their outlines and shadows whole;
    - the four mouths can be told apart.
  - Tune the tokens or SVGs, re-run Step 1, then `rm -rf test/zz_visual`. `git status` must show no `zz_visual`.
- [ ] **Step 3: Integration, only on the iPhone Air**, one file at a time:
  ```bash
  cd /Users/sevi/projects/bellybuddy/.worktrees/round5
  cp /Users/sevi/projects/bellybuddy/env.json env.json   # gitignored; never commit
  SIM=CB1F6232-482F-408F-ADF4-89FDA602E6A8
  xcrun simctl boot $SIM || true
  for f in home_motivation_flow_test discover_flow_test tutorial_flow_test drink_tracking_flow_test meal_tracking_flow_test journey_rewards_flow_test insights_flow_test diary_flow_test recipe_collection_flow_test recipes_flow_test auth_flow_test registration_flow_test; do
    flutter test integration_test/$f.dart -d $SIM --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown $SIM
  ```
  Expected: every file `EXIT 0`. If a case fails, run the same file on `develop` @ 872ced7e in a temporary worktree before calling it pre-existing.
- [ ] **Step 4: Commit** what Steps 2–3 changed: `fix(round5): …` or `test(integration): …`. Check `git status`: no `env.json`, no `test/zz_visual`.

---

## Self-review notes

**Spec coverage:**

| Spec | Task |
|---|---|
| §3.1 the slot and its gap go; the ring moves up ≈84 px | 5 |
| §3.1 the bubble is an overlay only while he talks, never moves the layout, never blocks the top bubbles, on screen at 375×667 / 1.3 | 5 |
| §3.1 the chip stays top-left with the count only | 4 |
| §3.2 a large flame behind the Buddy in the ring's centre, under him, about his height | 4 (placement), 3 (drawing) |
| §3.2 „feuriger": red → orange → yellow, bright core, ≥ 3 independent tongues, glow, sparks from „brennt" | 3 |
| §3.2 glimmt, brennt (ignite), lodert (tier thresholds, blue core, more sparks); streak 0 an ember | 3, 4 |
| §3.2 reduced motion: still per state, no burst | 3 |
| §3.2 the same drawing in „Dein Streak", the ignite row and the week marks | 3 |
| §3.3 four stickers as SVG assets through one widget; every `CareNeed.emoji` use; icons decorative | 1, 2 |
| §3.3 emoji stay only inside sentences | 2 (button), Decisions 10 and 16 |
| §3.4 Tipps absent until a set with tips; the opt-in reachable (day-3 offer, Einstellungen); example card removed; with tips as today | 7 |
| §3.5 Ich without its header | 8 |
| §3.5 ≈2 s ease-out charge, the ignite and „Tag n" after it | 6 |
| §4 tokens, German, reduced motion, 375×667 / 1.3, ≥ 48 dp, vocabulary | Global Constraints; 4 (chip), 5, 6, 7, 8 |

**Type consistency:**
- `NeedIcon(need, size:, gutFeeling:)` is used in Tasks 2 and 9.
- `CareRing.buddyKey`, `behindBuddy` (Task 4) and `overBuddy`/`overBuddyRoom` (Task 5) share one constructor.
- `FlamePainter.bodyScale`, `flicker`, `sparkCount`, `hotCore` and `showsGlow` are defined in Task 3 and read in Tasks 4 and 6.
- `DiscoverTipsSection.showsFor` and `sets` are defined and used in Task 7.
- `AppConstants.homeTapTarget` belongs to Task 4, `buddyBubbleOverlayMaxWidth` to Task 5, and `careChargeCurve` to Task 6.
