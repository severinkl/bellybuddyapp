import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/diary/widgets/diary_day_swiper.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('DiaryDaySwiper', () {
    Future<void> pumpSwiper(
      WidgetTester tester, {
      required VoidCallback onPrevious,
      required VoidCallback onNext,
      bool canSwipeBack = true,
      bool canSwipeForward = true,
      VoidCallback? onChildTap,
    }) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: DiaryDaySwiper(
            canSwipeBack: canSwipeBack,
            canSwipeForward: canSwipeForward,
            onPrevious: onPrevious,
            onNext: onNext,
            child: SizedBox.expand(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChildTap,
                child: const ColoredBox(color: Color(0xFFEEEEEE)),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('left drag past threshold fires onNext', (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(next, equals(1));
      expect(prev, equals(0));
    });

    testWidgets('right drag past threshold fires onPrevious', (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(prev, equals(1));
      expect(next, equals(0));
    });

    testWidgets('left drag is a no-op when canSwipeForward is false', (
      tester,
    ) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
        canSwipeForward: false,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(next, equals(0));
      expect(prev, equals(0));
    });

    testWidgets('right drag is a no-op when canSwipeBack is false', (
      tester,
    ) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
        canSwipeBack: false,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(prev, equals(0));
      expect(next, equals(0));
    });

    testWidgets('short drag below threshold does not fire either callback', (
      tester,
    ) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      // 60px < the 80px threshold defined in DiaryDaySwiper.
      await tester.drag(find.byType(DiaryDaySwiper), const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(next, equals(0));
      expect(prev, equals(0));
    });

    testWidgets('vertical drag does not fire either callback', (tester) async {
      var prev = 0;
      var next = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
      );

      await tester.drag(find.byType(DiaryDaySwiper), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(next, equals(0));
      expect(prev, equals(0));
    });

    testWidgets('tap on child still reaches the child (translucent hit test)', (
      tester,
    ) async {
      var prev = 0;
      var next = 0;
      var childTaps = 0;
      await pumpSwiper(
        tester,
        onPrevious: () => prev += 1,
        onNext: () => next += 1,
        onChildTap: () => childTaps += 1,
      );

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFFEEEEEE),
        ),
      );
      await tester.pumpAndSettle();

      expect(childTaps, equals(1));
      expect(prev, equals(0));
      expect(next, equals(0));
    });
  });
}
