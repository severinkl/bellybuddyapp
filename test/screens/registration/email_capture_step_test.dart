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
      VoidCallback? onSkip,
      String? initialValue,
    }) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: EmailCaptureStep(
            value: initialValue,
            onChanged: onChanged,
            onSubmit: onSubmit,
            onSkip: onSkip ?? () {},
          ),
        ),
      );
    }

    ElevatedButton submitButton(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.byKey(EmailCaptureStep.submitButtonKey));

    Finder emailField() => find.byKey(EmailCaptureStep.emailFieldKey);

    testWidgets('shows headline, optional body copy, and skip button', (
      tester,
    ) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      expect(find.text('Deine E-Mail-Adresse'), findsOneWidget);
      expect(
        find.textContaining('Dieser Schritt ist optional'),
        findsOneWidget,
      );
      expect(find.text('Überspringen'), findsOneWidget);
    });

    testWidgets('tapping Überspringen fires onSkip', (tester) async {
      var skipped = false;
      await pumpStep(
        tester,
        onChanged: (_) {},
        onSubmit: () {},
        onSkip: () => skipped = true,
      );

      await tester.tap(find.byKey(EmailCaptureStep.skipButtonKey));
      await tester.pump();

      expect(skipped, isTrue);
    });

    testWidgets('Weiter button disabled when input is empty', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('Weiter button disabled for invalid format', (tester) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      await tester.enterText(emailField(), 'not-an-email');
      await tester.pump();

      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('Weiter button disabled for privaterelay.appleid.com', (
      tester,
    ) async {
      await pumpStep(tester, onChanged: (_) {}, onSubmit: () {});

      await tester.enterText(emailField(), 'abc@privaterelay.appleid.com');
      await tester.pump();

      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('onChanged fires with the trimmed typed value', (tester) async {
      String? captured;
      await pumpStep(tester, onChanged: (v) => captured = v, onSubmit: () {});

      await tester.enterText(emailField(), '  user@example.com  ');
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

      await tester.enterText(emailField(), 'user@example.com');
      await tester.pump();

      expect(submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(EmailCaptureStep.submitButtonKey));
      await tester.pump();

      expect(submitted, isTrue);
    });

    testWidgets('soft-keyboard Done with valid email fires onSubmit', (
      tester,
    ) async {
      var submitted = false;
      await pumpStep(
        tester,
        onChanged: (_) {},
        onSubmit: () => submitted = true,
      );

      await tester.enterText(emailField(), 'user@example.com');
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, isTrue);
    });

    testWidgets(
      'soft-keyboard Done with invalid email does NOT fire onSubmit',
      (tester) async {
        var submitted = false;
        await pumpStep(
          tester,
          onChanged: (_) {},
          onSubmit: () => submitted = true,
        );

        await tester.enterText(emailField(), 'not-an-email');
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(submitted, isFalse);
      },
    );
  });
}
