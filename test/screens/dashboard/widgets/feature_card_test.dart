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
}
