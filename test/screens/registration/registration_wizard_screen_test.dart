// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
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

    testWidgets('renders Zurück button', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Zurück'), findsOneWidget);
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
}
