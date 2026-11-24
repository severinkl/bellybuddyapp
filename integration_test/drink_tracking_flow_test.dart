import 'package:belly_buddy/screens/screens.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

/// Taps the plus in the bar, then [need] in the „Eintragen" sheet.
Future<void> _logVia(WidgetTester tester, CareNeed need) async {
  await tester.tap(find.byKey(BbBottomNav.centerButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(LogSheet.optionKey(need)));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('Trinken in the „Eintragen" sheet opens the drink tracker', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await _logVia(tester, CareNeed.drink);

    expect(find.byType(DrinkTrackerScreen), findsOneWidget);
    expect(find.byType(MealTrackerScreen), findsNothing);
  });

  testWidgets('the meal tracker hands over with „Trinken eintragen"', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await _logVia(tester, CareNeed.food);
    expect(find.byType(MealTrackerScreen), findsOneWidget);

    final drinkButton = find.byKey(MealTrackerScreen.drinkTrackerButtonKey);
    expect(drinkButton, findsOneWidget);
    expect(
      find.descendant(
        of: drinkButton,
        matching: find.text('Trinken eintragen'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(drinkButton);
    await tester.pumpAndSettle();
    await tester.tap(drinkButton);
    await tester.pumpAndSettle();

    expect(find.byType(DrinkTrackerScreen), findsOneWidget);
  });
}
