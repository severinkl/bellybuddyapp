# Akuthilfe („Ruhe für den Bauch") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Six bundled, text-guided calming exercises with a step timer and breathing pacer, reachable from the Bauchgefühl success page and Entdecken, behind a remote switch and a content-review guard, always free.

**Architecture:** One content file holds every exercise and every string of the feature. A gate provider combines the remote `app_config` switch, the content's `reviewed` flags and a preview flag. A Riverpod `Notifier` family runs the player as a wall-clock state machine; the screens render it. The „Hat's geholfen?" answer is a per-user shared-preferences map that orders the list. No server change.

**Tech Stack:** Flutter, Riverpod 3, GoRouter, shared_preferences, url_launcher (`tel:`), `wakelock_plus` (new: keeps the screen on during an exercise; nothing in the app does that today), fake_async in tests.

**Spec:** `docs/superpowers/specs/2026-11-27-akuthilfe-design.md` (branch `docs/plan-akuthilfe`).

## Repos and commands

| Repo | Where | Branch | Commands |
|---|---|---|---|
| App `bellybuddyapp` | new worktree `~/projects/bellybuddy/.worktrees/akuthilfe` | `feat/akuthilfe` from `origin/develop` @ 22a9a2b | tests `flutter test <path>`; gates `dart format --set-exit-if-changed . && flutter analyze` (zero issues) |
| Core | — | — | no change (spec decision 4) |

- The app's pre-commit hook fails inside git worktrees: run the gates by hand before each commit, commit with `--no-verify`.
- No simulator or emulator on the dev box: device behaviour is in the spec's „Manual checks for Severin".
- Copy the spec into the feature branch in Task HA1 (`docs/superpowers/specs/2026-11-27-akuthilfe-design.md`) so the PR carries it.

## Global Constraints

