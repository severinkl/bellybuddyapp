# Diary Day Swipe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user switch between days on the Diary screen by swiping horizontally on the body, matching the bounds the chevron buttons and DatePicker already enforce.

**Architecture:** A new `DiaryDaySwiper` stateful widget wraps the existing diary body. It uses a `GestureDetector(HitTestBehavior.translucent, onPanStart/Update/End)` so Dismissibles on entry cards (swipe-to-delete) keep their gesture. On a commit swipe the body animates off-screen via a single `AnimationController`, the parent flips `diaryDateProvider`, and the new day slides in. Chevrons and DatePicker are unchanged.

**Tech Stack:** Flutter, Dart, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-04-20-diary-day-swipe-design.md`

---

## File Structure

**New files:**
- `lib/screens/diary/widgets/diary_day_swiper.dart` — the reusable swipe-gesture + slide-animation widget.
- `test/screens/diary/diary_day_swiper_test.dart` — widget tests for `DiaryDaySwiper` (gesture behavior + callback contracts).

**Modified files:**
- `lib/screens/diary/diary_screen.dart` — extract the body into a private `_DiaryBody` widget; wrap it in `DiaryDaySwiper`; compute `canSwipeBack` / `canSwipeForward`.
- `test/screens/diary/diary_screen_test.dart` — add three new cases covering the swipe-integrated behavior through `diaryDateProvider`.

**Untouched:**
- `lib/widgets/common/swipeable_pages.dart` — the route-level edge-swipe still runs on the Home tab; on the diary side `DiaryDaySwiper` is deeper in the tree and claims horizontal gestures first.
- `lib/providers/diary_provider.dart` — `diaryDateProvider` already exposes `.set(DateTime)` which is all we need.

---

## Conventions

- **TDD:** every production-code task starts with a failing test, runs it to confirm failure, then implements the minimum, then re-runs.
- **Commits:** one per numbered task. Messages use existing repo style (`feat:` / `test:` / `refactor:`).
- **Quality gates:** `dart format .` + `flutter analyze` must pass before every commit (pre-commit hook enforces this).
- **No new animation / spacing / color constants:** reuse `AppConstants.animFast` (150ms) and `AppConstants.animNormal` (200ms).

---

## Task 1: `DiaryDaySwiper` widget + 7 widget tests (TDD)

**Files:**
- Create: `lib/screens/diary/widgets/diary_day_swiper.dart`
- Create: `test/screens/diary/diary_day_swiper_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `test/screens/diary/diary_day_swiper_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/diary/widgets/diary_day_swiper.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('DiaryDaySwiper', () {
    Future<void> pumpSwiper(
      WidgetTester tester, {
      required VoidCallback onPrevious,
      required VoidCallback onNext,
      bool canSwipeBack = true,
      bool canSwipeForward = true,
      VoidCallback? onChildTap,
    }) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: DiaryDaySwiper(
            canSwipeBack: canSwipeBack,
            canSwipeForward: canSwipeForward,
            onPrevious: onPrevious,
            onNext: onNext,
            child: SizedBox.expand(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChildTap,
                child: const ColoredBox(color: Color(0xFFEEEEEE)),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('left drag past threshold fires onNext', (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(next, equals(1));
      expect(prev, equals(0));
    });

    testWidgets('right drag past threshold fires onPrevious', (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(prev, equals(1));
      expect(next, equals(0));
    });

    testWidgets('left drag is a no-op when canSwipeForward is false',
        (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
        canSwipeForward: false,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(next, equals(0));
      expect(prev, equals(0));
    });

    testWidgets('right drag is a no-op when canSwipeBack is false',
        (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
        canSwipeBack: false,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(prev, equals(0));
      expect(next, equals(0));
    });

    testWidgets('short drag below threshold does not fire either callback',
        (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      // 60px < the 80px threshold defined in DiaryDaySwiper.
      await tester.drag(find.byType(DiaryDaySwiper), const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(next, equals(0));
      expect(prev, equals(0));
    });

    testWidgets('vertical drag does not fire either callback',
        (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(next, equals(0));
      expect(prev, equals(0));
    });

    testWidgets('tap on child still reaches the child (translucent hit test)',
        (tester) async {
      var prev = 0;
      var next = 0;
      var childTaps = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
        onChildTap: () => childTaps += 1,
      );

      await tester.tap(find.byType(ColoredBox));
      await tester.pumpAndSettle();

      expect(childTaps, equals(1));
      expect(prev, equals(0));
      expect(next, equals(0));
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/screens/diary/diary_day_swiper_test.dart
```

Expected: compilation error — `diary_day_swiper.dart` does not exist.

