# Recommendations Horizontal Swipe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `RecommendationHistory` collapsible inside `RecommendationsScreen` with a horizontal `PageView.builder` that lets the user swipe between recommendations, mirroring the diary day-swipe UX. The latest recommendation becomes the rightmost page; swiping leftward reveals older entries. A pinned header sits above the PageView with prev/next chevrons and a "X von Y Empfehlungen" position indicator.

**Architecture:** `RecommendationsScreen` owns a `PageController`. Body is a `PageView.builder` with `itemCount = recommendations.length` and `initialPage = length - 1` (latest at the right). A new `NotifierProvider<RecommendationIndexNotifier, int>` tracks the currently-visible page index; `onPageChanged` writes to it, a `ref.listen` animates the controller when chevrons or external writes change the index. If `recommendations.first.id` changes between fetches (a new latest arrived on refresh), the controller jumps to the new `length - 1`. The old `RecommendationHistory` widget and its call site are deleted.

**Tech Stack:** Flutter `PageView.builder`, Riverpod `NotifierProvider` (Riverpod 3), existing `recommendationProvider`, `HapticService`, existing detail/summary card widgets.

---

## File Structure

**Modified runtime code:**
- `lib/screens/recommendations/recommendations_screen.dart` — rewrite `_buildDataState` around `PageView.builder` + pinned header + new page-level widget `_RecommendationPage`. Add `PageController` lifecycle + `ref.listen` on the index notifier.

**New runtime code:**
- `lib/providers/recommendation_index_provider.dart` — `NotifierProvider<RecommendationIndexNotifier, int>` with `set(int)`.

**Deleted runtime code:**
- `lib/screens/recommendations/widgets/recommendation_history.dart`

**Tests:**
- Rewrite: `test/screens/recommendations/recommendations_screen_test.dart` — cover the new PageView-based flow and the empty/single cases.
- New: `test/providers/recommendation_index_provider_test.dart` — unit test the notifier.
- Delete (if it exists): `test/screens/recommendations/widgets/recommendation_history_test.dart`.

---

## Task 1: Index notifier

**Files:**
- Create: `lib/providers/recommendation_index_provider.dart`
- Create: `test/providers/recommendation_index_provider_test.dart`

- [ ] **Step 1: Write failing notifier tests**

Create `test/providers/recommendation_index_provider_test.dart`:

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/providers/recommendation_index_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('recommendationIndexProvider', () {
    test('initial value is 0', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(recommendationIndexProvider), 0);
    });

    test('set(n) updates state to n', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(recommendationIndexProvider.notifier).set(5);
      expect(container.read(recommendationIndexProvider), 5);

      container.read(recommendationIndexProvider.notifier).set(0);
      expect(container.read(recommendationIndexProvider), 0);
    });
  });
}
```

Run: `flutter test test/providers/recommendation_index_provider_test.dart`. Expected: FAIL (provider doesn't exist).

- [ ] **Step 2: Implement the notifier**

Create `lib/providers/recommendation_index_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently-visible PageView index in `RecommendationsScreen`.
///
/// The screen seeds this to `recommendations.length - 1` (the latest) on
/// first data-resolve. `onPageChanged` writes to it; chevron taps call
/// [RecommendationIndexNotifier.set] and a `ref.listen` on the screen
/// animates the PageController to match.
class RecommendationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final recommendationIndexProvider =
    NotifierProvider<RecommendationIndexNotifier, int>(
      RecommendationIndexNotifier.new,
    );
```

- [ ] **Step 3: Run tests + analyze**

Run: `flutter test test/providers/recommendation_index_provider_test.dart` → pass.
Run: `flutter analyze` → 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/recommendation_index_provider.dart \
        test/providers/recommendation_index_provider_test.dart
git commit -m "feat(recommendations): page-index notifier"
```

---

## Task 2: Rewrite `RecommendationsScreen` with PageView

**Files:**
- Modify: `lib/screens/recommendations/recommendations_screen.dart`
- Delete: `lib/screens/recommendations/widgets/recommendation_history.dart`
- Delete: `test/screens/recommendations/widgets/recommendation_history_test.dart` (if it exists — check first)
- Rewrite: `test/screens/recommendations/recommendations_screen_test.dart`

### Before starting

