import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/date_time_chips.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('DateTimeChips', () {
    final testDate = DateTime(2024, 3, 15, 14, 30);

    testWidgets('displays formatted date', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: DateTimeChips(value: testDate, onChanged: (_) {}),
        ),
      );
      expect(find.text('15.03.2024'), findsOneWidget);
    });

    testWidgets('displays formatted time', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: DateTimeChips(value: testDate, onChanged: (_) {}),
        ),
      );
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('renders calendar and time icons', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: DateTimeChips(value: testDate, onChanged: (_) {}),
        ),
      );
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.access_time_outlined), findsOneWidget);
    });
  });
}
