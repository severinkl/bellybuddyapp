# Diary Day Swipe (PageView Refactor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom `DiaryDaySwiper` with a `PageView.builder`-based swipe so that swiping the diary is smooth, the day label slides with the body, and the target day is visible during the drag.

**Architecture:** `DiaryScreen` owns a `PageController` indexed by "days since 2020-01-01" and caps `itemCount` at `daysSince(today) + 1`. The AppBar keeps only the chevrons (navigation affordances). Each page (`_DiaryPage`) renders its own tappable date-label row + the existing body for that date. `diaryDateProvider` remains the single source of truth: `onPageChanged` writes to it; chevron taps and DatePicker writes trigger `ref.listen` → `controller.animateToPage(...)`.

**Tech Stack:** Flutter `PageView.builder`, Riverpod `ref.listen`, existing `diaryDateProvider`, `HapticService`.

---

## File Structure

- Rewrite: `lib/screens/diary/diary_screen.dart` — convert to `ConsumerStatefulWidget`, swap body for `PageView.builder`, move date-label row into new `_DiaryPage` widget in the same file.
- Delete: `lib/screens/diary/widgets/diary_day_swiper.dart` — superseded by PageView.
- Delete: `test/screens/diary/diary_day_swiper_test.dart` — widget no longer exists.
- Rewrite: `test/screens/diary/diary_screen_test.dart` — three swipe tests now drag on `PageView` and assert via `diaryDateProvider`.

---

## Task 1: Refactor DiaryScreen to PageView and clean up

**Files:**
- Rewrite: `lib/screens/diary/diary_screen.dart`
- Delete: `lib/screens/diary/widgets/diary_day_swiper.dart`
- Delete: `test/screens/diary/diary_day_swiper_test.dart`
- Rewrite: `test/screens/diary/diary_screen_test.dart`

- [ ] **Step 1: Rewrite the screen test file with the new behavior (still-red phase)**

Replace the entire contents of `test/screens/diary/diary_screen_test.dart` with:

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/screens/diary/diary_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