Read these three files to understand the existing shape of the screen and widgets you'll be reusing:
- `lib/screens/recommendations/recommendations_screen.dart` (current implementation)
- `lib/screens/recommendations/widgets/recommendation_summary_card.dart` — you'll embed this inside each page
- `lib/screens/recommendations/widgets/recommendation_card.dart` — you'll embed this for each item
- `lib/models/recommendation.dart` — `Recommendation` has `id`, `summary`, `recommendations: List<RecommendationItem>`, `createdAt: DateTime?`
- `lib/screens/diary/diary_screen.dart` — the reference pattern. In particular note how it wires `PageController` + `ref.listen` + chevron hide-at-boundary.
- `lib/providers/recommendation_provider.dart` — `recommendationProvider` is a `NotifierProvider<RecommendationNotifier, AsyncValue<List<Recommendation>>>`. Its `fetchRecommendations()` and `markAllAsSeen()` are still called in `initState` as today.

### Check for the history test

Run:
```bash
test -f test/screens/recommendations/widgets/recommendation_history_test.dart && \
  echo "history test exists — must be deleted" || echo "no history test"
```
If it exists, include its deletion in the commit. Otherwise skip.

- [ ] **Step 1: Rewrite the screen test file (still-red phase)**

Replace the entire contents of `test/screens/recommendations/recommendations_screen_test.dart` with a test covering the new behavior. Use the repo's existing test patterns — read the current file first for imports / helper-usage / fake-repository overrides. The tests to include:

```dart
testWidgets('loading state renders BbLoadingState', (tester) async {
  // Pump with the notifier in AsyncValue.loading (its default initial state).
  // Assert find.byType(BbLoadingState) or the known message 'Analysiere deine Daten...'.
});

testWidgets('error state renders BbErrorState with retry', (tester) async {
  // Override recommendationProvider to AsyncError.
  // Assert the error message and the retry button are visible.
});

testWidgets('empty state shows mascot + "Noch keine Empfehlungen"', (tester) async {
  // Override recommendationProvider to AsyncData([]).
  // Assert the German empty-state text is visible and emptyStateRefreshKey is present.
  // Assert no PageView is rendered.
});

testWidgets(
  'single-recommendation list renders one page with both chevrons hidden',
  (tester) async {
    // Override to a one-item list.
    // Assert the PageView is rendered with itemCount 1.
    // Assert 'previousRecommendationKey' and 'nextRecommendationKey' are NOT in the tree
    // (they're replaced by SizedBox placeholders when at the boundaries).
    // Assert the indicator text '1 von 1 Empfehlungen' is present.
  },
);

testWidgets(
  'multi-recommendation initial page is the latest (rightmost)',
  (tester) async {
    // Override to a three-item list (newest first per provider order).
    // Assert the indicator shows '3 von 3 Empfehlungen' initially.
    // Assert the next chevron is hidden (we are on the latest = rightmost).
    // Assert the previous chevron is visible.
  },
);

testWidgets(
  'swiping rightward on the PageView retreats to an older recommendation',
  (tester) async {
    // Start on a three-item list. Drag PageView rightward with a fling.
    // Assert the indicator updates to '2 von 3 Empfehlungen'.
    // Use tester.fling(find.byType(PageView), const Offset(600, 0), 1000) —
    // a plain drag of 400 px sits on PageView's commit threshold and is flaky.
  },
);

testWidgets(
  'tapping the previous chevron advances to the older recommendation',
  (tester) async {
    // Three-item list. Tap previousRecommendationKey.
    // pumpAndSettle to allow animateToPage to complete.
    // Assert indicator updates accordingly.
  },
);

testWidgets(
  'tapping the next chevron advances to the newer recommendation',
  (tester) async {
    // Three-item list. Seed recommendationIndexProvider to 1 (middle page) before pump.
    // Tap nextRecommendationKey. Assert indicator shows '3 von 3' afterwards.
  },
);
```

The exact helper invocations (container setup, `overrideWith`, `pumpWithProviders` or `UncontrolledProviderScope`) depend on what's already in `test/helpers/riverpod_helpers.dart` and `test/helpers/fakes.dart`. Follow the same pattern used in the diary screen tests (`test/screens/diary/diary_screen_test.dart`).

