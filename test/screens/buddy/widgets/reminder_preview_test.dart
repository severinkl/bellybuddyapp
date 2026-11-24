import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/buddy/widgets/reminder_preview.dart';

import '../../../helpers/riverpod_helpers.dart';

void main() {
  testWidgets('the previews are in the order of the day', (tester) async {
    await tester.pumpWithProviders(
      const Scaffold(
        body: SingleChildScrollView(
          child: ReminderPreview(
            buddyName: 'Kiwi',
            profile: UserProfile(
              mealReminderTimes: ['18:00', '11:55'],
              moodReminderTimes: ['07:15'],
            ),
          ),
        ),
      ),
    );

    final times = tester
        .widgetList<NotificationPreview>(find.byType(NotificationPreview))
        .map((p) => p.time)
        .toList();
    // The earliest meal reminder, and the mood one before it.
    expect(times, ['07:15', '11:55']);
    expect(
      tester.getTopLeft(find.text('07:15')).dy,
      lessThan(tester.getTopLeft(find.text('11:55')).dy),
    );
  });
}
