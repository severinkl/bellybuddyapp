import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_slider.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbSlider', () {
    testWidgets('renders Slider widget', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(body: BbSlider(value: 3, onChanged: (_) {})),
      );
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('renders leftLabel, centerLabel and rightLabel', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: BbSlider(
            value: 3,
            onChanged: (_) {},
            leftLabel: 'Wenig',
            centerLabel: 'Mittel',
            rightLabel: 'Viel',
          ),
        ),
      );
      expect(find.text('Wenig'), findsOneWidget);
      expect(find.text('Mittel'), findsOneWidget);
      expect(find.text('Viel'), findsOneWidget);
    });

    testWidgets('slider has correct initial value', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(body: BbSlider(value: 4, onChanged: (_) {})),
      );
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 4.0);
    });

    testWidgets('does not show label text when no labels provided', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        Scaffold(body: BbSlider(value: 2, onChanged: (_) {})),
      );
      // The Padding widget for labels should not appear when all labels are null
      expect(find.text('Wenig'), findsNothing);
      expect(find.text('Mittel'), findsNothing);
      expect(find.text('Viel'), findsNothing);
    });
  });
}
