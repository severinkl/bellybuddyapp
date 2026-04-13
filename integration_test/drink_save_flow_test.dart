import 'package:belly_buddy/screens/screens.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('drink save button is disabled without selection', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Navigate to meal tracker then drink tracker
    await tester.tap(find.byKey(BbBottomNav.centerButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MealTrackerScreen.drinkTrackerButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(DrinkTrackerScreen), findsOneWidget);

    // Save button should exist but be disabled (no drink selected)
    final saveButton = find.byKey(DrinkTrackerScreen.saveButtonKey);
    expect(saveButton, findsOneWidget);

    // Tapping a disabled button should not navigate away
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Still on drink tracker
    expect(find.byType(DrinkTrackerScreen), findsOneWidget);
  });
}
