# Getränk eintragen (drinks screen redesign) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The drinks tracker becomes a today card with glasses, a one-tap „Wie zuletzt" row, drink tiles with line icons, vessel tiles and a save button that names what it saves.

**Architecture:** Pure helpers in `DrinkHelpers` decide everything countable (icons, glass fills, labels, tiles); one `CustomPainter` draws every drink and vessel glyph; the existing `DrinkTrackerNotifier` gains the last entry (one new PostgREST read) and a search flag; the screen's four widget files are rewritten and four small ones added. No server change.

**Tech Stack:** Flutter, Riverpod (`Notifier`, as the existing provider), supabase_flutter (PostgREST), mocktail, the accessibility harness in `test/accessibility/`. No new package.

**Spec:** `docs/superpowers/specs/2026-11-27-drinks-screen-design.md`; mockups `docs/superpowers/specs/assets/2026-11-27-drinks-D1.html` and `-D2.html` (open in a browser at 390×844; copy, sizes and colours are binding as mapped in spec §4.9).

## Repo and commands

| | |
|---|---|
| Repo | app `bellybuddyapp`, checkout `/home/sevi/projects/bellybuddy` |
| Branch | `git -C /home/sevi/projects/bellybuddy fetch origin && git -C /home/sevi/projects/bellybuddy worktree add /home/sevi/projects/bellybuddy/.worktrees/drinks-screen -b feat/drinks-screen origin/develop` |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` (fresh worktree; no model changes in this plan) |
| Tests | `flutter test <path>` |
| Gates | `dart format --set-exit-if-changed . && flutter analyze` (zero issues) |
| Commits | conventional; the pre-commit hook fails inside worktrees: run the gates by hand, commit with `--no-verify` |
| Devices | no simulator/emulator on the dev box; device checks are spec §10 |

## Global Constraints

- User-facing strings German, „du"; the exact strings in the spec and this plan. „eintragen", never „erfassen"/„tracken" (`test/utils/vocabulary_test.dart`). No emoji anywhere on the screen.
- Colours only `static const Color` in `AppTheme` (this plan adds none); font sizes only `AppTheme.fontSize*`; spacing, radii and sizes only `AppConstants` (new ones listed in DR1).
- Nothing reads as a goal or advice: no target, no „noch … bis", no progress bar.
- `tracked_at` is the user's wall clock in the UTC slot: never `toLocal()` / `astimezone`; build times with plain `DateTime(...)` as `DateTimeChips` does.
- Tap targets ≥ 48 px; text contrast ≥ 4.5:1 (no `Opacity` over text); every animation through `ReducedMotion.duration`.
- 200 % text: no vertical overflow; grids switch to 2 columns at text scale ≥ `AppConstants.drinkGridLargeTextScale` (1.5).
- Riverpod: keep `DrinkTrackerNotifier` a `Notifier` with explicit `isLoading` and its stale-result guard (`ref.mounted` + same day).
- `AppLogger`, never `print()`; no user text or health data in log lines.
- No server, schema, RLS, privacy-policy or `privacyPolicyVersion` change. PR to `develop`; never merge or arm auto-merge.

## Review Focus

1. **The last entry's drink was deleted (or is another user's private drink).** The one-tap row hides; the screen works. Test in DR2 (`'a last entry whose drink is unknown shows no row'`).
2. **A day total far above 3 l, or with a remainder plus a pending amount that spans glasses** (1100 ml drunk + 400 ml pending; 15 l). Glasses split correctly, the row caps at 48, the total shows the real sum. Tests in DR1 (`glassFills`) and DR3.
3. **A drink chosen in search that is not among the five tiles.** It shows as the selected fifth tile; deselecting it brings the old fifth back. Tests in DR1 (`tileDrinks`) and DR4.
4. **Tapping „Eintragen" on the one-tap row while a backdated time is set** (opened from the meal success screen with yesterday 20:00). The entry is stored at that wall-clock time, the Buddy event carries it, the screen closes with `true`. Test in DR6.
5. **200 % text with a long drink name selected and search open.** No vertical overflow, the name ellipsises in tiles but is spoken in full, the save button wraps. Tests in DR4 and DR7.

---

### Task DR1: Pure helpers, vessel list and constants

**Files:**
- Modify: `lib/utils/drink_helpers.dart`, `lib/config/constants.dart`
- Test: `test/utils/drink_helpers_test.dart`, `test/utils/diary_helpers_test.dart` (expectations of „L" → „l")

**Interfaces — Produces:**

```dart
// drink_helpers.dart
enum DrinkIcon { glass, hotCup, cup, bottle, carton, can }

