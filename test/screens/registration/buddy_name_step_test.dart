import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('BuddyNameStep', () {
    Future<List<String>> pumpStep(
      WidgetTester tester, {
      String value = 'Buddy',
    }) async {
      final changes = <String>[];
      await tester.pumpWithProviders(
        Scaffold(
          body: BuddyNameStep(value: value, onChanged: changes.add),
        ),
      );
      return changes;
    }

    TextField field(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(BuddyNameStep.fieldKey),
        matching: find.byType(TextField),
      ),
    );

    testWidgets('shows the title and the prefilled name', (tester) async {
      await pumpStep(tester);

      expect(find.byKey(BuddyNameStep.titleKey), findsOneWidget);
      expect(find.text('Wie soll ich heißen?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(BuddyNameStep.fieldKey),
          matching: find.text('Buddy'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('typing reports the new name', (tester) async {
      final changes = await pumpStep(tester);

      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');

      expect(changes.last, 'Bauchi');
    });

    testWidgets('limits the name length and capitalizes words', (tester) async {
      await pumpStep(tester);

      final textField = field(tester);
      expect(textField.maxLength, AppConstants.buddyNameMaxLength);
      expect(textField.textCapitalization, TextCapitalization.words);
    });
  });
}
