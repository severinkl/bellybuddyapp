import 'package:flutter/material.dart';
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
  });
}