enum DrinkVessel {
  glass('Glas', 250), can('Dose', 330), bottle('Flasche', 500), large('Große', 1000);
  const DrinkVessel(this.label, this.ml);
  final String label; final int ml;
}

typedef GlassFill = ({double drunk, double pending});
typedef LastDrink = ({Drink drink, int amountMl});

abstract final class DrinkHelpers {
  static DrinkIcon iconFor(String name);
  static List<GlassFill> glassFills(int drunkMl, int pendingMl);
  static String glassesLabel(int drunkMl, int pendingMl);
  static List<Drink> tileDrinks(List<Drink> quick, Drink? selected, {int count = AppConstants.drinkTileCount});
  static String saveLabel(Drink drink, int? amountMl);
  static String timeLabel(DateTime at, DateTime now);
  static String formatAmount(int ml);                  // now „1 l", „1,4 l", „250 ml"
  static List<Drink> buildQuickDrinks(List<Drink> allDrinks, List<String> recentIds); // + starter fill
}

// constants.dart (new)
static const double drinkTileMinHeight = 84, vesselTileMinHeight = 96;
static const double drinkTileIconSize = 28, drinkRowIconSize = 26, drinkGlyphStroke = 1.8;
static const int drinkGlassMl = 250, glassMeterMaxGlasses = 48, drinkTileCount = 5;
static const Size glassMeterGlassSize = Size(22, 28);
static const double dashLengthSm = 3, dashGapSm = 3, drinkGridLargeTextScale = 1.5;
static const List<String> starterDrinkNames = ['Wasser', 'Kaffee', 'Pfefferminztee', 'Schwarzer Tee', 'Apfelsaftschorle'];
```

Keyword lists and their order are spec §4.4 (copy them verbatim as private `const` lists). `glassFills`/`glassesLabel` are spec §4.8.

- [ ] **Step 1: Write the failing tests** in `drink_helpers_test.dart`:

```dart
test('iconFor maps names by keyword in order', () {
  final cases = {
    'Wasser': DrinkIcon.glass, 'Mineralwasser': DrinkIcon.glass, 'Rotwein': DrinkIcon.glass,
    'Pfefferminztee': DrinkIcon.hotCup, 'Kakao': DrinkIcon.hotCup, 'Gemüsebrühe': DrinkIcon.hotCup,
    'Kaffee': DrinkIcon.cup, 'Milchkaffee': DrinkIcon.cup, 'Chai Latte': DrinkIcon.cup,
    'Apfelsaft gespritzt': DrinkIcon.bottle, 'Eistee': DrinkIcon.bottle, 'Tomatensaft': DrinkIcon.bottle, 'Zitronenlimo': DrinkIcon.bottle,
    'Hafermilch': DrinkIcon.carton, 'Sojadrink': DrinkIcon.carton, 'Kefir': DrinkIcon.carton,
    'Cola Zero': DrinkIcon.can, 'Energy Drink': DrinkIcon.can, 'Alkoholfreies Bier': DrinkIcon.can,
  };
  cases.forEach((name, icon) => expect(DrinkHelpers.iconFor(name), icon, reason: name));
});
test('iconFor ignores case and falls back to glass', () {
  expect(DrinkHelpers.iconFor('KAFFEE'), DrinkIcon.cup);
  expect(DrinkHelpers.iconFor('Xyz'), DrinkIcon.glass);
  expect(DrinkHelpers.iconFor(''), DrinkIcon.glass);
});
test('glassFills: 1000 drunk → four full glasses', () {
  expect(DrinkHelpers.glassFills(1000, 0), List.filled(4, (drunk: 1.0, pending: 0.0)));
});
test('glassFills: 1100 drunk + 400 pending splits the fifth glass', () {
  expect(DrinkHelpers.glassFills(1100, 400), [
    ...List.filled(4, (drunk: 1.0, pending: 0.0)),
    (drunk: 0.4, pending: 0.6), (drunk: 0.0, pending: 1.0),
  ]);
});
test('glassFills: 1000 + 400 → two pending glasses, the last 60 %', () {
  final f = DrinkHelpers.glassFills(1000, 400);
  expect(f.length, 6); expect(f[4], (drunk: 0.0, pending: 1.0));
  expect(f[5].pending, closeTo(0.6, 1e-9));
});
test('glassFills: 0 ml → one empty glass; 15 l → capped at 48', () {
  expect(DrinkHelpers.glassFills(0, 0), [(drunk: 0.0, pending: 0.0)]);
  expect(DrinkHelpers.glassFills(15000, 0).length, 48);
});
test('glassesLabel', () {
  expect(DrinkHelpers.glassesLabel(0, 0), 'Nichts eingetragen');
  expect(DrinkHelpers.glassesLabel(250, 0), '1 Glas zu 250 ml getrunken');
  expect(DrinkHelpers.glassesLabel(1000, 0), '4 Gläser zu je 250 ml getrunken');
  expect(DrinkHelpers.glassesLabel(1100, 0), '4 Gläser zu je 250 ml und 100 ml getrunken');
  expect(DrinkHelpers.glassesLabel(100, 0), '100 ml getrunken');
  expect(DrinkHelpers.glassesLabel(1000, 400), '4 Gläser zu je 250 ml getrunken, dazu kommen 400 ml');
  expect(DrinkHelpers.glassesLabel(0, 400), 'Nichts eingetragen, dazu kommen 400 ml');
});
test('tileDrinks: Wasser first, at most five, no duplicates', ...);   // quick [Kaffee, Wasser, Tee, Saft, Milch, Kakao, Kaffee] → [Wasser, Kaffee, Tee, Saft, Milch]
test('tileDrinks: a selected drink outside the five takes the fifth slot', ...); // selected Mate → [Wasser, Kaffee, Tee, Saft, Mate]
test('tileDrinks: a selected drink among the five changes nothing', ...);
test('saveLabel', () {
  final tee = testDrink(name: 'Pfefferminztee');
  expect(DrinkHelpers.saveLabel(tee, 400), '400 ml Pfefferminztee eintragen');
  expect(DrinkHelpers.saveLabel(tee, 1000), '1 l Pfefferminztee eintragen');
  expect(DrinkHelpers.saveLabel(tee, null), 'Pfefferminztee eintragen');
});
test('timeLabel', () {
  final now = DateTime(2026, 11, 27, 15);
  expect(DrinkHelpers.timeLabel(DateTime(2026, 11, 27, 14, 30), now), 'Heute, 14:30');
  expect(DrinkHelpers.timeLabel(DateTime(2026, 11, 26, 14, 30), now), 'Gestern, 14:30');
  expect(DrinkHelpers.timeLabel(DateTime(2026, 11, 19, 9, 5), now), '19. Nov., 09:05');
});
test('formatAmount writes l', () {
  expect(DrinkHelpers.formatAmount(1000), '1 l');
  expect(DrinkHelpers.formatAmount(1400), '1,4 l');
  expect(DrinkHelpers.formatAmount(250), '250 ml');
});
test('buildQuickDrinks fills a user without history with the starter drinks that exist', ...);
  // all = [Apfelsaftschorle, Cola, Kaffee, Wasser] (alphabetical), recent [] → [Wasser, Kaffee, Apfelsaftschorle]
