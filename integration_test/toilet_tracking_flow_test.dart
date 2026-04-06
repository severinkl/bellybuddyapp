import 'package:belly_buddy/screens/trackers/toilet/toilet_tracker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets('can navigate to toilet tracker and see save button', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final toiletCard = find.byKey(const Key('tracker_card_toilet'));
    expect(toiletCard, findsOneWidget);
    await tester.tap(toiletCard);
    await tester.pumpAndSettle();

    expect(find.byType(ToiletTrackerScreen), findsOneWidget);
    expect(find.byKey(ToiletTrackerScreen.saveButtonKey), findsOneWidget);
  });

  testWidgets('can save a toilet entry', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tracker_card_toilet')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ToiletTrackerScreen.saveButtonKey));
    await tester.pumpAndSettle();

    // Success overlay should appear
    expect(find.text('Toilettengang gespeichert!'), findsOneWidget);
  });
}
