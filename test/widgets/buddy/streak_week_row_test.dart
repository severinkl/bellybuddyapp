import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/buddy/streak_week_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget c) => MaterialApp(
  theme: AppTheme.theme,
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: c)),
  ),
);

/// Wednesday, 25 November 2026, mid-afternoon.
final _wednesday = DateTime(2026, 11, 25, 15, 30);

void main() {
  testWidgets('shows Mo–So of the current week with a flame per active day', (
    t,
  ) async {
    await t.pumpWidget(
      _wrap(
        StreakWeekRow(
          activeDays: {
            DateTime(2026, 11, 22), // last week's Sunday: not shown
            DateTime(2026, 11, 23), // Monday
            DateTime(2026, 11, 25, 9), // today, any time of day
          },
          today: _wednesday,
        ),
      ),
    );

    for (final day in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('🔥'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('marks today and reads the active days out', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(
      _wrap(
        StreakWeekRow(
          activeDays: {DateTime(2026, 11, 23), DateTime(2026, 11, 25)},
          today: _wednesday,
        ),
      ),
    );

    expect(find.byKey(StreakWeekRow.todayKey), findsOneWidget);
    expect(
      find.bySemanticsLabel('Diese Woche eingetragen: Montag, Mittwoch'),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('no activity this week', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(
      _wrap(StreakWeekRow(activeDays: const {}, today: _wednesday)),
    );

    expect(find.text('🔥'), findsNothing);
    expect(
      find.bySemanticsLabel('Diese Woche noch kein Eintrag'),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('the small size fits a narrow card', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: StreakWeekRow(
                activeDays: {DateTime(2026, 11, 23)},
                today: _wednesday,
                size: StreakWeekRowSize.small,
              ),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