test('buildQuickDrinks with five recents adds no starters', ...);
test('vessels match AppConstants.drinkSizes', () {
  expect(DrinkVessel.values.map((v) => v.ml), AppConstants.drinkSizes);
  expect(DrinkVessel.values.map((v) => v.label), ['Glas', 'Dose', 'Flasche', 'Große']);
});
```

Fill in the three `...` bodies with the inputs/outputs in their comments. Update the existing „L" expectations in `drink_helpers_test.dart` and `diary_helpers_test.dart` to „l".

- [ ] **Step 2: Run** `flutter test test/utils/drink_helpers_test.dart test/utils/diary_helpers_test.dart` — expected: FAIL (undefined names, „L" vs „l").
- [ ] **Step 3: Implement** in `drink_helpers.dart` and `constants.dart`. `timeLabel` = `formatRecentDayTime(at, now)` with its first character upper-cased. `buildQuickDrinks`: today's result, then, while shorter than `drinkTileCount`, append drinks from `allDrinks` whose lower-cased name equals a `starterDrinkNames` entry (in that list's order), skipping ones already in it; the existing „no Wasser and no recents → first 11" fallback stays for an empty result.
- [ ] **Step 4: Run** the same tests and `flutter test test/screens/diary` — expected: PASS.
- [ ] **Step 5: Commit** `feat(drinks): icon mapping, glass fills and labels for the drinks screen`.

### Task DR2: The last entry and the search flag

**Files:**
- Modify: `lib/services/drink_service.dart`, `lib/repositories/drink_repository.dart`, `lib/providers/drink_tracker_provider.dart`, `test/helpers/fakes.dart` (`FakeDrinkRepository`), `test/helpers/app_host.dart` (`baseOverrides(drinks:)`)
- Test: `test/services/drink_service_test.dart`, `test/repositories/drink_repository_test.dart`, `test/providers/drink_tracker_provider_test.dart`

**Interfaces — Consumes:** `LastDrink`, `DrinkHelpers.buildQuickDrinks` (DR1). **Produces:**

```dart
// DrinkService / DrinkRepository
Future<DrinkEntry?> fetchLastEntry(String userId);
// from('drink_entries').select('*, drinks(name)').eq('user_id', userId)
//   .order('tracked_at', ascending: false).order('created_at', ascending: false).limit(1).maybeSingle()
//   → DrinkEntry.fromDbRow or null. Errors logged ('fetchLastEntry failed') and rethrown, like its neighbours.

