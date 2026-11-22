import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';

import 'helpers/test_app.dart';

/// The dashboard's animated Buddy ticks every frame, so `pumpAndSettle`
/// never settles there: pump in steps instead.
Future<void> _pumpFor(
  WidgetTester tester, [
  Duration total = const Duration(seconds: 2),
]) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Clear any SharedPreferences state left over from previous integration
    // tests so the notification opt-in modal is NOT pre-suppressed. This test
    // explicitly asserts that the modal appears after the tutorial finishes.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('first-run dashboard tour then notification modal', (
    tester,
  ) async {
    final profileRepo = FakeProfileRepository()
      // Explicitly opt in to the fresh-tutorial state — testUserProfile()
      // otherwise defaults to an already-seen timestamp so unrelated tests
      // don't trigger the tour.
      ..seedProfile(testUserProfile(alreadySeenTutorial: false));

    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        seedProfile: false,
        profileRepo: profileRepo,
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 5));

    // Welcome modal is the first tutorial stage on first launch. Dismiss it
    // via the CTA so the spotlight tour renders behind it.
    expect(find.text('Willkommen bei Belly Buddy!'), findsOneWidget);
    await tester.tap(find.text("Los geht's"));
    await _pumpFor(tester);

    // Tour is visible after the welcome modal is dismissed.
    expect(find.text('Überspringen'), findsOneWidget);

    // Advance 11 times (Buddy + 10 feature steps) via the overlay's advance
    // gesture — key-based so the test is independent of where the
    // Überspringen link sits.
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
      await _pumpFor(tester, const Duration(seconds: 1));
    }

    // Tour finished → repo written → notification modal appears.
    expect(find.text('Überspringen'), findsNothing);
    expect(profileRepo.lastTutorialSeenAt, isNotNull);
    expect(find.text('Bleib auf dem Laufenden!'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await _pumpFor(tester);
  });
}
