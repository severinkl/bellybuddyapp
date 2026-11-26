import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/buddy/daily_care.dart';

/// The solid and the soft colour a [CareNeed] is drawn in.
({Color color, Color soft}) careColorsOf(CareNeed need) => switch (need) {
  CareNeed.food => (color: AppTheme.careFood, soft: AppTheme.careFoodSoft),
  CareNeed.drink => (color: AppTheme.careWater, soft: AppTheme.careWaterSoft),
  CareNeed.gutFeeling => (color: AppTheme.careGut, soft: AppTheme.careGutSoft),
  CareNeed.toilet => (color: AppTheme.careLoo, soft: AppTheme.careLooSoft),
};

/// A need's meter: a circle whose fill deepens and whose ring fills with
/// [level] (0..1). A null [level] (Klo has no meter) is a plain circle.
/// Its [child] (the need's [NeedIcon], without a size of its own) fills
/// the square [AppConstants.careMeterIconShare] of it in its middle. It
/// adds no semantics; the bubble or page around it speaks.
class NeedMeter extends StatelessWidget {
  const NeedMeter({
    super.key,
    required this.need,
    required this.level,
    required this.size,
    required this.child,
  });

  final CareNeed need;
  final double? level;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: NeedMeterPainter(need: need, level: level),
        child: Center(
          child: SizedBox.square(
            dimension: size * AppConstants.careMeterIconShare,
            child: child,
          ),
        ),
      ),
    );
  }
}

class NeedMeterPainter extends CustomPainter {
  const NeedMeterPainter({required this.need, required this.level});

  final CareNeed need;
  final double? level;

  @visibleForTesting
  Color get fill {
    final soft = careColorsOf(need).soft;
    final l = level;
    return l == null ? soft : Color.lerp(AppTheme.background, soft, l)!;
  }

  @visibleForTesting
  double get sweep => 2 * math.pi * (level ?? 0);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = careColorsOf(need);
    final center = size.center(Offset.zero);
    final l = level;
    if (l == null) {
      const stroke = AppConstants.borderWidthLg;
      canvas.drawCircle(center, size.shortestSide / 2, Paint()..color = fill);
      canvas.drawCircle(
        center,
        size.shortestSide / 2 - stroke / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors.color,
      );
      return;
    }
    final stroke = size.shortestSide * AppConstants.careMeterStrokeShare;
    final radius = size.shortestSide / 2 - stroke / 2;
    canvas.drawCircle(center, size.shortestSide / 2, Paint()..color = fill);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, ring..color = AppTheme.muted);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      ring
        ..color = colors.color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(NeedMeterPainter old) =>
      old.need != need || old.level != level;
}