List<Override> _emptyOverrides() => [
  entryRepositoryProvider.overrideWithValue(
    FakeEntryRepository()..seedResult(
      testEntryQueryResult(
        meals: [],
        toiletEntries: [],
        gutFeelings: [],
        drinks: [],
      ),
    ),
  ),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('DiaryScreen', () {
    testWidgets('renders calendar icon', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('renders diary entries for today', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Testmahlzeit'), findsOneWidget);
    });

    testWidgets('shows empty state message when no entries', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _emptyOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Noch keine Daten für heute.'), findsOneWidget);
    });

    testWidgets('renders navigation chevrons', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets(
      'swiping the PageView left when already on today does NOT advance the date',
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

        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();

        final after = container.read(diaryDateProvider);
        expect(
          isSameDay(after, today),
          isTrue,
          reason: 'today is the last page; PageView has no forward neighbor',
        );
      },
    );

    testWidgets(
      'swiping the PageView left advances to the next day when not on today',
      (tester) async {
        final container = createContainer(overrides: _emptyOverrides());
        addTearDown(container.dispose);
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        container.read(diaryDateProvider.notifier).set(threeDaysAgo);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DiaryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();

        final after = container.read(diaryDateProvider);
        final expected = threeDaysAgo.add(const Duration(days: 1));
        expect(isSameDay(after, expected), isTrue);
      },
    );

    testWidgets('swiping the PageView right retreats to the previous day', (
      tester,
    ) async {
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

      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();

      final after = container.read(diaryDateProvider);
      final expected = today.subtract(const Duration(days: 1));
      expect(isSameDay(after, expected), isTrue);
    });

    testWidgets('tapping the next-day chevron animates the PageView forward', (
      tester,
    ) async {
      final container = createContainer(overrides: _emptyOverrides());
      addTearDown(container.dispose);
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      container.read(diaryDateProvider.notifier).set(twoDaysAgo);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DiaryScreen.nextDayKey));
      await tester.pumpAndSettle();

      final after = container.read(diaryDateProvider);
      final expected = twoDaysAgo.add(const Duration(days: 1));
      expect(isSameDay(after, expected), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

Run: `flutter test test/screens/diary/diary_screen_test.dart`
Expected: the three swipe tests and the chevron-animation test fail because `DiaryDaySwiper` still exists and `PageView` is not yet wired in. (Static rendering tests may pass or fail depending on order — either outcome is fine; the point is the new behavior is not yet present.)

- [ ] **Step 3: Delete the obsolete widget and its test file**

```bash
rm lib/screens/diary/widgets/diary_day_swiper.dart
rm test/screens/diary/diary_day_swiper_test.dart
```

- [ ] **Step 4: Rewrite `lib/screens/diary/diary_screen.dart`**

Replace the entire file contents with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/diary_provider.dart';
import '../../providers/entries_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../utils/date_format_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/tracker_card.dart';
import 'widgets/diary_detail_sheets.dart';
import 'widgets/diary_entry_card.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  static const previousDayKey = Key('diary_previous_day');
  static const nextDayKey = Key('diary_next_day');

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  static final DateTime _firstDate = DateTime(2020, 1, 1);
  late final PageController _controller;
  late final DateTime _today;

  int _indexFor(DateTime date) =>
      DateTime(date.year, date.month, date.day).difference(_firstDate).inDays;

  DateTime _dateAt(int index) => _firstDate.add(Duration(days: index));

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _controller = PageController(
      initialPage: _indexFor(ref.read(diaryDateProvider)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(diaryDateProvider);
    final isToday = isSameDay(date, _today);
    final pageCount = _indexFor(_today) + 1;

    ref.listen<DateTime>(diaryDateProvider, (_, next) {
      if (!_controller.hasClients) return;
      final target = _indexFor(next);
      final current = (_controller.page ?? _controller.initialPage.toDouble())
          .round();
      if (current == target) return;
      _controller.animateToPage(
        target,
        duration: AppConstants.animNormal,
        curve: Curves.easeOut,
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: AppConstants.spacingMd,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleIconButton(
              tapKey: DiaryScreen.previousDayKey,
              icon: Icons.chevron_left,
              onPressed: () {
                HapticService.light();
                ref
                    .read(diaryDateProvider.notifier)
                    .set(date.subtract(const Duration(days: 1)));
              },
            ),
            if (isToday)
              const SizedBox(width: 44)
            else
              CircleIconButton(
                tapKey: DiaryScreen.nextDayKey,
                icon: Icons.chevron_right,
                onPressed: () {
                  HapticService.light();
                  ref
                      .read(diaryDateProvider.notifier)
                      .set(date.add(const Duration(days: 1)));
                },
              ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: pageCount,
        onPageChanged: (index) {
          HapticService.light();
          ref.read(diaryDateProvider.notifier).set(_dateAt(index));
        },
        itemBuilder: (context, index) => _DiaryPage(date: _dateAt(index)),
      ),
    );
  }
}

class _DiaryPage extends ConsumerWidget {
  const _DiaryPage({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingSm,
            AppConstants.spacingMd,
            AppConstants.spacingSm,
          ),
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('de', 'DE'),
              );
              if (picked != null) {
                HapticService.light();
                ref.read(diaryDateProvider.notifier).set(picked);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    formatDateWeekday(date),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeSubtitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _DiaryBody(date: date)),
      ],
    );
  }
}

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
      child: entriesAsync.when(
        loading: () => const BbLoadingState(message: 'Einträge laden...'),
        error: (e, _) =>
            const BbErrorState(message: 'Fehler beim Laden der Einträge.'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: TrackerCard(
                            svgPath: AppConstants.logoSvg,
                            label: 'Bauchgefühl',
                            onTap: () =>
                                context.push(RoutePaths.gutFeelingTracker),
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
    );
  }
}
```

Note: the old `DiaryScreen.displayedDateKey` is intentionally removed — with multiple pages built simultaneously a single static key would be non-unique. Tests now assert via `diaryDateProvider` state instead.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (566+ tests, minus the 7 from the deleted `diary_day_swiper_test.dart`).

- [ ] **Step 6: Run `flutter analyze`**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 7: Run `dart format`**

Run: `dart format lib/screens/diary/diary_screen.dart test/screens/diary/diary_screen_test.dart`
Expected: no changes or formatting applied cleanly.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/diary/diary_screen.dart \
        test/screens/diary/diary_screen_test.dart
git add -u lib/screens/diary/widgets/diary_day_swiper.dart \
           test/screens/diary/diary_day_swiper_test.dart
git commit -m "refactor(diary): swap custom swiper for PageView"
```

---

## Task 2: Manual smoke test (user performs)

- [ ] On device, open the diary on today.
- [ ] Swipe left → rubber-bands (PageView's default over-scroll), stays on today.
- [ ] Tap the date picker, jump to an earlier day, swipe left → advances smoothly; date label slides with the body; next day's label peeks during the drag.
- [ ] Swipe right → retreats one day.
- [ ] Add/confirm an entry card with swipe-to-delete — the `Dismissible` gesture on the card should still fire (horizontal-drag gesture arena favours the inner `Dismissible`).
- [ ] Confirm chevron taps in the AppBar animate the PageView smoothly to the neighbour day.
