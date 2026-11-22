import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/buddy/widgets/gift_reveal.dart';

void main() {
  group('GiftReveal', () {
    Future<List<int>> pumpGift(
      WidgetTester tester, {
      String? cardLabel = '🛡 Streak-Saver',
    }) async {
      final opened = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Center(
              child: GiftReveal(
                onOpened: () => opened.add(1),
                cardLabel: cardLabel,
              ),
            ),
          ),
        ),
      );
      return opened;
    }

    void reduceMotion(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('starts closed: box shown, no saver card', (tester) async {
      await pumpGift(tester);

      expect(find.byKey(GiftReveal.boxKey), findsOneWidget);
      expect(find.byKey(GiftReveal.cardKey), findsNothing);
      expect(find.bySemanticsLabel('Geschenk öffnen'), findsOneWidget);
    });

    testWidgets('the closed box wiggles', (tester) async {
      await pumpGift(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('tap opens it once and reveals the Streak-Saver card', (
      tester,
    ) async {
      final opened = await pumpGift(tester);

      await tester.tap(find.byKey(GiftReveal.boxKey));
      await tester.pump();
      expect(opened, hasLength(1));

      // A second tap (mid-animation and after it) does nothing.
      await tester.tap(find.byKey(GiftReveal.boxKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GiftReveal.boxKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.byKey(GiftReveal.cardKey), findsOneWidget);
      expect(find.textContaining('Streak-Saver'), findsOneWidget);
      // Once open, nothing keeps animating.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the card waits for its label, then shows it', (tester) async {
      final opened = await pumpGift(tester, cardLabel: null);

      await tester.tap(find.byKey(GiftReveal.boxKey));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(find.byKey(GiftReveal.cardKey), findsNothing);

      await pumpGift(tester, cardLabel: '🛡 Schutzschilde voll');
      await tester.pumpAndSettle();
      expect(find.byKey(GiftReveal.cardKey), findsOneWidget);
      expect(find.text('🛡 Schutzschilde voll'), findsOneWidget);
      expect(find.textContaining('Streak-Saver'), findsNothing);
    });

    testWidgets('reduced motion: no wiggle, opens instantly', (tester) async {
      reduceMotion(tester);
      final opened = await pumpGift(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(find.byKey(GiftReveal.boxKey));
      await tester.pump();

      expect(opened, hasLength(1));
      expect(find.byKey(GiftReveal.cardKey), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
