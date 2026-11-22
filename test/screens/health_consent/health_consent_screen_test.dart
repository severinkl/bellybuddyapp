// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/screens/health_consent/health_consent_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

void main() {
  late FakeProfileRepository profiles;

  setUp(() {
    profiles = FakeProfileRepository()
      ..seedProfile(testUserProfile(hasHealthConsent: false));
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWithProviders(
      const HealthConsentScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    await tester.pump();
  }

  ElevatedButton acceptButton(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.byKey(HealthConsentScreen.acceptButtonKey));

  Future<void> tickCheckbox(WidgetTester tester) async {
    final checkbox = find.byKey(HealthConsentScreen.consentCheckboxKey);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
  }

  group('HealthConsentScreen', () {
    testWidgets('explains the processing in German', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Deine Gesundheitsdaten'), findsOneWidget);
      expect(find.textContaining('FODMAP-Hinweise'), findsOneWidget);
      expect(find.text('Mahlzeiten mit Fotos'), findsOneWidget);
      expect(find.text('Getränke'), findsOneWidget);
      expect(find.text('Bauchgefühl und Symptome'), findsOneWidget);
      expect(find.text('Toiletten-Einträge'), findsOneWidget);
      expect(find.textContaining('Anthropic, USA'), findsOneWidget);
      expect(find.textContaining('jederzeit widerrufen'), findsOneWidget);
      expect(find.text('Datenschutzerklärung lesen'), findsOneWidget);
      expect(
        find.text(
          'Ich willige ausdrücklich ein, dass meine Gesundheitsdaten wie '
          'beschrieben verarbeitet werden.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abmelden'), findsOneWidget);
      expect(find.text('Konto löschen'), findsOneWidget);
    });

    testWidgets('the accept button is disabled until the checkbox is ticked', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Zustimmen und fortfahren'), findsOneWidget);
      expect(acceptButton(tester).onPressed, isNull);

      await tickCheckbox(tester);
      expect(acceptButton(tester).onPressed, isNotNull);

      await tickCheckbox(tester);
      expect(acceptButton(tester).onPressed, isNull);
    });

    testWidgets('a failed save shows a German error snackbar', (tester) async {
      profiles.acceptHealthConsentError = Exception('network');
      await pumpScreen(tester);

      await tickCheckbox(tester);
      final button = find.byKey(HealthConsentScreen.acceptButtonKey);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(profiles.acceptHealthConsentCount, 1);
      expect(
        find.textContaining('Einwilligung konnte nicht gespeichert werden'),
        findsOneWidget,
      );
      expect(find.byType(HealthConsentScreen), findsOneWidget);
    });

    testWidgets('"Konto löschen" opens the delete-account dialog', (
      tester,
    ) async {
      await pumpScreen(tester);

      final link = find.text('Konto löschen');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.text('Konto endgültig löschen'), findsOneWidget);
    });
  });
}