// DrinkTrackerState: + final LastDrink? lastDrink; + final bool isSearchOpen (default false);
//                    − hasRecentDrinks (removed; no caller left after DR4)
// copyWith: lastDrink uses the existing _unset sentinel pattern.

// DrinkTrackerNotifier
Future<void> loadDrinks();   // + fetches recents and the last entry in parallel (Future.wait);
                             //   lastDrink = drink with entry.drinkId in allDrinks, else null;
                             //   a failing fetchLastEntry: _log.error('failed to load the last drink', e, st), lastDrink null, rest loads
void openSearch();           // isSearchOpen = true
void closeSearch();          // isSearchOpen = false
void toggleDrink(Drink d);   // as today + isSearchOpen = false
Future<void> createDrink(String name); // as today, but no longer prepends to quickDrinks (tileDrinks shows it); + isSearchOpen = false
Future<void> saveLast();     // no-op without lastDrink; else stores lastDrink's drink + amount at state.trackedAt
Future<void> save();         // unchanged behaviour; both go through one private _store(Drink drink, int amountMl)

// FakeDrinkRepository: + DrinkEntry? lastEntry = testDrinkEntry();  (Wasser, 250 ml, drinkId 'water-id')
//                      + int lastEntryFetches; fetchLastEntry returns lastEntry
// baseOverrides: + FakeDrinkRepository? drinks  (default FakeDrinkRepository())
```

- [ ] **Step 1: Write the failing tests.**

```dart
// drink_service_test.dart, group 'DrinkService.fetchLastEntry' (mock style of fetchRecentDrinkIds)
test('reads the newest entry by tracked_at, then created_at, for the user, with the drink name')
  // verify select('*, drinks(name)'), eq('user_id', testUserId),
  // order('tracked_at', ascending: false) then order('created_at', ascending: false), limit(1), maybeSingle()
test('returns the row as a DrinkEntry with its wall-clock tracked_at')
  // row tracked_at '2026-11-26T20:00:00+00:00' → trackedAt == DateTime(2026, 11, 26, 20)
test('returns null without entries')

// drink_tracker_provider_test.dart
test('loadDrinks resolves the last entry to its drink and amount')   // lastDrink == (drink: tee, amountMl: 400)
test('a last entry whose drink is unknown shows no row')             // lastEntry.drinkId 'gone' → lastDrink null
test('a failing last-entry fetch leaves lastDrink null and loads the rest') // allDrinks loaded, isLoading false
test('saveLast stores the last drink at the chosen time and shows success')
  // setTrackedAt(DateTime(2026, 11, 26, 20)); saveLast(); verify addDrinkEntry with drinkId, amountMl 400, trackedAt that value
test('saveLast without a last entry stores nothing')
test('openSearch / closeSearch; picking or creating a drink closes the search')
test('createDrink selects the new drink without reordering quickDrinks')
```

Delete the two `hasRecentDrinks` tests in the provider test.

- [ ] **Step 2: Run** `flutter test test/services/drink_service_test.dart test/repositories/drink_repository_test.dart test/providers/drink_tracker_provider_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement** as in the Interfaces block. `QuickDrinkGrid` still reads `hasRecentDrinks` until DR4: in this task make its heading read `state.lastDrink != null ? 'Wähle aus deinen letzten Getränken' : 'Häufige Getränke'` and adjust the two screen tests that check it, so the suite stays green; DR4 replaces the widget.
- [ ] **Step 4: Run** those tests plus `flutter test test/screens/trackers/drink test/accessibility` — expected: PASS.
- [ ] **Step 5: Commit** `feat(drinks): load the last drink entry for one-tap logging`.

### Task DR3: Glyph painter and glass meter

**Files:**
- Create: `lib/screens/trackers/drink/widgets/drink_glyph.dart`, `lib/screens/trackers/drink/widgets/glass_meter.dart`
- Modify: `lib/widgets/common/dashed_border_painter.dart` (extract `dashPath`)
- Test: `test/screens/trackers/drink/drink_glyph_test.dart`, `test/screens/trackers/drink/glass_meter_test.dart`

**Interfaces — Consumes:** `DrinkIcon`, `DrinkVessel`, `GlassFill`, `glassFills`, `glassesLabel`, constants (DR1). **Produces:**

