// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/screens/diary/diary_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_day_swiper.dart';
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

      // FakeEntryRepository returns testMealEntry (title: Testmahlzeit)
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

    testWidgets('renders navigation arrows', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

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
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
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

    testWidgets('right-swiping the body retreats to the previous day', (
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

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(200, 0));
      await tester.pumpAndSettle();

      final after = container.read(diaryDateProvider);
      final expected = today.subtract(const Duration(days: 1));
      expect(isSameDay(after, expected), isTrue);
    });
  });
}
