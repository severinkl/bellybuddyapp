// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:belly_buddy/screens/settings/settings_screen.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('renders Einstellungen app bar title', (tester) async {
      await tester.pumpWithProviders(const SettingsScreen());
      await tester.pump();

      expect(find.text('Einstellungen'), findsOneWidget);
    });

    testWidgets('renders Mein Profil menu item', (tester) async {
      await tester.pumpWithProviders(const SettingsScreen());
      await tester.pump();

      expect(find.text('Mein Profil'), findsOneWidget);
    });

    testWidgets('renders Benachrichtigungen menu item', (tester) async {
      await tester.pumpWithProviders(const SettingsScreen());
      await tester.pump();

      expect(find.text('Benachrichtigungen'), findsOneWidget);
    });

    testWidgets('renders Konto & Sicherheit menu item', (tester) async {
      await tester.pumpWithProviders(const SettingsScreen());
      await tester.pump();

      expect(find.text('Konto & Sicherheit'), findsOneWidget);
    });

    testWidgets('renders Datenschutzerklärung menu item', (tester) async {
      await tester.pumpWithProviders(const SettingsScreen());
      await tester.pump();

      expect(find.text('Datenschutzerklärung'), findsOneWidget);
    });

    testWidgets('has no Feedback geben row (it lives in the Ich tab)', (
      tester,
    ) async {
      await tester.pumpWithProviders(const SettingsScreen());
      await tester.pump();

      expect(find.text('Feedback geben'), findsNothing);
    });

    testWidgets('Produktdaten row under Datenschutzerklärung opens the dialog '
        'with the ODbL text and both links', (tester) async {
      final opened = <Uri>[];
      Future<bool> open(
        Uri url, {
        LaunchMode mode = LaunchMode.platformDefault,
      }) async {
        opened.add(url);
        return true;
      }

      await tester.pumpWithProviders(SettingsScreen(openUrl: open));
      await tester.pump();

      expect(find.text('Open Food Facts, Lizenz ODbL'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(SettingsScreen.productDataKey)).dy,
        greaterThan(tester.getTopLeft(find.text('Datenschutzerklärung')).dy),
      );

      await tester.tap(find.byKey(SettingsScreen.productDataKey));
      await tester.pumpAndSettle();
      expect(find.text('Produktdaten von Open Food Facts'), findsOneWidget);
      expect(
        find.text(
          'Name, Marke und Zutaten von Produkten, die du scannst oder '
          'suchst, sowie ein Teil der Zutatennamen in unserem Katalog '
          'stammen aus Open Food Facts, einer freien Lebensmitteldatenbank. '
          'Die Daten stehen unter der Open Database License (ODbL).',
        ),
        findsOneWidget,
      );

      // A link closes the dialog before it opens.
      await tester.tap(find.text('Open Food Facts öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Produktdaten von Open Food Facts'), findsNothing);
      await tester.tap(find.byKey(SettingsScreen.productDataKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lizenz ansehen'));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse(AppConstants.offHomeUrl),
        Uri.parse(AppConstants.odblLicenseUrl),
      ]);

      await tester.tap(find.byKey(SettingsScreen.productDataKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      expect(find.text('Produktdaten von Open Food Facts'), findsNothing);
    });

    testWidgets('a link that fails to open shows the message with no dialog '
        'barrier above it', (tester) async {
      Future<bool> open(
        Uri url, {
        LaunchMode mode = LaunchMode.platformDefault,
      }) async => false;

      await tester.pumpWithProviders(SettingsScreen(openUrl: open));
      await tester.pump();
      await tester.tap(find.byKey(SettingsScreen.productDataKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lizenz ansehen'));
      await tester.pumpAndSettle();

      expect(find.text('Produktdaten von Open Food Facts'), findsNothing);
      expect(find.text('Link konnte nicht geöffnet werden.'), findsOneWidget);
      // Visible: the SnackBar takes the tap (no barrier in front of it).
      expect(
        find.text('Link konnte nicht geöffnet werden.').hitTestable(),
        findsOneWidget,
      );
    });
  });
}
