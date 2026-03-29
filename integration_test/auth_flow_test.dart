import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/screens/auth/auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unauthenticated user (null userId) sees welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(userId: null, authenticated: false));

    await tester.pumpAndSettle();

    // Unauthenticated user should be redirected to the welcome screen
    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
  });

  testWidgets(
    'unauthenticated user can navigate to auth screen and submit credentials',
    (tester) async {
      await tester.pumpWidget(buildTestApp(userId: null, authenticated: false));

      await tester.pumpAndSettle();

      // Verify we're on the welcome screen
      expect(find.byKey(WelcomeScreen.signInButtonKey), findsOneWidget);
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);

      // Tap the sign-in button to navigate to auth screen
      await tester.tap(find.byKey(WelcomeScreen.signInButtonKey));
      await tester.pumpAndSettle();

      // Verify we're on the auth screen by finding the email field
      expect(find.byKey(AuthScreen.emailFieldKey), findsOneWidget);
      expect(find.byKey(AuthScreen.passwordFieldKey), findsOneWidget);

      // Enter dummy credentials
      await tester.enterText(
        find.byKey(AuthScreen.emailFieldKey),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(AuthScreen.passwordFieldKey),
        'TestPassword123',
      );
      await tester.pumpAndSettle();

      // Verify the submit button exists and tap it
      expect(find.byKey(AuthScreen.submitLoginButtonKey), findsOneWidget);
      await tester.tap(find.byKey(AuthScreen.submitLoginButtonKey));
      await tester.pumpAndSettle();
    },
  );
}
