import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/mood_slider_row.dart';
import 'package:belly_buddy/widgets/common/bb_slider.dart';
import 'package:belly_buddy/config/constants.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('MoodSliderRow', () {
    testWidgets('renders rightLabel text', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: SizedBox(
            width: 400,
            child: MoodSliderRow(
              value: 1,
              onChanged: (_) {},
              rightLabel: 'Sehr stark',
              leftMascot: AppConstants.mascotHappy,
              rightMascot: AppConstants.mascotSad,
            ),
          ),
        ),
      );
      expect(find.text('Sehr stark'), findsOneWidget);
    });

    testWidgets('renders Slider widget via BbSlider', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: SizedBox(
            width: 400,
            child: MoodSliderRow(
              value: 3,
              onChanged: (_) {},
              rightLabel: 'Stark',
              leftMascot: AppConstants.mascotHappy,
              rightMascot: AppConstants.mascotSad,
            ),
          ),
        ),
      );
      expect(find.byType(BbSlider), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('tapping left mascot sets value to 1', (tester) async {
      int? changedValue;
      await tester.pumpWithProviders(
        Scaffold(
          body: SizedBox(
            width: 400,
            child: MoodSliderRow(
              value: 3,
              onChanged: (v) => changedValue = v,
              rightLabel: 'Stark',
              leftMascot: AppConstants.mascotHappy,
              rightMascot: AppConstants.mascotSad,
            ),
          ),
        ),
      );
      // The left mascot is the first GestureDetector child in the Row
      final gestures = find.byType(GestureDetector);
      await tester.tap(gestures.first);
      await tester.pump();
      expect(changedValue, 1);
    });
  });
}
