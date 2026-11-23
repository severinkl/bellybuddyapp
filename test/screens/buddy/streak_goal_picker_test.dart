import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('streakGoalChoices: every goal above the current streak', () {
    expect(streakGoalChoices(0), [7, 14, 30, 50, 100]);
    expect(streakGoalChoices(10), [14, 30, 50, 100]);
    expect(streakGoalChoices(120), isEmpty);
    expect(streakGoalChoices(50), [100]);
  });

  test('recommendedStreakGoal: 14 while it is open, else the next one', () {
    expect(recommendedStreakGoal(streakGoalChoices(0)), 14);
    expect(recommendedStreakGoal(streakGoalChoices(13)), 14);
    expect(recommendedStreakGoal(streakGoalChoices(14)), 30);
    expect(recommendedStreakGoal(const []), isNull);
  });

  test('every goal has a label and a one-liner', () {
    for (final goal in kStreakGoalOptions) {
      expect(kStreakGoalLabels[goal], isNotEmpty);
      expect(kStreakGoalHints[goal], isNotEmpty);
    }
    expect(kStreakGoalLabels[100], 'Bauch-Legende');
  });

  testWidgets('picker tap calls onSelected', (t) async {
    int? got;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: StreakGoalPicker(currentStreak: 0, onSelected: (g) => got = g),
        ),
      ),
    );
    expect(find.text('Guter Start'), findsOneWidget);
    expect(find.text('Eine Woche zum Reinkommen'), findsOneWidget);
    expect(find.text('Das ganz große Ziel'), findsOneWidget);
    await t.tap(find.text('14 Tage'));
    expect(got, 14);
  });

  testWidgets('the Buddy\'s tip sits on the recommended goal', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakGoalPicker(currentStreak: 0, onSelected: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text('Mein Tipp'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('streak_goal_14')),
        matching: find.text('Mein Tipp'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a long-running streak: only the goals still ahead', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: StreakGoalPicker(currentStreak: 40, onSelected: (_) {}),
        ),
      ),
    );
    expect(find.text('30 Tage'), findsNothing);
    expect(find.text('50 Tage'), findsOneWidget);
    expect(find.text('100 Tage'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('streak_goal_50')),
        matching: find.text('Mein Tipp'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sheet returns tapped value', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    int? result;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async => result = await showStreakGoalSheet(
                c,
                currentStreak: 3,
                title: 'Neues Ziel',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Neues Ziel'), findsOneWidget);
    await t.tap(find.text('30 Tage'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(result, 30);
  });
}
