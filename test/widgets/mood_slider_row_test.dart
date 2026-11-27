import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/mood_slider_row.dart';
import 'package:belly_buddy/widgets/common/bb_slider.dart';
import 'package:belly_buddy/config/constants.dart';

import '../helpers/riverpod_helpers.dart';
import '../helpers/reduce_motion.dart';

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

    testWidgets('an unset value highlights neither mascot', (tester) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: SizedBox(
            width: 400,
            child: MoodSliderRow(
              value: null,
              onChanged: (_) {},
              rightLabel: 'Stark',
              leftMascot: AppConstants.mascotHappy,
              rightMascot: AppConstants.mascotSad,
            ),
          ),
        ),
      );
      final opacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((o) => o.opacity);
      expect(opacities, everyElement(lessThan(1.0)));
    });

    Widget row({required int? value, ValueChanged<int>? onChanged}) => Scaffold(
      body: SizedBox(
        width: 400,
        child: MoodSliderRow(
          value: value,
          onChanged: onChanged ?? (_) {},
          rightLabel: 'Krämpfe',
          leftMascot: AppConstants.mascotHappy,
          rightMascot: AppConstants.mascotSad,
        ),
      ),
    );

    testWidgets('Bauchgefühl: the mascots are not in the semantics tree; each '
        'row is one slider „Krämpfe, 3 von 5"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(row(value: 3));

      // The one control is the slider; besides it only the end label's
      // text is read. Neither mascot has a node (no tap of its own).
      final controls = find.semantics
          .byPredicate((n) => n.getSemanticsData().actions != 0)
          .evaluate()
          .toList();
      expect(controls, hasLength(1), reason: '$controls');
      final slider = controls.single.getSemanticsData();
      expect(slider.flagsCollection.isSlider, isTrue);
      expect(slider.label, 'Krämpfe');
      expect(slider.value, '3 von 5');
      handle.dispose();
    });

    testWidgets('with disableAnimations the mascot does not scale', (
      tester,
    ) async {
      reduceMotion(tester);
      await tester.pumpWithProviders(row(value: 3));
      // Left becomes active: it would bounce (and grow from 0.9 to 1.1).
      await tester.pumpWithProviders(row(value: 1));
      await tester.pump();

      final scales = tester
          .widgetList<ScaleTransition>(
            find.descendant(
              of: find.byType(MoodSliderRow),
              matching: find.byType(ScaleTransition),
            ),
          )
          .map((t) => t.scale.value)
          .toList();
      expect(scales, [1.1, 0.9]);
      // No bounce either, a frame later.
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: find.byType(MoodSliderRow),
                matching: find.byType(ScaleTransition),
              ),
            )
            .map((t) => t.scale.value),
        [1.1, 0.9],
      );
    });
  });
}
