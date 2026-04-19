// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/widgets/common/bb_social_button.dart';

import '../../helpers/fakes.dart';
import '../../helpers/registration_driver.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  currentUserIdProvider.overrideWithValue(null),
];

void main() {
  group('RegistrationWizardScreen', () {
    testWidgets('renders linear progress indicator', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders Weiter button on first step', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Weiter'), findsOneWidget);
    });

    testWidgets('renders Zur Anmeldung button', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Zur Anmeldung'), findsOneWidget);
    });

    testWidgets('Weiter button is present and tappable', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Weiter'), findsOneWidget);
      await tester.tap(find.text('Weiter'));
      await tester.pump(const Duration(milliseconds: 500));

      // After advancing, PageView moves to next step
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('OAuth email capture branch', () {
    // All three tests drive sign-in through the Google button. Apple's
    // `BbSocialButton.apple` is only rendered when `Platform.isIOS`, which is
    // false under `flutter test` on the host VM. The detection logic in the
    // wizard (`_needsEmailCapture` + `_finalizeAfterOAuthSignIn`) is
    // provider-agnostic, so driving the three seeded-email cases through
    // Google exercises the same branching regardless of which OAuth provider
    // would be used in production.

    Future<void> pumpWizard(
      WidgetTester tester, {
      required FakeAuthRepository authRepo,
      required FakeProfileRepository profileRepo,
    }) async {
      // The Gender and Diet steps use column layouts with chips that need
      // more vertical room than the default 800x600 test viewport provides.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          currentUserIdProvider.overrideWithValue(null),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Google sign-in with a real email skips the email capture step',
      (tester) async {
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: 'real@example.com',
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(tester, authRepo: authRepo, profileRepo: profileRepo);
        await advanceToAuthStep(tester);

        await tester.tap(
          find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsNothing);
        // Positive assertion: the skip branch must have reached _createProfile
        // with the auth user's email. Without this, a silent failure in
        // _finalizeAfterOAuthSignIn (e.g. GoRouter not found) would also
        // produce `findsNothing` and pass vacuously.
        expect(profileRepo.lastWrittenEmail, equals('real@example.com'));
      },
    );

    testWidgets(
      'Google sign-in with Apple relay email shows the email capture step',
      (tester) async {
        // Seeds an Apple relay address on the Google path (see group comment):
        // the branching logic is provider-agnostic, so this exercises the
        // "Apple Hide My Email" case through the only button that renders
        // in the host-VM test binding.
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: 'abc@privaterelay.appleid.com',
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(tester, authRepo: authRepo, profileRepo: profileRepo);
        await advanceToAuthStep(tester);

        await tester.tap(
          find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsOneWidget);
        // createProfile must NOT have fired yet — the wizard is waiting on
        // the user to type a real email on the new step.
        expect(profileRepo.lastWrittenEmail, isNull);
      },
    );

    testWidgets(
      'Google sign-in with empty email shows the email capture step',
      (tester) async {
        // Seeds a null email (simulates Apple second-sign-in) via the Google
        // path for the reasons documented in the group comment.
        final authRepo = FakeAuthRepository(signedIn: false, signInEmail: null);
        final profileRepo = FakeProfileRepository();
        await pumpWizard(tester, authRepo: authRepo, profileRepo: profileRepo);
        await advanceToAuthStep(tester);

        await tester.tap(
          find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsOneWidget);
        expect(profileRepo.lastWrittenEmail, isNull);
      },
    );
  });
}
