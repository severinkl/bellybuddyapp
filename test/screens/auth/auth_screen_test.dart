// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/auth/auth_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  currentUserIdProvider.overrideWithValue(null),
];

void main() {
  group('AuthScreen', () {
    testWidgets('renders email field', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('E-Mail'), findsAtLeast(1));
    });

    testWidgets('renders Anmelden button', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Anmelden'), findsOneWidget);
    });

    testWidgets('renders Willkommen zurück heading', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Willkommen zurück'), findsOneWidget);
    });

    testWidgets('switches to forgot-password view on tap', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      // Tap the TextButton "Passwort vergessen?" (not the label, the button)
      await tester.tap(find.text('Passwort vergessen?').first);
      await tester.pump();

      expect(find.text('Zurücksetzen'), findsOneWidget);
    });

    testWidgets('shows validation error when submitting empty form', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      await tester.tap(find.text('Anmelden'));
      await tester.pump();

      expect(find.text('E-Mail ist erforderlich'), findsOneWidget);
    });
  });
}
