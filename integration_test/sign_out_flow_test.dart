import 'package:belly_buddy/screens/auth/auth_screen.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_account_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('authenticated user can sign out and see welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(dynamicAuth: true));
    await tester.pumpAndSettle();

    // Should be on dashboard
    expect(find.byKey(BbBottomNav.centerButtonKey), findsOneWidget);

    // Navigate to settings
    await tester.tap(find.byKey(const Key('dashboard_settings_button')));
    await tester.pumpAndSettle();

    // Navigate to account settings
    await tester.tap(find.text('Konto & Sicherheit'));
    await tester.pumpAndSettle();

    // Tap sign out — scrolling may be needed on small screens
    await tester.ensureVisible(
      find.byKey(SettingsAccountScreen.signOutButtonKey),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SettingsAccountScreen.signOutButtonKey));
    await tester.pumpAndSettle();

    // Auth state change + router redirect may need extra settling
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Should be redirected to auth screen
    expect(find.byKey(AuthScreen.emailFieldKey), findsOneWidget);
  });
}