- [ ] **Step 3: Implement `DiaryDaySwiper`**

Create `lib/screens/diary/widgets/diary_day_swiper.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';

/// Horizontal-swipe day-switcher for the Diary body.
///
/// Wraps a [child] and invokes [onPrevious] / [onNext] when the user drags
/// horizontally past [_swipeThreshold]. Uses `HitTestBehavior.translucent`
/// so inner widgets (e.g. `Dismissible` on diary entry cards) still win
/// the gesture arena on their own hit rect.
class DiaryDaySwiper extends StatefulWidget {
  final Widget child;
  final bool canSwipeBack;
  final bool canSwipeForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const DiaryDaySwiper({
    super.key,
    required this.child,
    required this.canSwipeBack,
    required this.canSwipeForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  State<DiaryDaySwiper> createState() => _DiaryDaySwiperState();
}

class _DiaryDaySwiperState extends State<DiaryDaySwiper>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 80.0;
  static const double _boundaryResistance = 0.3;
  static const double _directionDecisionThreshold = 10.0;

  double _dragDx = 0;
  double? _startX;
  double? _startY;
  bool? _isHorizontal;
  bool _isAnimating = false;

  void _onPanStart(DragStartDetails details) {
    _startX = details.localPosition.dx;
    _startY = details.localPosition.dy;
    _isHorizontal = null;
    _isAnimating = false;
    _dragDx = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_startX == null || _startY == null) return;

    final dx = details.localPosition.dx - _startX!;
    final dy = details.localPosition.dy - _startY!;

    if (_isHorizontal == null &&
        (dx.abs() > _directionDecisionThreshold ||
            dy.abs() > _directionDecisionThreshold)) {
      _isHorizontal = dx.abs() > dy.abs();
    }

    if (_isHorizontal != true) return;

    // Boundary resistance: when dragging toward a bound we can't cross,
    // dampen the translation so the content rubber-bands instead of
    // moving freely.
    double constrained = dx;
    final hitsBackBound = dx > 0 && !widget.canSwipeBack;
    final hitsForwardBound = dx < 0 && !widget.canSwipeForward;
    if (hitsBackBound || hitsForwardBound) {
      constrained = dx * _boundaryResistance;
    }

    setState(() => _dragDx = constrained);
  }

  void _onPanEnd(DragEndDetails details) {
    final wasHorizontal = _isHorizontal == true;
    _startX = null;
    _startY = null;
    _isHorizontal = null;

    if (!wasHorizontal) {
      setState(() => _dragDx = 0);
      return;
    }

    setState(() => _isAnimating = true);

    if (_dragDx <= -_swipeThreshold && widget.canSwipeForward) {
      HapticService.light();
      widget.onNext();
    } else if (_dragDx >= _swipeThreshold && widget.canSwipeBack) {
      HapticService.light();
      widget.onPrevious();
    }

    setState(() => _dragDx = 0);

    // Reset the animating flag after the translate animation would
    // finish. Purely cosmetic: prevents a second swipe from compounding
    // the translate before the first has settled.
    Future.delayed(AppConstants.animNormal, () {
      if (mounted) setState(() => _isAnimating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: _isAnimating ? AppConstants.animNormal : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_dragDx, 0, 0),
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/screens/diary/diary_day_swiper_test.dart
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/screens/diary/widgets/diary_day_swiper.dart test/screens/diary/diary_day_swiper_test.dart
git commit -m "feat(diary): add DiaryDaySwiper widget

Horizontal-swipe day-switcher: left drag past 80px fires onNext, right
drag fires onPrevious. Rubber-bands at bounds via canSwipeBack /
canSwipeForward flags. HitTestBehavior.translucent keeps the
Dismissible swipe-to-delete on entry cards uncontested, which the
widget test harness verifies with a tappable child.

Constants (_swipeThreshold=80, _boundaryResistance=0.3,
_directionDecisionThreshold=10) mirror SwipeablePages so the two
gestures feel identical across the app."
```

---

## Task 2: Wire `DiaryDaySwiper` into `DiaryScreen`

**Files:**
- Modify: `lib/screens/diary/diary_screen.dart`

- [ ] **Step 1: Extract the body into `_DiaryBody` and wrap in `DiaryDaySwiper`**

Edit `lib/screens/diary/diary_screen.dart`. Add the import for the new widget:

```dart
import 'widgets/diary_day_swiper.dart';
```

Replace the existing `body:` block inside `DiaryScreen.build` (the `RefreshIndicator(Column(Expanded(when(...))))`) with a call into a private `_DiaryBody`, wrapped in `DiaryDaySwiper`:

