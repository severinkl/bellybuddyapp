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
      VoidCallback? onSubmitted,
    }) async {
      final changes = <String>[];
      await tester.pumpWithProviders(
        Scaffold(
          body: BuddyNameStep(
            value: value,
            onChanged: changes.add,
            onSubmitted: onSubmitted,
          ),
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

    testWidgets('shows the prefilled name and no headline (the Buddy asks)', (
      tester,
    ) async {
      await pumpStep(tester);

      expect(find.byKey(BuddyNameStep.titleKey), findsOneWidget);
      expect(find.text('Wie soll ich heißen?'), findsNothing);
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

    testWidgets('the keyboard\'s done action submits', (tester) async {
      var submitted = 0;
      await pumpStep(tester, onSubmitted: () => submitted++);

      await tester.showKeyboard(find.byKey(BuddyNameStep.fieldKey));
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(submitted, 1);
    });

    String text(WidgetTester tester) => field(tester).controller!.text;

    Finder counter(String value) => find.descendant(
      of: find.byKey(BuddyNameStep.fieldKey),
      matching: find.text(value),
    );

    testWidgets('limits the name length and capitalizes words', (tester) async {
      await pumpStep(tester);

      expect(counter('5/20'), findsOneWidget);
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'a' * 25);
      await tester.pump();

      expect(text(tester), 'a' * AppConstants.buddyNameMaxLength);
      expect(counter('20/20'), findsOneWidget);
      expect(field(tester).textCapitalization, TextCapitalization.words);
    });

    testWidgets('counts code points like the database, not characters', (
      tester,
    ) async {
      await pumpStep(tester);

      // One visible character, five code points (man, ZWJ, woman, ZWJ, girl).
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), family);
      await tester.pump();
      expect(counter('5/20'), findsOneWidget);

      // 25 code points: four whole families fit, the fifth is not split.
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), family * 5);
      await tester.pump();
      expect(text(tester), family * 4);
      expect(counter('20/20'), findsOneWidget);
      expect(AppConstants.isValidBuddyName(text(tester)), isTrue);

      // Apples are one code point each (two UTF-16 units): 20 fit.
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), '');
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), '🍎' * 25);
      await tester.pump();
      expect(text(tester), '🍎' * 20);
      expect(AppConstants.isValidBuddyName(text(tester)), isTrue);
    });

    testWidgets('typing at the limit keeps the name', (tester) async {
      final changes = await pumpStep(tester, value: 'a' * 20);
      await tester.showKeyboard(find.byKey(BuddyNameStep.fieldKey));
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: 'a' * 20,
          selection: const TextSelection.collapsed(offset: 10),
        ),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '${'a' * 10}b${'a' * 10}',
          selection: const TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();

      expect(text(tester), 'a' * 20);
      expect(changes, isEmpty);
    });
  });
}
