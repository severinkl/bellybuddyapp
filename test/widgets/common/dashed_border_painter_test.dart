import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/common/dashed_border_painter.dart';

void main() {
  Future<RenderObject> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const Center(
        child: CustomPaint(
          key: Key('dashed'),
          size: Size(200, 100),
          foregroundPainter: DashedBorderPainter(),
        ),
      ),
    );
    return tester.renderObject(find.byKey(const Key('dashed')));
  }

  testWidgets('the dashes are one path, stroked once inside the box', (
    tester,
  ) async {
    final box = await pump(tester);

    // Around the box, half a stroke inside its edges.
    const inset = AppConstants.borderWidthLg / 2;
    expect(
      box,
      paints..something((method, args) {
        if (method != #drawPath) return false;
        final paint = args[1] as Paint;
        final bounds = (args[0] as Path).getBounds();
        return paint.style == PaintingStyle.stroke &&
            paint.strokeWidth == AppConstants.borderWidthLg &&
            paint.color.toARGB32() == AppTheme.border.toARGB32() &&
            (bounds.left - inset).abs() < 0.5 &&
            (bounds.top - inset).abs() < 0.5 &&
            (bounds.right - (200 - inset)).abs() < 0.5 &&
            (bounds.bottom - (100 - inset)).abs() < 0.5;
      }),
    );
    expect(
      box,
      isNot(
        paints
          ..path()
          ..path(),
      ),
    );
  });

  test('repaints only when its look changes', () {
    const painter = DashedBorderPainter();
    expect(painter.shouldRepaint(const DashedBorderPainter()), isFalse);
    expect(
      painter.shouldRepaint(
        const DashedBorderPainter(radius: AppConstants.radiusXl),
      ),
      isTrue,
    );
  });
}
