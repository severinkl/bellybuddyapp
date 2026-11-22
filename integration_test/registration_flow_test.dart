import 'package:belly_buddy/screens/buddy/buddy_onboarding_screen.dart';
import 'package:belly_buddy/screens/health_consent/health_consent_screen.dart';
import 'package:belly_buddy/screens/registration/steps/auth_step.dart';
import 'package:belly_buddy/screens/registration/steps/buddy_name_step.dart';
import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/widgets/buddy/buddy_stage.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:belly_buddy/widgets/common/bb_social_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/registration_driver.dart';
import 'helpers/test_app.dart';
import 'helpers/welcome_driver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new user should see welcome screen and registration button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(authenticated: false, seedProfile: false, dynamicAuth: true),
    );
    await pumpUntilWelcome(tester);

    // New user (no profile) should be redirected to the welcome screen,
    // whose Buddy offers the registration after his intro.
    await finishWelcomeStory(tester);
    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
  });

  testWidgets(
    'new user should tap on registration button and go through registration process',
    (tester) async {
      await setNotificationModalShown();
      await tester.pumpWidget(
        buildTestApp(
          authenticated: false,
          seedProfile: false,
          dynamicAuth: true,
        ),
      );

      await pumpUntilWelcome(tester);
      await finishWelcomeStory(tester);

      final registrationButton = find.byKey(
        WelcomeScreen.registrationButtonKey,
      );

      // New user (no profile) should be redirected to the welcome screen
      expect(registrationButton, findsOneWidget);

      // Tap on the registration button
      await tester.tap(registrationButton);
      await tester.pumpAndSettle();

      // Step 0: name the Buddy, then advance through the consent and the
      // six profile steps
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await advanceToAuthStep(tester);

      // Step 8: Auth - Verify email/password fields are shown
      expect(find.byKey(AuthStep.emailFieldKey), findsOneWidget);
      expect(find.byKey(BbPasswordField.passwordFieldKey), findsOneWidget);

      // Enter email and password, then tap on sign up button
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

      // The consent given in the wizard is stored with the profile, so the
      // post-login consent gate does not appear.
      expect(find.byType(HealthConsentScreen), findsNothing);

      // After successful registration the Buddy onboarding takes over, with
      // the name given in the wizard saved.
      expect(find.byType(BuddyOnboardingScreen), findsOneWidget);
      expect(tester.widget<BuddyStage>(find.byType(BuddyStage)).name, 'Bauchi');
    },
  );

  testWidgets(
    'Apple sign-up with Hide My Email captures a real email into the profile',
    (tester) async {
      // Test-VM note: `BbSocialButton.apple` is gated on `Platform.isIOS` and
      // does not render in the host-VM test binding. The wizard's
      // `_finalizeAfterOAuthSignIn` branching is provider-agnostic, so the
      // test name says "Apple" (the real-world scenario we care about) but
      // drives the flow through the Google button while seeding an Apple
      // Hide-My-Email relay address on the fake auth repository.
      await setNotificationModalShown();

      // The Gender and Diet steps need more vertical room than the default
      // test viewport to render their chip rows without overflow.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profileRepo = FakeProfileRepository();

      await tester.pumpWidget(
        buildTestApp(
          authenticated: false,
          seedProfile: false,
          dynamicAuth: true,
          signInEmail: 'abc@privaterelay.appleid.com',
          profileRepo: profileRepo,
        ),
      );
      await pumpUntilWelcome(tester);

      // Start registration.
      await finishWelcomeStory(tester);
      await tester.tap(find.byKey(WelcomeScreen.registrationButtonKey));
      await tester.pumpAndSettle();

      // Advance through the name, consent and six profile steps.
      await advanceToAuthStep(tester);

      // Tap Google sign-up (see test-VM note above).
      await tester.tap(
        find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
      );
      await tester.pumpAndSettle();

      // Email capture step is showing because the seeded user has no email
      // (simulates Apple Hide-My-Email / second-sign-in).
      expect(find.byType(EmailCaptureStep), findsOneWidget);

      // Type a real email and submit.
      await tester.enterText(
        find.byKey(EmailCaptureStep.emailFieldKey),
        'user@example.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(EmailCaptureStep.submitButtonKey));
      await tester.pumpAndSettle();

      // The consent given in the wizard is stored with the profile, so the
      // post-login consent gate does not appear.
      expect(find.byType(HealthConsentScreen), findsNothing);

      // The Buddy onboarding takes over.
      expect(find.byType(BuddyOnboardingScreen), findsOneWidget);

      // Profile was written with the captured email.
      expect(profileRepo.lastWrittenEmail, equals('user@example.com'));
    },
  );
}
