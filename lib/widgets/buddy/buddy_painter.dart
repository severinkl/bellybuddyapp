/// Draws one [BuddyFrame]: the traced body pushed through a smooth
/// deformation field (breathing, jelly sway, gulp bulge) with the face and
/// effects drawn procedurally on top. Ported from the approved spike.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Colors;

import '../../config/app_theme.dart';
import 'buddy_controller.dart';
import 'buddy_geometry.dart';
import 'buddy_pose.dart';
import 'buddy_shape_data.dart' show kBuddyHeight, kBuddyWidth;

/// Paints the Buddy of [controller] into any size, repainting on every tick.
class BuddyPainter extends CustomPainter {
  BuddyPainter(this.controller) : super(repaint: controller);

  final BuddyController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = BuddyLayout(size);
    if (!(layout.scale > 0) || !layout.scale.isFinite) return;
    canvas.save();
    canvas.translate(layout.origin.dx, layout.origin.dy);
    canvas.scale(layout.scale);
    _FramePainter(canvas, controller.frame).paint();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BuddyPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

// Deformation field (image px).
const Offset _breathCentre = Offset(820, 520);
const double _breathSigma = 480;
const double _breathTwoSigmaSq = 2 * _breathSigma * _breathSigma;
const double _bulgeGain = 0.75;
const double _bulgeSigma = 115;
const double _bulgeTwoSigmaSq = 2 * _bulgeSigma * _bulgeSigma;

/// Water swells the gut less than food: it reads as a wave, not a lump.
const double _waterGain = 0.4;

// Face strokes (image px).
const double _eyeRing = 34;
const double _lidEdge = 26;
const double _mouthStroke = 40;
const double _browStroke = 28;
const double _foodRadius = 75;
const double _foodStroke = 16;

/// Largest mouth opening (a yawn goes past 1 for a tall "O").
const double _maxOpen = 1.4;

/// Pupil scale above 1 at which catchlights reach full size.
const double _shinePupil = 0.15;

// Water wave: a radial-gradient front at the bulge plus a tail of blobs
// every [_waterTrailStep] px of gut behind it, fading over
// [_waterTrailBlobs] steps.
const double _waterAlpha = 0.55;
const double _waterRadius = 170;
const int _waterTrailBlobs = 7;
const double _waterTrailStep = 60;
const double _waterTrailRadius = 120;

// Sleepy "z"s.
const Offset _zzzOrigin = Offset(1150, 250);
const double _zzzLoop = 2.4;

/// The deformation field of one frame (breathing, jelly sway, gulp bulge)
/// with its per-frame terms hoisted. [apply] leaves the displaced point in
/// [x]/[y], so deforming a whole outline allocates nothing per point.
class _Field {
  _Field(BuddyFrame fr)
    : _breath = fr.breath,
      _sway = fr.sway,
      _swayY = fr.sway * 0.22,
      _phaseX = fr.t * 1.8,
      _phaseY = fr.t * 1.4,
      _hasBulge = fr.bulgePoint != null && fr.bulgeAmt > 0,
      _gx = fr.bulgePoint?.dx ?? 0,
      _gy = fr.bulgePoint?.dy ?? 0,
      _bulgeK = fr.bulgeAmt * (fr.bulgeIsWater ? _waterGain : _bulgeGain);

  final double _breath, _sway, _swayY, _phaseX, _phaseY;
  final bool _hasBulge;
  final double _gx, _gy, _bulgeK;

  /// The last displaced point.
  double x = 0, y = 0;

