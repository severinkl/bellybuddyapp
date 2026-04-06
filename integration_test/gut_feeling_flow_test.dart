import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('can navigate to gut feeling tracker', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final gutCard = find.byKey(const Key('tracker_card_gut_feeling'));
    expect(gutCard, findsOneWidget);
    await tester.tap(gutCard);
    await tester.pumpAndSettle();

    expect(find.byType(GutFeelingTrackerScreen), findsOneWidget);
    expect(find.text('Wie geht es dir?'), findsOneWidget);
  });

  testWidgets('can navigate through tabs and save', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tracker_card_gut_feeling')));
    await tester.pumpAndSettle();

    // First tab: Bauchgefühl — tap "weiter"
    final actionButton = find.byKey(GutFeelingTrackerScreen.saveButtonKey);
    expect(actionButton, findsOneWidget);
    await tester.tap(actionButton);
    await tester.pumpAndSettle();

    // Second tab: Stimmung — button should now say "speichern"
    expect(find.text('speichern'), findsOneWidget);
    await tester.tap(actionButton);
    await tester.pumpAndSettle();

    // Success overlay
    expect(find.text('Eintrag gespeichert!'), findsOneWidget);
  });
}
