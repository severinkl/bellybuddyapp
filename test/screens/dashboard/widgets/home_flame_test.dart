import 'dart:ui' show ImageFilter;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/home_flame.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';

void main() {
  const side = 192.0;

  Future<void> pump(WidgetTester tester, {required int streak, bool? lit}) =>
      tester.pumpWidget(
        Center(
          child: HomeFlame(streak: streak, lit: lit ?? false, buddySide: side),
        ),
      );

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byType(StreakFlame),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('the streak flame, larger than his square', (tester) async {
    await pump(tester, streak: 12, lit: true);

    final flame = tester.widget<StreakFlame>(find.byType(StreakFlame));
    expect(flame.streak, 12);
    expect(flame.lit, isTrue);
    expect(flame.height, side * AppConstants.homeFlameScale);
    // It moves: its motion is Home's.
    expect(flame.still, isFalse);
    expect(flame.igniteOnMount, isFalse);
  });

  testWidgets('a backdrop: translucent by its look (an ember, brennt, '
      'lodert), slightly blurred', (tester) async {
    for (final (streak, lit, expected) in [
      (5, false, AppConstants.homeFlameEmberOpacity),
      (0, false, AppConstants.homeFlameEmberOpacity),
      (30, false, AppConstants.homeFlameEmberOpacity),
      (5, true, AppConstants.homeFlameLitOpacity),
      (29, true, AppConstants.homeFlameLitOpacity),
      (30, true, AppConstants.homeFlameBlazingOpacity),
    ]) {
      await pump(tester, streak: streak, lit: lit);
      expect(opacity(tester), expected, reason: '$streak, lit: $lit');
    }
    expect(
      AppConstants.homeFlameLitOpacity,
      lessThan(AppConstants.homeFlameBlazingOpacity),
    );
    expect(
      AppConstants.homeFlameBlazingOpacity,
      lessThan(AppConstants.homeFlameEmberOpacity),
    );

    expect(
      tester
          .widget<ImageFiltered>(
            find.ancestor(
              of: find.byType(StreakFlame),
              matching: find.byType(ImageFiltered),
            ),
          )
          .imageFilter,
      ImageFilter.blur(
        sigmaX: AppConstants.homeFlameBlur,
        sigmaY: AppConstants.homeFlameBlur,
      ),
    );
  });
}