```dart
// dashed_border_painter.dart
Path dashPath(Path source, {required double dash, required double gap}); // DashedBorderPainter uses it

// drink_glyph.dart — decorative (no semantics), drawn at the glyph's own size
class DrinkGlyph extends StatelessWidget {
  const DrinkGlyph.icon(DrinkIcon icon, {Key? key, double size = AppConstants.drinkTileIconSize, Color color = AppTheme.foreground});
  const DrinkGlyph.vessel(DrinkVessel vessel, {Key? key, Color color = AppTheme.foreground});
  static Size vesselSize(DrinkVessel v); // glass 22×28, can 20×34, bottle 18×40, large 24×46
}
class DrinkGlyphPainter extends CustomPainter { final DrinkIcon? icon; final DrinkVessel? vessel; final Color color; }
  // stroke AppConstants.drinkGlyphStroke, StrokeJoin.round, StrokeCap.round, no fill;
  // paths transcribed from the mockups (icons in a 24 box scaled to size; vessels in their own box)

// glass_meter.dart
class GlassMeter extends StatelessWidget {
  const GlassMeter({super.key, required this.drunkMl, required this.pendingMl});
  static const glassesKey = Key('glass_meter');
}
  // Semantics(image: true, label: glassesLabel(drunkMl, pendingMl), excludeSemantics: true) around a Wrap
  // (spacing/runSpacing spacing6) of glassFills(...) glasses, each AppConstants.glassMeterGlassSize, painted by
class GlassPainter extends CustomPainter { final GlassFill fill; }
  // drunk share bottom-up in buddyWater, pending share above it in careWaterSoft,
  // outline foreground solid, or infoText dashed (dashLengthSm/dashGapSm) when fill.drunk == 0 && fill.pending > 0
  // fill shares animate over ReducedMotion.duration(context, AppConstants.animNormal)
```

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('every icon and vessel paints without errors at its size')   // pump each; tester.takeException() isNull; getSize == size
testWidgets('a glyph has no semantics node')                            // ensureSemantics; find.bySemanticsLabel(RegExp('.')) inside → none
testWidgets('GlassMeter is one image with the spoken summary', (t) async {
  // drunk 1000, pending 400
  expect(t.getSemantics(find.byKey(GlassMeter.glassesKey)),
      isSemantics(isImage: true, label: '4 Gläser zu je 250 ml getrunken, dazu kommen 400 ml'));
});
testWidgets('GlassMeter draws one painter per glass with its fill')     // 1100/400 → 6 GlassPainters, [4].fill == (drunk: 0.4, pending: 0.6)
testWidgets('only a glass that is all pending has the dashed outline')  // painter property `dashed` true only for index 5
testWidgets('20 l wraps onto more rows and stops at 48 glasses')        // 48 painters, distinct row tops > 1, no overflow at width 342
testWidgets('with reduced motion a new amount shows at once')           // MediaQuery(disableAnimations: true); change pending; one pump → final fills
```

- [ ] **Step 2: Run** `flutter test test/screens/trackers/drink/drink_glyph_test.dart test/screens/trackers/drink/glass_meter_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement.** Transcribe each mockup `<path d>` to `Path` calls (`moveTo`, `lineTo`, `relativeLineTo`, `relativeArcToPoint`, `cubicTo`); the search tile uses `Icons.search`, so its circle is not transcribed. Expose `bool get dashed` on `GlassPainter` for the test. `shouldRepaint` compares all fields.
- [ ] **Step 4: Run** the tests, plus `flutter test test/widgets` (dashed border users) — expected: PASS.
- [ ] **Step 5: Commit** `feat(drinks): line glyphs and the glass meter`.

### Task DR4: Drink tiles and the search reveal

**Files:**
- Modify (rewrite): `lib/screens/trackers/drink/widgets/quick_drink_grid.dart`; modify `lib/screens/trackers/drink/widgets/drink_search.dart` (`autofocus`)
- Test: `test/screens/trackers/drink/quick_drink_grid_test.dart` (new), `test/screens/trackers/drink/drink_tracker_test.dart` (move/adjust the quick-drink tests)

**Interfaces — Consumes:** `tileDrinks`, `iconFor`, `DrinkGlyph.icon` (DR1, DR3); `openSearch`, `closeSearch`, `toggleDrink`, `isSearchOpen`, `lastDrink` (DR2). **Produces:**

```dart
class QuickDrinkGrid extends ConsumerWidget {
  static Key tileKey(String drinkId) => Key('drink_tile_$drinkId');
  static const searchTileKey = Key('drink_tile_search');
}
// heading: 'Oder wähle aus' when lastDrink != null && selectedDrink == null, else 'Was?'; Semantics(header: true)
// isSearchOpen: DrinkSearch(autofocus: true) in the heading's place
// tiles per spec §4.5; columns 3, or 2 at MediaQuery.textScalerOf(context).scale(1) >= drinkGridLargeTextScale
class DrinkSearch { const DrinkSearch({super.key, this.autofocus = false}); final bool autofocus; }
```

