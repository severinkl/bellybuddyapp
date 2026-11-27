import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/screens/settings/widgets/reminder_time_picker.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('ReminderTimePicker', () {
    testWidgets('shows close icon when multiple times exist', (tester) async {
      await tester.pumpWithProviders(
        ReminderTimePicker(
          selectedTimes: const ['08:00', '12:00'],
          onChanged: (_) {},
        ),
      );

      expect(find.byIcon(Icons.close), findsNWidgets(2));
    });

    testWidgets('hides close icon when only one time exists', (tester) async {
      await tester.pumpWithProviders(
        ReminderTimePicker(selectedTimes: const ['08:00'], onChanged: (_) {}),
      );

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('tapping close icon removes that time', (tester) async {
      List<String>? result;

      await tester.pumpWithProviders(
        ReminderTimePicker(
          selectedTimes: const ['08:00', '12:00', '18:00'],
          onChanged: (times) => result = times,
        ),
      );

      // Tap the first close icon
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(result, ['12:00', '18:00']);
    });
    testWidgets('the ✕ of a reminder time is „Uhrzeit 08:00 entfernen", '
        '48 × 48', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        ReminderTimePicker(
          selectedTimes: const ['08:00', '12:00'],
          onChanged: (_) {},
        ),
      );

      final remove = find.bySemanticsLabel('Uhrzeit 08:00 entfernen');
      expect(remove, findsOneWidget);
      final node = tester.getSemantics(remove);
      expect(node, isSemantics(isButton: true, hasTapAction: true));
      expect(node.rect.width, greaterThanOrEqualTo(48));
      expect(node.rect.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('a reminder time is a button (no selected state: a list '
        'item that opens the picker), at least 48 high; '
        '„Hinzufügen" a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        ReminderTimePicker(selectedTimes: const ['08:00'], onChanged: (_) {}),
      );

      final time = tester.getSemantics(find.text('08:00'));
      expect(
        time,
        isSemantics(
          isButton: true,
          hasSelectedState: false,
          hasTapAction: true,
        ),
      );
      expect(time.rect.height, greaterThanOrEqualTo(48));
      final add = tester.getSemantics(find.text('Hinzufügen'));
      expect(add, isSemantics(isButton: true, hasTapAction: true));
      expect(add.rect.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });
  });
}
