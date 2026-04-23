# Dashboard "Tipps" + Recommendations Header Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the "Für dich" dashboard card to "Tipps", replace its "Neu" badge with a pulsing "ungelesen" badge, and rebuild the recommendations detail AppBar so the date is the title, chevrons live in the actions slot, and the back button is a clearly-labelled "Dashboard" button.

**Architecture:** Six sequential tasks, each its own TDD loop and git commit. Tasks 1–2 cover the dashboard card; tasks 3–5 cover the recommendations AppBar; task 6 runs the final lint/test/push. No new providers or data fields — existing `recommendationIndexProvider`, `recommendationProvider`, and `formatDateWeekday` util carry all the needed state.

**Tech Stack:** Flutter (StatefulWidget + AnimationController for the pulse), Riverpod 3 (read-only in AppBar), GoRouter (`context.pop()` for back), `flutter_test` + `mocktail` for widget tests. Target branch: `feat/tipps-and-header-polish`, base: `origin/develop`.

---

## Spec

Read the spec before starting:
`docs/superpowers/specs/2026-04-23-dashboard-tipps-and-recommendations-header-design.md`

## File structure

**Modified:**

- `lib/screens/dashboard/widgets/feature_card.dart` — gains `pulse: bool` prop + `StatefulWidget` conversion + badge animation; badge text `'Neu'` → `'ungelesen'`
- `lib/screens/dashboard/dashboard_screen.dart` — card label `'Für dich'` → `'Tipps'`; passes `pulse: newRecommendationCount > 0`
- `lib/screens/recommendations/recommendations_screen.dart` — AppBar leading = `'Dashboard'` TextButton, title = date, actions = prev/next IconButtons; `_SwipeLayout` loses its inline top row
- `test/screens/dashboard/dashboard_screen_test.dart` — `'Für dich'` → `'Tipps'` in the card-renders assertion
- `test/screens/recommendations/recommendations_screen_test.dart` — replaces `'Empfehlungen (X von Y)'` assertions with provider-value assertions; updates Ausblenden/chevron lookups

**Created:**

- `test/screens/dashboard/widgets/feature_card_test.dart` — covers badge copy + pulse controller lifecycle + reduced-motion path

**Not renamed (out of scope):**

- `TutorialKeys.fuerDich` — internal GlobalKey identifier; renaming propagates into tutorial overlay wiring. Left as-is.

## Conventions

- `AppTheme.primary` / `AppTheme.foreground` / `AppTheme.mutedForeground` — never hardcode colours (CLAUDE.md)
- `AppTheme.fontSize*` — never hardcode font sizes
- `AppConstants.spacing*` / `AppConstants.radius*` / `AppConstants.anim*` / `AppConstants.iconBadge*` — never hardcode spacing/radii/durations/icon sizes
- Run `dart format <changed files>` before each commit; the pre-commit hook will reject unformatted code
- All user-facing strings in German

---

### Task 1: Dashboard copy — "Tipps" label + "ungelesen" badge text

**Files:**

- Modify: `lib/screens/dashboard/widgets/feature_card.dart:81`
- Modify: `lib/screens/dashboard/dashboard_screen.dart:249`
- Create: `test/screens/dashboard/widgets/feature_card_test.dart`
- Modify: `test/screens/dashboard/dashboard_screen_test.dart:22-29`

- [ ] **Step 1: Write failing tests**

Create `test/screens/dashboard/widgets/feature_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/feature_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, child: child)));

void main() {
  group('FeatureCard badge copy', () {
    testWidgets('hasNew: renders "ungelesen" (not "Neu")', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/fuer-dich-card.png',
            label: 'Tipps',
            icon: Icons.auto_awesome,
            iconColor: Colors.black,
            hasNew: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('ungelesen'), findsOneWidget);
      expect(find.text('Neu'), findsNothing);
    });

    testWidgets('badgeCount > 0: renders the number', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/alternativen-card.jpg',
            label: 'Alternativen',
            icon: Icons.eco,
            iconColor: Colors.black,
            badgeCount: 3,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });
  });
}
```

Modify `test/screens/dashboard/dashboard_screen_test.dart:22-29` — change the test name and the asserted label:

