import 'dart:math' as math;
import 'dart:ui';

import 'buddy_shape_data.dart';

/// Splits every line/cubic into short cubic pieces (control polygon <= [maxLen])
/// so local deformations actually bend the outline. Done once.
List<double> subdivideBuddyPath(List<double> d, {double maxLen = 45}) {
  final out = <double>[];
  var i = 0;
  var px = 0.0, py = 0.0;
  void cubicPieces(Offset p0, Offset c1, Offset c2, Offset p3) {
    Offset at(double t) {
      final u = 1 - t;
      return p0 * (u * u * u) +
          c1 * (3 * u * u * t) +
          c2 * (3 * u * t * t) +
          p3 * (t * t * t);
    }

    Offset deriv(double t) {
      final u = 1 - t;
      return (c1 - p0) * (3 * u * u) +
          (c2 - c1) * (6 * u * t) +
          (p3 - c2) * (3 * t * t);
    }

    final approxLen =
        (c1 - p0).distance + (c2 - c1).distance + (p3 - c2).distance;
    // Start from the control-polygon estimate, then refine until every
    // emitted piece's own control polygon is within [maxLen] (the polygon of
    // a sub-curve can exceed an even share where curvature is uneven).
    var n = math.max(1, (approxLen / maxLen).ceil());
    while (true) {
      final pieces = <double>[];
      var ok = true;
      for (var k = 0; k < n; k++) {
        final t0 = k / n, t1 = (k + 1) / n, h = (t1 - t0) / 3;
        final a = at(t0), b = at(t1);
        final q1 = a + deriv(t0) * h, q2 = b - deriv(t1) * h;
        final len = (q1 - a).distance + (q2 - q1).distance + (b - q2).distance;
        if (len > maxLen && n < 512) ok = false;
        pieces.addAll([2, q1.dx, q1.dy, q2.dx, q2.dy, b.dx, b.dy]);
      }
      if (ok) {
        out.addAll(pieces);
        return;
      }
      n++;
    }
  }

  while (i < d.length) {
    final op = d[i].toInt();
    i++;
    switch (op) {
      case 0:
        px = d[i];
        py = d[i + 1];
        out.addAll([0, px, py]);
        i += 2;
      case 1:
        final p0 = Offset(px, py), p3 = Offset(d[i], d[i + 1]);
        cubicPieces(
          p0,
          Offset.lerp(p0, p3, 1 / 3)!,
          Offset.lerp(p0, p3, 2 / 3)!,
          p3,
        );
        px = p3.dx;
        py = p3.dy;
        i += 2;
      case 2:
        final p3 = Offset(d[i + 4], d[i + 5]);
        cubicPieces(
          Offset(px, py),
          Offset(d[i], d[i + 1]),
          Offset(d[i + 2], d[i + 3]),
          p3,
        );
        px = p3.dx;
        py = p3.dy;
        i += 6;
      default:
        out.add(3);
    }
  }
  return out;
}

/// Builds an even-odd [Path] from opcode data, mapping points through [f].
Path buildBuddyPath(List<double> d, Offset Function(double x, double y) f) {
  final p = Path()..fillType = PathFillType.evenOdd;
  var i = 0;
  while (i < d.length) {
    final op = d[i].toInt();
    i++;
    switch (op) {
      case 0:
        final o = f(d[i], d[i + 1]);
        p.moveTo(o.dx, o.dy);
        i += 2;
      case 1:
        final o = f(d[i], d[i + 1]);
        p.lineTo(o.dx, o.dy);
        i += 2;
      case 2:
        final c1 = f(d[i], d[i + 1]);
        final c2 = f(d[i + 2], d[i + 3]);
        final e = f(d[i + 4], d[i + 5]);
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        i += 6;
      default:
        p.close();
    }
  }
  return p;
}

/// Subdivided shape layers, computed lazily once.
class BuddyShapes {
  BuddyShapes._();

