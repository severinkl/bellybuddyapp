import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _size = Size(300, 400);

/// Pumps [child] inside a themed [MaterialApp], centred on the screen.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.theme,
    home: Scaffold(body: Center(child: child)),
  ),
);

Widget _box(Widget child, [Size size = _size]) =>
    SizedBox(width: size.width, height: size.height, child: child);

BuddyController _controller() {
  final c = BuddyController();
  addTearDown(c.dispose);
  return c;
}

/// Global position of the Buddy image point [image] inside the first
/// [AnimatedBuddy] laid out at [size].
Offset _globalOf(WidgetTester tester, Offset image, [Size size = _size]) =>
    tester.getTopLeft(find.byType(AnimatedBuddy)) +
    BuddyLayout(size).toLocal(image);

void main() {
  group('AnimatedBuddy', () {
    testWidgets('renders a CustomPaint with a BuddyPainter and ticks', (
      tester,
    ) async {
      final c = _controller();
      await _pump(tester, _box(AnimatedBuddy(controller: c)));

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BuddyPainter,
        ),
        findsOneWidget,
      );
      final t0 = c.frame.t;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.frame.t, greaterThan(t0));
    });

    testWidgets('tap on the body pokes and calls onPoke', (tester) async {
      final c = _controller();
      var pokes = 0;
      await _pump(
        tester,
        _box(AnimatedBuddy(controller: c, onPoke: () => pokes++)),
      );

      await tester.tapAt(_globalOf(tester, const Offset(900, 420)));
      expect(c.currentAction, BuddyAction.poke);
      expect(pokes, 1);
    });

    testWidgets('tap outside the body does not poke', (tester) async {
      final c = _controller();
      var pokes = 0;
      await _pump(
        tester,
        _box(AnimatedBuddy(controller: c, onPoke: () => pokes++)),
      );

      await tester.tapAt(_globalOf(tester, const Offset(20, 20)));
      expect(c.currentAction, isNull);
      expect(pokes, 0);
    });

    testWidgets('non-interactive Buddy ignores taps', (tester) async {
      final c = _controller();
      await _pump(
        tester,
        _box(AnimatedBuddy(controller: c, interactive: false)),
      );

      await tester.tapAt(_globalOf(tester, const Offset(900, 420)));
      expect(c.currentAction, isNull);
    });

    testWidgets('semantics label names the Buddy and its mood', (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller();
      await _pump(tester, _box(AnimatedBuddy(controller: c)));

      expect(find.bySemanticsLabel(RegExp('Buddy, glücklich')), findsOneWidget);

      c.mood = BuddyMood.hungry;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.bySemanticsLabel(RegExp('Buddy, hungrig')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('disableAnimations switches the controller to reduced '
        'motion', (tester) async {
      final c = _controller();
      await _pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _box(AnimatedBuddy(controller: c)),
        ),
      );
      expect(c.reducedMotion, isTrue);
    });

    testWidgets('TickerMode(enabled: false) stops ticking', (tester) async {
      final c = _controller();
      await _pump(
        tester,
        TickerMode(enabled: false, child: _box(AnimatedBuddy(controller: c))),
      );
      final t0 = c.frame.t;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.frame.t, t0);
    });

    testWidgets('tickerEnabled = false (test seam) renders without ticking', (
      tester,
    ) async {
      AnimatedBuddy.tickerEnabled = false;
      addTearDown(() => AnimatedBuddy.tickerEnabled = true);
      final c = _controller();
      await _pump(tester, _box(AnimatedBuddy(controller: c)));
      final t0 = c.frame.t;

      await tester.pumpAndSettle();

      expect(c.frame.t, t0);
      expect(
        find.descendant(
          of: find.byType(AnimatedBuddy),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('zero-size constraints render nothing without errors', (
      tester,
    ) async {
      final c = _controller();
      await _pump(tester, _box(AnimatedBuddy(controller: c), Size.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BuddyPainter,
        ),
        findsNothing,
      );
    });

    testWidgets('48×48 avatar renders without errors', (tester) async {
      final c = _controller();
      await _pump(
        tester,
        _box(AnimatedBuddy(controller: c), const Size(48, 48)),
      );
      c.play(BuddyAction.celebrate);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing while eat runs throws nothing', (tester) async {
      final c = _controller();
      await _pump(tester, _box(AnimatedBuddy(controller: c)));
      c.play(BuddyAction.eat);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await _pump(tester, const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('BuddySpeechBubble', () {
    testWidgets('renders nothing until say() and then the text', (
      tester,
    ) async {
      final c = _controller();
      await _pump(tester, BuddySpeechBubble(controller: c));
      expect(find.byType(Text), findsNothing);

      c
        ..say('Hallo!')
        ..tick(0.016);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hallo!'), findsOneWidget);
    });

    testWidgets('is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller();
      await _pump(tester, BuddySpeechBubble(controller: c));
      c
        ..say('Hallo!')
        ..tick(0.016);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getSemantics(find.text('Hallo!')),
        isSemantics(label: 'Hallo!', isLiveRegion: true),
      );
      handle.dispose();
    });
  });

  group('BuddyStage', () {
    testWidgets('long German bubble text wraps without overflow', (
      tester,
    ) async {
      const text =
          'Puh! Dein Streak-Saver hat uns gestern gerettet – '
          'heute schaffen wir es wieder gemeinsam!!';
      expect(text.length, 90);
      final c = _controller();
      await _pump(
        tester,
        _box(BuddyStage(controller: c), const Size(320, 480)),
      );
      c.say(text);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(find.byType(BuddySpeechBubble), findsOneWidget);
      final bubble = tester.getRect(find.byType(BuddySpeechBubble));
      expect(bubble.width, lessThanOrEqualTo(320));
    });
  });
}