- [ ] **Step 1: Write the failing tests** (`ProviderContainer` + `FakeDrinkRepository` seeded with Wasser, Pfefferminztee, Kaffee, Apfelsaft gespritzt, Hafermilch, Mate):

```dart
testWidgets('five drink tiles, Wasser first, then „Anderes suchen"')     // order of tile keys; text 'Anderes suchen'
testWidgets('heading reads „Oder wähle aus" with a last entry, „Was?" without, and „Was?" once a drink is selected')
testWidgets('a tile shows the glyph for its name')                       // DrinkGlyph under Hafermilch's tile has icon DrinkIcon.carton
testWidgets('the selected tile: white fill, 2 px infoText border, infoText glyph, w600 name; tapping it again deselects')
testWidgets('tiles are a one-of group named by the full drink name', (t) async {
  // seed a 40-char name; its Text has maxLines 2 and TextOverflow.ellipsis;
  expect(t.getSemantics(find.byKey(QuickDrinkGrid.tileKey(longId))),
      isSemantics(label: longName, isButton: true, hasSelectedState: true, isSelected: false,
                  isInMutuallyExclusiveGroup: true, hasTapAction: true));
});
testWidgets('„Anderes suchen" opens the focused search in place of the heading and reads as expanded')
  // after tap: DrinkSearch.searchFieldKey found and focused; heading text gone; semantics hasExpandedState, isExpanded
testWidgets('tapping „Anderes suchen" again closes the search')
testWidgets('a drink picked in search closes it and becomes the selected fifth tile') // pick Mate → tileKey('mate') selected, Hafermilch gone
testWidgets('„„Mate" hinzufügen" creates, selects and shows the new drink as a tile')
testWidgets('the dashed outline of „Anderes suchen" uses mutedForeground')        // DashedBorderPainter.color
testWidgets('every tile is at least 48 px and at 200 % text the grid has 2 columns without vertical overflow')
testWidgets('with reduced motion the selection shows after one pump')
```

Keep the existing search tests in `drink_tracker_test.dart` (drag-safe dropdown, „Getränk suchen" read once, keeps its name with text, „Getränk löschen", create row colour), each now opening the search via `QuickDrinkGrid.searchTileKey` first. Remove the quick-pill tests „Häufige Getränke" / „letzten Getränken" and the 8-px pill-row gap test (replaced above).

- [ ] **Step 2: Run** `flutter test test/screens/trackers/drink` — expected: the new tests FAIL.
- [ ] **Step 3: Implement** per spec §4.5. Each row of tiles: `IntrinsicHeight` + `Row(crossAxisAlignment: stretch)` of `Expanded` cells; empty cells in the last row stay empty `Expanded`. Selection border/fill via `AnimatedContainer(duration: ReducedMotion.duration(context, AppConstants.animFast))`. `HapticService.selection()` on drink tiles.
- [ ] **Step 4: Run** `flutter test test/screens/trackers/drink` — expected: PASS.
- [ ] **Step 5: Commit** `feat(drinks): drink tiles with icons and a search tile`.

### Task DR5: Vessel tiles and „Andere Menge"

**Files:**
- Modify (rewrite): `lib/screens/trackers/drink/widgets/drink_size_selector.dart`; modify `lib/widgets/common/bb_tap_area.dart` (`hint`)
- Test: `test/screens/trackers/drink/drink_size_selector_test.dart` (new), `test/widgets/common/bb_tap_area_test.dart` (add a case; create the file if missing)

**Interfaces — Consumes:** `DrinkVessel`, `DrinkGlyph.vessel`, `formatAmount`, `amountError`, `parseAmount` (DR1, DR3); `selectAmount`, `setCustomAmount`, `selectedDrink` (existing). **Produces:**

