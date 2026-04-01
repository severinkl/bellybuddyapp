import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new user should see welcome screen and registration button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(authenticated: false, seedProfile: false, dynamicAuth: true),
    );
    await tester.pumpAndSettle();

    // New user (no profile) should be redirected to the welcome screen
    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
  });

  testWidgets(
    'new user should tap on registration button and go through registration process',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          authenticated: false,
          seedProfile: false,
          dynamicAuth: true,
        ),
      );

      await tester.pumpAndSettle();

      final registrationButton = find.byKey(
        WelcomeScreen.registrationButtonKey,
      );

      // New user (no profile) should be redirected to the welcome screen
      expect(registrationButton, findsOneWidget);

      // Tap on the registration button
      await tester.tap(registrationButton);
      await tester.pumpAndSettle();

      final nextButtonKey = find.byKey(RegistrationWizardScreen.nextButtonKey);

      // Step 1: Birth Year
      expect(find.byKey(BirthYearStep.birthYearTitleKey), findsOneWidget);
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 2: Gender - Select "Männlich" option
      expect(find.byKey(GenderStep.genderTitleKey), findsOneWidget);
      await tester.tap(find.byKey(GenderStep.genderMaennlichKey));
      await tester.pumpAndSettle();

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 3: Height & Weight - Verify title is shown
      expect(find.byKey(HeightWeightStep.heightWeightTitleKey), findsOneWidget);

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 4: Diet - Select "Alles" option
      expect(find.byKey(DietStep.dietTitleKey), findsOneWidget);
      await tester.tap(find.byKey(DietStep.dietAllesKey));
      await tester.pumpAndSettle();

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 5: Symptoms - Verify title is shown
      expect(find.byKey(SymptomsStep.symptomsTitleKey), findsOneWidget);

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 6: Intolerances - Verify title is shown
      expect(find.byKey(IntolerancesStep.intolerancesTitleKey), findsOneWidget);

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 7: Auth - Verify email/password fields are shown
      expect(find.byKey(AuthStep.emailFieldKey), findsOneWidget);
      expect(find.byKey(BbPasswordField.passwordFieldKey), findsOneWidget);

      // Step 8: Enter email and password, then tap on sign up button
      await tester.enterText(
        find.byKey(AuthStep.emailFieldKey),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(BbPasswordField.passwordFieldKey),
        'TestPassword123',
      );

      await tester.pumpAndSettle();

      final submitButton = find.byKey(AuthStep.submitButtonKey);
      expect(submitButton, findsOneWidget);

      // Tap on the sign up button
      await tester.tap(submitButton);
      await tester.pumpAndSettle(); // Wait for async operations to complete

      // After successful registration, user should be navigated to the main app (bottom nav should be visible)
      expect(find.byKey(BbBottomNav.centerButtonKey), findsOneWidget);
    },
  );
}
