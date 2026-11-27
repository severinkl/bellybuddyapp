# Dein Verlauf + Wissen „Für dich" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A free 12-week progress page „Dein Verlauf" (reached from „Ich" and the Muster page) and a deterministic „Für dich" ordering of the existing myfodmap knowledge feed.

**Architecture:** App only. A pure `computeProgress` over one bounded fetch (four tables, 12 Monday weeks) feeds `progressProvider` and a page of week rows, counts, streaks and custom-painted symptom bars; the day class is the Muster's, shared through one public function. A pure keyword scorer ranks feed articles against signals the app already holds (Muster items, profile, this week's entries) minus a local opened-articles list; Entdecken and Wissen show the picks first with one reason line.

**Tech Stack:** Flutter, Riverpod (AsyncNotifier), GoRouter, shared_preferences, `xml` (already used). No new package.

**Spec:** `docs/superpowers/specs/2026-11-27-progress-knowledge-design.md` (branch `docs/plan-progress-knowledge`).

## Repos and commands

| What | Where / command |
|---|---|
| App worktree | create `git -C ~/projects/bellybuddy worktree add .worktrees/progress-knowledge -b feat/progress-knowledge origin/develop` |
| Core | no change in this track |
| Tests | `flutter test <path>` |
| Gates | `dart format --set-exit-if-changed . && flutter analyze` (zero issues) |
| Codegen | none (no freezed model changes) |
| Commits | the pre-commit hook fails inside worktrees: run the gates by hand, `git commit --no-verify`; conventional commits |
| Devices | no simulator on the dev box: device checks go to the spec's §9 |

## Global Constraints

