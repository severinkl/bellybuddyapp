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

  testWidgets('can navigate to settings from dashboard', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(BbBottomNav.centerButtonKey), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard_settings_button')));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Mein Profil'), findsOneWidget);
    expect(find.text('Benachrichtigungen'), findsOneWidget);
    expect(find.text('Konto & Sicherheit'), findsOneWidget);
    expect(find.text('Feedback geben'), findsOneWidget);
  });

  testWidgets('can navigate to profile settings', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_settings_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mein Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Mein Profil'), findsWidgets);
  });

  testWidgets('can navigate to notification settings', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_settings_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Benachrichtigungen'));
    await tester.pumpAndSettle();

    expect(find.text('Benachrichtigungen erlauben'), findsOneWidget);
  });

  testWidgets('can navigate to account settings', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_settings_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Konto & Sicherheit'));
    await tester.pumpAndSettle();

    expect(find.text('Abmelden'), findsOneWidget);
  });
}
