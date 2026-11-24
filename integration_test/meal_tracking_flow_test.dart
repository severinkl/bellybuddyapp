import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('the plus opens „Eintragen", and Essen opens the meal tracker', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final plus = find.byKey(BbBottomNav.centerButtonKey);
    expect(plus, findsOneWidget);
    await tester.tap(plus);
    await tester.pumpAndSettle();

    expect(find.byType(LogSheet), findsOneWidget);
    await tester.tap(find.byKey(LogSheet.optionKey(CareNeed.food)));
    await tester.pumpAndSettle();

    expect(find.byType(LogSheet), findsNothing);
    expect(find.byKey(MealTrackerScreen.mealTrackerTitleKey), findsOneWidget);
    expect(find.byType(MealTrackerScreen), findsOneWidget);
  });
}