```dart
class BbTapArea { ...; final String? hint; }      // passed to Semantics(hint:)
class DrinkSizeSelector {
  static const customAmountKey = Key('drink_custom_amount');     // kept
  static Key vesselKey(int ml) => Key('drink_vessel_$ml');
}
```

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('without a drink the vessels are disabled and say why', (t) async {
  expect(t.getSemantics(find.byKey(DrinkSizeSelector.vesselKey(250))),
      isSemantics(label: 'Glas, 250 ml', hint: 'Wähle zuerst ein Getränk.', isButton: true,
                  hasEnabledState: true, isEnabled: false, isInMutuallyExclusiveGroup: true));
  expect(find.text('Wähle zuerst ein Getränk.'), findsOneWidget);       // visible, excluded from semantics
  expect(find.byKey(DrinkSizeSelector.customAmountKey), findsNothing);
  // „Wie viel?" heading colour mutedForeground; amount Text colour mutedForeground; no Opacity ancestor of any Text
});
testWidgets('with a drink the four vessels read Glas, Dose, Flasche, Große with 250 ml, 330 ml, 500 ml, 1 l')
testWidgets('a vessel tap selects it (white, infoText border) and sets selectedAmount; the hint is gone')
testWidgets('typing in „Andere Menge" clears the vessel; a vessel tap clears the field')
testWidgets('„Andere Menge" refuses 99999 with „Bitte gib 1 bis 3000 ml ein." and accepts 3000')
testWidgets('the field is named „Andere Menge in ml" with „300" entered and shows „ml" inside')
testWidgets('vessel glyphs grow: heights 28 < 34 < 40 < 46')
testWidgets('at 200 % text the vessels use 2 columns without vertical overflow')
// bb_tap_area_test.dart
testWidgets('hint reaches the semantics node')
```

Move the custom-amount tests out of `drink_tracker_test.dart` into this file (same assertions), except the 393×852 keypad test, which stays on the screen (DR6).

- [ ] **Step 2: Run** `flutter test test/screens/trackers/drink test/widgets/common/bb_tap_area_test.dart` — expected: new tests FAIL.
- [ ] **Step 3: Implement** per spec §4.6, same field rules (`digitsOnly`, `LengthLimitingTextInputFormatter(5)`, `scrollPadding: fieldWithHintScrollPadding`, the `ref.listen` controller sync). `HapticService.selection()` on vessel taps.
- [ ] **Step 4: Run** the same — expected: PASS.
- [ ] **Step 5: Commit** `feat(drinks): vessel tiles that grow with the amount`.

### Task DR6: Today card, one-tap row, time line and the named button

**Files:**
- Create: `lib/screens/trackers/drink/widgets/drink_today_card.dart`, `lib/screens/trackers/drink/widgets/last_drink_row.dart`, `lib/screens/trackers/drink/widgets/drink_time_line.dart`
- Modify: `lib/screens/trackers/drink/drink_tracker_screen.dart`, `lib/widgets/common/bb_button.dart` (`semanticLabel`), `integration_test/home_motivation_flow_test.dart`
- Test: `test/screens/trackers/drink/drink_tracker_test.dart`

**Interfaces — Consumes:** everything above. **Produces:**

```dart
class BbButton { ...; final String? semanticLabel; }   // replaces the label for assistive tech; visible text unchanged
class DrinkTodayCard extends ConsumerWidget { static const totalKey = Key('drink_today_total'); }
class LastDrinkRow extends ConsumerWidget { const LastDrinkRow({super.key, required this.onSave}); final VoidCallback onSave;
  static const saveKey = Key('last_drink_save'); }
class DrinkTimeLine extends ConsumerStatefulWidget { static const toggleKey = Key('drink_time_line'); }
class DrinkTrackerScreen { static const saveKey = Key('drink_save'); }   // + trackerKey kept
// screen: _save() as today; _saveLast() = logEntry(kind: EntryKind.drink, trackedAt: state.trackedAt,
//   save: notifier.saveLast, stored: () => ref.read(drinkTrackerProvider).showSuccess)
```

Layout, strings and semantics: spec §4.1–4.3, §4.7. Pending = `selectedDrink != null ? (selectedAmount ?? 0) : 0`.

- [ ] **Step 1: Write the failing tests** (rewrite the old title/„Heute: "/„Speichern" tests):

```dart
testWidgets('title „Was hast du getrunken?" without emoji')
testWidgets('opened: card „Heute getrunken" with the day total, „Wie zuletzt" „Wasser, 250 ml", no save button')
  // FakeDrinkRepository.fetchDayTotal → 500: find.text('500 ml') under DrinkTodayCard.totalKey; DrinkTrackerScreen.saveKey findsNothing
testWidgets('a past day reads „Am 22.11. getrunken" and loads that day')   // replaces "Am 22.11.: "
testWidgets('choosing Pfefferminztee and typing 400: „+ 400 ml", total 900 ml, button „400 ml Pfefferminztee eintragen"')
testWidgets('with a drink but no valid amount the button reads „Pfefferminztee eintragen" and is disabled')
testWidgets('selecting a drink hides „Wie zuletzt"; deselecting brings it back')
testWidgets('no last entry: no row, heading „Was?"')
testWidgets('„Eintragen" on the row saves the last drink at the chosen time, shows success and the Buddy reacts', (t) async {
  // setTrackedAt(DateTime(2026, 11, 21, 20)); tap LastDrinkRow.saveKey; pump 700 ms
  // buddyEventsProvider.kind drink, trackedAt that value; 'Getränk gespeichert!' shown; FakeEntryRepository got drinkId 'water-id', 250
});
testWidgets('the row\'s button is named „Wasser, 250 ml eintragen"')
testWidgets('after a one-tap save it closes with true for its opener')     // the GoRouter opener test, via LastDrinkRow.saveKey
testWidgets('the time line reads „Heute, <HH:mm> · ändern", opens the date and time chips and reads as expanded')
  // semantics label 'Zeitpunkt', hasExpandedState; after tap find.byType(DateTimeChips) findsOneWidget
