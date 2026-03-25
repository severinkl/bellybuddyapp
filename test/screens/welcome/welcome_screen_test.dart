// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('renders Registrieren button', (tester) async {
      await tester.pumpWithProviders(const WelcomeScreen());
      // Use pump with duration; WelcomeScreen has an infinite Timer
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Registrieren'), findsOneWidget);
    });

    testWidgets('renders Zur Anmeldung button', (tester) async {
      await tester.pumpWithProviders(const WelcomeScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Zur Anmeldung'), findsOneWidget);
    });

    testWidgets('renders first slide title', (tester) async {
      await tester.pumpWithProviders(const WelcomeScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verstehe dein Bauchgefühl'), findsOneWidget);
    });

    testWidgets('renders PageView for slides', (tester) async {
      await tester.pumpWithProviders(const WelcomeScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
