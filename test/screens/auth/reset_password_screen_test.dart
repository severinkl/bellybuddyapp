// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/auth/reset_password_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  currentUserIdProvider.overrideWithValue(null),
];

void main() {
  group('ResetPasswordScreen', () {
    testWidgets('renders Neues Passwort app bar title', (tester) async {
      await tester.pumpWithProviders(
        const ResetPasswordScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      // "Neues Passwort" appears in both the appBar title and the input label
      expect(find.text('Neues Passwort'), findsAtLeast(1));
    });

    testWidgets('renders password input fields', (tester) async {
      await tester.pumpWithProviders(
        const ResetPasswordScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byType(TextField), findsAtLeast(2));
    });

    testWidgets('renders Passwort ändern button', (tester) async {
      await tester.pumpWithProviders(
        const ResetPasswordScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Passwort ändern'), findsOneWidget);
    });

    testWidgets('shows error when passwords do not match', (tester) async {
      await tester.pumpWithProviders(
        const ResetPasswordScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'passwort1');
      await tester.enterText(fields.at(1), 'passwort2');
      await tester.tap(find.text('Passwort ändern'));
      await tester.pump();

      expect(find.text('Passwörter stimmen nicht überein.'), findsOneWidget);
    });
  });
}
