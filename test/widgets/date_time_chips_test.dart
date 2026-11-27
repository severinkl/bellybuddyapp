import 'package:material_ui/material_ui.dart';
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

    testWidgets('side by side when they fit; the time wraps below the date '
        'instead of overflowing on a narrow sheet', (tester) async {
      Future<void> pumpAt(double width) => tester.pumpWithProviders(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: DateTimeChips(value: testDate, onChanged: (_) {}),
            ),
          ),
        ),
      );

      await pumpAt(600);
      expect(
        tester.getCenter(find.text('14:30')).dy,
        tester.getCenter(find.text('15.03.2024')).dy,
      );

      await pumpAt(300);
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('14:30')).dy,
        greaterThan(tester.getBottomLeft(find.text('15.03.2024')).dy),
      );
    });

    testWidgets('date and time chips read „Datum, Donnerstag, 26. November '
        '2026" and „Uhrzeit, 14:30", each ≥ 48 high', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        Scaffold(
          body: DateTimeChips(
            value: DateTime(2026, 11, 26, 14, 30),
            onChanged: (_) {},
          ),
        ),
      );

      for (final (shown, label, value) in [
        ('26.11.2026', 'Datum', 'Donnerstag, 26. November 2026'),
        ('14:30', 'Uhrzeit', '14:30'),
      ]) {
        final node = tester.getSemantics(find.text(shown));
        expect(
          node,
          isSemantics(
            label: label,
            value: value,
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(node.rect.height, greaterThanOrEqualTo(48), reason: label);
      }
      handle.dispose();
    });
  });
}
