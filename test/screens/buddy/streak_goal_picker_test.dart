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

  /// The row for [days] shows as selected: its check and its semantics.
  void expectSelected(WidgetTester t, int days, {required bool selected}) {
    final row = find.byKey(StreakGoalPicker.goalKey(days));
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.check_circle)),
      selected ? findsOneWidget : findsNothing,
      reason: '$days',
    );
    expect(
      t.getSemantics(row),
      isSemantics(
        isChecked: selected,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
      reason: '$days',
    );
  }

  testWidgets('a single choice: a tap selects the goal, only it shows as '
      'selected', (t) async {
    final handle = t.ensureSemantics();
    int? selected = 14;
    final changes = <int>[];
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (_, setState) => StreakGoalPicker(
                currentStreak: 0,
                selected: selected,
                onChanged: (g) => setState(() {
                  changes.add(g);
                  selected = g;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Guter Start'), findsOneWidget);
    expect(find.text('Eine Woche zum Reinkommen'), findsOneWidget);
    expect(find.text('Das ganz große Ziel'), findsOneWidget);
    expectSelected(t, 14, selected: true);
    expectSelected(t, 30, selected: false);

    await t.tap(find.text('30 Tage'));
    await t.pump();
    expect(changes, [30]);
    expectSelected(t, 30, selected: true);
    expectSelected(t, 14, selected: false);
    // The tip keeps its badge either way.
    expect(
      find.descendant(
        of: find.byKey(StreakGoalPicker.goalKey(14)),
        matching: find.text('Mein Tipp'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('without onChanged the goals do not react', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: StreakGoalPicker(
              currentStreak: 0,
              selected: 14,
              onChanged: null,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('30 Tage'));
    await t.pump();
    expect(
      find.descendant(
        of: find.byKey(StreakGoalPicker.goalKey(14)),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  test('streakGoalSelection: the goal while it is open, else his tip', () {
    expect(streakGoalSelection(streakGoalChoices(0), null), 14);
    expect(streakGoalSelection(streakGoalChoices(0), 50), 50);
    expect(streakGoalSelection(streakGoalChoices(10), 7), 14);
    expect(streakGoalSelection(streakGoalChoices(20), null), 30);
    expect(streakGoalSelection(const [], 7), isNull);
  });

  testWidgets('the Buddy\'s tip sits on the recommended goal', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakGoalPicker(
              currentStreak: 0,
              selected: null,
              onChanged: (_) {},
            ),
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
          body: StreakGoalPicker(
            currentStreak: 40,
            selected: null,
            onChanged: (_) {},
          ),
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

  Future<void> pumpSheetOpener(
    WidgetTester t,
    void Function(int?) onResult,
  ) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async => onResult(
                await showStreakGoalSheet(
                  c,
                  currentStreak: 3,
                  title: 'Neues Ziel',
                ),
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
  }

  testWidgets('sheet: a tap selects without closing; „Ziel festlegen" '
      'returns the selected goal', (t) async {
    int? result;
    var returned = false;
    await pumpSheetOpener(t, (r) {
      returned = true;
      result = r;
    });
    expect(find.text('Neues Ziel'), findsOneWidget);

    await t.tap(find.text('30 Tage'));
    await t.pump(const Duration(milliseconds: 500));
    expect(returned, isFalse);
    expect(find.text('Neues Ziel'), findsOneWidget);

    await t.tap(find.byKey(StreakGoalChooser.confirmKey));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(returned, isTrue);
    expect(result, 30);
  });

  testWidgets('sheet: „Ziel festlegen" right away takes his tip', (t) async {
    int? result;
    await pumpSheetOpener(t, (r) => result = r);

    expect(find.text('Ziel festlegen'), findsOneWidget);
    await t.tap(find.byKey(StreakGoalChooser.confirmKey));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(result, 14);
  });
}
