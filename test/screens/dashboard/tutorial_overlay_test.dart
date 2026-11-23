import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/constants.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/spotlight_painter.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tooltip_bubble.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_step.dart';

import '../../helpers/riverpod_helpers.dart';

/// The rect the spotlight cuts out.
Rect _spotlight(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<SpotlightPainter>()
    .single
    .targetRect;

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

      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
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

      // step a → step b
      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
      await tester.pumpAndSettle();
      // step b → finish
      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
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

    testWidgets('overlay advances through 7 steps', (tester) async {
      var finished = false;
      await tester.pumpWithProviders(
        Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  for (final step in dashboardTutorialSteps)
                    SizedBox(key: step.targetKey, width: 80, height: 60),
                ],
              ),
              Positioned.fill(
                child: DashboardTutorialOverlay(
                  steps: dashboardTutorialSteps,
                  onFinish: () => finished = true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      String bubble() => tester
          .widget<RichText>(
            find.descendant(
              of: find.byType(TooltipBubble),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText();
      for (var i = 0; i < 7; i++) {
        expect(finished, isFalse, reason: 'step $i');
        expect(
          bubble(),
          dashboardTutorialSteps[i].richText.map((s) => s.toPlainText()).join(),
        );
        await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
        await tester.pumpAndSettle();
      }

      expect(finished, isTrue);
    });

    testWidgets('skips a target that is not shown (no size)', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: Stack(
            children: [
              Positioned(left: 20, top: 100, child: SizedBox.shrink(key: keyA)),
              Positioned(
                left: 20,
                top: 300,
                width: 80,
                height: 80,
                child: Container(key: keyB, color: Colors.green),
              ),
              Positioned.fill(
                child: DashboardTutorialOverlay(
                  steps: twoSteps(),
                  onFinish: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('step a', findRichText: true), findsNothing);
      expect(find.text('step b', findRichText: true), findsOneWidget);
    });

    testWidgets('a bubble with no room beside its target stays on screen', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // A long text in a tall target: neither side has room for it.
      final long = List.filled(12, 'Ein langer Satz.').join(' ');
      await tester.pumpWithProviders(
        Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 20,
                right: 20,
                top: 120,
                height: 420,
                child: Container(key: keyA, color: Colors.blue),
              ),
              Positioned.fill(
                child: DashboardTutorialOverlay(
                  steps: [
                    TutorialStep(
                      targetKey: keyA,
                      richText: [TextSpan(text: long)],
                    ),
                  ],
                  onFinish: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.getRect(find.byType(TooltipBubble));
      expect(bubble.top, greaterThanOrEqualTo(0));
      expect(bubble.bottom, lessThanOrEqualTo(667));
    });

    testWidgets('a bubble above its target ends just above it', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 20,
                bottom: 40,
                width: 80,
                height: 60,
                child: Container(key: keyA, color: Colors.blue),
              ),
              Positioned.fill(
                child: DashboardTutorialOverlay(
                  steps: [
                    TutorialStep(
                      targetKey: keyA,
                      richText: const [TextSpan(text: 'kurz')],
                      preferredAnchor: TooltipAnchor.above,
                    ),
                  ],
                  onFinish: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.getRect(find.byType(TooltipBubble));
      final target = tester.getRect(find.byKey(keyA));
      // A short bubble sits one gap above the target, not an estimated
      // bubble height above it.
      expect(target.top - bubble.bottom, AppConstants.spacingLg);
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
      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
      await tester.tap(find.text('Überspringen'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(finishCount, equals(1));
    });

    testWidgets('scrolls an off-screen target into view before its step', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWithProviders(
        Scaffold(
          body: Stack(
            children: [
              // Slivers, as on Home: their positions only update on layout.
              CustomScrollView(
                controller: scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Container(key: keyA, height: 80, color: Colors.blue),
                        const SizedBox(height: 1500),
                        Container(key: keyB, height: 80, color: Colors.green),
                        const SizedBox(height: 300),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: DashboardTutorialOverlay(
                  steps: twoSteps(),
                  onFinish: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);

      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
      await tester.pumpAndSettle();

      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final target = tester.getRect(find.byKey(keyB));
      expect(scroll.offset, greaterThan(0));
      expect(target.top, greaterThanOrEqualTo(0));
      expect(target.bottom, lessThanOrEqualTo(height));
      expect(find.text('step b', findRichText: true), findsOneWidget);
      // Measured once the scroll has landed, not a frame before.
      expect(_spotlight(tester), target.inflate(AppConstants.spacingXs));
    });

    testWidgets('leaves a fully visible target where it is', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWithProviders(
        Scaffold(
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    Container(key: keyA, height: 80, color: Colors.blue),
                    const SizedBox(height: 300),
                    Container(key: keyB, height: 80, color: Colors.green),
                    const SizedBox(height: 1500),
                  ],
                ),
              ),
              Positioned.fill(
                child: DashboardTutorialOverlay(
                  steps: twoSteps(),
                  onFinish: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
      await tester.pumpAndSettle();

      // Centring it would scroll; it is already on screen, so nothing moves.
      expect(scroll.offset, 0);
      expect(find.text('step b', findRichText: true), findsOneWidget);
    });
  });
}
