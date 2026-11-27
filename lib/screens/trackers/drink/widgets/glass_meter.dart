import 'package:material_ui/material_ui.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../utils/drink_helpers.dart';
import '../../../../utils/reduced_motion.dart';
import '../../../../widgets/common/dashed_border_painter.dart';
import 'drink_glyph.dart';

/// The today card's glasses: one per [AppConstants.drinkGlassMl], drunk
/// share filled, pending share lighter above it; one image for screen
/// readers.
class GlassMeter extends StatelessWidget {
  const GlassMeter({super.key, required this.drunkMl, required this.pendingMl});

  final int drunkMl;
  final int pendingMl;

  static const glassesKey = Key('glass_meter');

  @override
  Widget build(BuildContext context) {
    final duration = ReducedMotion.duration(context, AppConstants.animNormal);
    final fills = DrinkHelpers.glassFills(drunkMl, pendingMl);
    return Semantics(
      key: glassesKey,
      image: true,
      label: DrinkHelpers.glassesLabel(drunkMl, pendingMl),
      excludeSemantics: true,
      child: Wrap(
        spacing: AppConstants.spacing6,
        runSpacing: AppConstants.spacing6,
        children: [
          for (final (i, fill) in fills.indexed)
            TweenAnimationBuilder<GlassFill>(
              key: ValueKey(i),
              tween: _GlassFillTween(end: fill),
              duration: duration,
              curve: Curves.easeOut,
              builder: (_, f, _) => CustomPaint(
                size: AppConstants.glassMeterGlassSize,
                painter: GlassPainter(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassFillTween extends Tween<GlassFill> {
  _GlassFillTween({super.end});

  @override
  GlassFill lerp(double t) {
    final a = begin!;
    final b = end!;
    return (
      drunk: a.drunk + (b.drunk - a.drunk) * t,
      pending: a.pending + (b.pending - a.pending) * t,
    );
  }
}

/// One glass of the [GlassMeter] (mockup 22×28 box, scaled to the canvas):
/// [fill]'s drunk share from the bottom in [AppTheme.buddyWater], the
/// pending share above it in [AppTheme.careWaterSoft]; a solid
/// [AppTheme.foreground] outline, or a dashed [AppTheme.infoText] one when
/// the glass is only pending.
class GlassPainter extends CustomPainter {
  const GlassPainter(this.fill);

  final GlassFill fill;

  /// Whether the outline is dashed.
  bool get dashed => fill.drunk == 0 && fill.pending > 0;

  static const _top = 2.0;
  static const _bottom = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = glassOutline();
    final box = DrinkGlyph.vesselSize(DrinkVessel.glass);
    canvas
      ..save()
      ..scale(size.width / box.width, size.height / box.height);

    const height = _bottom - _top;
    final drunkTop = _bottom - height * fill.drunk;
    final pendingTop = drunkTop - height * fill.pending;
    if (fill.drunk > 0 || fill.pending > 0) {
      canvas
        ..save()
        ..clipPath(outline);
      if (fill.drunk > 0) {
        canvas.drawRect(
          Rect.fromLTRB(0, drunkTop, box.width, _bottom),
          Paint()..color = AppTheme.buddyWater,
        );
      }
      if (fill.pending > 0) {
        canvas.drawRect(
          Rect.fromLTRB(0, pendingTop, box.width, drunkTop),
          Paint()..color = AppTheme.careWaterSoft,
        );
      }
      canvas.restore();
    }

    final dashed = this.dashed;
    canvas
      ..drawPath(
        dashed
            ? dashPath(
                outline,
                dash: AppConstants.dashLengthSm,
                gap: AppConstants.dashGapSm,
              )
            : outline,
        Paint()
          ..color = dashed ? AppTheme.infoText : AppTheme.foreground
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppConstants.drinkGlyphStroke
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlassPainter old) => old.fill != fill;
}
