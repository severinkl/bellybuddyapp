import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:belly_buddy/screens/dashboard/widgets/streak_sheet.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';

import '../../../helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 11, 23, 13);

  BuddyStatus status({
    int streak = 3,
    int? goal = 14,
    int savers = 1,
    bool todayCounted = true,
  }) => buddyStatus(
    goal: goal,
    savers: savers,
    streak: streak,
    todayCounted: todayCounted,
    weekDays: {if (todayCounted) DateTime(2026, 11, 23)},
  );

  /// The goal row for [days] shows as the selected one.
  bool selected(WidgetTester tester, int days) => find
      .descendant(
        of: find.byKey(StreakGoalPicker.goalKey(days)),
        matching: find.byIcon(Icons.check_circle),
      )
      .evaluate()
      .isNotEmpty;

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

  testWidgets('„Dein Streak" shows the flame as an ember until today counts', (
    tester,
  ) async {
    List<String?> texts() => [
      for (final text in tester.widgetList<Text>(find.byType(Text))) text.data,
    ];
    // The count's flame (the week row's marks are flames too).
    FlameLook look() => tester
        .widget<StreakFlame>(
          find.byWidgetPredicate((w) => w is StreakFlame && !w.still),
        )
        .look;

    await pump(tester, status(todayCounted: true));
    expect(look(), FlameLook.lit);
    final litTexts = texts();

    await pump(tester, status(todayCounted: false));
    expect(look(), FlameLook.ember);
    // Neutral: no text of its own.
    expect(texts(), litTexts);
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

  testWidgets('„Ziel ändern" swaps in the goal list to choose from, the '
      'current goal selected, with „Ziel festlegen"', (tester) async {
    await pump(tester, status(goal: 30));

    await tester.ensureVisible(find.byKey(StreakSheet.changeGoalKey));
    await tester.tap(find.byKey(StreakSheet.changeGoalKey));
    await tester.pump();

    expect(find.text('Neues Streak-Ziel'), findsOneWidget);
    expect(find.text('7 Tage'), findsOneWidget);
    expect(find.text('Streak-Saver: 1'), findsNothing);
    expect(selected(tester, 30), isTrue);
    expect(selected(tester, 14), isFalse);
    expect(find.byKey(StreakGoalChooser.confirmKey), findsOneWidget);

    // A tap only selects; the list stays.
    await tester.tap(find.text('7 Tage'));
    await tester.pump();
    expect(find.text('Neues Streak-Ziel'), findsOneWidget);
    expect(selected(tester, 7), isTrue);
    expect(selected(tester, 30), isFalse);
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

  group('openStreakSheetAndSaveGoal', () {
    Future<void> open(WidgetTester tester, FakeBuddyNotifier buddy) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [buddyProvider.overrideWith(() => buddy)],
          child: MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => openStreakSheetAndSaveGoal(
                    context,
                    ref,
                    status: status(goal: 14, streak: 5),
                    today: today,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseThirty(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(StreakSheet.changeGoalKey));
      await tester.tap(find.byKey(StreakSheet.changeGoalKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 Tage'));
      await tester.pump();
      await tester.tap(find.byKey(StreakGoalChooser.confirmKey));
      await tester.pumpAndSettle();
    }

    testWidgets('saves the chosen goal', (tester) async {
      final buddy = FakeBuddyNotifier();
      await open(tester, buddy);
      expect(find.byType(StreakWeekRow), findsOneWidget);

      await chooseThirty(tester);

      expect(buddy.goals, [30]);
      expect(
        find.text('Das Ziel konnte nicht gespeichert werden.'),
        findsNothing,
      );
    });

    testWidgets('dismissed: saves nothing', (tester) async {
      final buddy = FakeBuddyNotifier();
      await open(tester, buddy);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Dein Streak'), findsNothing);
      expect(buddy.goals, isEmpty);
    });

    testWidgets('a failing save shows the SnackBar', (tester) async {
      final buddy = FakeBuddyNotifier()..failGoal = true;
      await open(tester, buddy);

      await chooseThirty(tester);

      expect(buddy.goals, [30]);
      expect(
        find.text('Das Ziel konnte nicht gespeichert werden.'),
        findsOneWidget,
      );
    });
  });
}
