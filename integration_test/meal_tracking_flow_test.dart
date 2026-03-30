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

  testWidgets(
    'can navigate to meal tracker from dashboard and should see the title',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // should find the meal tracker button on the dashboard and tap it
      final mealTrackerButton = find.byKey(BbBottomNav.centerButtonKey);
      expect(mealTrackerButton, findsOneWidget);
      await tester.tap(mealTrackerButton);
      await tester.pumpAndSettle();

      // should navigate to the meal tracker screen and find the title
      expect(find.byKey(MealTrackerScreen.mealTrackerTitleKey), findsOneWidget);
      expect(find.byType(MealTrackerScreen), findsOneWidget);
    },
  );
}
