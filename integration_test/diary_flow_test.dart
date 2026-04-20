import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:belly_buddy/screens/diary/diary_screen.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('diary tab shows entries for the selected date', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final diaryNavItem = find.byKey(BbBottomNav.navDiaryKey);

    expect(diaryNavItem, findsOneWidget);

    await tester.ensureVisible(diaryNavItem);
    await tester.pumpAndSettle();

    await tester.tap(diaryNavItem);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);

    final hasEntries = find
        .textContaining('Testmahlzeit')
        .evaluate()
        .isNotEmpty;
    final hasEmptyState =
        find.textContaining('Tracken').evaluate().isNotEmpty ||
        find.textContaining('Daten').evaluate().isNotEmpty;

    expect(hasEntries || hasEmptyState, isTrue);
  });

  testWidgets('diary date navigation changes the displayed date', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final diaryNavItem = find.byKey(BbBottomNav.navDiaryKey);
    expect(diaryNavItem, findsOneWidget);

    await tester.ensureVisible(diaryNavItem);
    await tester.pumpAndSettle();

    await tester.tap(diaryNavItem);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    expect(find.text(formatDateWeekday(today)), findsWidgets);

    final prevDayFinder = find.byKey(DiaryScreen.previousDayKey);
    expect(prevDayFinder, findsOneWidget);

    await tester.ensureVisible(prevDayFinder);
    await tester.pumpAndSettle();

    await tester.tap(prevDayFinder);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);
    expect(find.text(formatDateWeekday(yesterday)), findsWidgets);
  });
}
