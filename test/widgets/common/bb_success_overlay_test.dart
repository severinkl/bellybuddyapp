import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/layout_checks.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Pumps past all staggered intro timers of [BbSuccessOverlay] (scheduled on
/// its first `didChangeDependencies`: 100 ms mascot delay + 250 ms text delay
/// + animation durations ≤ 600 ms).
/// Draining to 700 ms leaves no pending timers while still within test bounds.
Future<void> _pumpOverlay(WidgetTester tester, Widget overlay) async {
  await tester.pumpWidget(_wrap(overlay));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('BbSuccessOverlay actions', () {
    testWidgets('renders multiple actions separated by gaps', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          // mascotAsset keeps the overlay alive (no auto-dismiss timer).
          mascotAsset: 'assets/images/mascot/mascot-cool.png',
          actions: const [Text('Aktion 1'), Text('Aktion 2')],
        ),
      );

      expect(find.text('Aktion 1'), findsOneWidget);
      expect(find.text('Aktion 2'), findsOneWidget);
    });

    testWidgets('renders without actions gracefully (no exception)', (
      tester,
    ) async {
      // Provide a mascot so the overlay does not schedule an auto-dismiss timer.
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-happy.png',
          // actions omitted — must not throw
        ),
      );

      expect(find.text('Gespeichert!'), findsOneWidget);
    });

    testWidgets('renders with empty actions list gracefully', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-happy.png',
          actions: const [],
        ),
      );

      expect(find.text('Gespeichert!'), findsOneWidget);
    });

    testWidgets('renders single action', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-cool.png',
          actions: const [Text('Nur eine Aktion')],
        ),
      );

      expect(find.text('Nur eine Aktion'), findsOneWidget);
    });

    testWidgets('renders bottomCallout below actions', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert',
          onDismissed: () {},
          actions: const [Text('ACTION_ONE')],
          bottomCallout: const Text('CALLOUT_TEXT'),
        ),
      );

      expect(find.text('ACTION_ONE'), findsOneWidget);
      expect(find.text('CALLOUT_TEXT'), findsOneWidget);
    });

    testWidgets('renders cleanly without bottomCallout', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert',
          onDismissed: () {},
          actions: const [Text('ACTION_ONE')],
        ),
      );

      expect(find.text('ACTION_ONE'), findsOneWidget);
    });
  });

  group('BbSuccessOverlay illustration', () {
    const illustrationKey = Key('illustration');
    const illustration = SizedBox(key: illustrationKey, width: 10, height: 10);

    testWidgets('replaces the mascot image', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-cool.png',
          illustration: illustration,
        ),
      );

      expect(find.byKey(illustrationKey), findsOneWidget);
      expect(find.byType(MascotImage), findsNothing);
    });

    testWidgets('does not auto-dismiss and dismisses on tap', (tester) async {
      var dismissed = 0;
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () => dismissed++,
          illustration: illustration,
        ),
      );
      await tester.pump(
        AppConstants.successOverlayDuration + const Duration(seconds: 1),
      );
      expect(dismissed, 0);
      expect(find.text('Tippen zum Fortfahren'), findsOneWidget);

      await tester.tap(find.text('Gespeichert!'));
      expect(dismissed, 1);
    });

    testWidgets('shows its content at once under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: BbSuccessOverlay(
                  message: 'Gespeichert!',
                  onDismissed: () {},
                  illustration: illustration,
                ),
              ),
            ),
          ),
        ),
      );

      // One frame, no further pumps: nothing may still be fading or sliding.
      final message = find.text('Gespeichert!');
      Finder above(Type type) =>
          find.ancestor(of: message, matching: find.byType(type));
      expect(above(Opacity), findsWidgets);
      for (final o in tester.widgetList<Opacity>(above(Opacity))) {
        expect(o.opacity, 1.0);
      }
      for (final f in tester.widgetList<FadeTransition>(
        above(FadeTransition),
      )) {
        expect(f.opacity.value, 1.0);
      }
      expect(above(SlideTransition), findsWidgets);
      for (final s in tester.widgetList<SlideTransition>(
        above(SlideTransition),
      )) {
        expect(s.position.value, Offset.zero);
      }
    });
  });

  group('BbSuccessOverlay contrast', () {
    /// WCAG relative luminance of [c].
    double luminance(Color c) => c.computeLuminance();

    /// WCAG contrast of [fg] (alpha composited) on [bg].
    double contrast(Color fg, Color bg) {
      final shown = Color.alphaBlend(fg, bg);
      final a = luminance(shown), b = luminance(bg);
      final (hi, lo) = a > b ? (a, b) : (b, a);
      return (hi + 0.05) / (lo + 0.05);
    }

    testWidgets('„Tippen zum Fortfahren" reads at ≥ 4.5:1 on the lime', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          subMessage: 'Ist jetzt in deinem Tagebuch eingetragen.',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-happy.png',
        ),
      );

      final background = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.color)
          .nonNulls
          .first;
      for (final text in [
        'Tippen zum Fortfahren',
        'Ist jetzt in deinem Tagebuch eingetragen.',
      ]) {
        final color = tester.widget<Text>(find.text(text)).style!.color!;
        expect(
          contrast(color, Color.alphaBlend(background, Colors.white)),
          greaterThanOrEqualTo(4.5),
          reason: text,
        );
      }
    });
  });

  group('BbSuccessOverlay for screen readers', () {
    /// Sized by what it is given, like the Buddy's success hero; it can't
    /// answer intrinsic sizes (a [LayoutBuilder]).
    const heroKey = Key('hero');
    Widget hero() => LayoutBuilder(
      key: heroKey,
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight.isFinite ? constraints.maxHeight : 100,
        width: 100,
      ),
    );

    BbSuccessOverlay overlay({VoidCallback? onDismissed}) => BbSuccessOverlay(
      message: 'Muster frei!',
      subMessage: 'Deine Muster-Seite ist jetzt frei. ' * 3,
      onDismissed: onDismissed ?? () {},
      illustration: hero(),
      actions: [BbButton(label: 'Muster ansehen', onPressed: () {})],
    );

    testWidgets('one named „Schließen" button dismisses it', (tester) async {
      final handle = tester.ensureSemantics();
      var dismissed = 0;
      await _pumpOverlay(tester, overlay(onDismissed: () => dismissed++));

      final close = find.bySemanticsLabel('Schließen');
      expect(close, findsOneWidget);
      expect(
        tester.getSemantics(close),
        isSemantics(
          label: 'Schließen',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Schließen'));
      expect(dismissed, 1);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the title is a heading', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpOverlay(tester, overlay());
      // Past the text's fade-in (it starts on the frame after its delay).
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Muster frei!')),
        isSemantics(label: 'Muster frei!', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('a tap anywhere still dismisses it', (tester) async {
      var dismissed = 0;
      await _pumpOverlay(tester, overlay(onDismissed: () => dismissed++));

      await tester.tapAt(const Offset(5, 5));
      expect(dismissed, 1);
    });

    testWidgets('scrolls at 200 % text instead of overflowing', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errors = await collectFlutterErrors(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery.withClampedTextScaling(
              minScaleFactor: 2,
              maxScaleFactor: 2,
              child: Scaffold(body: overlay()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));
      });

      expect(verticalOverflows(errors), isEmpty);
      expect(find.byType(Scrollable), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Tippen zum Fortfahren'), 100);
      expect(find.text('Tippen zum Fortfahren').hitTestable(), findsOneWidget);
    });

    testWidgets('gives the hero the height left over at 100 % text', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpOverlay(tester, overlay());

      // The page fills the screen and the hero takes what the texts and
      // the button leave (more than the minimum it gets when it scrolls).
      expect(
        tester.getSize(find.byKey(heroKey)).height,
        greaterThan(AppConstants.successHeroMinHeight),
      );
    });
  });
}
