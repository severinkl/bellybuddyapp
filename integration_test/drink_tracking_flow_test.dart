import 'package:belly_buddy/screens/screens.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fixtures.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('can open drink tracker', (tester) async {
    await tester.pumpWidget(
      buildTestApp(userId: testUserId, authenticated: true),
    );
    await tester.pumpAndSettle();

    // should find the drink tracker button on the dashboard and tap it
    final drinkTrackerButton = find.byKey(BbBottomNav.centerButtonKey);
    expect(drinkTrackerButton, findsOneWidget);
    await tester.tap(drinkTrackerButton);
    await tester.pumpAndSettle();

    expect(find.byKey(MealTrackerScreen.drinkTrackerButtonKey), findsOneWidget);
  });

  testWidgets('drink tracker shows drink options when open', (tester) async {
    await tester.pumpWidget(
      buildTestApp(userId: testUserId, authenticated: true),
    );
    await tester.pumpAndSettle();

    // should find the drink tracker button on the dashboard and tap it
    final centerButtonKey = find.byKey(BbBottomNav.centerButtonKey);
    expect(centerButtonKey, findsOneWidget);
    await tester.tap(centerButtonKey);
    await tester.pumpAndSettle();

    expect(find.byKey(MealTrackerScreen.drinkTrackerButtonKey), findsOneWidget);

    final drinkTrackerButtonKey = find.byKey(
      MealTrackerScreen.drinkTrackerButtonKey,
    );
    expect(drinkTrackerButtonKey, findsOneWidget);
    await tester.tap(drinkTrackerButtonKey);
    await tester.pumpAndSettle();

    expect(find.byType(DrinkTrackerScreen), findsOneWidget);
  });
}