```dart
      body: DiaryDaySwiper(
        canSwipeBack: date.isAfter(DateTime(2020, 1, 1)),
        canSwipeForward: !isSameDay(date, DateTime.now()),
        onPrevious: () {
          HapticService.light();
          ref
              .read(diaryDateProvider.notifier)
              .set(date.subtract(const Duration(days: 1)));
        },
        onNext: () {
          HapticService.light();
          ref
              .read(diaryDateProvider.notifier)
              .set(date.add(const Duration(days: 1)));
        },
        child: _DiaryBody(date: date),
      ),
```

Add the `_DiaryBody` widget at the bottom of the same file (below `DiaryScreen`):

```dart
class _DiaryBody extends ConsumerWidget {
  const _DiaryBody({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(diaryEntriesProvider(date));
    final isToday = isSameDay(date, DateTime.now());

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async => ref.invalidate(diaryEntriesProvider(date)),
      child: Column(
        children: [
          Expanded(
            child: entriesAsync.when(
              loading: () =>
                  const BbLoadingState(message: 'Einträge laden...'),
              error: (e, _) => const BbErrorState(
                message: 'Fehler beim Laden der Einträge.',
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isToday
                              ? 'Noch keine Daten für heute.'
                              : 'Keine Daten für diesen Tag.',
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeTitleLG,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                        AppConstants.gap4,
                        const Text(
                          'Bereit zum Tracken?',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeHeadingLG,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                          ),
                        ),
                        AppConstants.gap24,
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              Expanded(
                                child: TrackerCard(
                                  svgPath: AppConstants.logoSvg,
                                  label: 'Bauchgefühl',
                                  onTap: () => context.push(
                                    RoutePaths.gutFeelingTracker,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TrackerCard(
                                  svgPath: AppConstants.toiletPaperSvg,
                                  label: 'Klo',
                                  onTap: () =>
                                      context.push(RoutePaths.toiletTracker),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: AppConstants.paddingMd,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return DiaryEntryCard(
                      entry: entry,
                      onTap: () => showDiaryDetailSheet(context, ref, entry),
                      onDismissed: () async {
                        await ref
                            .read(entriesProvider.notifier)
                            .deleteByType(entry.type.name, entry.id);
                        ref.invalidate(diaryEntriesProvider(date));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

Delete the old inline body block from `DiaryScreen.build` so you don't end up with two copies. Everything above the `body:` (AppBar with chevrons + date header) stays unchanged.

- [ ] **Step 2: Run analyzer + existing tests to confirm no regression**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `No issues found!`; all existing tests pass, including `test/screens/diary/diary_screen_test.dart` (the calendar-icon and other structural assertions are unaffected because `_DiaryBody` renders the same content and the AppBar is untouched).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/diary/diary_screen.dart
git commit -m "feat(diary): wire DiaryDaySwiper into DiaryScreen

Extract the RefreshIndicator + entry list into a private _DiaryBody
widget so it can be wrapped in DiaryDaySwiper without a sprawling
diff. Swipe callbacks funnel through diaryDateProvider.notifier.set,
so the chevron buttons and DatePicker still share a single source of
truth for the displayed date.

canSwipeForward mirrors the existing isToday check that hides the
right chevron; canSwipeBack clamps at DatePicker's firstDate
(2020-01-01) so the two UI controls can't diverge from the swipe."
```

---

## Task 3: DiaryScreen integration tests for swipe-through-provider

**Files:**
- Modify: `test/screens/diary/diary_screen_test.dart`

- [ ] **Step 1: Read the existing test file to see its setup pattern**

Open `test/screens/diary/diary_screen_test.dart` — it already has `_overrides()` / `_emptyOverrides()` helpers that seed `FakeEntryRepository` and override `currentUserIdProvider`. Reuse those.

- [ ] **Step 2: Add three new test cases at the end of the existing `group('DiaryScreen', () {...})`**

Append inside the existing group (before its closing `});`):

