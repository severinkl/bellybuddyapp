import 'package:belly_buddy/config/entry_tables.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/screens/diary/diary_screen.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_entry_card.dart';
import 'package:belly_buddy/screens/trackers/toilet/toilet_tracker_screen.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fakes.dart';
import 'helpers/test_app.dart';

/// Keeps the Klo entries the app writes and returns, for each day, the ones
/// tracked on it, so the diary shows what was just entered.
class _DayEntryRepository extends FakeEntryRepository {
  final toiletEntries = <ToiletEntry>[];

  @override
  Future<void> insertEntry(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) async {
    await super.insertEntry(table, data, userId: userId);
    if (table == entryTableFor['toilet']) {
      toiletEntries.add(ToiletEntry.fromJson(data));
    }
  }

  @override
  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) async => EntryQueryResult(
    meals: const [],
    toiletEntries: [
      for (final entry in toiletEntries)
        if (isSameDay(entry.trackedAt, date)) entry,
    ],
    gutFeelings: const [],
    drinks: const [],
  );
}

Future<void> _openDiary(WidgetTester tester) async {
  final diaryNavItem = find.byKey(BbBottomNav.navDiaryKey);
  expect(diaryNavItem, findsOneWidget);
  await tester.tap(diaryNavItem);
  await tester.pumpAndSettle();
  expect(find.byType(DiaryScreen), findsOneWidget);
}

Future<void> _goToPreviousDay(WidgetTester tester) async {
  final prevDay = find.byKey(DiaryScreen.previousDayKey);
  expect(prevDay, findsOneWidget);
  await tester.tap(prevDay);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  DateTime today() => startOfDay(DateTime.now());
  DateTime yesterday() {
    final t = today();
    return DateTime(t.year, t.month, t.day - 1);
  }

  testWidgets('diary tab shows the entries of the selected day', (
    tester,
  ) async {
    // The default fake returns its seeded entries for every day.
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await _openDiary(tester);

    expect(
      find.descendant(
        of: find.byType(DiaryScreen),
        matching: find.text('Testmahlzeit'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('diary date navigation changes the displayed date', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await _openDiary(tester);
    expect(find.text(formatDateWeekday(today())), findsWidgets);

    await _goToPreviousDay(tester);

    expect(find.byType(DiaryScreen), findsOneWidget);
    expect(find.text(formatDateWeekday(yesterday())), findsWidgets);
  });

  testWidgets(
    'a Klo entry from yesterday\'s page lands on yesterday at 12:00',
    (tester) async {
      final repo = _DayEntryRepository();
      await tester.pumpWidget(buildTestApp(entryRepo: repo));
      await tester.pumpAndSettle();

      await _openDiary(tester);
      await _goToPreviousDay(tester);
      final day = yesterday();
      expect(find.text(formatDateWeekday(day)), findsWidgets);
      expect(find.text('Keine Einträge an diesem Tag.'), findsOneWidget);

      // The plus logs for the day the diary shows.
      await tester.tap(find.byKey(BbBottomNav.centerButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Für ${formatLogTargetDay(day)}'), findsOneWidget);
      await tester.tap(find.byKey(LogSheet.optionKey(CareNeed.toilet)));
      await tester.pumpAndSettle();

      expect(find.byType(ToiletTrackerScreen), findsOneWidget);
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      // Dismiss by tapping the message: a tap in the middle would land on
      // the Buddy, who is interactive and gets poked instead.
      final saved = find.text('Klo-Eintrag gespeichert!');
      expect(saved, findsOneWidget);
      await tester.tap(saved);
      await tester.pumpAndSettle();
      expect(find.byType(BbSuccessOverlay), findsNothing);

      // Back on yesterday's page, which now shows the entry at 12:00.
      expect(find.byType(DiaryScreen), findsOneWidget);
      expect(find.text(formatDateWeekday(day)), findsWidgets);
      final card = find.byType(DiaryEntryCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Klo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('12:00')),
        findsOneWidget,
      );
      expect(
        repo.toiletEntries.single.trackedAt,
        DateTime(day.year, day.month, day.day, 12),
      );
    },
  );
}
