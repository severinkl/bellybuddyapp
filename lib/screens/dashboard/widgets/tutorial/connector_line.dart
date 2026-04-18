import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';

/// Paints a single 1.2-logical-pixel straight line from [bubbleAnchor] to
/// [targetAnchor], both expressed in the overlay Stack's coordinate space.
/// Used to draw the hairline connector between the tooltip bubble and the
/// spotlighted element, matching the mockup.
class ConnectorLine extends CustomPainter {
  final Offset bubbleAnchor;
  final Offset targetAnchor;

  const ConnectorLine({required this.bubbleAnchor, required this.targetAnchor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.foreground
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(bubbleAnchor, targetAnchor, paint);
  }

  @override
  bool shouldRepaint(covariant ConnectorLine old) =>
      old.bubbleAnchor != bubbleAnchor || old.targetAnchor != targetAnchor;
}
