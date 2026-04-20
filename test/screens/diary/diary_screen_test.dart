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

      // Fling rather than drag: at the last page, a 400px drag sits right on
      // PageView's commit threshold and non-deterministically snaps back. A
      // 1000 px/s fling crosses the threshold cleanly.
      await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
      await tester.pumpAndSettle();

      final after = container.read(diaryDateProvider);
      final expected = today.subtract(const Duration(days: 1));
      expect(isSameDay(after, expected), isTrue);
    });

    testWidgets('hides the previous-day chevron on the first available day', (
      tester,
    ) async {
      final container = createContainer(overrides: _emptyOverrides());
      addTearDown(container.dispose);
      container.read(diaryDateProvider.notifier).set(DateTime(2020, 1, 1));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(DiaryScreen.previousDayKey), findsNothing);
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