testWidgets('the card is one header node and one image', ...)              // label 'Heute getrunken', value '500 ml'; GlassMeter image
testWidgets('D2 state meets the tap-target, label and contrast guidelines')
  // drink + 400 selected, search open: meetsGuideline(androidTapTargetGuideline / labeledTapTargetGuideline / textContrastGuideline)
```

Keep, switched to `find.byKey(DrinkTrackerScreen.saveKey)`: initialTrackedAt seeding, reset-to-now, Buddy event + reaction, Trinken charges to full, the 375×667 success-page fit at 1.0 and 1.3, „a save that stores nothing emits no Buddy event" (now: deselect between render and tap), closes with true, and the 393×852 keypad test (hint fully above the button). Delete the chip/✕ „Auswahl entfernen" test.

- [ ] **Step 2: Run** `flutter test test/screens/trackers/drink/drink_tracker_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement** the three widgets and rewire the screen per spec §4.1. Delete `_buildDayTotal` and `_buildSelectedChip`. In `integration_test/home_motivation_flow_test.dart` replace the „Wasser → 250 ml → Speichern" taps with `tapVisible(find.byKey(QuickDrinkGrid.tileKey(<water id>)))`, `tapVisible(find.byKey(DrinkSizeSelector.vesselKey(250)))`, `tap(find.byKey(DrinkTrackerScreen.saveKey))` (only the drink block; the other trackers' „Speichern" stays).
- [ ] **Step 4: Run** `flutter test test/screens/trackers test/widgets` — expected: PASS (meal handoff test unchanged).
- [ ] **Step 5: Commit** `feat(drinks): today card, one-tap entry and a named save button`.

### Task DR7: Accessibility harness

**Files:**
- Modify: `test/accessibility/a11y_screens.dart`, `test/accessibility/static_rules_test.dart` (only if an allowlist entry for the old drink files goes stale)
- Test: `test/accessibility/screen_guidelines_test.dart`, `test/accessibility/text_scale_test.dart` (run, no edit)

**Interfaces — Consumes:** `baseOverrides(drinks:)`, `FakeDrinkRepository.lastEntry` (DR2).

- [ ] **Step 1: Add the screens** (they fail until everything above holds):

```dart
A11yScreen('Getränk', RoutePaths.drinkTracker),                       // kept: default fake → „Wie zuletzt" row (D1)
A11yScreen('Getränk (ohne Verlauf)', RoutePaths.drinkTracker, base: _drinkNoHistoryBase),
// List<Override> _drinkNoHistoryBase() => baseOverrides(drinks: FakeDrinkRepository()..recentDrinkIds = []..lastEntry = null);
```

Neither has a `pending` entry.
- [ ] **Step 2: Run** `flutter test test/accessibility` — expected: PASS for both drink screens on all five checks and the static rules (fix the screen, never add `pending`).
- [ ] **Step 3: Commit** `test(a11y): the drinks screen with and without history in the guardrail`.

### Task DR8: Gates, full suite and the PR

- [ ] **Step 1:** `grep -rn "toLocal()\|astimezone\|Color(0x\|fontSize: [0-9]" lib/screens/trackers/drink lib/utils/drink_helpers.dart` — expected: no output.
- [ ] **Step 2:** `dart format --set-exit-if-changed . && flutter analyze` — expected: no changes, „No issues found!".
- [ ] **Step 3:** `flutter test` — expected: all pass (including `test/utils/vocabulary_test.dart` and `test/accessibility`).
- [ ] **Step 4:** The owner's routine: `/simplify` → `/code-review` → fix findings, re-run Steps 2–3, commit fixes as `fix(drinks): …` / `refactor(drinks): …`.
- [ ] **Step 5:** `git push -u origin feat/drinks-screen` and `gh pr create --base develop --title "feat: a friendlier drinks screen with one-tap entry"` with a body listing: the five sections, the Claude's-call decisions from spec §2 (7–18), „no server change, no new data", the spec §10 manual checks as a checklist for Severin, and the open question on starter names. Stop there: no merge, no auto-merge.
