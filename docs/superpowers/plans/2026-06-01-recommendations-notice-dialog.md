# Recommendations Notice Dialog + Feedback URL Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a once-per-session info dialog on the Tipps (recommendations) screen explaining the recommendations pause and linking to the feedback form, and swap the shared feedback URL to the new Mailchimp survey.

**Architecture:** A new `AlertDialog` widget following the existing `welcome_modal` / `notification_opt_in_dialog` pattern, gated by an in-memory `StateProvider<bool>` so it shows once per app session. The recommendations screen triggers it from `initState` via a post-frame callback. The feedback URL is a single shared constant, so updating it propagates to the dashboard button, settings button, and the new dialog.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), `url_launcher`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-01-recommendations-notice-dialog-design.md`

---

## File Structure

- `lib/config/constants.dart` — modify `feedbackFormUrl` value.
- `lib/providers/recommendation_provider.dart` — add `recommendationsNoticeSeenProvider` (in-memory session flag).
- `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart` — **new** dialog widget + `showRecommendationsNoticeDialog()` helper.
- `lib/screens/recommendations/recommendations_screen.dart` — trigger the dialog in `initState`.
- `test/config/feedback_url_test.dart` — **new** test asserting the URL value.
- `test/screens/recommendations/widgets/recommendations_notice_dialog_test.dart` — **new** dialog widget test.
- `test/screens/recommendations/recommendations_screen_test.dart` — modify to suppress the notice in existing tests and add a trigger test.

---

## Task 1: Swap the feedback form URL

**Files:**
- Modify: `lib/config/constants.dart:84-85`
- Test: `test/config/feedback_url_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/config/feedback_url_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/config/constants.dart';

