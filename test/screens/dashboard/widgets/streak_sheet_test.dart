import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/screens/dashboard/widgets/streak_sheet.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

void main() {
  final today = DateTime(2026, 11, 23, 13);

  BuddyStatus status({int streak = 3, int? goal = 14, int savers = 1}) =>
      BuddyStatus(
        state: BuddyState(
          userId: 'u1',
          name: 'Bubu',
          streakGoal: goal,
          savers: savers,
        ),
        hasRow: true,
        streak: streak,
        todayCounted: true,
        weekDays: {DateTime(2026, 11, 23)},
      );

  Future<void> pump(WidgetTester tester, BuddyStatus s) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: StreakSheet(status: s, today: today),
        ),
      ),
    );
  }

  testWidgets('shows the streak, this week, the goal and the savers', (
    tester,
  ) async {
    await pump(tester, status());

    expect(find.text('Dein Streak'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(StreakWeekRow), findsOneWidget);
    expect(find.text('Ziel: 14 Tage'), findsOneWidget);
    expect(find.text('Stark · 3 von 14'), findsOneWidget);
    expect(find.text('Streak-Saver: 1'), findsOneWidget);
    expect(find.text(StreakSheet.saverText), findsOneWidget);
    expect(find.text('Ziel ändern'), findsOneWidget);
  });

  testWidgets('no goal yet → „Noch kein Ziel" and „Ziel festlegen"', (
    tester,
  ) async {
    await pump(tester, status(goal: null));

    expect(find.text('Noch kein Ziel'), findsOneWidget);
    expect(find.text('Ziel festlegen'), findsOneWidget);
  });

  testWidgets('goal reached → „Geschafft!"', (tester) async {
    await pump(tester, status(streak: 14));

    expect(find.text('Geschafft! 🎉'), findsOneWidget);
  });

  testWidgets('„Ziel ändern" swaps in the goal list', (tester) async {
    await pump(tester, status());

    await tester.ensureVisible(find.byKey(StreakSheet.changeGoalKey));
    await tester.tap(find.byKey(StreakSheet.changeGoalKey));
    await tester.pump();

    expect(find.text('Neues Streak-Ziel'), findsOneWidget);
    expect(find.text('7 Tage'), findsOneWidget);
    expect(find.text('Streak-Saver: 1'), findsNothing);
  });

  testWidgets('text scale 1.3 on a small phone: no overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: StreakSheet(status: status(), today: today),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