```dart
testWidgets('renders feature card Tipps', (tester) async {
  // ... existing setup unchanged ...
  expect(find.text('Tipps'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/dashboard/`
Expected: both `feature_card_test.dart` tests fail with "Expected: exactly one matching node in the widget tree / Actual: _TextFinder:<zero widgets with text "ungelesen">"; dashboard_screen_test fails because the label is still `'Für dich'`.

- [ ] **Step 3: Change the strings**

Edit `lib/screens/dashboard/widgets/feature_card.dart:81`:

```dart
child: Text(
  hasNew ? 'ungelesen' : '$badgeCount',
  style: const TextStyle(
    fontSize: AppTheme.fontSizeCaption,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  ),
),
```

Edit `lib/screens/dashboard/dashboard_screen.dart:249`:

```dart
child: FeatureCard(
  key: TutorialKeys.fuerDich,
  imageAsset: AppConstants.fuerDichCard,
  label: 'Tipps',
  icon: Icons.auto_awesome,
  iconColor: AppTheme.foreground,
  hasNew: newRecommendationCount > 0,
  onTap: () => context.push(RoutePaths.recommendations),
),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/dashboard/`
Expected: all pass (including the existing "Für dich erstellt" section-header test, which is unchanged).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/screens/dashboard/widgets/feature_card.dart \
  lib/screens/dashboard/dashboard_screen.dart \
  test/screens/dashboard/widgets/feature_card_test.dart \
  test/screens/dashboard/dashboard_screen_test.dart
git add lib/screens/dashboard/widgets/feature_card.dart \
  lib/screens/dashboard/dashboard_screen.dart \
  test/screens/dashboard/widgets/feature_card_test.dart \
  test/screens/dashboard/dashboard_screen_test.dart
