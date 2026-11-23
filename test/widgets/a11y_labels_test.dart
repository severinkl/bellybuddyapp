import 'package:belly_buddy/config/app_localizations.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/widgets/common/tracker_screen_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';

/// The app's German setup ([appLocalizationsDelegates]) around [home].
Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: const [Locale('de', 'DE')],
  locale: const Locale('de', 'DE'),
  home: home,
);

/// The tooltip of the semantics node of [finder]: iOS reads it as the
/// label of a button that has none.
String? _tooltipOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData().tooltip;

void main() {
  testWidgets('the password eye says what it does, in German', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Scaffold(body: BbPasswordField(controller: TextEditingController())),
      ),
    );

    expect(_tooltipOf(tester, find.byType(IconButton)), 'Passwort anzeigen');
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(_tooltipOf(tester, find.byType(IconButton)), 'Passwort verbergen');
    semantics.dispose();
  });

  testWidgets('a tracker\'s back arrow is „Zurück"', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const TrackerScreenScaffold(
          title: 'Test',
          showSuccess: false,
          successMessage: '',
          body: SizedBox.shrink(),
        ),
      ),
    );

    expect(_tooltipOf(tester, find.byIcon(Icons.arrow_back)), 'Zurück');
    semantics.dispose();
  });

  testWidgets('the Bauchgefühl tracker\'s back arrow is „Zurück"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
          buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
        child: _app(const GutFeelingTrackerScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(_tooltipOf(tester, find.byIcon(Icons.arrow_back)), 'Zurück');
    semantics.dispose();
  });

  testWidgets('a sheet\'s scrim reads „Schließen", not „Gitter"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 200),
              ),
              child: const Text('öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
    expect(find.bySemanticsLabel('Gitter'), findsNothing);
    // Everything else stays the stock German.
    final l10n = MaterialLocalizations.of(tester.element(find.text('öffnen')));
    expect(l10n.backButtonTooltip, 'Zurück');
    expect(l10n.okButtonLabel, 'OK');
    semantics.dispose();
  });
}
