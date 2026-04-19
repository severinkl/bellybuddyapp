import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_step.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('DashboardTutorialOverlay', () {
    final keyA = GlobalKey(debugLabel: 'a');
    final keyB = GlobalKey(debugLabel: 'b');

    List<TutorialStep> twoSteps() => [
      TutorialStep(
        targetKey: keyA,
        richText: const [TextSpan(text: 'step a')],
      ),
      TutorialStep(
        targetKey: keyB,
        richText: const [TextSpan(text: 'step b')],
      ),
    ];

    Widget harness({required Widget overlay}) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 20,
              top: 100,
              width: 80,
              height: 80,
              child: Container(key: keyA, color: Colors.blue),
            ),
            Positioned(
              left: 20,
              bottom: 100,
              width: 80,
              height: 80,
              child: Container(key: keyB, color: Colors.green),
            ),
            Positioned.fill(child: overlay),
          ],
        ),
      );
    }

    testWidgets('renders the first step\'s bubble text', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('step a', findRichText: true), findsOneWidget);
      expect(find.text('step b', findRichText: true), findsNothing);
      expect(find.text('Überspringen'), findsOneWidget);
      expect(finished, isFalse);
    });

    testWidgets('tapping background advances to the next step', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap bottom-right where the advance GestureDetector is unobstructed.
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();

      expect(find.text('step b', findRichText: true), findsOneWidget);
      expect(finished, isFalse);
    });

    testWidgets('advancing past the last step calls onFinish', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to step b
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
      // Advance past last → finish
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });

    testWidgets('tapping Überspringen finishes immediately', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Überspringen'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });

    testWidgets('onFinish fires at most once across rapid taps', (
      tester,
    ) async {
      var finishCount = 0;
      await tester.pumpWithProviders(
        harness(
          overlay: DashboardTutorialOverlay(
            steps: twoSteps(),
            onFinish: () => finishCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Überspringen, then immediately tap background and Überspringen again
      // before the fade-out completes — the _finished guard must block duplicates.
      await tester.tap(find.text('Überspringen'));
      await tester.tapAt(const Offset(400, 500));
      await tester.tap(find.text('Überspringen'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(finishCount, equals(1));
    });
  });
}
