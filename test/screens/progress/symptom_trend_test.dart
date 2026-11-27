import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/screens/progress/widgets/symptom_trend.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';

SymptomMeans _m(double v) =>
    SymptomMeans(bloating: v, gas: v + 1, cramps: 1, fullness: 5);

List<ProgressWeek> _weeks(Map<int, SymptomMeans> means, {int n = 12}) => [
  for (var i = 0; i < n; i++)
    ProgressWeek(
      monday: addDays(DateTime(2026, 11, 23), (i - n + 1) * 7),
      days: const [],
      good: 0,
      medium: 0,
      hard: 0,
      activeDays: 0,
      elapsedDays: 7,
      means: means[i],
    ),
];

Future<void> _pump(WidgetTester tester, List<ProgressWeek> weeks) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SymptomTrend(weeks: weeks, enough: true)),
      ),
    );

void main() {
  testWidgets('four rows with the tracker labels and the caption', (
    tester,
  ) async {
    await _pump(tester, _weeks({10: _m(2), 11: _m(3)}));

    for (final label in ['Blähbauch', 'Blähungen', 'Krämpfe', 'Völlegefühl']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Beschwerden pro Woche'), findsOneWidget);
    expect(
      find.textContaining('1 = gar nicht, 5 = sehr stark'),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(4));
  });

  testWidgets('a missing week is a marker (null), a week with means a value', (
    tester,
  ) async {
    await _pump(tester, _weeks({10: _m(2), 11: _m(3)}));

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<TrendBarsPainter>()
        .toList();
    expect(painters, hasLength(4));
    final bloating = painters.first.values;
    expect(bloating, hasLength(12));
    expect(bloating.take(10), everyElement(isNull));
    expect(bloating[10], 2);
    expect(bloating[11], 3);
    // Blähungen reads the gas mean.
    expect(painters[1].values[11], 4);
    // Krämpfe, Völlegefühl.
    expect(painters[2].values[11], 1);
    expect(painters[3].values[11], 5);
  });

  testWidgets('row semantics: newest and oldest week with means', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _weeks({10: _m(2), 11: _m(3)}));

    expect(
      find.bySemanticsLabel(
        'Blähbauch: diese Woche im Schnitt 3,0 von 5; letzte Woche 2,0',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('row semantics with one mean only has no "vor" part', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _weeks({11: _m(2)}));

    expect(
      find.bySemanticsLabel('Krämpfe: diese Woche im Schnitt 1,0 von 5'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
