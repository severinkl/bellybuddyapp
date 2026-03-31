import 'package:belly_buddy/screens/auth/auth_screen.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('unauthenticated user sees welcome screen', (tester) async {
    await tester.pumpWidget(
      buildTestApp(authenticated: false, dynamicAuth: true),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
  });

  testWidgets('unauthenticated user can navigate to auth screen and sign in', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(authenticated: false, dynamicAuth: true),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(WelcomeScreen.signInButtonKey), findsOneWidget);
    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);

    await tester.tap(find.byKey(WelcomeScreen.signInButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(AuthScreen.emailFieldKey), findsOneWidget);
    expect(find.byKey(AuthScreen.passwordFieldKey), findsOneWidget);

    await tester.enterText(
      find.byKey(AuthScreen.emailFieldKey),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(AuthScreen.passwordFieldKey),
      'TestPassword123',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AuthScreen.submitLoginButtonKey), findsOneWidget);
    await tester.tap(find.byKey(AuthScreen.submitLoginButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(BbBottomNav.centerButtonKey), findsOneWidget);
  });
}