  @pragma('vm:prefer-inline')
  void apply(double px, double py) {
    var dx = 0.0, dy = 0.0;
    // Breathing: the stomach region swells.
    final bx = px - _breathCentre.dx, by = py - _breathCentre.dy;
    final w = math.exp(-(bx * bx + by * by) / _breathTwoSigmaSq);
    dx += bx * _breath * w;
    dy += by * _breath * w;
    // Jelly sway: travelling wave, anchored at the bottom of the tube.
    final a = ((kBuddyHeight - py) / kBuddyHeight).clamp(0.0, 1.0);
    final anchor = a * a;
    dx += _sway * math.sin(_phaseX - py * 0.0032) * anchor;
    dy += _swayY * math.sin(_phaseY - px * 0.004) * anchor;
    // Gulp bulge.
    if (_hasBulge) {
      final gx = px - _gx, gy = py - _gy;
      final k = _bulgeK * math.exp(-(gx * gx + gy * gy) / _bulgeTwoSigmaSq);
      dx += gx * k;
      dy += gy * k;
    }
    x = px + dx;
    y = py + dy;
  }

  /// [layer] pushed through the field, as an even-odd [Path].
  Path deform(BuddyPathData layer) {
    final ops = layer.ops, pts = layer.pts;
    final p = Path()..fillType = PathFillType.evenOdd;
    var j = 0;
    for (var i = 0; i < ops.length; i++) {
      switch (ops[i]) {
        case 0:
          apply(pts[j], pts[j + 1]);
          p.moveTo(x, y);
          j += 2;
        case 1:
          apply(pts[j], pts[j + 1]);
          p.lineTo(x, y);
          j += 2;
        case 2:
          apply(pts[j], pts[j + 1]);
          final x1 = x, y1 = y;
          apply(pts[j + 2], pts[j + 3]);
          final x2 = x, y2 = y;
          apply(pts[j + 4], pts[j + 5]);
          p.cubicTo(x1, y1, x2, y2, x, y);
          j += 6;
        default:
          p.close();
      }
    }
    return p;
  }
}

/// An eye's frame-independent drawing data.
class _Eye {
  _Eye(this.spec)
    : rect = Rect.fromCenter(
        center: Offset.zero,
        width: 2 * spec.rx,
        height: 2 * spec.ry,
      ),
      cos = math.cos(-spec.angleRad),
      sin = math.sin(-spec.angleRad);

  final BuddyEyeSpec spec;

  /// The eye white in eye-local space.
  final Rect rect;
  late final Rect ring = rect.inflate(_eyeRing / 2);
  late final Path clip = Path()..addOval(rect);

  /// Rotation from screen space into eye-local space.
  final double cos, sin;

  Offset toLocal(Offset v) =>
      Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
}

/// Paints a single frame in Buddy image space (the canvas is already mapped
/// by [BuddyLayout]).
class _FramePainter {
  _FramePainter(this.canvas, this.fr) : f = fr.face, _field = _Field(fr);

  final Canvas canvas;
  final BuddyFrame fr;
  final FacePose f;
  final _Field _field;

  static final List<_Eye> _eyes = [for (final e in kBuddyEyes) _Eye(e)];

  // Constant paints, shared by every frame.
  static final Paint _shadowPaint = _fill(AppTheme.buddyShadow);
  static final Paint _whitePaint = _fill(Colors.white);
  static final Paint _bodyPaint = _fill(AppTheme.buddyBody);
  static final Paint _outlineFill = _fill(AppTheme.buddyOutline);
  static final Paint _tonguePaint = _fill(AppTheme.buddyTongue);
  static final Paint _heartPaint = _fill(AppTheme.buddyHeart);
  static final Paint _sparklePaint = _fill(AppTheme.buddySparkle);
  static final Paint _foodPaint = _fill(AppTheme.buddyFood);
  static final Paint _leafPaint = _fill(AppTheme.buddyFoodLeaf);
  static final Paint _appleShinePaint = _fill(
    Colors.white.withValues(alpha: 0.8),
  );
  static final Paint _foodImagePaint = Paint()
    ..filterQuality = FilterQuality.medium;
  static final Paint _eyeRingPaint = Paint()
    ..color = AppTheme.buddyOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _eyeRing;
  static final Paint _lidEdgePaint = _roundStroke(
    AppTheme.buddyOutline,
    _lidEdge,
  );
  static final Paint _mouthPaint = _roundStroke(
    AppTheme.buddyOutline,
    _mouthStroke,
  );
  static final Paint _foodOutlinePaint = _roundStroke(
    AppTheme.buddyOutline,
    _foodStroke,
  );
  static final Paint _leafOutlinePaint = _roundStroke(
    AppTheme.buddyOutline,
    10,
  );

