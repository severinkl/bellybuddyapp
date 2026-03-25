import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_card.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbCard', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWithProviders(
        const Scaffold(body: BbCard(child: Text('Karten-Inhalt'))),
      );
      expect(find.text('Karten-Inhalt'), findsOneWidget);
    });

    testWidgets('applies default padding and border decoration', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const Scaffold(body: BbCard(child: Text('Mit Rahmen'))),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.border, isNotNull);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWithProviders(
        Scaffold(
          body: BbCard(
            onTap: () => tapped = true,
            child: const Text('Tippbar'),
          ),
        ),
      );
      await tester.tap(find.text('Tippbar'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
