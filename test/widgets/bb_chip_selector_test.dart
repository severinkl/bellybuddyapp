import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_chip_selector.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbChipSelector', () {
    const options = ['Laktose', 'Gluten', 'Fruktose'];

    testWidgets('renders all chip labels', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: BbChipSelector(
            options: options,
            selected: const [],
            onChanged: (_) {},
          ),
        ),
      );
      for (final option in options) {
        expect(find.text(option), findsOneWidget);
      }
    });

    testWidgets('tapping unselected chip adds it to selected', (tester) async {
      final selected = <String>[];
      await tester.pumpWithProviders(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BbChipSelector(
                options: options,
                selected: selected,
                onChanged: (newSelected) {
                  setState(
                    () => selected
                      ..clear()
                      ..addAll(newSelected),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Laktose'));
      await tester.pump();
      expect(selected, contains('Laktose'));
    });

    testWidgets('tapping selected chip removes it', (tester) async {
      final selected = ['Gluten'];
      await tester.pumpWithProviders(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BbChipSelector(
                options: options,
                selected: List<String>.from(selected),
                onChanged: (newSelected) {
                  setState(
                    () => selected
                      ..clear()
                      ..addAll(newSelected),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Gluten'));
      await tester.pump();
      expect(selected, isNot(contains('Gluten')));
    });

    testWidgets('selected chip shows as selected in FilterChip', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: BbChipSelector(
            options: options,
            selected: const ['Laktose'],
            onChanged: (_) {},
          ),
        ),
      );
      // The FilterChip for 'Laktose' should have selected == true
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final laktoseChip = chips.firstWhere(
        (chip) => (chip.label as Text).data == 'Laktose',
      );
      expect(laktoseChip.selected, isTrue);

      // Other chips should be unselected
      final glutenChip = chips.firstWhere(
        (chip) => (chip.label as Text).data == 'Gluten',
      );
      expect(glutenChip.selected, isFalse);
    });
  });
}
