import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';

Future<void> _pump(WidgetTester tester, AsyncValue<InsightProgress> progress) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(body: InsightCard(progress: progress)),
      ),
    );

AsyncValue<InsightProgress> _progress(int days, int gutFeelings) => AsyncData(
  InsightProgress(activeDays: days, gutFeelingEntries: gutFeelings),
);

void main() {
  group('InsightCard', () {
    testWidgets('locked shows the days left and both bars', (tester) async {
      await _pump(tester, _progress(2, 1));

      expect(find.byKey(InsightCard.cardKey), findsOneWidget);
      // Drawn in the uppercase label style.
      expect(
        find.text('Was ich über deinen Bauch lerne'.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text('Noch 5 Tage, dann zeig ich dir erste Muster.'),
        findsOneWidget,
      );
      expect(find.text('Tage mit Einträgen'), findsOneWidget);
      expect(find.text('2 von 7'), findsOneWidget);
      expect(find.text('Bauchgefühl-Einträge'), findsOneWidget);
      expect(find.text('1 von 3'), findsOneWidget);
    });

    testWidgets('singular', (tester) async {
      await _pump(tester, _progress(6, 3));

      expect(
        find.text('Noch 1 Tag, dann zeig ich dir erste Muster.'),
        findsOneWidget,
      );
    });

    testWidgets('days done, gut feelings missing', (tester) async {
      await _pump(tester, _progress(9, 1));
      expect(
        find.text(
          'Noch 2 Bauchgefühl-Einträge, dann zeig ich dir erste Muster.',
        ),
        findsOneWidget,
      );
      // The days bar is full and says so, not „9 von 7".
      expect(find.text('7 von 7'), findsOneWidget);

      await _pump(tester, _progress(9, 2));
      expect(
        find.text(
          'Noch 1 Bauchgefühl-Eintrag, dann zeig ich dir erste Muster.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('unlocked (Stage 1 interim)', (tester) async {
      await _pump(tester, _progress(7, 3));

      expect(find.byKey(InsightCard.cardKey), findsOneWidget);
      expect(
        find.text('Genug Einträge! Deine ersten Muster kommen bald.'),
        findsOneWidget,
      );
      expect(find.text('Tage mit Einträgen'), findsNothing);
      expect(find.text('Bauchgefühl-Einträge'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(InsightCard.cardKey),
          matching: find.byWidgetPredicate(
            (w) =>
                (w is GestureDetector && w.onTap != null) ||
                (w is InkWell && w.onTap != null),
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('error/loading hides the card', (tester) async {
      await _pump(
        tester,
        AsyncError<InsightProgress>(Exception('offline'), StackTrace.empty),
      );
      expect(find.byKey(InsightCard.cardKey), findsNothing);

      await _pump(tester, const AsyncLoading<InsightProgress>());
      expect(find.byKey(InsightCard.cardKey), findsNothing);
    });

    testWidgets('reads the bars as one label each', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _progress(2, 1));

      expect(
        find.bySemanticsLabel('Tage mit Einträgen: 2 von 7'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Bauchgefühl-Einträge: 1 von 3'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
