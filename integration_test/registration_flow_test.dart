import 'package:belly_buddy/screens/registration/steps/auth_step.dart';
import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:belly_buddy/widgets/common/bb_social_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/registration_driver.dart';
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
      await setNotificationModalShown();
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

      // Advance through the 6 pre-auth wizard steps
      await advanceToAuthStep(tester);

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
      await tester.pumpAndSettle();

      // Start registration.
      await tester.tap(find.byKey(WelcomeScreen.registrationButtonKey));
      await tester.pumpAndSettle();

      // Advance through the 6 pre-auth wizard steps.
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

      // Dashboard reached.
      expect(find.byKey(BbBottomNav.navHomeKey), findsOneWidget);

      // Profile was written with the captured email.
      expect(profileRepo.lastWrittenEmail, equals('user@example.com'));
    },
  );
}
