import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/screens/health_consent/widgets/health_consent_content.dart';
import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';

/// Drives the registration wizard from the Buddy's name (step 0) up to and
/// including AuthStep (step 8). The name step keeps whatever name was typed
/// (prefilled „Buddy"); Consent (step 1), Gender (step 3) and Diet (step 5)
/// are gated — the helper ticks the consent checkbox and picks a default
/// chip on the others before tapping "Weiter".
///
/// Shared between the widget-test driver in
/// `test/screens/registration/registration_wizard_screen_test.dart` and the
/// end-to-end driver in `integration_test/registration_flow_test.dart` so
/// wizard-step ordering lives in one place.
Future<void> advanceToAuthStep(WidgetTester tester) async {
  final nextButton = find.byKey(RegistrationWizardScreen.nextButtonKey);

  await confirmRegistrationBuddyName(tester);
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

/// Confirms the Buddy's name on the wizard's first step and advances.
Future<void> confirmRegistrationBuddyName(WidgetTester tester) async {
  expect(find.byKey(BuddyNameStep.titleKey), findsOneWidget);
  await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
  await tester.pumpAndSettle();
}

/// Ticks the consent checkbox on the wizard's second step and advances.
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
