import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';

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

  testWidgets('first-run dashboard tour + replay from settings', (
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

    // 1. Tour is visible
    expect(find.text('Überspringen'), findsOneWidget);

    // 2. Advance 10 times by tapping anywhere that is NOT the Überspringen link.
    // Tap well inside the screen but away from the top-right corner.
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
    }

    // 3. Tour finished
    expect(find.text('Überspringen'), findsNothing);

    // 4. Notification opt-in modal appears (title copy from
    //    lib/screens/dashboard/widgets/notification_opt_in_dialog.dart:108)
    expect(find.text('Bleib auf dem Laufenden!'), findsOneWidget);

    // 5. Dismiss notification modal by tapping its close icon.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 6. Verify the repo was written
    expect(profileRepo.lastTutorialSeenAt, isNotNull);

    // 7. Open settings → replay
    await tester.tap(find.byKey(TutorialKeys.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tour neu starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neu starten'));
    await tester.pumpAndSettle();

    // 8. Tour reappears on dashboard
    expect(find.text('Überspringen'), findsOneWidget);
    expect(profileRepo.lastTutorialSeenAt, isNull);
  });
}