git commit -m "feat(dashboard): rename Für dich card to Tipps; Neu badge → ungelesen"
```

---

### Task 2: FeatureCard pulse animation

**Files:**

- Modify: `lib/screens/dashboard/widgets/feature_card.dart` (convert to StatefulWidget + add AnimationController)
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (pass `pulse: newRecommendationCount > 0`)
- Modify: `test/screens/dashboard/widgets/feature_card_test.dart` (add pulse tests)

- [ ] **Step 1: Write failing tests**

Append to `test/screens/dashboard/widgets/feature_card_test.dart`:

```dart
  group('FeatureCard pulse', () {
    testWidgets('pulse=true: badge pill has a non-unit Transform.scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/fuer-dich-card.png',
            label: 'Tipps',
            icon: Icons.auto_awesome,
            iconColor: Colors.black,
            hasNew: true,
            pulse: true,
            onTap: () {},
          ),
        ),
      );
      // Advance far enough to leave the AnimationController at a non-zero
      // value mid-cycle (controller duration is 700 ms, reverses).
      await tester.pump(const Duration(milliseconds: 350));

      final badge = find.ancestor(
        of: find.text('ungelesen'),
        matching: find.byType(Transform),
      );
      expect(badge, findsWidgets);
    });

    testWidgets('pulse=false: no AnimationController; badge is static', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/fuer-dich-card.png',
            label: 'Tipps',
            icon: Icons.auto_awesome,
            iconColor: Colors.black,
            hasNew: true,
            pulse: false,
            onTap: () {},
          ),
        ),
      );
      // No pending animation frames → pumpAndSettle returns instantly.
      await tester.pumpAndSettle();
      expect(find.text('ungelesen'), findsOneWidget);
    });

    testWidgets('MediaQuery.disableAnimations: badge is static even if pulse=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              accessibleNavigation: false,
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 200,
                child: FeatureCard(
                  imageAsset: 'assets/images/fuer-dich-card.png',
                  label: 'Tipps',
                  icon: Icons.auto_awesome,
                  iconColor: Colors.black,
                  hasNew: true,
                  pulse: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      // pumpAndSettle succeeds → no repeating animation.
      await tester.pumpAndSettle();
      expect(find.text('ungelesen'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/dashboard/widgets/feature_card_test.dart`
Expected: pulse tests fail because `FeatureCard` has no `pulse` parameter (compile error / "pulse isn't defined").

- [ ] **Step 3: Convert FeatureCard to StatefulWidget + add pulse**

Replace the entire `lib/screens/dashboard/widgets/feature_card.dart` with:

```dart
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/press_scale_wrapper.dart';

class FeatureCard extends StatefulWidget {
  final String imageAsset;
  final String label;
  final IconData icon;
  final Color iconColor;
  final int badgeCount;
  final bool hasNew;
  final bool pulse;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.imageAsset,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.badgeCount = 0,
    this.hasNew = false,
    this.pulse = false,
    required this.onTap,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 700);
  static const _pulseScaleMax = 1.08;
  static const _pulseHaloSpread = 6.0;
  static const _pulseHaloOpacity = 0.55;
  static const _borderWidth = 3.0;

  late final AnimationController _controller;
  bool? _isAnimating;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _pulseDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant FeatureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  /// Starts or stops the pulse based on [widget.pulse] and the current
  /// `MediaQuery.disableAnimations` flag. Guarded by [_isAnimating] so a
  /// rebuild with unchanged effective state is a no-op.
  void _syncAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate = widget.pulse && !reduceMotion;
    if (shouldAnimate == _isAnimating) return;
    _isAnimating = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _showBorder => widget.hasNew || widget.badgeCount > 0;

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = _isAnimating ?? false;
    return PressScaleWrapper(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: _showBorder
              ? Border.all(color: AppTheme.primary, width: _borderWidth)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            _showBorder
                ? AppConstants.radiusLg - _borderWidth
                : AppConstants.radiusLg,
          ),
          child: SizedBox(
            height: 128,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(widget.imageAsset, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                if (widget.hasNew || widget.badgeCount > 0)
                  Positioned(
                    top: AppConstants.spacingSm,
                    right: AppConstants.spacingSm,
                    child: _Badge(
                      text: widget.hasNew ? 'ungelesen' : '${widget.badgeCount}',
                      controller: shouldAnimate ? _controller : null,
                    ),
                  ),
                Positioned(
                  bottom: AppConstants.spacing10,
                  left: AppConstants.spacing10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacing10,
                      vertical: AppConstants.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: _showBorder
                          ? AppTheme.primary
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusRound,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: AppConstants.iconSizeXs,
                          color: widget.iconColor,
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeBodyLG,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing2),
                        const Icon(
                          Icons.chevron_right,
                          size: AppConstants.spacing14,
                          color: AppTheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.controller});

  final String text;
  final AnimationController? controller;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
    if (controller == null) return badge;
    return AnimatedBuilder(
      animation: controller!,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller!.value);
        return Transform.scale(
          scale: 1.0 + (_FeatureCardState._pulseScaleMax - 1.0) * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(
                    alpha: _FeatureCardState._pulseHaloOpacity * (1 - t),
                  ),
                  blurRadius: 0,
                  spreadRadius: _FeatureCardState._pulseHaloSpread * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: badge,
    );
  }
}
```

Edit `lib/screens/dashboard/dashboard_screen.dart:246-254`:

```dart
child: FeatureCard(
  key: TutorialKeys.fuerDich,
  imageAsset: AppConstants.fuerDichCard,
  label: 'Tipps',
  icon: Icons.auto_awesome,
  iconColor: AppTheme.foreground,
  hasNew: newRecommendationCount > 0,
  pulse: newRecommendationCount > 0,
  onTap: () => context.push(RoutePaths.recommendations),
),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/dashboard/`
Expected: all pass. (If the pulse-false test times out on `pumpAndSettle`, the controller is still ticking — check that `didUpdateWidget` + the build-time guard both stop it.)

- [ ] **Step 5: Format and commit**

```bash
dart format lib/screens/dashboard/widgets/feature_card.dart \
  lib/screens/dashboard/dashboard_screen.dart \
  test/screens/dashboard/widgets/feature_card_test.dart
git add lib/screens/dashboard/widgets/feature_card.dart \
  lib/screens/dashboard/dashboard_screen.dart \
  test/screens/dashboard/widgets/feature_card_test.dart
git commit -m "feat(dashboard): pulse the ungelesen badge when new recommendations arrive"
```

---

### Task 3: Recommendations AppBar — "Dashboard" leading button

**Files:**

- Modify: `lib/screens/recommendations/recommendations_screen.dart` (AppBar `leading` + `leadingWidth`)
- Modify: `test/screens/recommendations/recommendations_screen_test.dart` (new assertion for the leading label)

- [ ] **Step 1: Write failing test**

Append a new test inside the existing `group('RecommendationsScreen', ...)` block in `test/screens/recommendations/recommendations_screen_test.dart`:

```dart
testWidgets('AppBar leading renders "Dashboard" button that pops', (
  tester,
) async {
  final repo = MockRecommendationRepository();
  when(() => repo.fetchByUserId(any())).thenAnswer(
    (_) async => [testRecommendation(id: '1')],
  );
  when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

  bool popped = false;
  await tester.pumpWithProviders(
    PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popped = true;
      },
      child: const RecommendationsScreen(),
    ),
    overrides: [
      recommendationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u'),
    ],
  );
  await tester.pumpAndSettle();

  expect(find.widgetWithText(TextButton, 'Dashboard'), findsOneWidget);

  await tester.tap(find.text('Dashboard'));
  await tester.pumpAndSettle();
  expect(popped, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart --plain-name "AppBar leading"`
Expected: FAIL with "Expected: exactly one matching node" because the default Flutter back arrow renders instead.

- [ ] **Step 3: Implement the leading button**

Edit `lib/screens/recommendations/recommendations_screen.dart` inside `build` (the `Scaffold`'s `appBar`):

```dart
return Scaffold(
  appBar: AppBar(
    leading: const _DashboardBackButton(),
    leadingWidth: 128,
    title: const _RecommendationsTitle(),
  ),
  body: state.when(
    // ... unchanged ...
  ),
);
```

Add a new widget at the bottom of the file (below `_RecommendationPage`):

```dart
class _DashboardBackButton extends StatelessWidget {
  const _DashboardBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppConstants.spacingXs),
      child: TextButton.icon(
        onPressed: () => context.pop(),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.foreground,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
          ),
        ),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: AppConstants.iconSizeSm,
        ),
        label: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
```

Ensure the file's existing imports include `package:go_router/go_router.dart` (check for `context.pop`). If not present, add:

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart --plain-name "AppBar leading"`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/screens/recommendations/recommendations_screen.dart \
  test/screens/recommendations/recommendations_screen_test.dart
git add lib/screens/recommendations/recommendations_screen.dart \
  test/screens/recommendations/recommendations_screen_test.dart
git commit -m "feat(recommendations): AppBar leading = labelled Dashboard back button"
```

---

### Task 4: Recommendations AppBar — date-as-title

**Files:**

- Modify: `lib/screens/recommendations/recommendations_screen.dart` (`_RecommendationsTitle` renders date)
- Modify: `test/helpers/fixtures.dart` (`testRecommendation` accepts `createdAt`)
- Modify: `test/screens/recommendations/recommendations_screen_test.dart` (assertions shift from "X von Y" to the formatted date OR the index provider value)

- [ ] **Step 1: Extend the test fixture**

Edit `test/helpers/fixtures.dart:133-141`:

```dart
Recommendation testRecommendation({
  String? id,
  String? summary,
  List<RecommendationItem>? recommendations,
  DateTime? createdAt,
}) => Recommendation(
  id: id ?? 'rec-1',
  summary: summary ?? 'Tipp: Mehr Wasser trinken.',
  recommendations: recommendations ?? [],
  createdAt: createdAt,
);
```

- [ ] **Step 2: Write failing test**

In `test/screens/recommendations/recommendations_screen_test.dart`, add an import for the date util (near the other imports):

```dart
import 'package:belly_buddy/utils/date_format_utils.dart';
```

Add a new test inside the existing `group('RecommendationsScreen', ...)` block:

```dart
testWidgets('AppBar title shows the current recommendation\'s date', (
  tester,
) async {
  final rec = testRecommendation(
    id: '1',
    createdAt: DateTime(2026, 4, 22, 10, 30),
  );
  final repo = MockRecommendationRepository();
  when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
  when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

  await tester.pumpWithProviders(
    const RecommendationsScreen(),
    overrides: [
      recommendationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u'),
    ],
  );
  await tester.pumpAndSettle();

  expect(find.text(formatDateWeekday(rec.createdAt!)), findsOneWidget);
  // The old "Empfehlungen (X von Y)" text is gone.
  expect(find.textContaining('Empfehlungen ('), findsNothing);
});

testWidgets('AppBar title falls back to "Empfehlungen" on empty list', (
  tester,
) async {
  final repo = MockRecommendationRepository();
  when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
  when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

  await tester.pumpWithProviders(
    const RecommendationsScreen(),
    overrides: [
      recommendationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u'),
    ],
  );
  await tester.pumpAndSettle();

  expect(find.text('Empfehlungen'), findsOneWidget);
});
```

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart --plain-name "AppBar title"`
Expected: FAIL — the title still renders "Empfehlungen (X von Y)" counter form.

- [ ] **Step 3: Replace the title builder**

Edit `lib/screens/recommendations/recommendations_screen.dart` `_RecommendationsTitle` widget body:

```dart
class _RecommendationsTitle extends ConsumerWidget {
  const _RecommendationsTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref
        .watch(recommendationProvider)
        .maybeWhen(data: (r) => r, orElse: () => const <Recommendation>[]);
    if (recs.isEmpty) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: AppConstants.iconSizeSm),
          SizedBox(width: AppConstants.spacingSm),
          Text('Empfehlungen', overflow: TextOverflow.ellipsis),
        ],
      );
    }

    final rawIndex = ref.watch(recommendationIndexProvider);
    // Clamp against the current list length: when the user hides the
    // currently-viewed recommendation, the list shrinks below the raw
    // index for a frame before the post-frame animateToPage + onPageChanged
    // cycle brings the notifier back in range.
    final total = recs.length;
    final displayIndex = rawIndex.clamp(0, total - 1);
    // pageIndex 0 = oldest; pageIndex total-1 = latest. The list is
    // newest-first, so convert to the matching list index.
    final listIndex = (total - 1) - displayIndex;
    final createdAt = recs[listIndex].createdAt;
    final text = createdAt != null
        ? formatDateWeekday(createdAt)
        : 'Empfehlungen';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, size: AppConstants.iconSizeSm),
        const SizedBox(width: AppConstants.spacingSm),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
```

Ensure the file has:

```dart
import '../../utils/date_format_utils.dart';
```

(It already imports this for the inline date row — keep the import when you delete the row in Task 5.)

- [ ] **Step 4: Update the existing hide-clamp test**

In `test/screens/recommendations/recommendations_screen_test.dart`, the hide-clamp regression test (around `find.text('Empfehlungen (3 von 2)')`) now needs to assert on date text or index state. Change the two lines:

```dart
// Before:
expect(find.text('Empfehlungen (3 von 2)'), findsNothing);
expect(find.text('Empfehlungen (2 von 2)'), findsOneWidget);

// After — verify the clamp via the provider's settled value:
expect(
  container.read(recommendationIndexProvider).clamp(0, 1),
  container.read(recommendationIndexProvider),
);
```

Any other `find.text('Empfehlungen (X von Y)')` assertions in the file should either be deleted (if they only existed to pin counter text) or converted to index-provider reads as above.

- [ ] **Step 5: Run tests + commit**

```bash
flutter test test/screens/recommendations/recommendations_screen_test.dart
```

Expected: all tests pass. (Some tests that asserted counter text purely for debugging — not as the subject of the test — may simply lose those expectations.)

```bash
dart format lib/screens/recommendations/recommendations_screen.dart \
  test/helpers/fixtures.dart \
  test/screens/recommendations/recommendations_screen_test.dart
git add lib/screens/recommendations/recommendations_screen.dart \
  test/helpers/fixtures.dart \
  test/screens/recommendations/recommendations_screen_test.dart
git commit -m "feat(recommendations): AppBar title = date of current recommendation"
```

---

### Task 5: Recommendations AppBar — prev/next chevron actions; drop the inline row

**Files:**

- Modify: `lib/screens/recommendations/recommendations_screen.dart` (add `actions:` to AppBar; gut `_SwipeLayout`'s header row)
- Modify: `test/screens/recommendations/recommendations_screen_test.dart` (remove date-row-in-body assertions — keys stay, finders via `byKey` still work)

- [ ] **Step 1: Write failing test**

Add to `test/screens/recommendations/recommendations_screen_test.dart`:

```dart
testWidgets('chevron actions live in the AppBar, not the body row', (
  tester,
) async {
  final recs = [
    testRecommendation(id: '1', createdAt: DateTime(2026, 4, 20)),
    testRecommendation(id: '2', createdAt: DateTime(2026, 4, 21)),
    testRecommendation(id: '3', createdAt: DateTime(2026, 4, 22)),
  ];
  final repo = MockRecommendationRepository();
  when(() => repo.fetchByUserId(any())).thenAnswer((_) async => recs);
  when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

  await tester.pumpWithProviders(
    const RecommendationsScreen(),
    overrides: [
      recommendationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u'),
    ],
  );
  await tester.pumpAndSettle();

  // Both prev/next buttons render in the AppBar (descendants of AppBar).
  final appBarFinder = find.byType(AppBar);
  expect(
    find.descendant(
      of: appBarFinder,
      matching: find.byKey(RecommendationsScreen.previousRecommendationKey),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: appBarFinder,
      matching: find.byKey(RecommendationsScreen.nextRecommendationKey),
    ),
    findsOneWidget,
  );
  // The body no longer contains an inline prev/next row.
  expect(
    find.descendant(
      of: find.byType(Scaffold),
      matching: find.byIcon(Icons.chevron_right),
    ).hitTestable(),
    findsOneWidget, // only the AppBar one; the inline row is gone
  );
});
```

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart --plain-name "chevron actions"`
Expected: FAIL — currently two `chevron_right` icons render (inline row + no AppBar action yet).

- [ ] **Step 2: Add the AppBar actions + remove the inline row**

Edit the `Scaffold`'s `appBar` in `lib/screens/recommendations/recommendations_screen.dart:127-128`:

```dart
return Scaffold(
  appBar: AppBar(
    leading: const _DashboardBackButton(),
    leadingWidth: 128,
    title: const _RecommendationsTitle(),
    actions: const [
      _PrevRecommendationAction(),
      _NextRecommendationAction(),
      SizedBox(width: AppConstants.spacingXs),
    ],
  ),
  body: state.when(
    // ... unchanged ...
  ),
);
```

Add two widgets near the other private classes in the same file:

```dart
class _PrevRecommendationAction extends ConsumerWidget {
  const _PrevRecommendationAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref
        .watch(recommendationProvider)
        .maybeWhen(data: (r) => r, orElse: () => const <Recommendation>[]);
    if (recs.isEmpty) {
      return const SizedBox(width: AppConstants.iconBadgeMd);
    }
    final rawIndex = ref.watch(recommendationIndexProvider);
    final currentIndex = rawIndex.clamp(0, recs.length - 1);
    final isOldest = currentIndex == 0;
    return IconButton(
      key: RecommendationsScreen.previousRecommendationKey,
      icon: const Icon(Icons.chevron_left),
      onPressed: isOldest
          ? null
          : () {
              HapticService.light();
              ref
                  .read(recommendationIndexProvider.notifier)
                  .set(currentIndex - 1);
            },
    );
  }
}

class _NextRecommendationAction extends ConsumerWidget {
  const _NextRecommendationAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref
        .watch(recommendationProvider)
        .maybeWhen(data: (r) => r, orElse: () => const <Recommendation>[]);
    if (recs.isEmpty) {
      return const SizedBox(width: AppConstants.iconBadgeMd);
    }
    final rawIndex = ref.watch(recommendationIndexProvider);
    final currentIndex = rawIndex.clamp(0, recs.length - 1);
    final isLatest = currentIndex == recs.length - 1;
    return IconButton(
      key: RecommendationsScreen.nextRecommendationKey,
      icon: const Icon(Icons.chevron_right),
      onPressed: isLatest
          ? null
          : () {
              HapticService.light();
              ref
                  .read(recommendationIndexProvider.notifier)
                  .set(currentIndex + 1);
            },
    );
  }
}
```

Gut `_SwipeLayout` — delete the entire top `Padding` + `Row(children: [chevron, date, chevron])` block. The new body of `_SwipeLayout.build` is:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final rawIndex = ref.watch(recommendationIndexProvider);
  // Clamp against the list: if the user just hid the currently-viewed
  // recommendation, the list shrunk and the notifier's raw value may
  // point past the new end. See `_RecommendationsTitle` for the rationale.
  final currentIndex = rawIndex.clamp(0, recommendations.length - 1);

  // If the raw notifier value was out of bounds, schedule a write-back so
  // the controller's ref.listen animates the PageView to a valid page on
  // the next frame. Avoids a stuck "controller at page N but list only
  // has N items" after a hide. Idempotent: the next rebuild sees
  // rawIndex == currentIndex and skips scheduling a second callback.
  if (rawIndex != currentIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ref.read(recommendationIndexProvider.notifier).set(currentIndex);
    });
  }

  return PageView.builder(
    controller: controller,
    itemCount: recommendations.length,
    onPageChanged: (index) {
      HapticService.light();
      ref.read(recommendationIndexProvider.notifier).set(index);
    },
    itemBuilder: (context, pageIndex) {
      // pageIndex 0 = oldest; pageIndex length-1 = latest.
      // Our list from the provider is newest-first, so convert.
      final listIndex = (recommendations.length - 1) - pageIndex;
      return _RecommendationPage(
        recommendation: recommendations[listIndex],
      );
    },
  );
}
```

Remove any now-unused imports in `recommendations_screen.dart`. Specifically check whether these are still used:

- `CircleIconButton` (import from `widgets/common/circle_icon_button.dart`) — if not used elsewhere in the file, remove the import.
- The chevron icons are still used inside `_PrevRecommendationAction` / `_NextRecommendationAction` — keep them.

- [ ] **Step 3: Run tests to verify they pass**

Run: `flutter test test/screens/recommendations/`
Expected: all tests in the file pass, including the updated hide-clamp and the new AppBar-actions test.

- [ ] **Step 4: Run the full test suite to catch any cross-file regressions**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/screens/recommendations/recommendations_screen.dart \
  test/screens/recommendations/recommendations_screen_test.dart
git add lib/screens/recommendations/recommendations_screen.dart \
  test/screens/recommendations/recommendations_screen_test.dart
git commit -m "feat(recommendations): move prev/next chevrons into AppBar actions"
```

---

### Task 6: Analyze, full test run, open PR

**Files:** none (verification + git ops only)

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run `dart format` in check mode**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: exit 0 (no files need formatting).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass. Record the pass count in the PR body.

- [ ] **Step 4: Push the branch**

Run: `git push -u origin feat/tipps-and-header-polish`

- [ ] **Step 5: Open the PR against `develop`**

```bash
gh pr create --base develop --title "feat: Tipps rename + recommendations header polish" --body "$(cat <<'EOF'
## Summary

- Dashboard: "Für dich" card renamed to "Tipps"; "Neu" badge becomes a pulsing "ungelesen" pill
- Recommendations AppBar: labelled "Dashboard" back button (left), current recommendation's date as title, prev/next chevrons in actions (right)
- Body no longer carries its own date/chevron row — all three live in the AppBar

## Test plan

- [ ] Dashboard: open with unread recommendations → Tipps card shows pulsing "ungelesen" badge
- [ ] Dashboard: mark all seen → pulse stops, badge disappears
- [ ] Dashboard: toggle system reduce-motion → badge is static even with unread
- [ ] Recommendations: open with 3+ recommendations → AppBar leading reads "‹ Dashboard", title shows date, actions show ‹/›
- [ ] Tap chevrons → page advances; first/last disable the respective chevron
- [ ] Tap "Dashboard" → back to dashboard
- [ ] Hide the currently-viewed recommendation → AppBar title updates to the previous date; no transient invalid state
EOF
)"
```

**Do NOT arm `--auto`.** Leave the PR parked pending review.

---

## Done criteria

- All 6 tasks' commits are on `feat/tipps-and-header-polish`
- `flutter analyze` clean
- `flutter test` all green
- PR open against `develop`, no auto-merge armed
