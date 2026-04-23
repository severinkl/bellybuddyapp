import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/feature_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 200, child: child)),
);

void main() {
  group('FeatureCard badge copy', () {
    testWidgets('hasNew: renders "ungelesen" (not "Neu")', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/fuer-dich-card.png',
            label: 'Tipps',
            icon: Icons.auto_awesome,
            iconColor: Colors.black,
            hasNew: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('ungelesen'), findsOneWidget);
      expect(find.text('Neu'), findsNothing);
    });

    testWidgets('badgeCount > 0: renders the number', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/alternativen-card.jpg',
            label: 'Alternativen',
            icon: Icons.eco,
            iconColor: Colors.black,
            badgeCount: 3,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });
  });

  group('FeatureCard pulse', () {
    testWidgets('pulse=true: badge pill has a non-unit Transform.scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/fuer-dich-card.png',
            label: 'Tipps',
            icon: Icons.auto_awesome,
            iconColor: Colors.black,
            hasNew: true,
            pulse: true,
            onTap: () {},
          ),
        ),
      );
      // Advance far enough to leave the AnimationController at a non-zero
      // value mid-cycle (controller duration is 700 ms, reverses).
      await tester.pump(const Duration(milliseconds: 350));

      final badge = find.ancestor(
        of: find.text('ungelesen'),
        matching: find.byType(Transform),
      );
      expect(badge, findsWidgets);
    });

    testWidgets('pulse=false: no AnimationController; badge is static', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FeatureCard(
            imageAsset: 'assets/images/fuer-dich-card.png',
            label: 'Tipps',
            icon: Icons.auto_awesome,
            iconColor: Colors.black,
            hasNew: true,
            pulse: false,
            onTap: () {},
          ),
        ),
      );
      // No pending animation frames → pumpAndSettle returns instantly.
      await tester.pumpAndSettle();
      expect(find.text('ungelesen'), findsOneWidget);
    });

    testWidgets(
      'MediaQuery.disableAnimations: badge is static even if pulse=true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                accessibleNavigation: false,
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 200,
                  child: FeatureCard(
                    imageAsset: 'assets/images/fuer-dich-card.png',
                    label: 'Tipps',
                    icon: Icons.auto_awesome,
                    iconColor: Colors.black,
                    hasNew: true,
                    pulse: true,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        // pumpAndSettle succeeds → no repeating animation.
        await tester.pumpAndSettle();
        expect(find.text('ungelesen'), findsOneWidget);
      },
    );
  });
}
