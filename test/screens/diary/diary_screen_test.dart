// ignore_for_file: invalid_use_of_internal_member
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/screens/diary/diary_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/common/bb_card.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_entry_card.dart';

import '../../helpers/app_lifecycle.dart';
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

      expect(find.text('Noch keine Einträge für heute.'), findsOneWidget);
      expect(
        find.text('Tipp unten aufs Plus, dann tragen wir was ein!'),
        findsOneWidget,
      );
      expect(find.byType(MascotImage), findsOneWidget);
    });

    testWidgets("the day's totals stand above its entries", (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(DiaryScreen.totalsKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(DiaryScreen.totalsKey)).dy,
        lessThan(tester.getTopLeft(find.byType(DiaryEntryCard).first).dy),
      );
    });

    testWidgets('an empty day shows no totals', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _emptyOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(DiaryScreen.totalsKey), findsNothing);
    });

    testWidgets('fits 375×667 at text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(DiaryScreen.totalsKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(DiaryScreen.totalsKey)).data,
        '1× Essen · 250 ml getrunken · 1× Bauchgefühl · 1× Klo',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('VoiceOver reads the day arrows by name', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byIcon(Icons.chevron_left)).label,
        'Vorheriger Tag',
      );
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byIcon(Icons.chevron_right)).label,
        'Nächster Tag',
      );
      semantics.dispose();
    });

    testWidgets('an entry card is a button named by its title and subtitle', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find
            .descendant(
              of: find.widgetWithText(DiaryEntryCard, 'Testmahlzeit'),
              matching: find.byType(BbCard),
            )
            .first,
      );
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, contains('Testmahlzeit'));
      expect(node.label, contains('2 Zutaten'));
      semantics.dispose();
    });

    testWidgets('a long subtitle shows on two lines', (tester) async {
      final entry = DiaryEntry(
        id: 'm',
        type: DiaryEntryType.meal,
        trackedAt: DateTime(2026, 3, 25, 12),
        title: 'Titel',
        subtitle: List.filled(30, 'Zutat').join(', '),
        data: MealDiaryData(testMealEntry()),
      );
      await tester.pumpWithProviders(
        SizedBox(
          width: 320,
          child: DiaryEntryCard(entry: entry, onTap: () {}),
        ),
        overrides: _overrides(),
      );
      final text = tester.widget<Text>(find.text(entry.subtitle));
      expect(text.maxLines, 2);
      expect(
        tester.getSize(find.text(entry.subtitle)).height,
        greaterThan(tester.getSize(find.text('Titel')).height * 1.5),
      );
    });

    testWidgets(
      'the day arrows are 48 × 48 „Vorheriger Tag" / „Nächster Tag"',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWithProviders(
          const DiaryScreen(),
          overrides: _overrides(),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.byKey(DiaryScreen.previousDayKey)).label,
          'Vorheriger Tag',
        );
        expect(
          tester.getSize(find.byKey(DiaryScreen.previousDayKey)),
          const Size(48, 48),
        );
        await tester.tap(find.byKey(DiaryScreen.previousDayKey));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(DiaryScreen.nextDayKey)).label,
          'Nächster Tag',
        );
        expect(
          tester.getSize(find.byKey(DiaryScreen.nextDayKey)),
          const Size(48, 48),
        );
        semantics.dispose();
      },
    );

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

  group('DiaryScreen after midnight (kept alive by the shell)', () {
    // Today, just before midnight; the clock moves on in each test.
    final real = DateTime.now();
    final lateEvening = DateTime(real.year, real.month, real.day, 23, 50);
    final nextDay = DateTime(real.year, real.month, real.day + 1);
    late DateTime now;

    Future<ProviderContainer> pumpDiary(WidgetTester tester) async {
      now = lateEvening;
      final container = createContainer(
        overrides: [
          ..._emptyOverrides(),
          buddyClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.read(diaryDateProvider.notifier).set(startOfDay(lateEvening));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(formatDateWeekday(lateEvening)), findsOneWidget);
      expect(find.byKey(DiaryScreen.nextDayKey), findsNothing);
      return container;
    }

    void expectShowsNewToday() {
      expect(find.text(formatDateWeekday(nextDay)), findsOneWidget);
      expect(find.text('Noch keine Einträge für heute.'), findsOneWidget);
      expect(find.byKey(DiaryScreen.nextDayKey), findsNothing);
    }

    testWidgets('opened on the new today (Tagebuch tab), it shows that day', (
      tester,
    ) async {
      final container = await pumpDiary(tester);

      now = nextDay.add(const Duration(minutes: 10));
      // As the Tagebuch tab does.
      container.read(diaryDateProvider.notifier).set(startOfDay(now));
      await tester.pumpAndSettle();

      expectShowsNewToday();
      expect(container.read(diaryDateProvider), nextDay);
    });

    testWidgets('back in the app after midnight, the next day can be '
        'reached', (tester) async {
      final container = await pumpDiary(tester);

      now = nextDay.add(const Duration(minutes: 10));
      returnFromBackground();
      await tester.pumpAndSettle();

      // Still on the day it showed, now yesterday.
      expect(find.text('Keine Einträge an diesem Tag.'), findsOneWidget);
      await tester.tap(find.byKey(DiaryScreen.nextDayKey));
      await tester.pumpAndSettle();

      expectShowsNewToday();
      expect(container.read(diaryDateProvider), nextDay);
    });
  });
}
