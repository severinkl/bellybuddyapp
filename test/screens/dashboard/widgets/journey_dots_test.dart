import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_dots.dart';

List<JourneyDay> _days(List<bool> gut) => [
  for (var i = 0; i < gut.length; i++)
    JourneyDay(DateTime(2026, 11, 17 + i), gutFeeling: gut[i]),
];

Future<void> _pump(
  WidgetTester tester,
  List<JourneyDay> days, {
  bool reduced = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: JourneyDots(days: days),
          ),
        ),
      ),
    ),
  ),
);

double _cx(WidgetTester tester, Key key) =>
    tester.getCenter(find.byKey(key)).dx;

void main() {
  testWidgets('fills one dot per day with entries, a green pip for '
      'Bauchgefühl days', (tester) async {
    await _pump(tester, _days([true, false, true]));

    expect(find.byIcon(Icons.check), findsNWidgets(3));
    expect(find.byKey(JourneyDots.pipKey), findsNWidgets(2));
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(JourneyDots.dotKey(i)), findsOneWidget);
    }
  });

  testWidgets('the Buddy stands on the last filled dot', (tester) async {
    await _pump(tester, _days([true, false, true]));
    expect(
      _cx(tester, JourneyDots.buddyKey),
      closeTo(_cx(tester, JourneyDots.dotKey(2)), 1),
    );

    await _pump(tester, const []);
    expect(
      _cx(tester, JourneyDots.buddyKey),
      closeTo(_cx(tester, JourneyDots.dotKey(0)), 1),
    );
  });

  testWidgets('a dot that fills while shown bumps', (tester) async {
    await _pump(tester, _days([true, false, true]));
    expect(tester.hasRunningAnimations, isFalse);

    await _pump(tester, _days([true, false, true, false]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: no bump', (tester) async {
    await _pump(tester, _days([true]), reduced: true);
    await _pump(tester, _days([true, true]), reduced: true);

    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
  });

  testWidgets('silent to a screen reader: adds nothing to the card around '
      'it', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Semantics(
            container: true,
            label: 'Karte',
            child: JourneyDots(days: _days([true, false])),
          ),
        ),
      ),
    );

    final card = tester.getSemantics(find.byType(JourneyDots));
    expect(card.label, 'Karte');
    expect(card.childrenCount, 0);
    handle.dispose();
  });
}
