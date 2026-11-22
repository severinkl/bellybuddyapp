import 'package:belly_buddy/screens/registration/steps/auth_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('AuthStep', () {
    testWidgets('shows the privacy policy notice', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: AuthStep(
            isLoading: false,
            error: null,
            onEmailSignUp: (_, _) async {},
            onGoogleSignUp: () async {},
            onAppleSignUp: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(AuthStep.privacyNoticeKey), findsOneWidget);
      expect(
        find.text(
          'Mit der Registrierung akzeptierst du unsere Datenschutzerklärung.',
        ),
        findsOneWidget,
      );
    });
  });
}