  static final List<double> silhouette = subdivideBuddyPath(kBuddySilhouette);
  static final List<double> fill = subdivideBuddyPath(kBuddyFill);
  static final List<double> outline = subdivideBuddyPath(kBuddyOutline);

  /// Undeformed silhouette, used for hit testing in image coordinates.
  static final Path hitPath = buildBuddyPath(
    silhouette,
    (x, y) => Offset(x, y),
  );
}

/// Maps between widget-local coordinates and Buddy image coordinates.
class BuddyLayout {
  BuddyLayout(Size size)
    : scale = (size.width <= 0 || size.height <= 0)
          ? 0
          : math.min(
              size.width / (kBuddyWidth * 1.12),
              size.height / (kBuddyHeight * 1.18),
            ),
      origin = Offset(
        (size.width - kBuddyWidth * _s(size)) / 2,
        size.height - kBuddyHeight * _s(size) - size.height * 0.03,
      );

  static double _s(Size size) => (size.width <= 0 || size.height <= 0)
      ? 0
      : math.min(
          size.width / (kBuddyWidth * 1.12),
          size.height / (kBuddyHeight * 1.18),
        );

  final double scale;
  final Offset origin;

  Offset toImage(Offset local) =>
      scale == 0 ? Offset.zero : (local - origin) / scale;

  Offset toLocal(Offset image) => origin + image * scale;
}

/// Gut centerline (image coords) the "gulp" bulge travels along.
const List<Offset> kBuddyCenterline = [
  Offset(430, 0),
  Offset(430, 200),
  Offset(480, 360),
  Offset(650, 420),
  Offset(880, 430),
  Offset(960, 520),
  Offset(870, 630),
  Offset(680, 700),
  Offset(640, 800),
  Offset(900, 830),
  Offset(1200, 840),
  Offset(1310, 960),
  Offset(1200, 1085),
  Offset(800, 1090),
  Offset(450, 1095),
  Offset(360, 1220),
  Offset(450, 1370),
  Offset(800, 1385),
  Offset(1060, 1400),
  Offset(1150, 1520),
  Offset(1050, 1650),
  Offset(880, 1720),
  Offset(840, 1830),
  Offset(840, 1920),
];

final List<double> _cum = () {
  final c = <double>[0];
  var acc = 0.0;
  for (var i = 1; i < kBuddyCenterline.length; i++) {
    acc += (kBuddyCenterline[i] - kBuddyCenterline[i - 1]).distance;
    c.add(acc);
  }
  return c;
}();

/// Point on the centerline at arc-length fraction [u] (clamped to 0..1).
Offset pointAlongCenterline(double u) {
  final target = u.clamp(0.0, 1.0) * _cum.last;
  for (var i = 1; i < _cum.length; i++) {
    if (_cum[i] >= target) {
      final seg = _cum[i] - _cum[i - 1];
      final k = seg == 0 ? 0.0 : (target - _cum[i - 1]) / seg;
      return Offset.lerp(kBuddyCenterline[i - 1], kBuddyCenterline[i], k)!;
    }
  }
  return kBuddyCenterline.last;
}

/// Elliptical eye anchor in image coordinates.
class BuddyEyeSpec {
  const BuddyEyeSpec(this.center, this.rx, this.ry, this.angleRad, this.side);
  final Offset center;
  final double rx, ry, angleRad, side;
}

const double _deg = math.pi / 180;

const List<BuddyEyeSpec> kBuddyEyes = [
  BuddyEyeSpec(Offset(237.3, 558.3), 89, 142.4, 14.5 * _deg, -1),
  BuddyEyeSpec(Offset(697.2, 541.6), 90.2, 141.5, -12.9 * _deg, 1),
];

const Offset kBuddyMouthCenter = Offset(466, 764);
const double kBuddyMouthTilt = 0.127;
const Offset kBuddyEyeMid = Offset(467, 550);