void main() {
  test('feedbackFormUrl points at the Mailchimp survey', () {
    expect(
      AppConstants.feedbackFormUrl,
      'https://us20.list-manage.com/survey?u=526bdf1360ec4bf225504e006&id=d47032793c&attribution=false',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/feedback_url_test.dart`
Expected: FAIL — actual value is the old Google Forms URL.

- [ ] **Step 3: Update the constant**

In `lib/config/constants.dart`, replace the existing `feedbackFormUrl` (lines 84-85):

```dart
  static const String feedbackFormUrl =
      'https://us20.list-manage.com/survey?u=526bdf1360ec4bf225504e006&id=d47032793c&attribution=false';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/feedback_url_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/constants.dart test/config/feedback_url_test.dart
git commit -m "feat: point feedback form URL at new Mailchimp survey"
```

---

## Task 2: Add the once-per-session flag provider

**Files:**
- Modify: `lib/providers/recommendation_provider.dart` (append provider near the existing `recommendationProvider` declaration)
- Test: `test/providers/recommendations_notice_seen_provider_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/providers/recommendations_notice_seen_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';

void main() {
  test('recommendationsNoticeSeenProvider defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(recommendationsNoticeSeenProvider), isFalse);
  });

  test('flag can be flipped to true within a container (session)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(recommendationsNoticeSeenProvider.notifier).state = true;

    expect(container.read(recommendationsNoticeSeenProvider), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/recommendations_notice_seen_provider_test.dart`
Expected: FAIL — `recommendationsNoticeSeenProvider` is not defined.

- [ ] **Step 3: Add the provider**

In `lib/providers/recommendation_provider.dart`, directly below the existing `recommendationProvider` declaration, add:

```dart
/// Whether the "no new recommendations for now" notice has been shown during
/// this app session. In-memory only — it is never persisted, so the notice
/// reappears once per app launch (resets on cold start). Set to `true` by
/// `RecommendationsScreen` the first time the screen is opened in a session.
final recommendationsNoticeSeenProvider = StateProvider<bool>((ref) => false);
```

(`StateProvider` is exported by `flutter_riverpod`, already imported in this file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/recommendations_notice_seen_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/providers/recommendation_provider.dart test/providers/recommendations_notice_seen_provider_test.dart
git commit -m "feat: add in-memory session flag for recommendations notice"
```

---

## Task 3: Build the notice dialog

**Files:**
- Create: `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart`
- Test: `test/screens/recommendations/widgets/recommendations_notice_dialog_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/screens/recommendations/widgets/recommendations_notice_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recommendations/widgets/recommendations_notice_dialog.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

Widget _host(void Function(BuildContext) onOpenPressed) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => onOpenPressed(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showRecommendationsNoticeDialog', () {
    testWidgets('renders mascot, title, body and both actions', (tester) async {
      late Future<void> dialogFuture;
      await tester.pumpWidget(
        _host((ctx) => dialogFuture = showRecommendationsNoticeDialog(ctx)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(MascotImage), findsOneWidget);
      expect(find.text('Danke, dass du dabei bist! 💛'), findsOneWidget);
      expect(find.textContaining('vorerst keine'), findsOneWidget);
      expect(find.text('Feedback geben'), findsOneWidget);
      expect(find.text('Schließen'), findsOneWidget);

      // Clean up the open dialog so the test future completes.
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      await dialogFuture;
    });

    testWidgets('tapping Schließen dismisses the dialog', (tester) async {
      await tester.pumpWidget(_host(showRecommendationsNoticeDialog));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Danke, dass du dabei bist! 💛'), findsOneWidget);

      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();

      expect(find.text('Danke, dass du dabei bist! 💛'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/recommendations/widgets/recommendations_notice_dialog_test.dart`
Expected: FAIL — `recommendations_notice_dialog.dart` / `showRecommendationsNoticeDialog` does not exist.

- [ ] **Step 3: Create the dialog widget**

Create `lib/screens/recommendations/widgets/recommendations_notice_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/mascot_image.dart';

/// Shows the "no new recommendations for now" notice on the Tipps screen.
/// Informational only: thanks the user, explains that tester feedback is
/// currently being reviewed so there are no new recommendations for now, and
/// links to the feedback form.
///
/// Gated upstream by `recommendationsNoticeSeenProvider` (see
/// `RecommendationsScreen`) so it appears once per app session — this helper
/// does not check or write any state of its own.
Future<void> showRecommendationsNoticeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _RecommendationsNoticeDialog(),
  );
}

class _RecommendationsNoticeDialog extends StatelessWidget {
  const _RecommendationsNoticeDialog();

  Future<void> _openFeedback(BuildContext context) async {
    // Capture the navigator before the async gap — the dialog may rebuild
    // while the external browser is launching.
    final navigator = Navigator.of(context);
    await launchUrl(
      Uri.parse(AppConstants.feedbackFormUrl),
      mode: LaunchMode.externalApplication,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      contentPadding: AppConstants.paddingLg,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: AppConstants.mascotSizeMd,
            height: AppConstants.mascotSizeMd,
          ),
          AppConstants.gap16,
          const Text(
            'Danke, dass du dabei bist! 💛',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap12,
          const Text(
            'Danke, dass du Belly Buddy nutzt! Wir werten gerade das Feedback '
            'aus der bisherigen Testphase aus. Deshalb gibt es vorerst keine '
            'neuen Empfehlungen.\n\n'
            'Dein Feedback hilft uns sehr weiter – teile es gerne über unser '
            'Formular.',
            style: TextStyle(fontSize: AppTheme.fontSizeBody),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap24,
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: () => _openFeedback(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: const Text('Feedback geben'),
            ),
          ),
          AppConstants.gap8,
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Schließen',
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/recommendations/widgets/recommendations_notice_dialog_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/recommendations/widgets/recommendations_notice_dialog.dart test/screens/recommendations/widgets/recommendations_notice_dialog_test.dart
git commit -m "feat: add recommendations notice dialog widget"
```

---

## Task 4: Trigger the dialog once per session on the Tipps screen

**Files:**
- Modify: `lib/screens/recommendations/recommendations_screen.dart` (imports + `initState`)
- Modify: `test/screens/recommendations/recommendations_screen_test.dart` (suppress notice in existing tests + add trigger test)

### 4a. Suppress the notice in existing screen tests

The screen now auto-shows a modal on mount. Without suppression, the modal barrier would intercept taps/flings in the existing tests and break them. Suppress by overriding the flag to `true` (already-seen) in every override list that mounts `RecommendationsScreen`.

- [ ] **Step 1: Add the import to the test file**

In `test/screens/recommendations/recommendations_screen_test.dart`, the import for `recommendation_provider.dart` already exists (line 15). No new import needed — `recommendationsNoticeSeenProvider` lives in that file.

- [ ] **Step 2: Suppress in the shared `_overridesFor` helper**

Replace the `_overridesFor` return list (lines 31-34) with:

```dart
  return [
    recommendationRepositoryProvider.overrideWithValue(mock),
    currentUserIdProvider.overrideWithValue('test-user'),
    recommendationsNoticeSeenProvider.overrideWith((ref) => true),
  ];
```

- [ ] **Step 3: Suppress in every inline override list**

In the same file, add this line to each of the remaining override lists that mount `RecommendationsScreen` (the ones not using `_overridesFor`):

```dart
    recommendationsNoticeSeenProvider.overrideWith((ref) => true),
```

Add it to the override list in each of these tests:
- `loading state renders BbLoadingState` (the `overrides:` list, ~line 61)
- `error state renders BbErrorState with retry` (~line 84)
- `tapping the next chevron advances...` (`createContainer(overrides:`, ~line 269)
- `every entry lands on the latest...` (`createContainer(overrides:`, ~line 363)
- `AppBar leading is a tonal back-icon button that pops` (`ProviderScope(overrides:`, ~line 514)
- `hiding the currently-viewed recommendation...` (`createContainer(overrides:`, ~line 569)
- `AppBar title shows the current recommendation's date` (`overrides:`, ~line 615)
- `chevron actions live in the AppBar, not the body` (`overrides:`, ~line 647)
- `AppBar title falls back to "Empfehlungen" on empty list` (`overrides:`, ~line 690)
- `refresh with a new latest while reading an older page keeps the user put` (`createContainer(overrides:`, ~line 440)

> Tip: search the file for `currentUserIdProvider.overrideWithValue` — every match is an override list that mounts the screen and needs the suppression line added next to it.

- [ ] **Step 4: Run the existing screen tests to confirm still green**

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart`
Expected: PASS (all existing tests, unchanged behavior — no modal interferes).

### 4b. Wire the trigger into the screen

- [ ] **Step 5: Write the failing trigger test**

Append this test inside the existing `group('RecommendationsScreen', ...)` in `test/screens/recommendations/recommendations_screen_test.dart` (before the closing `});` of the group, around line 703):

```dart
    testWidgets(
      'shows the notice dialog on first open and flips the session flag',
      (tester) async {
        final mock = MockRecommendationRepository();
        when(
          () => mock.fetchByUserId(any()),
        ).thenAnswer((_) async => [_rec('1')]);
        when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

        final container = createContainer(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(mock),
            currentUserIdProvider.overrideWithValue('test-user'),
            // NOTE: notice flag NOT overridden — defaults to false so the
            // dialog should appear.
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: RecommendationsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // The notice dialog is shown on first open.
        expect(find.text('Danke, dass du dabei bist! 💛'), findsOneWidget);
        // And the session flag has been flipped so it won't show again.
        expect(container.read(recommendationsNoticeSeenProvider), isTrue);
      },
    );

    testWidgets(
      'does not show the notice dialog when the session flag is already set',
      (tester) async {
        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: _overridesFor([_rec('1')]),
        );
        await tester.pumpAndSettle();

        // _overridesFor sets the notice flag to true → no dialog.
        expect(find.text('Danke, dass du dabei bist! 💛'), findsNothing);
      },
    );
```

- [ ] **Step 6: Run the trigger test to verify it fails**

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart --plain-name "shows the notice dialog on first open"`
Expected: FAIL — no dialog appears (trigger not wired yet); the title text is not found.

- [ ] **Step 7: Wire the trigger in `initState`**

In `lib/screens/recommendations/recommendations_screen.dart`, add the import near the other `widgets/` imports (after line 16):

```dart
import 'widgets/recommendations_notice_dialog.dart';
```

Then, in `_RecommendationsScreenState.initState` (lines 51-60), add a post-frame callback after the existing `Future.microtask(...)` block so the existing fetch logic is untouched. The method becomes:

```dart
  @override
  void initState() {
    super.initState();
    _controller = PageController();
    Future.microtask(() async {
      final notifier = ref.read(recommendationProvider.notifier);
      await notifier.fetchRecommendations();
      await notifier.markAllAsSeen();
    });
    // Show the "no new recommendations for now" notice once per app session.
    // The flag lives in memory only, so it resets on cold start. Scheduled
    // post-frame so the first frame (and the Navigator) is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(recommendationsNoticeSeenProvider)) return;
      ref.read(recommendationsNoticeSeenProvider.notifier).state = true;
      showRecommendationsNoticeDialog(context);
    });
  }
```

- [ ] **Step 8: Run the trigger tests to verify they pass**

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart`
Expected: PASS — all tests, including both new trigger tests and the suppressed existing tests.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/recommendations/recommendations_screen.dart test/screens/recommendations/recommendations_screen_test.dart
git commit -m "feat: show recommendations notice once per session on Tipps screen"
```

---

## Task 5: Full verification

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Analyze and format**

Run: `flutter analyze && dart format --set-exit-if-changed lib test`
Expected: No issues; no files reformatted (if `dart format` changes files, re-run without `--set-exit-if-changed`, then commit the formatting).

- [ ] **Step 3: Manual smoke check (optional but recommended)**

Run the app, open the Tipps screen → the notice dialog appears with the German copy and both buttons. Tap `Feedback geben` → the Mailchimp survey opens in the external browser. Reopen the Tipps screen in the same session → no dialog. Confirm the dashboard and settings feedback buttons also open the Mailchimp survey.

---

## Notes / gotchas

- **Test pollution:** Auto-showing a modal on screen mount is why Task 4a exists. The modal barrier blocks gesture input, so any existing test that taps/flings would fail unless the notice is suppressed via the flag override. The search tip (`currentUserIdProvider.overrideWithValue`) finds every site that needs it.
- **Session semantics:** The flag is a plain in-memory `StateProvider` — no `SharedPreferences`, no Supabase. "Once per session" = once per app process; cold start re-shows it. This is intentional per the spec.
- **Shared URL constant:** No code change is needed in the dashboard or settings screens — they already read `AppConstants.feedbackFormUrl`.
