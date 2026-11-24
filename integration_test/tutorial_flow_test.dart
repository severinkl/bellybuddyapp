import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tooltip_bubble.dart';

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
        // Back from the Buddy onboarding: the gate lets the dashboard show.
        seedBuddy: true,
        profileRepo: profileRepo,
      ),
    );
    await tester.pumpAndSettle();

    // The Buddy onboarding did the welcoming: the spotlight tour starts
    // right away, with no welcome modal in front of it.
    expect(find.text('Willkommen bei Belly Buddy!'), findsNothing);
    expect(find.text('Überspringen'), findsOneWidget);

    // Advance through the 7 steps (Buddy and ring, next action, plus,
    // insight card, Tagebuch, Entdecken, Ich) via the overlay's advance
    // gesture — key-based so the test is independent of where the
    // Überspringen link sits. Each step must show its own bubble: a target
    // missing on the real Home would be skipped and end the tour early.
    expect(dashboardTutorialSteps, hasLength(7));
    for (final step in dashboardTutorialSteps) {
      final text = step.richText.map((s) => s.toPlainText()).join();
      expect(
        find.descendant(
          of: find.byType(TooltipBubble),
          matching: find.text(text, findRichText: true),
        ),
        findsOneWidget,
        reason: text,
      );
      await tester.tap(find.byKey(DashboardTutorialOverlay.advanceKey));
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
