import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('EmailCaptureStep', () {
    Future<void> pumpStep(
      WidgetTester tester, {
      required void Function(String) onChanged,
      required VoidCallback onSubmit,
      String? initialValue,
    }) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: EmailCaptureStep(
            value: initialValue,
            onChanged: onChanged,
            onSubmit: onSubmit,
          ),
        ),
      );
    }

    testWidgets('shows headline and body copy', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      expect(find.text('Deine E-Mail-Adresse'), findsOneWidget);
      expect(
        find.textContaining('wir dir Empfehlungen, Erinnerungen'),
        findsOneWidget,
      );
    });

    testWidgets('Weiter button disabled when input is empty', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Weiter button disabled for invalid format', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Weiter button disabled for privaterelay.appleid.com', (
      tester,
    ) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      await tester.enterText(
        find.byType(TextFormField),
        'abc@privaterelay.appleid.com',
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('onChanged fires with the typed value', (tester) async {
      String? captured;
      await pumpStep(tester, onChanged: (v) => captured = v, onSubmit: () {});

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.pump();

      expect(captured, equals('user@example.com'));
    });

    testWidgets('Weiter button enabled for valid email; tap fires onSubmit', (
      tester,
    ) async {
      var submitted = false;
      await pumpStep(
        tester,
        onChanged: (_) {},
        onSubmit: () => submitted = true,
      );

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });
}