  /// Unit-size water blob (radius 1, full opacity); drawn scaled, with the
  /// blob's opacity as the paint's alpha.
  static final Paint _waterPaint = Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [
        AppTheme.buddyWater,
        AppTheme.buddyWater.withValues(alpha: 0.8),
        AppTheme.buddyWater.withValues(alpha: 0),
      ],
      const [0, 0.45, 1],
    );

  // Paints whose colour (alpha) or width change per draw: set right before
  // each use via [_alphaFill] / [_alphaStroke].
  static final Paint _varFill = Paint();
  static final Paint _varStroke = _roundStroke(AppTheme.buddyOutline, 1);

  static Paint _fill(Color color) => Paint()..color = color;

  static Paint _roundStroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _alphaFill(Color color) => _varFill..color = color;

  Paint _alphaStroke(Color color, double width) => _varStroke
    ..color = color
    ..strokeWidth = width;

  Offset _d(Offset p) {
    _field.apply(p.dx, p.dy);
    return Offset(_field.x, _field.y);
  }

  void paint() {
    // Ground shadow (shrinks while airborne).
    final air = (-fr.ty / 900).clamp(0.0, 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(kBuddyWidth / 2 + fr.tx, kBuddyHeight + 10),
        width: 820 * (1 - air),
        height: 70 * (1 - air),
      ),
      _shadowPaint,
    );

    // Hearts in stage space: the mood's rising stream, the action's burst.
    if (f.hearts > 0.01) _paintHearts(f.hearts);
    if (fr.hearts > 0.01) _paintHeartBurst(fr.hearts);

    canvas.save();
    // Squash/stretch/jump around the bottom-centre "feet". `rot` already
    // contains the pose's lean.
    canvas.translate(kBuddyWidth / 2 + fr.tx, kBuddyHeight + fr.ty);
    canvas.rotate(fr.rot);
    canvas.scale(fr.sx, fr.sy);
    canvas.translate(-kBuddyWidth / 2, -kBuddyHeight);

    canvas.drawPath(_field.deform(BuddyShapes.silhouette), _whitePaint);
    final fill = _field.deform(BuddyShapes.fill);
    canvas.drawPath(fill, _bodyPaint);
    if (fr.bulgeIsWater) _paintWater(fill);
    canvas.drawPath(_field.deform(BuddyShapes.outline), _outlineFill);

    _paintBlush();
    for (final e in _eyes) {
      _paintEye(e);
    }
    _paintMouth();
    _paintBrows();
    if (f.nervousFx > 0.01) _paintNervous(f.nervousFx);
    if (f.rumble > 0.01) _paintRumble(f.rumble);
    final food = fr.foodPos;
    if (food != null && fr.foodScale > 0.01) {
      _paintFood(food, fr.foodScale);
    }
    canvas.restore();