Run: `flutter test test/screens/recommendations/recommendations_screen_test.dart` — expected FAIL (the keys referenced don't exist yet; screen still uses the old layout).

- [ ] **Step 2: Delete `recommendation_history.dart` and its test**

```bash
rm lib/screens/recommendations/widgets/recommendation_history.dart
# Only if the history test existed per the check above:
rm test/screens/recommendations/widgets/recommendation_history_test.dart 2>/dev/null || true
```

This will temporarily break `recommendations_screen.dart`'s imports — fixed in the next step.

- [ ] **Step 3: Rewrite `recommendations_screen.dart`**

Replace the entire file with the new PageView-based structure. Keep these call-sites intact (do not remove):
- `initState` still triggers `fetchRecommendations` + `markAllAsSeen` via the existing `Future.microtask` pattern.
- Loading state renders `BbLoadingState(message: 'Analysiere deine Daten...')`.
- Error state renders the existing `BbErrorState` with retry.
- Empty state renders the mascot + German text + refresh button, keyed by `RecommendationsScreen.emptyStateRefreshKey`.

New data-state rendering:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/recommendation.dart';
import '../../providers/recommendation_index_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../services/haptic_service.dart';
import '../../utils/date_format_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_summary_card.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  static const emptyStateRefreshKey = Key(
    'recommendations_empty_refresh_button',
  );
  static const previousRecommendationKey = Key('recommendations_previous');
  static const nextRecommendationKey = Key('recommendations_next');

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  late final PageController _controller;

  /// The id of the latest recommendation the controller is currently anchored
  /// to. When a refresh brings a new latest in at index 0, this changes and
  /// we re-anchor the controller to the new `length - 1`.
  String? _anchoredLatestId;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    Future.microtask(() async {
      final notifier = ref.read(recommendationProvider.notifier);
      await notifier.fetchRecommendations();
      await notifier.markAllAsSeen();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Seed / re-seed the controller + index notifier when the data resolves
  /// or when a new latest recommendation arrives.
  void _maybeAnchor(List<Recommendation> list) {
    if (list.isEmpty) return;
    final latestId = list.first.id;
    if (latestId == _anchoredLatestId) return;
    _anchoredLatestId = latestId;

    final targetPage = list.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        _controller.jumpToPage(targetPage);
      }
      ref.read(recommendationIndexProvider.notifier).set(targetPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);

    ref.listen<int>(recommendationIndexProvider, (_, next) {
      if (!_controller.hasClients) return;
      final current = (_controller.page ??
              _controller.initialPage.toDouble())
          .round();
      if (current == next) return;
      _controller.animateToPage(
        next,
        duration: AppConstants.animNormal,
        curve: Curves.easeOut,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: AppConstants.spacingSm),
            Text('Empfehlungen'),
          ],
        ),
      ),
      body: state.when(
        loading: () => const BbLoadingState(message: 'Analysiere deine Daten...'),
        error: (e, _) => ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            BbErrorState(
              message: 'Fehler beim Laden der Empfehlungen.',
              onRetry: () => ref
                  .read(recommendationProvider.notifier)
                  .fetchRecommendations(),
            ),
          ],
        ),
        data: (recommendations) {
          if (recommendations.isEmpty) return _buildEmptyState();
          _maybeAnchor(recommendations);
          return _buildSwipeLayout(recommendations);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    // (unchanged from current implementation — copy the existing body here)
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MascotImage(
                assetPath: AppConstants.mascotHappy,
                width: 96,
                height: 96,
              ),
              AppConstants.gap16,
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingXl,
                ),
                child: Text(
                  'Noch keine Empfehlungen — sobald Belly Buddy deine Daten analysiert hat, siehst du sie hier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
              AppConstants.gap16,
              TextButton.icon(
                key: RecommendationsScreen.emptyStateRefreshKey,
                onPressed: () => ref
                    .read(recommendationProvider.notifier)
                    .fetchRecommendations(),
                icon: const Icon(Icons.refresh, size: AppConstants.iconSizeSm),
                label: const Text('Aktualisieren'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeLayout(List<Recommendation> recommendations) {
    final currentIndex = ref.watch(recommendationIndexProvider);
    final isOldest = currentIndex == 0;
    final isLatest = currentIndex == recommendations.length - 1;
    const chevronSlotWidth = 44.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isOldest)
                const SizedBox(width: chevronSlotWidth)
              else
                CircleIconButton(
                  tapKey: RecommendationsScreen.previousRecommendationKey,
                  icon: Icons.chevron_left,
                  onPressed: () {
                    HapticService.light();
                    ref
                        .read(recommendationIndexProvider.notifier)
                        .set(currentIndex - 1);
                  },
                ),
              Text(
                '${currentIndex + 1} von ${recommendations.length} Empfehlungen',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
              if (isLatest)
                const SizedBox(width: chevronSlotWidth)
              else
                CircleIconButton(
                  tapKey: RecommendationsScreen.nextRecommendationKey,
                  icon: Icons.chevron_right,
                  onPressed: () {
                    HapticService.light();
                    ref
                        .read(recommendationIndexProvider.notifier)
                        .set(currentIndex + 1);
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: recommendations.length,
            onPageChanged: (index) {
              HapticService.light();
              ref.read(recommendationIndexProvider.notifier).set(index);
            },
            itemBuilder: (context, pageIndex) {
              // pageIndex 0 = oldest; pageIndex length-1 = latest.
              // Our list from the provider is newest-first, so convert:
              final listIndex = (recommendations.length - 1) - pageIndex;
              return _RecommendationPage(
                recommendation: recommendations[listIndex],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationPage extends StatelessWidget {
  const _RecommendationPage({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final createdAt = recommendation.createdAt;
    return ListView(
      padding: AppConstants.paddingMd,
      children: [
        if (createdAt != null) ...[
          Text(
            formatDateWeekday(createdAt),
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap12,
        ],
        RecommendationSummaryCard(recommendation: recommendation),
        AppConstants.gap20,
        const Text(
          'Empfehlungen',
          style: TextStyle(
            fontSize: AppTheme.fontSizeTitle,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        AppConstants.gap12,
        ...recommendation.recommendations.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacing10),
            child: RecommendationCard(item: item),
          ),
        ),
        AppConstants.gap24,
      ],
    );
  }
}
```

Notes for the implementer:
- The empty-state is copied as-is from the current implementation. If the existing file's empty-state diverges in details, match it exactly rather than the snippet above.
- `CircleIconButton` is the existing helper used by the diary screen — it accepts `tapKey`, `icon`, `onPressed`. Verify the import path (`../../widgets/common/circle_icon_button.dart`) matches the diary screen's.
- `HapticService.light()` is imported from `../../services/haptic_service.dart`.
- If `AppConstants.animNormal` doesn't exist under that name, use whichever animation-duration constant the diary uses.
- **No AppBar change** — no chevrons in the AppBar, no back-arrow customization. The default GoRouter back-arrow from the push is correct.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`. Expected: all pass (the new recommendations tests + every existing test). If any diary / entries / other provider tests regress, something is wrong — stop and report.

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze`. Expected: 0 issues.

- [ ] **Step 6: Run `dart format`**

Run: `dart format lib/screens/recommendations/recommendations_screen.dart test/screens/recommendations/recommendations_screen_test.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/recommendations/recommendations_screen.dart \
        test/screens/recommendations/recommendations_screen_test.dart
git add -u lib/screens/recommendations/widgets/recommendation_history.dart
# Only if the history test existed:
git add -u test/screens/recommendations/widgets/recommendation_history_test.dart 2>/dev/null || true

git commit -m "feat(recommendations): horizontal swipe between recommendations"
```

---

## Task 3: Manual smoke test (user performs)

- [ ] Open the dashboard → "Für dich" card → recommendations screen.
- [ ] Verify the latest recommendation is shown first. The indicator reads "N von N Empfehlungen". The next-chevron slot is empty (latest = rightmost). The previous-chevron slot is visible.
- [ ] Swipe leftward — no change (at the latest, nothing newer).
- [ ] Swipe rightward — slides to the previous recommendation. Indicator updates. Next chevron now visible; previous chevron disappears when you reach the oldest.
- [ ] Tap the previous chevron — slides to the older recommendation.
- [ ] Tap the next chevron — slides to the newer recommendation.
- [ ] Force a refresh (dismiss and re-open or pull-to-refresh if available) and observe the initial page is still the latest.
- [ ] If your account only has one recommendation, confirm both chevrons are hidden and the indicator reads "1 von 1".
- [ ] If the account has zero recommendations, the empty state still renders as before; the PageView is absent.
