// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/screens/health_consent/health_consent_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

/// The re-consent line for the policy of 01.12.2026.
const _policyUpdated =
    'Wir haben unsere Datenschutzerklärung aktualisiert (Stand 01.12.2026).';

/// What the copy says goes to the KI-Dienst, sentence by sentence.
const _aiSentences = [
  'Fotos und Beschreibungen deiner Mahlzeiten werden von einem KI-Dienst '
      '(Anthropic, USA) analysiert.',
  'Wenn du die wöchentlichen Tipps einschaltest, gehen deine Einträge der '
      'letzten Wochen, die Muster daraus und deine Bewertungen der bisherigen '
      'Tipps an diesen KI-Dienst.',
  'Erst wenn du bei einem Rezept auf „Für mich anpassen“ tippst, gehen dieses '
      'Rezept, deine Unverträglichkeiten und deine Ernährungsform an den '
      'KI-Dienst.',
];

void main() {
  late FakeProfileRepository profiles;

  setUp(() {
    profiles = FakeProfileRepository()
      ..seedProfile(testUserProfile(hasHealthConsent: false));
  });

  /// The screen once the seeded profile is loaded, as the router shows it.
  Future<void> pumpScreen(WidgetTester tester) async {
    final overrides = [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      profileRepositoryProvider.overrideWithValue(profiles),
    ];
    await tester.pumpWithProviders(const SizedBox(), overrides: overrides);
    await ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(profileProvider.notifier).fetchProfile();
    // The same scope, now with the screen.
    await tester.pumpWithProviders(
      const HealthConsentScreen(),
      overrides: overrides,
    );
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
    testWidgets('a re-consent says first that the policy changed', (
      tester,
    ) async {
      profiles = FakeProfileRepository()
        ..seedProfile(testUserProfile(privacyPolicyVersion: '2026-11-22'));
      await pumpScreen(tester);

      expect(find.text(_policyUpdated), findsOneWidget);
      // Above the existing copy, which follows unchanged.
      expect(
        tester.getRect(find.text(_policyUpdated)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.textContaining('Belly Buddy verarbeitet')).top,
        ),
      );
      expect(find.textContaining('FODMAP-Hinweise'), findsOneWidget);
      expect(find.text('Datenschutzerklärung lesen'), findsOneWidget);
    });

    testWidgets('a first-time consent says nothing about an update', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Deine Gesundheitsdaten'), findsOneWidget);
      expect(find.textContaining('aktualisiert'), findsNothing);
    });

    testWidgets('the KI-Dienst copy names the weekly Tipps and „Für mich '
        'anpassen“', (tester) async {
      await pumpScreen(tester);

      for (final sentence in _aiSentences) {
        expect(find.textContaining(sentence), findsOneWidget, reason: sentence);
      }
      // The copy file is exempt from the vocabulary scan: guard it here.
      expect(find.textContaining('Empfehlung'), findsNothing);
    });

    testWidgets('a re-consent fits 375×667 at text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      profiles = FakeProfileRepository()
        ..seedProfile(testUserProfile(privacyPolicyVersion: '2026-11-22'));
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      final line = tester.getRect(find.text(_policyUpdated));
      expect(line.left, greaterThanOrEqualTo(0));
      expect(line.right, lessThanOrEqualTo(375));

      // The checkbox and the button are reachable by scrolling.
      await tickCheckbox(tester);
      final button = find.byKey(HealthConsentScreen.acceptButtonKey);
      await tester.ensureVisible(button);
      await tester.pump();
      expect(button.hitTestable(), findsOneWidget);
      expect(acceptButton(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

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