    if (f.zzz > 0.01) _paintZzz(f.zzz);
    if (fr.sparkleP >= 0 && fr.sparkleP <= 1) _paintSparkles(fr.sparkleP);
  }

  /// Blue wave inside the gut: a soft front at the water bulge with a
  /// fading tail behind it along the gut centerline.
  void _paintWater(Path fill) {
    final g = fr.bulgePoint;
    if (g == null || fr.bulgeAmt <= 0) return;
    final a = (_waterAlpha * fr.bulgeAmt).clamp(0.0, 1.0);
    final front = centerlineArcLengthAt(g);
    canvas.save();
    canvas.clipPath(fill);
    for (var k = _waterTrailBlobs; k >= 1; k--) {
      final s = front - k * _waterTrailStep;
      if (s < 0) continue;
      _waterBlob(
        _d(pointAtArcLength(s)),
        _waterTrailRadius,
        a * (1 - k / (_waterTrailBlobs + 1)),
      );
    }
    _waterBlob(_d(g), _waterRadius, a);
    canvas.restore();
  }

  void _waterBlob(Offset c, double r, double alpha) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r);
    canvas.drawCircle(
      Offset.zero,
      1,
      _waterPaint..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  void _paintEye(_Eye eye) {
    final e = eye.spec;
    final c = _d(e.center);
    final rx = e.rx, ry = e.ry;
    final rect = eye.rect;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(e.angleRad);
    canvas.drawOval(rect, _whitePaint);

    canvas.save();
    canvas.clipPath(eye.clip);

    // Pupil, gaze rotated into eye-local space.
    final gl = eye.toLocal(fr.gaze);
    final pw = 50 * f.pupil, ph = 74 * f.pupil;
    final po = Offset(gl.dx * (rx - pw * 0.9), gl.dy * (ry - ph * 0.85));
    if (f.heart < 0.99) {
      final k = 1 - f.heart;
      canvas.drawOval(
        Rect.fromCenter(center: po, width: 2 * pw * k, height: 2 * ph * k),
        _outlineFill,
      );
      // Big pupils (hungry, empathetic) get catchlights: pleading/soft eyes.
      final shine = k * ((f.pupil - 1) / _shinePupil).clamp(0.0, 1.0);
      if (shine > 0.01) {
        _paintCatchlights(eye, po, pw * k, ph * k, shine);
      }
    }
    if (f.heart > 0.01) {
      final pulse = 1 + 0.08 * math.sin(fr.t * 7);
      final hs = 150 * f.heart * pulse;
      canvas.save();
      canvas.translate(po.dx, po.dy);
      canvas.rotate(-e.angleRad);
      canvas.scale(hs);
      canvas.drawPath(_unitHeart, _heartPaint);
      canvas.drawPath(_unitHeart, _alphaStroke(AppTheme.buddyOutline, 14 / hs));
      canvas.restore();
    }

    final lidPaint = _bodyPaint;
    final edge = _lidEdgePaint;

    // Upper lid (blink / sleepy / sad tilt).
    final lid = math.max(f.lidTop, fr.blink).clamp(0.0, 1.0);
    if (lid > 0.03) {
      final yEdge = -ry + lid * 2 * ry * 1.02;
      final tilt = f.lidTilt * ry * 0.45;
      final yLeft = yEdge + (e.side < 0 ? tilt : -tilt);
      final yRight = yEdge + (e.side > 0 ? tilt : -tilt);
      final bow = ry * 0.18 * (1 - lid);
      final edgePath = Path()
        ..moveTo(-rx * 1.2, yLeft)
        ..quadraticBezierTo(0, (yLeft + yRight) / 2 + bow, rx * 1.2, yRight);
      final fill = Path()
        ..moveTo(-rx * 1.2, -ry * 1.3)
        ..lineTo(rx * 1.2, -ry * 1.3)
        ..lineTo(rx * 1.2, yRight)
        ..quadraticBezierTo(0, (yLeft + yRight) / 2 + bow, -rx * 1.2, yLeft)
        ..close();
      canvas.drawPath(fill, lidPaint);
      canvas.drawPath(edgePath, edge);
    }

    // Lower lid (happy ^ ^ squint).
    if (f.lidBottom > 0.01) {
      final yB = ry - f.lidBottom * 2 * ry * 0.9;
      final edgePath = Path()
        ..moveTo(-rx * 1.2, yB + ry * 0.35)
        ..quadraticBezierTo(0, yB - ry * 0.35, rx * 1.2, yB + ry * 0.35);
      final fill = Path()
        ..moveTo(-rx * 1.2, ry * 1.3)
        ..lineTo(rx * 1.2, ry * 1.3)
        ..lineTo(rx * 1.2, yB + ry * 0.35)
        ..quadraticBezierTo(0, yB - ry * 0.35, -rx * 1.2, yB + ry * 0.35)
        ..close();
      canvas.drawPath(fill, lidPaint);
      canvas.drawPath(edgePath, edge);
    }
    canvas.restore(); // clip

    canvas.drawOval(eye.ring, _eyeRingPaint);
    canvas.restore();
  }

  /// Two white highlights in a pupil (in [eye]'s rotated local canvas), lit
  /// from the upper left in screen space.
  void _paintCatchlights(_Eye eye, Offset po, double pw, double ph, double a) {
    final paint = _alphaFill(Colors.white.withValues(alpha: a));
    canvas.drawCircle(
      po + eye.toLocal(Offset(-0.32 * pw, -0.4 * ph)),
      0.36 * pw * a,
      paint,
    );
    canvas.drawCircle(
      po + eye.toLocal(Offset(0.34 * pw, 0.3 * ph)),
      0.16 * pw * a,
      paint,
    );
  }

  void _paintMouth() {
    final m = _d(kBuddyMouthCenter);
    canvas.save();
    canvas.translate(m.dx, m.dy);
    canvas.rotate(kBuddyMouthTilt);
    final hw = 94 * f.mouthWidth;
    final s = f.smile, o = f.open.clamp(0.0, _maxOpen);
    final uc = s * (110 - 50 * o) - o * 45;
    final dc = s * 110 + o * 190;
    final mp = Path()
      ..moveTo(-hw, 0)
      ..quadraticBezierTo(0, uc, hw, 0)
      ..quadraticBezierTo(0, dc, -hw, 0)
      ..close();
    if (o > 0.02) {
      canvas.drawPath(mp, _outlineFill);
      canvas.save();
      canvas.clipPath(mp);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, dc * 0.42),
          width: hw * 1.2,
          height: math.max(20, dc * 0.35),
        ),
        _tonguePaint,
      );
      canvas.restore();
    }
    canvas.drawPath(mp, _mouthPaint);
    canvas.restore();
  }

  void _paintBrows() {
    if (f.brow < 0.02) return;
    final paint = _alphaStroke(
      AppTheme.buddyOutline.withValues(alpha: f.brow.clamp(0.0, 1.0)),
      _browStroke,
    );
    for (final (center, side) in const [
      (Offset(170, 330), -1.0),
      (Offset(705, 312), 1.0),
    ]) {
      final c = _d(center);
      final innerY = -f.browTilt * 28, outerY = f.browTilt * 14;
      final left = c + Offset(-65, side < 0 ? outerY : innerY);
      final right = c + Offset(65, side < 0 ? innerY : outerY);
      final mid = Offset.lerp(left, right, 0.5)! + const Offset(0, -28);
      canvas.drawPath(
        Path()
          ..moveTo(left.dx, left.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, right.dx, right.dy),
        paint,
      );
    }
  }

  void _paintBlush() {
    if (f.blush < 0.02) return;
    final p = _alphaFill(
      AppTheme.buddyBlush.withValues(alpha: 0.55 * f.blush.clamp(0.0, 1.0)),
    );
    for (final c in const [Offset(165, 800), Offset(780, 770)]) {
      canvas.drawOval(
        Rect.fromCenter(center: _d(c), width: 120, height: 64),
        p,
      );
    }
  }

  /// Nervous "sweat" arcs around the body, each with the direction its
  /// jitter moves it in.
  static final List<(Path, Offset)> _nervousArcs = [
    for (final (a0, c, a1, dir) in const [
      (Offset(1040, -20), Offset(1260, 60), Offset(1300, 320), Offset(1, -1)),
      (Offset(-40, 420), Offset(-10, 300), Offset(100, 250), Offset(-1, -1)),
      (Offset(40, 1300), Offset(70, 1520), Offset(280, 1640), Offset(-1, 1)),
    ])
      (
        Path()
          ..moveTo(a0.dx, a0.dy)
          ..quadraticBezierTo(c.dx, c.dy, a1.dx, a1.dy),
        dir,
      ),
  ];

  void _paintNervous(double a) {
    // The jitter follows `shake`, which reduced motion zeroes.
    final j = math.sin(fr.t * 31) * 6 * f.shake.clamp(0.0, 1.0);
    final p = _alphaStroke(
      AppTheme.buddyOutline.withValues(alpha: a.clamp(0.0, 1.0)),
      40,
    );
    for (final (arc, dir) in _nervousArcs) {
      canvas.save();
      canvas.translate(dir.dx * j, dir.dy * j);
      canvas.drawPath(arc, p);
      canvas.restore();
    }
  }

  /// Two short "grumble" arcs beside the stomach.
  static final List<Path> _rumbleArcs = [
    for (final (x, half) in const [(1225.0, 70.0), (1290.0, 105.0)])
      Path()
        ..moveTo(x, 430 - half)
        ..quadraticBezierTo(x + 0.6 * half, 430, x, 430 + half),
  ];

  void _paintRumble(double a) {
    final alpha = (a * math.sin(3 * fr.t).abs()).clamp(0.0, 1.0);
    if (alpha < 0.01) return;
    final p = _alphaStroke(AppTheme.buddyOutline.withValues(alpha: alpha), 26);
    for (final arc in _rumbleArcs) {
      canvas.drawPath(arc, p);
    }
  }

  void _paintFood(Offset pos, double s) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(s * 1.35);
    canvas.rotate(math.sin(fr.t * 9) * 0.2);
    final image = fr.food;
    if (image != null) {
      _paintFoodImage(image);
    } else {
      _paintApple();
    }
    canvas.restore();
  }

  /// The meal photo, centre-cropped into a circle.
  void _paintFoodImage(ui.Image image) {
    final circle = Rect.fromCircle(center: Offset.zero, radius: _foodRadius);
    final w = image.width.toDouble(), h = image.height.toDouble();
    final side = math.min(w, h);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawCircle(Offset.zero, _foodRadius, _whitePaint);
    if (side > 0) {
      canvas.drawImageRect(
        image,
        Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: side,
          height: side,
        ),
        circle,
        _foodImagePaint,
      );
    }
    canvas.restore();
    canvas.drawCircle(Offset.zero, _foodRadius, _foodOutlinePaint);
  }

  void _paintApple() {
    final outline = _foodOutlinePaint;
    canvas.drawLine(const Offset(0, -70), const Offset(8, -110), outline);
    canvas.save();
    canvas.translate(38, -100);
    canvas.rotate(-0.5);
    final leaf = Rect.fromCenter(center: Offset.zero, width: 70, height: 34);
    canvas.drawOval(leaf, _leafPaint);
    canvas.drawOval(leaf, _leafOutlinePaint);
    canvas.restore();
    canvas.drawCircle(Offset.zero, _foodRadius, _foodPaint);
    canvas.drawCircle(Offset.zero, _foodRadius, outline);
    canvas.drawCircle(const Offset(-28, -26), 14, _appleShinePaint);
  }

  /// Up to three "z" glyphs drifting up from beside the head.
  void _paintZzz(double a) {
    for (var i = 0; i < 3; i++) {
      final p = (fr.t / _zzzLoop + i / 3) % 1.0;
      final fade = math.min(1.0, p / 0.2) * math.min(1.0, (1 - p) / 0.3);
      final alpha = (a * fade).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;
      final half = 28 + 32 * p;
      final c =
          _zzzOrigin +
          Offset(150 * p + 25 * math.sin(p * 2 * math.pi), -380 * p);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - half, c.dy - half)
          ..lineTo(c.dx + half, c.dy - half)
          ..lineTo(c.dx - half, c.dy + half)
          ..lineTo(c.dx + half, c.dy + half),
        _alphaStroke(
          AppTheme.buddyOutline.withValues(alpha: alpha),
          14 + 10 * p,
        ),
      );
    }
  }

  void _paintSparkles(double p) {
    final ease = 1 - math.pow(1 - p, 3).toDouble();
    final size = 70 * math.sin(math.pi * p);
    // A zero-size star draws nothing (and would need a singular transform).
    if (!(size > 0)) return;
    for (var i = 0; i < 12; i++) {
      final ang = i * math.pi / 6 + (i.isEven ? 0.15 : -0.1);
      final dist = (i.isEven ? 620 : 480) * ease + 200;
      final c =
          const Offset(717, 820) + Offset(math.cos(ang), math.sin(ang)) * dist;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p * 3 + i);
      canvas.scale(size * (i.isEven ? 1 : 0.7));
      canvas.drawPath(_unitStar, _sparklePaint);
      canvas.restore();
    }
  }

  void _paintHearts(double a) {
    const every = 0.55, life = 2.6;
    final t = fr.t;
    final first = ((t - life) / every).floor();
    final last = (t / every).floor();
    for (var i = first; i <= last; i++) {
      final age = t - i * every;
      if (age < 0 || age > life) continue;
      final h1 = _hash(i), h2 = _hash(i + 99);
      final x = 120 + h1 * 1200 + math.sin(age * 3 + i) * 30;
      final y = 350 + h2 * 350 - age * 280;
      final fade = math.min(1.0, age / 0.3) * math.min(1.0, (life - age) / 0.6);
      final s = 70 + h2 * 50;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s);
      canvas.drawPath(
        _unitHeart,
        _alphaFill(
          AppTheme.buddyHeart.withValues(alpha: (a * fade).clamp(0.0, 1.0)),
        ),
      );
      canvas.restore();
    }
  }

  /// The hug's hearts: outlined hearts popping up around the Buddy, scaled
  /// by [a] and bobbing gently.
  void _paintHeartBurst(double a) {
    final k = a.clamp(0.0, 1.0);
    final outlineColor = AppTheme.buddyOutline.withValues(alpha: k);
    final fill = _alphaFill(AppTheme.buddyHeart.withValues(alpha: k));
    for (var i = 0; i < _burst.length; i++) {
      final (pos, size) = _burst[i];
      final bob = math.sin(fr.t * 4 + i * 1.7) * 18;
      // Pop: slight overshoot as the intensity ramps in.
      final pop = (0.4 + 0.6 * k) * (1 + 0.25 * math.sin(math.pi * k));
      final c = pos + Offset(0, bob - 60 * k);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate((i.isEven ? -1 : 1) * 0.2);
      canvas.scale(pop * size);
      canvas.drawPath(_unitHeart, fill);
      // The unit heart is scaled by its width: keep the outline 12 px wide.
      canvas.drawPath(_unitHeart, _alphaStroke(outlineColor, 12 / size));
      canvas.restore();
    }
  }

  /// Hug-heart positions (image px) and widths.
  static const List<(Offset, double)> _burst = [
    (Offset(-40, 330), 130),
    (Offset(1060, 40), 150),
    (Offset(1330, 520), 120),
    (Offset(40, 1080), 110),
    (Offset(1380, 1260), 100),
  ];

  static double _hash(int i) {
    final v = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// Heart of width 1 centred on the origin; draw it scaled to its width.
  static final Path _unitHeart = () {
    const h = 0.9;
    return Path()
      ..moveTo(0, h * 0.45)
      ..cubicTo(-0.62, h * 0.02, -0.5, -h * 0.6, 0, -h * 0.22)
      ..cubicTo(0.5, -h * 0.6, 0.62, h * 0.02, 0, h * 0.45)
      ..close();
  }();

  /// Four-point star of radius 1; draw it scaled to its radius.
  static final Path _unitStar = () {
    const k = 0.12;
    return Path()
      ..moveTo(0, -1)
      ..quadraticBezierTo(k, -k, 1, 0)
      ..quadraticBezierTo(k, k, 0, 1)
      ..quadraticBezierTo(-k, k, -1, 0)
      ..quadraticBezierTo(-k, -k, 0, -1)
      ..close();
  }();
}