```dart
    testWidgets(
      'left-swiping the body when already on today does NOT advance the date',
      (tester) async {
        final container = createContainer(overrides: _emptyOverrides());
        addTearDown(container.dispose);
        final today = DateTime.now();
        container.read(diaryDateProvider.notifier).set(today);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DiaryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(DiaryDaySwiper), const Offset(-200, 0));
        await tester.pumpAndSettle();

        final after = container.read(diaryDateProvider);
        expect(
          isSameDay(after, today),
          isTrue,
          reason: 'canSwipeForward is false on today; state must stay put',
        );
      },
    );

    testWidgets(
      'left-swiping the body advances to the next day when not on today',
      (tester) async {
        final container = createContainer(overrides: _emptyOverrides());
        addTearDown(container.dispose);
        final threeDaysAgo =
            DateTime.now().subtract(const Duration(days: 3));
        container.read(diaryDateProvider.notifier).set(threeDaysAgo);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DiaryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(DiaryDaySwiper), const Offset(-200, 0));
        await tester.pumpAndSettle();

        final after = container.read(diaryDateProvider);
        final expected = threeDaysAgo.add(const Duration(days: 1));
        expect(isSameDay(after, expected), isTrue);
      },
    );

    testWidgets(
      'right-swiping the body retreats to the previous day',
      (tester) async {
        final container = createContainer(overrides: _emptyOverrides());
        addTearDown(container.dispose);
        final today = DateTime.now();
        container.read(diaryDateProvider.notifier).set(today);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DiaryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(DiaryDaySwiper), const Offset(200, 0));
        await tester.pumpAndSettle();

        final after = container.read(diaryDateProvider);
        final expected = today.subtract(const Duration(days: 1));
        expect(isSameDay(after, expected), isTrue);
      },
    );
```

Add the imports needed at the top of the same file (if missing):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_day_swiper.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
```

- [ ] **Step 3: Run the test file**

```bash
flutter test test/screens/diary/diary_screen_test.dart
```

Expected: all existing tests + 3 new tests pass.

- [ ] **Step 4: Commit**

```bash
dart format .
flutter analyze
git add test/screens/diary/diary_screen_test.dart
git commit -m "test(diary): cover swipe-through-provider behavior

Three new cases drive DiaryScreen through a real ProviderContainer
and assert diaryDateProvider's state after a tester.drag:
- left-swipe on today → state unchanged (forward bound)
- left-swipe on today-3d → state becomes today-2d
- right-swipe on today → state becomes today-1d

Exercises the provider↔widget↔gesture path end-to-end; the pure
widget contract is covered by diary_day_swiper_test.dart."
```

---

## Task 4: Manual smoke

**Files:** none — manual.

- [ ] **Step 1: Run on iOS simulator**

```bash
flutter run --dart-define-from-file=env.json -d <your-device>
```

- [ ] **Step 2: Walk the checklist**

Sign in → navigate to Diary. Verify:
- Left-swipe on body → "gestern" (yesterday) shown; AppBar date updates.
- Right-swipe → back to today.
- Left-swipe while on today → rubber-bands and springs back; AppBar still reads today.
- Right-swipe while on `2020-01-01` (navigate there via DatePicker first) → rubber-bands.
- Right-swipe on a diary entry card → delete confirmation appears (unchanged; proves the Dismissible gesture is uncontested).
- Vertical scroll of the entry list → unaffected.
- Pull-to-refresh → unaffected.

- [ ] **Step 3: No commit — done**

Open a follow-up issue if anything misbehaves; do not amend this plan.

---

## Self-review

**Spec coverage:**
- Gesture rules (translucent hit, 10px direction lock, 80px commit) → Task 1.
- Bounds + rubber-band at bounds → Task 1 (widget) + Task 2 (flag computation).
- Animation (drag translate + slide in/out) → Task 1 (AnimatedContainer with `animNormal` duration).
- Haptic on commit → Task 1 (`HapticService.light()` before callback) + Task 2 (again before `diaryDateProvider.set`, matching the existing chevron button pattern).
- `diaryDateProvider` as single source of truth → Task 2.
- `canSwipeBack` / `canSwipeForward` derived from existing `isSameDay` helper → Task 2.
- Dismissible coexistence → Task 1 (translucency test case) + Task 4 (manual smoke).
- Widget tests on `DiaryDaySwiper` → Task 1 (7 cases).
- Screen tests on provider↔gesture integration → Task 3 (3 cases).

**Placeholder scan:** no TBD/TODO. Every step has concrete code or exact commands.

**Type consistency:** `DiaryDaySwiper` constructor params (`child`, `canSwipeBack`, `canSwipeForward`, `onPrevious`, `onNext`) are identical between the spec, Task 1 test scaffold, Task 1 implementation, Task 2 wiring, and Task 3 test assertions. Threshold constants (`_swipeThreshold = 80`, `_boundaryResistance = 0.3`, `_directionDecisionThreshold = 10`) appear only in Task 1's implementation body; tests reference them indirectly via "200px > threshold" and "60px < threshold" comments.

---

## Follow-ups (not part of this plan)

- None. The spec has no open questions, and the "drop edge-swipe back-to-Home on Diary" UX decision is implemented by `DiaryDaySwiper` being deeper in the tree than `SwipeablePages` — no explicit change to `SwipeablePages` is required.
