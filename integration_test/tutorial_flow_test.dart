import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';

import 'helpers/test_app.dart';

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
    await tester.pumpAndSettle();

    // Tour is visible on first launch.
    expect(find.text('Überspringen'), findsOneWidget);

    // Advance 10 times by tapping outside the Überspringen link.
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
    }

    // Tour finished → repo written → notification modal appears.
    expect(find.text('Überspringen'), findsNothing);
    expect(profileRepo.lastTutorialSeenAt, isNotNull);
    expect(find.text('Bleib auf dem Laufenden!'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });
}
