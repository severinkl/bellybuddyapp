import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';

/// Paints a semi-transparent dim layer over the whole screen, with a rounded
/// rectangular cutout around [targetRect]. Used as the backdrop of the
/// dashboard onboarding overlay.
class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double targetRadius;
  final Color dimColor;

  const SpotlightPainter({
    required this.targetRect,
    required this.targetRadius,
    this.dimColor = AppTheme.scrim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(0, 0, size.width, size.height);
    final screenPath = Path()..addRect(screen);

    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect, Radius.circular(targetRadius)),
      );

    final cutout = Path.combine(PathOperation.difference, screenPath, holePath);

    canvas.drawPath(cutout, Paint()..color = dimColor);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter old) =>
      old.targetRect != targetRect ||
      old.targetRadius != targetRadius ||
      old.dimColor != dimColor;
}
