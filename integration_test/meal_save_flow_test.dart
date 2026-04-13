import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('meal save button is disabled without ingredients', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BbBottomNav.centerButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(MealTrackerScreen), findsOneWidget);

    // Save button should exist but be disabled (no ingredients added)
    final saveButton = find.byKey(MealTrackerScreen.saveButtonKey);
    expect(saveButton, findsOneWidget);

    // Tapping a disabled button should not navigate away
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Still on the meal tracker screen
    expect(find.byType(MealTrackerScreen), findsOneWidget);
  });
}
