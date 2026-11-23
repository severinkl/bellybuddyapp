import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The bubble's text widget (whole text; the untyped part transparent).
Text _text(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byType(BuddySpeechBubble),
    matching: find.byType(Text),
  ),
);

/// The part of the text typed so far (the first span).
String _typed(WidgetTester tester) =>
    (_text(tester).textSpan! as TextSpan).children!.first.toPlainText();

Future<BuddyController> _pumpBubble(
  WidgetTester tester, {
  String? say,
  bool disableAnimations = false,
  BuddyBubbleTail tail = const BuddyBubbleTail.down(),
}) async {
  final controller = BuddyController();
  addTearDown(controller.dispose);
  if (say != null) controller.say(say, duration: null);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: BuddySpeechBubble(controller: controller, tail: tail),
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  const line = 'Wann bist du geboren? Ich bin gespannt!';

  group('BuddySpeechBubble', () {
    testWidgets('shows nothing while the Buddy says nothing', (tester) async {
      await _pumpBubble(tester);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('types the text in, at most buddyBubbleTypeMax long', (
      tester,
    ) async {
      await _pumpBubble(tester, say: line);

      // The whole text is laid out from the start (the bubble keeps its
      // size); none of it is typed yet.
      expect(find.text(line), findsOneWidget);
      expect(_typed(tester), isEmpty);

      await tester.pump(AppConstants.buddyBubbleTypeMax ~/ 2);
      expect(_typed(tester), isNotEmpty);
      expect(line.startsWith(_typed(tester)), isTrue);
      expect(_typed(tester).length, lessThan(line.length));

      await tester.pump(AppConstants.buddyBubbleTypeMax);
      expect(_typed(tester), line);
    });

    testWidgets('screen readers get the whole text from the first frame', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBubble(tester, say: line);

      expect(find.bySemanticsLabel(line), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a tap shows the whole text at once', (tester) async {
      await _pumpBubble(tester, say: line);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_typed(tester), isNot(line));

      await tester.tap(find.byType(BuddySpeechBubble));
      await tester.pump();
      expect(_typed(tester), line);
    });

    testWidgets('reduced motion shows the whole text at once', (tester) async {
      await _pumpBubble(tester, say: line, disableAnimations: true);
      await tester.pump();
      expect(_typed(tester), line);
    });

    testWidgets('a reduced-motion controller shows the whole text at once', (
      tester,
    ) async {
      final controller = BuddyController()..reducedMotion = true;
      addTearDown(controller.dispose);
      controller.say(line, duration: null);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: BuddySpeechBubble(controller: controller)),
        ),
      );
      expect(_typed(tester), line);
    });

    testWidgets('types whole characters (emoji with modifiers stay whole)', (
      tester,
    ) async {
      // 4 characters (graphemes): „H", „i", „👋🏽", „!".
      const wave = 'Hi👋🏽!';
      await _pumpBubble(tester, say: wave);
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 15));
        seen.add(_typed(tester));
      }
      expect(seen, containsAll(['H', 'Hi', 'Hi👋🏽', wave]));
      expect(seen, isNot(contains('Hi👋')));
    });

    testWidgets('the text rebuilds only when another character is typed', (
      tester,
    ) async {
      await _pumpBubble(tester, say: 'Hi');
      var builds = 0;
      Text? last;
      // 2 characters type in 60 ms; pump it in many short frames.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 5));
        final text = _text(tester);
        if (!identical(text, last)) builds++;
        last = text;
      }
      expect(_typed(tester), 'Hi');
      expect(builds, lessThanOrEqualTo(3));
    });

    testWidgets('text starts aligned left', (tester) async {
      await _pumpBubble(tester, say: line);
      expect(_text(tester).textAlign, TextAlign.start);
    });
  });

  group('buddyBubblePath', () {
    const size = Size(200, 80);
    const shadow = AppConstants.buddyBubbleShadowOffset;
    const length = AppConstants.buddyBubbleTailLength;

    test('a down tail hangs below the body, shifted toward the face', () {
      final path = buddyBubblePath(
        size,
        const BuddyBubbleTail.down(shift: -40),
      );
      final bodyBottom = size.height - shadow.dy - length;
      final centre = (size.width - shadow.dx) / 2;
      // Inside the tail, below the body, left of the centre.
      expect(path.contains(Offset(centre - 40, bodyBottom + length / 2)), true);
      // Not on the other side.
      expect(
        path.contains(Offset(centre + 40, bodyBottom + length / 2)),
        false,
      );
      // The body itself.
      expect(path.contains(Offset(centre, bodyBottom / 2)), true);
    });

    test('a left tail sticks out of the left edge near the top', () {
      final path = buddyBubblePath(size, const BuddyBubbleTail.left());
      const tailY = AppConstants.buddyBubbleSideTailTop;
      expect(path.contains(const Offset(length / 2, tailY)), true);
      expect(path.contains(Offset(length / 2, size.height - 10)), false);
    });

    test('the tail stays on the straight part of a narrow edge', () {
      final path = buddyBubblePath(
        size,
        const BuddyBubbleTail.down(shift: -1000),
      );
      final bodyBottom = size.height - shadow.dy - length;
      // Clamped past the corner radius, not at the far left.
      expect(path.contains(Offset(2, bodyBottom + length / 2)), false);
      expect(
        path.contains(
          Offset(
            AppConstants.radiusRound + AppConstants.buddyBubbleTailBase / 2,
            bodyBottom + length / 3,
          ),
        ),
        true,
      );
    });
  });

  group('BuddyStage', () {
    testWidgets('points the bubble\'s tail at the Buddy\'s face, left of '
        'centre', (tester) async {
      final controller = BuddyController()..say(line, duration: null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 360,
              child: BuddyStage(controller: controller),
            ),
          ),
        ),
      );

      final tail = tester
          .widget<BuddySpeechBubble>(find.byType(BuddySpeechBubble))
          .tail;
      expect(tail.side, BuddyBubbleSide.down);
      final expected = BuddyStage.faceShift(
        const Size(300, 360 - AppConstants.buddyBubbleHeight),
      );
      expect(tail.shift, expected);
      expect(tail.shift, lessThan(0));
    });
  });
}
