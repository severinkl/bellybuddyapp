import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: BbButton(label: 'Speichern', onPressed: () {}),
        ),
      );
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('onPressed fires callback on tap', (tester) async {
      var pressed = false;
      await tester.pumpWithProviders(
        Scaffold(
          body: BbButton(label: 'Tippen', onPressed: () => pressed = true),
        ),
      );
      await tester.tap(find.text('Tippen'));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWithProviders(
        const Scaffold(body: BbButton(label: 'Deaktiviert', onPressed: null)),
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: BbButton(label: 'Laden', onPressed: () {}, isLoading: true),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Laden'), findsNothing);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: BbButton(
            label: 'Mit Icon',
            onPressed: () {},
            icon: Icons.check,
          ),
        ),
      );
      expect(find.text('Mit Icon'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