- German UI, „du"; the mascot is „Belly Buddy"/„Buddy".
- Colours only `static const Color` in `AppTheme`; font sizes only `AppTheme.fontSize*`; spacing/radii/durations only from `AppConstants` (add new values there first).
- Riverpod (`Notifier`/`AsyncNotifier`); GoRouter paths in `lib/router/route_names.dart`; `AppLogger`, never `print()`.
- Vocabulary test rules apply; this plan adds „Therapie", „Behandlung", „heilt/heilen/Heilung", „Diagnose" to the ban list. No wording that promises an effect („kann helfen", „vielen tut … gut").
- Every user-facing string of the feature lives in `lib/services/relief/relief_content.dart` (Susi's one file). Widgets reference `ReliefCopy.*`.
- The feature is invisible unless `reliefEnabledProvider` is true. Nothing in it is ever behind `paywall_enabled`.
- `tracked_at` is wall clock: compare `entry.trackedAt` with `DateTime.now()` directly, never `toLocal()`/`toUtc()`.
- Nothing stored on the server; no health data, exercise ids or answers in log lines or Sentry.
- Conventional commits; PR to `develop`; never merge or auto-merge; stop at `gh pr create`.

## Review Focus

1. **A back-dated Bauchgefühl entry with Krämpfe 5** (logged for yesterday evening). No offer on the success page. Test in HA6 (`offersRelief` with `trackedAt = now − 3 h` → false) and HA6's widget test.
2. **The app goes to the background mid-exercise, and comes back 20 minutes later.** A breathing step is paused at the second it left; the warmth quiet step has advanced (or finished) by wall clock and never shows negative time. Tests in HA3.
3. **Severin flips `akuthilfe_enabled` before Susi's review commit.** Nothing appears for users; one warning is logged. Test in HA2.
4. **Corrupt or foreign data in the feedback preference** (not JSON, unknown exercise id, unknown answer). The list falls back to content order and does not crash. Test in HA2.
5. **Largest text size on the success page with the extra pill, and in the player.** No overflow; controls stay reachable. Tests in HA4 and HA6 (`expectSuccessPageFits` / overflow collection at `textScaler: TextScaler.linear(2)`).

---

### Task HA1: Content file, model and vocabulary guard

**Files:**
- Create: `lib/services/relief/relief_content.dart`, `docs/superpowers/specs/2026-11-27-akuthilfe-design.md` (copy)
- Modify: `test/utils/vocabulary_test.dart` (four new patterns)
- Test: `test/services/relief/relief_content_test.dart`

**Interfaces — Produces:**

```dart
enum BreathPhase { inhale, holdIn, exhale, holdOut }

class BreathPattern {
  const BreathPattern({required this.inhale, this.holdIn = 0, required this.exhale, this.holdOut = 0});
  final int inhale, holdIn, exhale, holdOut;            // seconds
  int get cycleSeconds;
  BreathPhase phaseAt(int secondInStep);                 // phases with 0 s are skipped
  int secondsLeftInPhase(int secondInStep);              // >= 1
}

class ReliefStep {
  const ReliefStep({required this.text, required this.seconds, this.breath, this.quiet = false});
  final String text; final int seconds; final BreathPattern? breath; final bool quiet;
}

class ReliefExercise {
  const ReliefExercise({required this.id, required this.title, required this.subtitle,
      required this.steps, this.caution, this.reviewed = false});
  final String id, title, subtitle; final String? caution; final List<ReliefStep> steps; final bool reviewed;
  int get totalSeconds;
  int get minutes;                                       // (totalSeconds / 60).round()
}

const List<ReliefExercise> reliefExercises;              // spec §5, in this order:
// bauchatmung, box_atmung, muskelentspannung, bauchmassage, waerme, gedanken
ReliefExercise? reliefExerciseById(String id);

String breathPhaseLabel(BreathPhase p);                  // Einatmen / Halten / Ausatmen / Halten

class ReliefCopy {                                       // every other string of the feature, verbatim from the spec
  static const title = 'Ruhe für den Bauch';
  static const cardSubtitle = 'Atmen, entspannen, Wärme – für den Moment';
  static const listIntro = 'Ich bin da. Such dir aus, was dir gerade guttut.';
  static const gutFeelingOffer = 'Brauchst du gerade etwas Ruhe für deinen Bauch?';
  static const helpedLabel = 'Hat dir geholfen';
  static const draftMarker = 'Entwurf: noch nicht fachlich geprüft';
  static const start = 'Starten', pause = 'Pause', resume = 'Fortsetzen', back = 'Zurück', next = 'Weiter';
  static String stepOf(int n, int total);                // 'Schritt $n von $total'
  static String minutesLabel(int m);                     // '$m Min.'
  static const doneLine = 'Schön, dass du dir die Zeit genommen hast.';
  static const helpedQuestion = "Hat's geholfen?";
  static const answerYes = 'Ja', answerLittle = 'Ein bisschen', answerNo = 'Nein', done = 'Fertig';
  static const thanks = 'Danke! Ich merk mir das.';
  static const thanksNo = 'Danke, dass du es mir sagst. Probier gern eine andere Übung – und hol dir Hilfe, wenn es nicht besser wird.';
  static const safetyLine = 'Das ersetzt keine ärztliche Hilfe. Bei starken Beschwerden: Notruf 144 (AT, CH) oder 112.';
  static const safetySheetTitle = 'Wann du Hilfe holen solltest';
  // + the sheet's intro, two headed lists, number rows (spec §4.5), and
  static String dialFailed(String number);               // 'Wähl bitte direkt $number.'
}
```

- [ ] **Step 1: Write the failing tests** in `relief_content_test.dart`:
  - `six exercises with unique ids in spec order` → ids equal the list above.
  - `durations match the spec` → `totalSeconds` equals `[180, 180, 220, 240, 690, 180]`.
  - `every breathing step is whole cycles` → for each step with `breath`, `seconds % breath.cycleSeconds == 0`; Bauchatmung's pattern is `4/0/6/0`, Box-Atmung's `4/4/4/4`.
  - `only the warmth timer is quiet` → exactly one quiet step, `waerme` step 4, `seconds == 600`.
  - `massage and warmth and both breathing exercises carry a caution`; `gedanken` has none.
  - `nothing is reviewed yet` → `reliefExercises.every((e) => !e.reviewed)` (Susi's sign-off commit flips this test with the flags).
  - `phaseAt walks the box` → pattern 4/4/4/4: seconds 0..3 inhale, 4..7 holdIn, 8..11 exhale, 12..15 holdOut, 16 inhale; `secondsLeftInPhase(0) == 4`, `(3) == 1`.
  - `phaseAt skips empty holds` → 4/0/6/0: second 4 is exhale, 9 exhale, 10 inhale.
  - `no promise words` → no step text, caution or `ReliefCopy` string matches `RegExp(r'\b(wirkt|garantiert|sofort besser)\b')`.
  - In `vocabulary_test.dart`: add `RegExp(r'Therapie')`, `RegExp(r'Behandlung')`, `RegExp(r'\b[Hh]eil(t|en|ung)\b')`, `RegExp(r'Diagnose')` to `banned`, plus a scan test: `offendersIn(["final a = 'Das heilt deinen Bauch';", "final b = 'Keine Behandlung';"])` has two offenders.
- [ ] **Step 2: Run** `flutter test test/services/relief/relief_content_test.dart test/utils/vocabulary_test.dart` — expected FAIL (file missing).
- [ ] **Step 3: Implement** `relief_content.dart` with the spec §5 texts and §4.5 strings verbatim; every exercise `reviewed: false`.
- [ ] **Step 4: Run** the same tests — expected PASS (including the whole-`lib` vocabulary scan).
- [ ] **Step 5: Commit** `feat(relief): exercise content and model for Ruhe für den Bauch (unreviewed)` (with the spec copy).

### Task HA2: Remote switch, gate and feedback store

**Files:**
- Modify: `lib/models/app_config.dart` (`final bool akuthilfeEnabled;`, default `false`), `lib/repositories/app_config_repository.dart` (also select `akuthilfe_enabled`; only `'true'` → true; missing → false), `lib/config/constants.dart` (`static const String keyReliefFeedbackPrefix = 'relief_feedback_';`)
- Create: `lib/providers/relief_provider.dart`, `lib/services/relief/relief_rules.dart`
- Test: `test/repositories/app_config_repository_test.dart`, `test/providers/relief_provider_test.dart`, `test/services/relief/relief_rules_test.dart`

**Interfaces — Consumes:** HA1's `reliefExercises`, `ReliefExercise`. **Produces:**

```dart
// relief_rules.dart (pure)
enum ReliefAnswer { yes, little, no }                         // stored as 'yes' | 'little' | 'no'
List<ReliefExercise> orderedExercises(List<ReliefExercise> all, Map<String, ReliefAnswer> answers);
      // yes first; then little and unanswered in content order; then no. Stable.
Map<String, ReliefAnswer> parseReliefAnswers(String? json);   // invalid → {} ; unknown ids/answers dropped
bool offersRelief(GutFeelingEntry entry, {required DateTime now});   // used in HA6
      // any of bloating/gas/cramps/fullness >= 4 AND !trackedAt.isBefore(now - 2h) AND !trackedAt.isAfter(now + 5min)

// relief_provider.dart
final reliefContentProvider = Provider<List<ReliefExercise>>((_) => reliefExercises);   // tests override
final reliefPreviewProvider = Provider<bool>((_) => kDebugMode || const bool.fromEnvironment('RELIEF_PREVIEW'));
final reliefEnabledProvider = Provider<bool>(...);           // preview || (appConfig.value?.akuthilfeEnabled == true && reliefContentProvider all reviewed)
final reliefReviewMarkersProvider = Provider<bool>(...);     // == reliefPreviewProvider
final reliefFeedbackProvider = AsyncNotifierProvider<ReliefFeedbackNotifier, Map<String, ReliefAnswer>>(...);
class ReliefFeedbackNotifier extends AsyncNotifier<Map<String, ReliefAnswer>> {
  Future<void> record(String exerciseId, ReliefAnswer answer);   // writes relief_feedback_<userId>; no user → no-op
}
final orderedReliefExercisesProvider = Provider<List<ReliefExercise>>(...);   // content order while loading/error
```

- [ ] **Step 1: Write the failing tests:**
  - Repository: `akuthilfe_enabled 'true' → true`; `missing → false`; `'TRUE' and '1' → false`; the existing version tests still pass with the extra key.
  - Rules: `orderedExercises` with `{gedanken: yes, bauchatmung: no}` → `gedanken` first, `bauchatmung` last, rest in content order; `parseReliefAnswers('not json') == {}`; `parseReliefAnswers('{"x":"yes","waerme":"maybe","waerme2":1}') == {}`; `parseReliefAnswers('{"waerme":"little"}') == {'waerme': ReliefAnswer.little}`.
  - Gate (overrides `appConfigProvider`, `reliefPreviewProvider`): preview false + switch on + content unreviewed → `false` and one warning in the captured logs (`test/helpers/logs.dart`); preview false + switch off → false; config fetch error → false; preview true + switch off → true. switch on + `reliefContentProvider` overridden with all-reviewed copies → true.
  - Feedback: `record('waerme', ReliefAnswer.yes)` stores `{"waerme":"yes"}` under `relief_feedback_test-user` (`SharedPreferences.setMockInitialValues({})`); two users keep separate maps; no user id → nothing stored.
- [ ] **Step 2: Run** `flutter test test/repositories/app_config_repository_test.dart test/providers/relief_provider_test.dart test/services/relief/relief_rules_test.dart` — expected FAIL.
- [ ] **Step 3: Implement.** The warning text names no user data: `'akuthilfe_enabled is on but content is unreviewed; staying off'`, logged once per process.
- [ ] **Step 4: Run** the same tests — expected PASS.
- [ ] **Step 5: Commit** `feat(relief): remote switch akuthilfe_enabled with review guard, local feedback`.

### Task HA3: Player state machine

**Files:**
- Create: `lib/providers/relief_player_provider.dart`
- Test: `test/providers/relief_player_provider_test.dart`

**Interfaces — Consumes:** HA1 model, HA2 `reliefContentProvider`. **Produces:**

```dart
enum ReliefPlayerStatus { ready, running, paused, done }

class ReliefPlayerState {
  const ReliefPlayerState({required this.status, required this.stepIndex, required this.secondInStep});
  final ReliefPlayerStatus status; final int stepIndex; final int secondInStep;
  // derived (getters, need the exercise): see ReliefPlayer
}

final reliefClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final reliefPlayerProvider =
    NotifierProvider.autoDispose.family<ReliefPlayer, ReliefPlayerState, String>(ReliefPlayer.new);

class ReliefPlayer extends Notifier<ReliefPlayerState> {
  ReliefPlayer(this.exerciseId);
  final String exerciseId;
  ReliefExercise get exercise;
  ReliefStep get step;
  int get secondsLeftInStep;                // >= 0
  int get secondsDone;                      // across all steps, for the progress bar
  void start();                             // ready → running at step 0, second 0
  void pause();  void resume();
  void next();                              // last step → done
  void back();                              // previous step at second 0; on step 0 restarts it
  void appHidden();                         // running non-quiet step → paused; quiet step keeps running
  void appShown();                          // recompute from the clock
}
```

Time is wall clock: while running, `secondInStep = baseSeconds + clock().difference(resumedAt).inSeconds`; a `Timer.periodic(const Duration(seconds: 1))` only triggers the recompute. When the step's time is up, advance to the next step at second 0 (overrun is not carried); after the last step → `done`, timer cancelled. `ref.onDispose` cancels the timer.

- [ ] **Step 1: Write the failing tests** (`fakeAsync`, a mutable fake clock in `reliefClockProvider`, `ProviderContainer.test`):
  - `start runs step 1` → after 5 s: `stepIndex 0`, `secondInStep 5`.
  - `steps advance by themselves` → Bauchatmung after 20 s: `stepIndex 1`, `secondInStep 0`.
  - `pause freezes time` → pause at 7 s, advance clock 60 s, resume, +1 s → `secondInStep 8`.
  - `next on the last step finishes` → status `done`, no pending timers.
  - `back on step 0 restarts it`; `back on step 2 goes to step 1 at 0`.
  - `appHidden pauses a breathing step` → Bauchatmung step 3, hidden at 30 s, clock +20 min, `appShown` → `paused`, `secondInStep 30`.
  - `appHidden keeps the quiet step running` → Wärme step 4 at 100 s, hidden, clock +5 min, `appShown` → running, `secondInStep 400`; clock +20 min, `appShown` → `stepIndex 4`, `secondInStep 0`, `secondsLeftInStep 20` (never negative).
  - `secondsDone` → Bauchatmung at step 2 second 10 → `50`.
  - `unknown id` → `exercise` getter throws `StateError` (the screen redirects before; see HA4).
- [ ] **Step 2: Run** `flutter test test/providers/relief_player_provider_test.dart` — expected FAIL.
- [ ] **Step 3: Implement** as above.
- [ ] **Step 4: Run** — expected PASS.
- [ ] **Step 5: Commit** `feat(relief): wall-clock player for guided exercises`.

### Task HA4: Player screen, pacer, wake lock and done view

**Files:**
- Create: `lib/screens/relief/relief_player_screen.dart`, `lib/screens/relief/widgets/breath_pacer.dart`, `lib/screens/relief/widgets/relief_done_view.dart`, `lib/screens/relief/widgets/relief_safety.dart` (`ReliefSafetyLine`, `showReliefSafetySheet`), `lib/services/relief/screen_awake.dart`
- Modify: `pubspec.yaml`/`pubspec.lock` (`flutter pub add wakelock_plus`), `android/app/src/main/AndroidManifest.xml` (`<queries>`: `<intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>`), `lib/config/constants.dart` (`reliefPacerMin = 120.0`, `reliefPacerMax = 220.0`)
- Test: `test/screens/relief/relief_player_screen_test.dart`, `test/screens/relief/widgets/breath_pacer_test.dart`, `test/screens/relief/widgets/relief_safety_test.dart`

**Interfaces — Consumes:** HA3 `reliefPlayerProvider`, HA2 `reliefFeedbackProvider`, `reliefReviewMarkersProvider`. **Produces:**

```dart
abstract interface class ScreenAwake { Future<void> set(bool on); }
final screenAwakeProvider = Provider<ScreenAwake>((_) => const WakelockScreenAwake());   // WakelockPlus.toggle(enable: on)
class ReliefPlayerScreen extends ConsumerStatefulWidget { const ReliefPlayerScreen({super.key, required this.exerciseId}); }
class BreathPacer extends StatefulWidget {
  const BreathPacer({super.key, required this.pattern, required this.secondInStep, required this.running});
  static const circleKey = ValueKey('relief-pacer-circle');
}
class ReliefSafetyLine extends StatelessWidget { const ReliefSafetyLine({super.key}); }   // tap → sheet
Future<void> showReliefSafetySheet(BuildContext context, {UrlOpener open = launchUrl});
```

Behaviour per spec §4.4–4.5: ready view with caution and „Starten"; running view with „Schritt n von m", `LinearProgressIndicator(value: secondsDone / totalSeconds)`, step text, `m:ss` remaining, pacer for breathing steps, info icon (tooltip `ReliefCopy.safetySheetTitle`); controls „Zurück", „Pause"/„Fortsetzen", „Weiter"; done view. `AppLifecycleListener(onHide: appHidden, onShow: appShown)`. Screen awake on iff `running && !step.quiet`; off in `dispose`. Haptics on phase and step change while running. Announcements: step text at step change, phase word at phase change; countdown in `ExcludeSemantics`; phase container `Semantics(label: '${breathPhaseLabel(p)}, noch $n Sekunden')`.

- [ ] **Step 1: Write the failing tests:**
  - Pacer: with `MediaQuery(disableAnimations: true)` the circle's size is the same at seconds 0 and 3 (`tester.getSize(find.byKey(BreathPacer.circleKey))`), and „Einatmen" / „3" are shown; without it the size at second 3 is larger than at 0; at second 4 of 4/0/6/0 the text is „Ausatmen".
  - Player: ready shows the Bauchmassage caution and „Starten"; after „Starten" shows „Schritt 1 von 6"; „Pause" → „Fortsetzen"; „Weiter" on the last step → `ReliefCopy.doneLine`.
  - Screen awake (fake `ScreenAwake` recording calls): `[true]` after start of Bauchatmung; `false` after pause; Wärme at its quiet step → last call `false`; leaving the screen → last call `false`.
  - Announcements: with `tester.binding.defaultBinaryMessenger` capturing `SystemChannels.accessibility` (or the pinned Flutter's announce API), advancing Bauchatmung from step 1 to 2 announces step 2's text once; ten seconds inside the breathing step announce only phase words, never digits.
  - Done: tapping „Nein" calls `record(id, ReliefAnswer.no)` and shows `ReliefCopy.thanksNo` and the „Wann du Hilfe holen solltest" link; „Fertig" without an answer records nothing.
  - Review marker: preview true + unreviewed → `ReliefCopy.draftMarker` visible; preview false → absent.
  - Safety: the line is visible in ready and done; the sheet lists 144, 112, 1450 and 116 117; tapping „112" calls the fake opener with `Uri(scheme: 'tel', path: '112')`; an opener returning false shows „Wähl bitte direkt 112.".
  - Large text: at `TextScaler.linear(2)` on a 360×640 surface the running view of Bauchmassage step 4 has no overflow errors (`collectFlutterErrors` + `verticalOverflows`) and „Weiter" is hit-testable.
- [ ] **Step 2: Run** `flutter test test/screens/relief` — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expected PASS.
- [ ] **Step 5: Commit** `feat(relief): exercise player with breathing pacer, safety sheet and screen awake`.

### Task HA5: List screen and routes

**Files:**
- Create: `lib/screens/relief/relief_list_screen.dart`
- Modify: `lib/router/route_names.dart` (`relief = 'relief'`, `reliefExercise = 'relief-exercise'`; paths `'/relief'`, `'/relief/:id'`, `static String reliefExerciseFor(String id) => '/relief/$id';`), `lib/router/app_router.dart` (top-level `GoRoute` like `patterns`, with `redirect`: gate off → `RoutePaths.discover`; unknown id → `RoutePaths.relief`)
- Test: `test/screens/relief/relief_list_screen_test.dart`, `test/router/relief_routes_test.dart`

**Interfaces — Consumes:** HA2 `orderedReliefExercisesProvider`, `reliefFeedbackProvider`, `reliefEnabledProvider`; HA4 screens and `ReliefSafetyLine`. **Produces:** `RoutePaths.relief`, `RoutePaths.reliefExerciseFor(id)`, `ReliefListScreen`.

- [ ] **Step 1: Write the failing tests:**
  - List: shows `ReliefCopy.listIntro`, six cards with titles and „3 Min." for Bauchatmung, „12 Min." for Wärme; with feedback `{gedanken: yes}` the first card is „Gedanken beruhigen" and shows „Hat dir geholfen"; the safety line is found while the list is scrolled to the end (it sits outside the `Scrollable`: `find.descendant(of: find.byType(Scrollable), matching: find.byType(ReliefSafetyLine))` finds nothing, `find.byType(ReliefSafetyLine)` finds one).
  - Tapping a card pushes `/relief/bauchatmung`.
  - Routes: gate off → `/relief` lands on `/discover`; gate on → `/relief/unknown` lands on `/relief`.
- [ ] **Step 2: Run** `flutter test test/screens/relief/relief_list_screen_test.dart test/router/relief_routes_test.dart` — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expected PASS.
- [ ] **Step 5: Commit** `feat(relief): Ruhe für den Bauch list and routes`.

### Task HA6: Entry points — Bauchgefühl success page and Entdecken card

**Files:**
- Modify: `lib/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart` (keep the saved entry; pass `actions` when `offersRelief(entry, now: DateTime.now()) && ref.read(reliefEnabledProvider)`), `lib/screens/discover/discover_screen.dart` (first child `DiscoverReliefCard` + `AppConstants.gap24` while the gate is on; `static const reliefKey = DiscoverReliefCard.cardKey;`)
- Create: `lib/screens/discover/widgets/discover_relief_card.dart`
- Test: `test/services/relief/relief_rules_test.dart` (offersRelief), `test/screens/trackers/gut_feeling/gut_feeling_tracker_test.dart`, `test/screens/discover/discover_screen_test.dart`

**Interfaces — Consumes:** HA2 `offersRelief`, `reliefEnabledProvider`; HA5 `RoutePaths.relief`. **Produces:** `DiscoverReliefCard({super.key, required VoidCallback onOpen})`, `static const cardKey = ValueKey('discover-relief')`.

- [ ] **Step 1: Write the failing tests:**
  - `offersRelief`: Krämpfe 4, `trackedAt = now` → true; all symptoms 3 → false; Blähbauch 5 at `now − 2 h` → true; at `now − 2 h − 1 min` → false; at `now + 10 min` → false; mood values high but symptoms 1 → false.
  - Tracker (gate overridden true): save with Krämpfe 5 → success page shows `ReliefCopy.gutFeelingOffer`; tapping it navigates to `/relief` (router test host) and does not call `onDismissed`'s pop twice; save with all symptoms 2 → no offer; gate false + Krämpfe 5 → no offer; Krämpfe 5 with the date chip set to yesterday → no offer; `expectSuccessPageFits` passes with the offer at `TextScaler.linear(2)`.
  - Discover: gate true → `DiscoverScreen.reliefKey` found above `DiscoverScreen.tipsKey`/`alternativesKey` (compare `getTopLeft().dy`); tap pushes `/relief`; gate false → not found.
- [ ] **Step 2: Run** `flutter test test/services/relief/relief_rules_test.dart test/screens/trackers/gut_feeling/gut_feeling_tracker_test.dart test/screens/discover/discover_screen_test.dart` — expected FAIL.
- [ ] **Step 3: Implement.** The pill navigates with `context.pushReplacement(RoutePaths.relief)`; the pill's child is `Text(ReliefCopy.gutFeelingOffer, textAlign: TextAlign.center)`.
- [ ] **Step 4: Run** — expected PASS.
- [ ] **Step 5: Commit** `feat(relief): offer calm after a hard Bauchgefühl entry; Entdecken card`.

### Task HA7: Gates and PR

- [ ] **Step 1:** `dart format --set-exit-if-changed . && flutter analyze` — expected: no changes, „No issues found!".
- [ ] **Step 2:** `flutter test test/services/relief test/providers/relief_provider_test.dart test/providers/relief_player_provider_test.dart test/screens/relief test/router/relief_routes_test.dart test/screens/trackers/gut_feeling test/screens/discover test/repositories/app_config_repository_test.dart test/utils/vocabulary_test.dart` — expected all PASS. Then the full `flutter test` once.
- [ ] **Step 3:** Grep check: `git grep -n "paywall\|plus" -- lib/screens/relief lib/providers/relief*` — expected no hits (the feature stays free).
- [ ] **Step 4:** Commit any gate fixes (`chore(relief): gates`), `--no-verify`.
- [ ] **Step 5: Open the PR after the routine** (simplify → code review → fix findings): `gh pr create --base develop --title "feat: Ruhe für den Bauch (Akuthilfe), off until Susi's review"`; body lists the spec, the switch-on SQL (spec §2.3), the Susi review item and the manual checks; ends with the attribution line. Stop there: no merge, no auto-merge.
