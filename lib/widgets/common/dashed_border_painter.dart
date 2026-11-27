import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// [source] cut into [dash]-long pieces with [gap] between them, each
/// contour starting with a dash.
Path dashPath(Path source, {required double dash, required double gap}) {
  final dashes = Path();
  for (final metric in source.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += dash + gap) {
      dashes.addPath(
        metric.extractPath(d, math.min(d + dash, metric.length)),
        Offset.zero,
      );
    }
  }
  return dashes;
}

/// Strokes a rounded rect's outline as dashes, inset by half its width so
/// all of it lies inside the box. Use it as a `foregroundPainter`, so a
/// card's fill doesn't cover it.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    this.color = AppTheme.border,
    this.radius = AppConstants.radiusLg,
    this.strokeWidth = AppConstants.borderWidthLg,
    this.dashLength = AppConstants.dashLength,
    this.dashGap = AppConstants.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(strokeWidth / 2),
          Radius.circular(radius),
        ),
      );
    canvas.drawPath(
      dashPath(outline, dash: dashLength, gap: dashGap),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.dashGap != dashGap;
}
