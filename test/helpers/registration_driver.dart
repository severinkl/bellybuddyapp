import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/screens/health_consent/widgets/health_consent_content.dart';
import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';

/// Drives the registration wizard from the health consent (step 0) up to and
/// including AuthStep (step 7). Consent (step 0), Gender (step 2) and Diet
/// (step 4) are gated — the helper ticks the consent checkbox and picks a
/// default chip on the others before tapping "Weiter".
///
/// Shared between the widget-test driver in
/// `test/screens/registration/registration_wizard_screen_test.dart` and the
/// end-to-end driver in `integration_test/registration_flow_test.dart` so
/// wizard-step ordering lives in one place.
Future<void> advanceToAuthStep(WidgetTester tester) async {
  final nextButton = find.byKey(RegistrationWizardScreen.nextButtonKey);

  await acceptRegistrationHealthConsent(tester);

  expect(find.byKey(BirthYearStep.birthYearTitleKey), findsOneWidget);
  await tester.tap(nextButton);
  await tester.pumpAndSettle();

  expect(find.byKey(GenderStep.genderTitleKey), findsOneWidget);
  await tester.tap(find.byKey(GenderStep.genderMaennlichKey));
  await tester.pumpAndSettle();
  await tester.tap(nextButton);
  await tester.pumpAndSettle();

  expect(find.byKey(HeightWeightStep.heightWeightTitleKey), findsOneWidget);
  await tester.tap(nextButton);
  await tester.pumpAndSettle();

  expect(find.byKey(DietStep.dietTitleKey), findsOneWidget);
  await tester.tap(find.byKey(DietStep.dietAllesKey));
  await tester.pumpAndSettle();
  await tester.tap(nextButton);
  await tester.pumpAndSettle();

  expect(find.byKey(SymptomsStep.symptomsTitleKey), findsOneWidget);
  await tester.tap(nextButton);
  await tester.pumpAndSettle();

  expect(find.byKey(IntolerancesStep.intolerancesTitleKey), findsOneWidget);
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
}

/// Ticks the consent checkbox on the wizard's first step and advances.
Future<void> acceptRegistrationHealthConsent(WidgetTester tester) async {
  expect(find.byKey(HealthConsentStep.titleKey), findsOneWidget);
  final checkbox = find.byKey(HealthConsentContent.checkboxKey);
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await tester.pump();
  await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
  await tester.pumpAndSettle();
}

/// Whether the wizard's "Weiter" button is currently enabled.
bool registrationNextEnabled(WidgetTester tester) =>
    tester
        .widget<ElevatedButton>(
          find.byKey(RegistrationWizardScreen.nextButtonKey),
        )
        .onPressed !=
    null;