- UI strings German, „du"; exact copy from the spec §4. Banned by `test/utils/vocabulary_test.dart`: „durchschnittlich", „tracken/getrackt", „erfassen", „Serie", „Empfehlung", „Stuhlgang", „Toilettengang", „Speise(n)", „Logbuch" — say „im Schnitt", „eintragen", „Streak", „Tipp", „Klo".
- The mascot is „Belly Buddy" / „Buddy".
- Colours only `static const Color` in `AppTheme`; font sizes only `AppTheme.fontSize*`; spacing/radii only `AppConstants`; add missing values there first.
- Riverpod `AsyncNotifier`; routes in `lib/router/`; `AppLogger`, never `print()`; no health data in log lines.
- `tracked_at` is wall clock in the UTC slot: day = `startOfDay(trackedAt)`, never `toLocal()` on it.
- Health-claims caution: reasons say what the user logged or stated („auffällt", „angegeben", „eingetragen"), never a diagnosis; the keyword map holds no disease names.
- Never state a mean from fewer than `ProgressRules.minEntriesForMeans` entries; never a negative comparison.
- The 30-day insights engine's behaviour and `test/fixtures/insights/vectors.json` stay unchanged.
- No core change, no privacy-policy change, no version bump.
- PR targets `develop`; never merge or arm auto-merge; stop at `gh pr create`.

## Review Focus

1. **Entries late in the evening and the DST week.** An entry stored `2026-10-25T23:30:00Z` belongs to 25 Oct whatever the device zone; the week of 19 Oct 2026 (summer time ends Sun 25 Oct) has seven days. Test in PRA1 (`wall-clock day and DST week`).
2. **A week with one or two gut-feeling entries.** Counts are shown, no mean, the bar slot is the hollow marker and reads „zu wenig Einträge". Tests in PRA1 (`means need 3 entries on 2 days`) and PRA4 (`missing week is a marker, not a bar`).
3. **A user who logs only meals and Klo, no Bauchgefühl.** Not the empty state: days show the „ohne Bauchgefühl" dot, weeks say „Kein Bauchgefühl eingetragen", the trend shows its line. Test in PRA3 (`active days without gut feeling`).
4. **Ingredient names inside other words and recipe articles.** Muster item „Reis" does not match „Reiswaffelbällchen"; „Hafermilch" is no Laktose hit; a Muster signal never picks a „Rezepte" article. Tests in PRA5 (`literal names are whole words`, `group prefixes start a word`, `muster signals skip recipes`).
5. **Two accounts on one device, and an account switch.** One user's opened list never hides another's picks; the progress page never shows the previous user's weeks. Tests in PRA2 (`user change reloads`) and PRA5 (`opened list is per user`).

---

### Task PRA1: Shared day class and the pure progress engine

**Files:**
- Create: `lib/services/insights/day_class.dart`, `lib/models/progress.dart`, `lib/models/progress_rules.dart`, `lib/services/progress/progress_engine.dart`
- Modify: `lib/services/insights/insights_engine.dart` (use `dayClassOf` / `entryClassOf`, delete the private copies)
- Test: `test/services/progress/progress_engine_test.dart` (existing `test/services/insights/*` must stay green unchanged)

**Interfaces — Produces:**

```dart
// day_class.dart — moved verbatim from insights_engine.dart (_dayClassOf, _entryClassOf, _classOf)
DayClass dayClassOf(List<GutFeelingEntry> entries);   // entries non-empty
DayClass entryClassOf(GutFeelingEntry entry);

// progress_rules.dart
abstract final class ProgressRules {
  static const weeks = 12;
  static const minEntriesForMeans = 3;
  static const minDaysForMeans = 2;
  static const minTrendWeeks = 2;
  static const recentDays = 7;
  static const recentMinEntries = 3;
  static const recentHigh = 3.0;      // symptom / stress mean that counts as „öfter"
  static const kloMin = 2;            // hard (stool_type 1–2) or loose (4–5) entries
  static const minRatedForComparison = 3;
}

// progress.dart (plain immutable classes with == / hashCode like insights.dart)
class ProgressSource { List<GutFeelingEntry> gutFeelings; List<({DateTime trackedAt, int stoolType})> toilets; List<DateTime> otherTimes; } // meals + drinks
class SymptomMeans { double bloating, gas, cramps, fullness; }
class ProgressDay { DateTime day; DayClass dayClass; bool active; bool future; }
class ProgressWeek {
  DateTime monday; List<ProgressDay> days;             // always 7
  int good, medium, hard, activeDays, elapsedDays, gutFeelingEntries;
  SymptomMeans? means;                                  // null below the minimums
  int get rated => good + medium + hard;
}
class RecentSignals { SymptomMeans? means; double? stress; int klo, kloHard, kloLoose; }
class Progress {
  List<ProgressWeek> weeks;                             // 12, oldest first; last = current week
  int good, medium, hard, activeDays, elapsedDays, longestStreak;
  RecentSignals recent;
  bool get isEmpty => activeDays == 0;
  bool get showTrend;                                   // weeks with means >= minTrendWeeks
  bool get moreGoodDaysLastWeek;                        // weeks[10].good > weeks[9].good, both rated >= minRatedForComparison
}

// progress_engine.dart — pure
Progress computeProgress(ProgressSource source, {required DateTime now, Set<DateTime> savedDays = const {}});
```

- [ ] **Step 1: Write the failing tests** (`now` = Thu 2026-11-26 10:00; fixtures built with helpers):

```dart
test('window is 12 Monday weeks ending this week') // weeks.first.monday == DateTime(2026, 9, 7); weeks.last.monday == DateTime(2026, 11, 23); Fri–Sun of the last week future; last week elapsedDays == 4
test('day class equals the Muster') // entries scoring 2 and 3 on one day → good (mean 2.5); 3 and 4 → medium; for each vector day of vectors.json in the window: dayClassOf == the vector's class
test('wall-clock day and DST week') // entry trackedAt DateTime.utc(2026, 10, 25, 23, 30) counts on 25 Oct; week of 19 Oct has 7 ProgressDays with distinct dates
test('activeDays counts any table') // a meal-only day: active true, dayClass none
test('means need 3 entries on 2 days') // 3 entries on one day → means null; 2+1 on two days → means.bloating == exact mean
test('totals and elapsed days') // elapsedDays == 81 (11·7 + 4); good/medium/hard sum the weeks
test('longest streak counts saved days and spans weeks') // active Sun 15 Nov, saved Mon 16, active Tue 17 → 3
test('moreGoodDaysLastWeek only with 3 rated days in both weeks')
test('recent: last 7 days only; symptom means need 3 entries; klo counts hard 1–2 and loose 4–5')
test('empty source') // isEmpty, 12 weeks, every past day none/inactive, showTrend false
```

- [ ] **Step 2: Run** `flutter test test/services/progress test/services/insights` — expected: progress tests FAIL (files missing), insights PASS.
- [ ] **Step 3: Implement.** Move the three helpers into `day_class.dart` unchanged and import them in the insights engine. `computeProgress` uses `startOfDay(now.toLocal())` for today (an instant), `startOfDay(trackedAt)` for entries, `addDays` for every step.
- [ ] **Step 4: Run** the same tests and the vocabulary test — expected: PASS.
- [ ] **Step 5: Commit** `refactor(insights): share the day class` then `feat(progress): pure 12-week progress engine`.

### Task PRA2: Progress source and provider

**Files:**
- Modify: `lib/services/entry_query_service.dart`, `lib/repositories/entry_repository.dart`
- Create: `lib/providers/progress_provider.dart`
- Test: `test/providers/progress_provider_test.dart`, extend the query-service test that covers `fetchInsightSource`

**Interfaces — Consumes:** `ProgressSource`, `computeProgress`, `ProgressRules` (PRA1). **Produces:**

```dart
// entry_query_service.dart — four _fetchPaged calls in parallel since `since`:
// gut_feeling_entries '*', toilet_entries 'tracked_at, stool_type', meal_entries 'tracked_at', drink_entries 'tracked_at'
Future<ProgressSource> fetchProgressSource({required String userId, required DateTime since});
// entry_repository.dart
Future<ProgressSource> fetchProgressSource({required String userId, required DateTime now}); // since = Monday of now's week − 11 weeks
// progress_provider.dart
class ProgressNotifier extends AsyncNotifier<Progress?> { Future<void> refresh(); } // null while signed out
final progressProvider = AsyncNotifierProvider<ProgressNotifier, Progress?>(ProgressNotifier.new, retry: noRetry);
```

`build` watches `currentUserIdProvider`, `entriesRevisionProvider`, `todayProvider`; reads `buddyClockProvider` for now and `buddyProvider.future`'s `state.savedDays` (empty when null or failing). Errors logged as „Loading the progress failed" (no data in the message).

- [ ] **Step 1: Write the failing tests** (fake repository):

```dart
test('signed out → null, no fetch')
test('computes from the fetched source with the buddy saved days')
test('since is the Monday 11 weeks before this week') // now Thu 26 Nov 2026 → since DateTime(2026, 9, 7)
test('an entry write recomputes') // bump entriesRevisionProvider → second fetch, new value
test('user change reloads') // switch user → fetch for user B; value never holds A's progress as AsyncData for B
test('a failing fetch is an error; refresh after it succeeds')
test('query service: four tables, wall-clock since, stool_type mapped') // existing fake-client style
```

- [ ] **Step 2: Run** `flutter test test/providers/progress_provider_test.dart` — FAIL.
- [ ] **Step 3: Implement** following `insightsProvider` / `fetchInsightSource` patterns.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(progress): fetch the 12-week source and expose progressProvider`.

### Task PRA3: „Dein Verlauf" page, route and entries

**Files:**
- Create: `lib/screens/progress/progress_screen.dart`, `lib/screens/progress/widgets/progress_weeks.dart`, `lib/screens/progress/widgets/progress_summary.dart`, `lib/services/progress/progress_copy.dart`
- Modify: `lib/router/route_names.dart`, `lib/router/app_router.dart`, `lib/screens/me/me_screen.dart`, `lib/screens/patterns/patterns_screen.dart`, `lib/screens/patterns/widgets/insight_calendar.dart` (make the legend public as `DayClassLegend({bool withNoGutFeeling = false})`), `lib/config/constants.dart` (cell sizes)
- Test: `test/services/progress/progress_copy_test.dart`, `test/screens/progress/progress_screen_test.dart`, extend `test/screens/me/me_screen_test.dart` and `test/screens/patterns/patterns_screen_test.dart`

**Interfaces — Consumes:** `progressProvider`, `Progress*` (PRA1–2), `buddyProvider` (`streak`), `dayClassLook`, `InsightCopy.dayClassLabel/footer/dayDefinitions`. **Produces:** `RouteNames.progress = 'progress'`, `RoutePaths.progress = '/progress'`, `MeScreen.progressKey`, `ProgressScreen` (with `ProgressScreen.emptyKey`, `ProgressScreen.weekKey(DateTime monday)`), and `ProgressCopy`:

```dart
abstract final class ProgressCopy {
  static const title = 'Dein Verlauf';
  static const meSubtitle = 'Wie es dir über die Wochen geht';
  static const patternsLink = 'Deinen Verlauf über 12 Wochen ansehen ›';
  static const header = 'Die letzten 12 Wochen';
  static String classTotal(DayClass c, int n); // „34 gute Tage", „1 guter Tag", „12 mittlere", „1 mittlerer", „6 schwere", „1 schwerer"
  static const moreGoodDays = 'Letzte Woche hattest du mehr gute Tage als die Woche davor.';
  static const currentStreak = 'Aktueller Streak';
  static const longestStreak = 'Längster Streak';
  static const longestSub = 'in den letzten 12 Wochen';
  static String streakDays(int n); // 0 → „Startet mit deinem nächsten Eintrag", 1 → „1 Tag", n → „$n Tage"
  static String loggedTotal(int active, int elapsed); // „Eingetragen an 61 von 84 Tagen"
  static String weekLabel(DateTime monday, DateTime today); // „Diese Woche", „17.–23. Nov", „27. Okt – 2. Nov"
  static String weekCounts(ProgressWeek w); // „5 gute Tage, 1 schwerer", „1 guter Tag, 2 mittlere", „Kein Bauchgefühl eingetragen"
  static String weekLogged(ProgressWeek w); // „ · an 6 von 7 Tagen eingetragen"; current week on day 1: „ · heute eingetragen" / „ · heute noch nichts eingetragen"
  static String daySemantics(ProgressDay d); // „18. Nov: gut", „18. Nov: eingetragen, ohne Bauchgefühl", „18. Nov: kein Eintrag"
  static const noGutFeelingLegend = 'ohne Bauchgefühl';
  static const emptyTitle = 'Dein Verlauf füllt sich bald';
  static const emptyBody = 'Trag dein Bauchgefühl ein – dann siehst du hier Woche für Woche, wie es dir geht.';
  static const emptyAction = 'Bauchgefühl eintragen';
  static const loadError = 'Dein Verlauf konnte nicht geladen werden.';
  static const retry = 'Nochmal versuchen';
}
```

- [ ] **Step 1: Write the failing tests:**

```dart
// progress_copy_test.dart: every example string above, exactly; weekCounts leaves zero classes out and keeps the order good, medium, hard
// progress_screen_test.dart (overridden providers)
testWidgets('no entries: empty state, button opens the gut-feeling tracker') // find.byKey(ProgressScreen.emptyKey); tap 'Bauchgefühl eintragen' → location RoutePaths.gutFeelingTracker
testWidgets('12 week rows, newest first, labelled') // first row 'Diese Woche', second '16.–22. Nov'
testWidgets('active days without gut feeling') // meal-only weeks: not empty state; 'Kein Bauchgefühl eingetragen'; cell semantics '24. Nov: eingetragen, ohne Bauchgefühl'
testWidgets('totals, streaks and the positive line') // '34 gute Tage'; current from BuddyStatus.streak = 5 → '5 Tage'; longest = max(progress 3, streak 5) → '5 Tage'; moreGoodDays shown only when the getter is true
testWidgets('error shows retry, retry calls refresh')
testWidgets('future days have no cell semantics')
// me_screen_test: 'Dein Verlauf' row after 'Streak & Ziel' pushes RoutePaths.progress
// patterns_screen_test: the link shows locked and unlocked and pushes RoutePaths.progress
```

- [ ] **Step 2: Run** the four test files — FAIL.
- [ ] **Step 3: Implement.** Page layout and cell looks per spec §4.1 items 1–6 and 8 (the trend section is a placeholder `SizedBox.shrink()` until PRA4). Pull to refresh → `progressProvider.notifier.refresh`. Without a page below, back → `RoutePaths.me`. Not wrapped in any Plus gate.
- [ ] **Step 4: Run** the tests, `test/utils/vocabulary_test.dart` and the gates — PASS.
- [ ] **Step 5: Commit** `feat(progress): Dein Verlauf page with weeks, counts and streaks`.

### Task PRA4: Symptom trend bars

**Files:**
- Create: `lib/screens/progress/widgets/symptom_trend.dart`
- Modify: `lib/screens/progress/progress_screen.dart`, `lib/services/progress/progress_copy.dart`, `lib/config/app_theme.dart` (`static const Color progressTrendBar = primary;`), `lib/config/constants.dart` (bar row height, bar gap, marker size)
- Test: `test/screens/progress/symptom_trend_test.dart`, extend `progress_copy_test.dart`

**Interfaces — Consumes:** `Progress.weeks`, `Progress.showTrend`, `AppConstants.gutFeelingSymptoms`. **Produces:**

```dart
class SymptomTrend extends StatelessWidget { const SymptomTrend({super.key, required this.weeks}); } // one row per symptom, CustomPainter bars
// ProgressCopy additions
static const trendTitle = 'Beschwerden pro Woche';
static const trendCaption = 'Im Schnitt pro Woche, 1 = gar nicht, 5 = sehr stark. Niedrige Balken heißen weniger Beschwerden. ○ = zu wenig Einträge.';
static const trendTooFew = 'Wie sich deine Beschwerden entwickeln, zeige ich dir, sobald zwei Wochen genug Bauchgefühl-Einträge haben (mindestens 3 pro Woche).';
static String trendSemantics(String symptom, List<ProgressWeek> weeks); // „Blähbauch: diese Woche im Schnitt 2,3 von 5; vor 12 Wochen 3,1"
```

`trendSemantics`: newest week with means („diese Woche" / „letzte Woche" / „vor N Wochen"), then the oldest week with means if different; one decimal with a comma.

- [ ] **Step 1: Write the failing tests:**

```dart
test('trendSemantics names newest and oldest week with means, German comma') // 'Blähbauch: diese Woche im Schnitt 2,3 von 5; vor 12 Wochen 3,1'
test('trendSemantics with only last week and week 5 ago') // 'Krämpfe: letzte Woche im Schnitt 1,0 von 5; vor 5 Wochen 2,5'
testWidgets('four rows with the tracker labels') // Blähbauch, Blähungen, Krämpfe, Völlegefühl
testWidgets('missing week is a marker, not a bar') // painter receives null for that week; semantics of a row with one mean only: no 'vor' part
testWidgets('page shows trendTooFew below minTrendWeeks, the chart from 2 weeks')
```

- [ ] **Step 2: Run** — FAIL. **Step 3: Implement** (bar height ∝ (mean − 1) / 4 above a minimum stub so 1,0 stays visible). **Step 4: Run** tests + gates — PASS.
- [ ] **Step 5: Commit** `feat(progress): weekly symptom trend bars`.

### Task PRA5: Teaser, opened articles and the scorer

**Files:**
- Modify: `lib/models/knowledge_article.dart` (`String? teaser`), `lib/services/knowledge/knowledge_feed_parser.dart` (read `<description>` with `_text`), `lib/config/constants.dart` (`keyKnowledgeOpenedPrefix = 'knowledge_opened_'`, `knowledgeOpenedMax = 50`)
- Create: `lib/services/knowledge/knowledge_keywords.dart`, `lib/services/knowledge/knowledge_matcher.dart`, `lib/providers/knowledge_opened_provider.dart`
- Test: extend `test/models/knowledge_article_test.dart`, `test/services/knowledge/knowledge_feed_parser_test.dart`; create `test/services/knowledge/knowledge_keywords_test.dart`, `test/services/knowledge/knowledge_matcher_test.dart`, `test/providers/knowledge_opened_provider_test.dart`

**Interfaces — Produces:**

```dart
// knowledge_keywords.dart — the three maps of spec §4.2, verbatim, lower case
abstract final class KnowledgeKeywords {
  static const Map<String, List<String>> intolerances;     // profile value → keywords
  static const Map<String, List<String>> symptoms;         // symptom / 'Stress' → keywords
  static const Map<String, List<String>> ingredientGroups; // intolerance key → ingredient word prefixes
  static const recipeCategory = 'Rezepte';
  static bool matchesAtWordStart(String text, String keyword); // case-insensitive, Unicode letters
  static bool matchesWholeWord(String text, String word);
  static String? groupOf(String ingredientName);              // first group whose prefix starts a word of the name
}

// knowledge_matcher.dart — pure
enum SignalKind { patternLiteral, patternGroup, recentSymptom, recentStress, kloHard, kloLoose, intolerance, profileSymptom }
class ForYouSignal { SignalKind kind; List<String> keywords; int weight; String reason; bool wholeWord; }
class ForYouPick { KnowledgeArticle article; String reason; int score; }
List<ForYouSignal> forYouSignals({UserProfile? profile, Insights? insights, RecentSignals? recent, required bool includePatterns});
List<ForYouPick> pickForYou(List<KnowledgeArticle> articles, List<ForYouSignal> signals, {required Set<String> opened}); // ≤ 3
// weights 5, 4, 4, 4, 4, 4, 3, 2; reasons exactly as in spec §4.2

// knowledge_opened_provider.dart
class KnowledgeOpenedNotifier extends AsyncNotifier<Set<String>> { Future<void> markOpened(Uri link); }
final knowledgeOpenedProvider = AsyncNotifierProvider<KnowledgeOpenedNotifier, Set<String>>(KnowledgeOpenedNotifier.new);
```

- [ ] **Step 1: Write the failing tests:**

```dart
// parser / model
test('reads the teaser from description, entities decoded, empty → null')
test('a cached feed without teaser still reads') // fromJson of the current v1 shape → teaser null
// keywords
test('every intoleranceOptions value has keywords; every symptom of the spec map has keywords; a kSymptomOptions value outside the map gives no signal')
test('no disease names in any keyword') // none contains 'sibo', 'leaky', 'zöliakie'
test('word start: "verstopf" matches "Reizdarm Typ: Verstopfung", "Blähung" matches "Unangenehme Blähungen"; "stress" does not match "Distress"')
test('group prefixes start a word') // groupOf('Milch') == 'Laktose'; groupOf('Hafermilch') == null; groupOf('Vollkornbrot') == null; groupOf('Brot, hell') == 'Gluten'
// matcher
test('literal names are whole words') // noticed 'Reis' does not match 'Reiswaffelbällchen …'; 'Zwiebel' matches teaser '… mit Zwiebel und …'
test('muster signals skip recipes') // a 'Rezepte' article containing 'Zwiebel' is not picked for the Zwiebel item; a Laktose intolerance still picks a laktosefrei recipe
test('uncertain and locked insights give no pattern signal; includePatterns false gives none')
test('recent signals follow the thresholds') // bloating mean 3.0 with 3 entries → signal; 2.9 → none; 2 entries → none; kloHard 2 of 4 → signal, 2 of 5 → none
test('score sums distinct signals; reason from the heaviest; ties by table order')
test('order: score, then newest, then link; at most 3; opened links excluded')
test('no signal or no match → empty list')
test('reason strings') // 'Weil Zwiebel bei dir auffällt', 'Weil du diese Woche öfter Blähbauch eingetragen hast', 'Weil du diese Woche öfter gestresst warst', 'Weil es beim Klo diese Woche öfter hart war', 'Weil es beim Klo diese Woche öfter weich war', 'Weil du Laktose angegeben hast', 'Weil du Verstopfung angegeben hast'
// opened
test('markOpened stores newest last, keeps 50, survives a rebuild')
test('opened list is per user') // user A's link absent for user B; signed out → empty
```

- [ ] **Step 2: Run** the five test files — FAIL.
- [ ] **Step 3: Implement.** Profile symptoms are read through the existing legacy-aware mapping of `kSymptomOptions`. Muster items: `insights.unlocked`, `noticed.where((n) => !n.uncertain).take(3)`.
- [ ] **Step 4: Run** tests + vocabulary test + gates — PASS.
- [ ] **Step 5: Commit** `feat(knowledge): teaser, opened articles and the „Für dich" scorer`.

### Task PRA6: „Für dich" in Entdecken and Wissen

**Files:**
- Create: `lib/providers/for_you_provider.dart`
- Modify: `lib/screens/discover/widgets/discover_knowledge_section.dart`, `lib/screens/discover/widgets/knowledge_article_tile.dart` (optional `reason`), `lib/screens/discover/knowledge_screen.dart`, `lib/screens/discover/discover_screen.dart` (tap → `markOpened` then `openArticle`)
- Test: `test/providers/for_you_provider_test.dart`, extend `test/screens/discover/discover_screen_test.dart`, `test/screens/discover/knowledge_screen_test.dart`

**Interfaces — Consumes:** `forYouSignals`, `pickForYou`, `knowledgeOpenedProvider` (PRA5), `progressProvider` (`recent`, PRA2), `insightsProvider`, `profileProvider`, `knowledgeFeedProvider`. **Produces:**

```dart
/// Empty until the feed and the profile have values; insights and progress optional.
/// Subscription seam: includePatterns becomes „Plus access open" in the subscription track.
final forYouProvider = Provider<List<ForYouPick>>(...);   // includePatterns: true
// KnowledgeArticleTile gains `String? reason`: shown instead of the meta line; semantics „{title}, {reason}"
static const forYouTitle = 'Für dich';
static const forYouCaption = 'Ausgewählt nach deinen Einträgen und Angaben.';
static const allArticlesTitle = 'Alle Artikel';
```

- [ ] **Step 1: Write the failing tests:**

```dart
test('empty while the feed or the profile is loading')
test('uses recent signals once progress has a value; works without it')
testWidgets('Entdecken: picks first with reason, filled to 3 with the newest') // one pick → tiles [pick (reason line), newest, second newest], pick not repeated
testWidgets('Entdecken: no pick → newest 3 with meta lines, as before')
testWidgets('Wissen: Für dich block above the list under Alle, picks not repeated in Alle Artikel')
testWidgets('Wissen: another chip hides Für dich')
testWidgets('tapping a pick marks it opened and opens it; it leaves Für dich')
```

- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** tests + gates — PASS.
- [ ] **Step 5: Commit** `feat(knowledge): show „Für dich" in Entdecken and Wissen`.

### Task PRA7: Gates and PR

- [ ] **Step 1:** `dart format --set-exit-if-changed . && flutter analyze` — zero issues.
- [ ] **Step 2:** `flutter test` (whole suite; includes `test/utils/vocabulary_test.dart` and the insight vectors) — all pass.
- [ ] **Step 3:** Owner's routine: /simplify → /code-review → fix findings, each fix its own `fix:`/`refactor:` commit (`--no-verify` after the gates).
- [ ] **Step 4:** Open the PR after the routine: `gh pr create --base develop --head feat/progress-knowledge --title "feat: Dein Verlauf and Wissen „Für dich“"`, body: summary, the spec link, the manual checks of spec §9, ending with the attribution line. Do not merge, do not arm auto-merge.
