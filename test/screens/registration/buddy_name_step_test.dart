import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';
import 'package:belly_buddy/utils/buddy_name.dart';

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

    testWidgets('counts the characters a person sees, not code points', (
      tester,
    ) async {
      await pumpStep(tester);

      // One visible character, five code points (man, ZWJ, woman, ZWJ, girl).
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), family);
      await tester.pump();
      expect(counter('1/20'), findsOneWidget);

      // A heart with its emoji selector is one character too (two code
      // points, two UTF-16 units): „Kiwi ❤️❤️❤️❤️❤️❤️❤️" is 12, not 19.
      const heart = '\u2764\uFE0F';
      await tester.enterText(
        find.byKey(BuddyNameStep.fieldKey),
        'Kiwi ${heart * 7}',
      );
      await tester.pump();
      expect(counter('12/20'), findsOneWidget);

      // 25 apples: 20 fit, whole ones only.
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), '');
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), '🍎' * 25);
      await tester.pump();
      expect(text(tester), '🍎' * 20);
      expect(counter('20/20'), findsOneWidget);
      expect(AppConstants.isValidBuddyName(text(tester)), isTrue);
    });

    testWidgets('a name the database cannot store yet says why', (
      tester,
    ) async {
      await pumpStep(tester);

      // 20 characters, but 420 code points: more than the buddy_state check
      // (char_length <= ${AppConstants.buddyNameMaxCodePoints}) takes.
      final heavy = 'a${'\u0301' * 20}' * 20;
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), heavy);
      await tester.pump();

      expect(counter('20/20'), findsOneWidget);
      expect(AppConstants.isValidBuddyName(text(tester)), isFalse);
      expect(find.text(BuddyNameRules.tooManySymbols), findsOneWidget);

      const heart = '\u2764\uFE0F';
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), heart * 11);
      await tester.pump();
      expect(AppConstants.isValidBuddyName(text(tester)), isTrue);
      expect(find.text(BuddyNameRules.tooManySymbols), findsNothing);

      const family =
          '\u{1F468}\u{1F3FB}\u200D\u{1F469}\u{1F3FB}\u200D'
          '\u{1F467}\u{1F3FB}\u200D\u{1F466}\u{1F3FB}';
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), family * 10);
      await tester.pump();
      expect(AppConstants.isValidBuddyName(text(tester)), isTrue);
      expect(find.text(BuddyNameRules.tooManySymbols), findsNothing);
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
