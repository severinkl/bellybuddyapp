// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/screens/settings/settings_screen.dart';

import '../../helpers/riverpod_helpers.dart';

final _overrides = [currentUserProvider.overrideWithValue(null)];

void main() {
  group('SettingsScreen', () {
    testWidgets('renders Einstellungen app bar title', (tester) async {
      await tester.pumpWithProviders(
        const SettingsScreen(),
        overrides: _overrides,
      );
      await tester.pump();

      expect(find.text('Einstellungen'), findsOneWidget);
    });

    testWidgets('renders Mein Profil menu item', (tester) async {
      await tester.pumpWithProviders(
        const SettingsScreen(),
        overrides: _overrides,
      );
      await tester.pump();

      expect(find.text('Mein Profil'), findsOneWidget);
    });

    testWidgets('renders Benachrichtigungen menu item', (tester) async {
      await tester.pumpWithProviders(
        const SettingsScreen(),
        overrides: _overrides,
      );
      await tester.pump();

      expect(find.text('Benachrichtigungen'), findsOneWidget);
    });

    testWidgets('renders Konto & Sicherheit menu item', (tester) async {
      await tester.pumpWithProviders(
        const SettingsScreen(),
        overrides: _overrides,
      );
      await tester.pump();

      expect(find.text('Konto & Sicherheit'), findsOneWidget);
    });
  });
}
