import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('streakGoalChoices', () {
    expect(streakGoalChoices(0), [7, 14, 30]);
    expect(streakGoalChoices(10), [14, 30, 50]);
    expect(streakGoalChoices(120), isEmpty);
    expect(streakGoalChoices(50), [100]);
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
    await t.tap(find.text('14 Tage'));
    expect(got, 14);
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
