// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/settings/widgets/settings_account_screen.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/reduce_motion.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _buildOverrides() {
  return [
    currentUserProvider.overrideWithValue(null),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
    currentUserIdProvider.overrideWithValue(null),
  ];
}

void main() {
  group('SettingsAccountScreen', () {
    testWidgets('renders Konto & Sicherheit app bar title', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Konto & Sicherheit'), findsOneWidget);
    });

    testWidgets('renders Kontoinformationen section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Kontoinformationen'), findsOneWidget);
    });

    testWidgets('renders Abmelden button', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Abmelden'), findsOneWidget);
    });

    testWidgets('renders Gefahrenzone section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Gefahrenzone'), findsOneWidget);
    });
    testWidgets(
      'each password eye says „Passwort anzeigen", then „Passwort verbergen"',
      (tester) async {
        await _openPasswordChange(tester);

        expect(find.byTooltip('Passwort anzeigen'), findsNWidgets(3));
        expect(find.byTooltip('Passwort verbergen'), findsNothing);

        for (var shown = 1; shown <= 3; shown++) {
          final eye = find.byTooltip('Passwort anzeigen').first;
          await tester.ensureVisible(eye);
          await tester.tap(eye);
          await tester.pump();
          expect(find.byTooltip('Passwort verbergen'), findsNWidgets(shown));
          expect(find.byTooltip('Passwort anzeigen'), findsNWidgets(3 - shown));
        }
      },
    );

    testWidgets('with reduce motion the password fields open without a fade', (
      tester,
    ) async {
      reduceMotion(tester);
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Passwort ändern').first);
      await tester.tap(find.text('Passwort ändern').first);
      await tester.pump();

      // Open after one frame, with nothing left to animate.
      expect(find.byType(AnimatedCrossFade), findsNothing);
      expect(find.text('Aktuelles Passwort'), findsWidgets);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('„Passwort vergessen?" is at least 48 high', (tester) async {
      await _openPasswordChange(tester);

      // Centred, so the viewport doesn't clip the hit area.
      await Scrollable.ensureVisible(
        tester.element(find.text('Passwort vergessen?')),
        alignment: 0.5,
      );
      await tester.pump();
      final handle = tester.ensureSemantics();
      final link = tester.getSemantics(find.text('Passwort vergessen?'));
      expect(link.rect.height, greaterThanOrEqualTo(48));
      expect(link, isSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('„Passwort ändern" is at least 48 high', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      final handle = tester.ensureSemantics();
      final row = tester.getSemantics(find.text('Passwort ändern').first);
      expect(row.rect.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('„Passwort ändern" is a button that says whether it is open', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      final row = find.text('Passwort ändern').first;
      await tester.ensureVisible(row);
      expect(
        tester.getSemantics(row),
        isSemantics(
          label: 'Passwort ändern',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Passwort ändern').first),
        isSemantics(
          label: 'Passwort ändern',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}

/// Pumps the account screen and opens „Passwort ändern".
Future<void> _openPasswordChange(WidgetTester tester) async {
  await tester.pumpWithProviders(
    const SettingsAccountScreen(),
    overrides: _buildOverrides(),
  );
  await tester.pump();
  // The first: the row; the other is the (folded) section's button.
  await tester.ensureVisible(find.text('Passwort ändern').first);
  await tester.tap(find.text('Passwort ändern').first);
  await tester.pumpAndSettle();
}
