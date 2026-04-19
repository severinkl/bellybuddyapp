import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';

/// Drives the registration wizard from BirthYear (step 0) up to and including
/// AuthStep (step 6). Gender (step 1) and Diet (step 3) are gated — the helper
/// picks a default chip on each before tapping "Weiter".
///
/// Shared between the widget-test driver in
/// `test/screens/registration/registration_wizard_screen_test.dart` and the
/// end-to-end driver in `integration_test/registration_flow_test.dart` so
/// wizard-step ordering lives in one place.
Future<void> advanceToAuthStep(WidgetTester tester) async {
  final nextButton = find.byKey(RegistrationWizardScreen.nextButtonKey);

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
