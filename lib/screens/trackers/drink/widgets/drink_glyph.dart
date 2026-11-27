import 'package:material_ui/material_ui.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../utils/drink_helpers.dart';

/// A line drawing of a drink or a vessel, from the drinks screen mockups.
/// Decorative: it adds no semantics, the tile around it speaks.
class DrinkGlyph extends StatelessWidget {
  /// [icon] in a [size] square (the mockup's 24 box scaled to it).
  const DrinkGlyph.icon(
    DrinkIcon this.icon, {
    super.key,
    this.size = AppConstants.drinkTileIconSize,
    this.color = AppTheme.foreground,
  }) : vessel = null;

  /// [vessel] at its own size, [vesselSize].
  const DrinkGlyph.vessel(
    DrinkVessel this.vessel, {
    super.key,
    this.color = AppTheme.foreground,
  }) : icon = null,
       size = 0;

  final DrinkIcon? icon;
  final DrinkVessel? vessel;
  final double size;
  final Color color;

  /// The box a vessel is drawn in.
  static Size vesselSize(DrinkVessel v) => switch (v) {
    DrinkVessel.glass => const Size(22, 28),
    DrinkVessel.can => const Size(20, 34),
    DrinkVessel.bottle => const Size(18, 40),
    DrinkVessel.large => const Size(24, 46),
  };

  @override
  Widget build(BuildContext context) {
    final v = vessel;
    return CustomPaint(
      size: v == null ? Size.square(size) : vesselSize(v),
      painter: DrinkGlyphPainter(icon: icon, vessel: v, color: color),
    );
  }
}

/// Strokes the mockup paths of an [icon] (24 box, scaled to the canvas,
/// stroke with it as an SVG does) or a [vessel] (its own box).
class DrinkGlyphPainter extends CustomPainter {
  const DrinkGlyphPainter({this.icon, this.vessel, required this.color})
    : assert((icon == null) != (vessel == null));

  final DrinkIcon? icon;
  final DrinkVessel? vessel;
  final Color color;

  static const _iconBox = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final icon = this.icon;
    final vessel = this.vessel;
    final Size box;
    final List<Path> paths;
    var roundCaps = false;
    if (icon != null) {
      box = const Size.square(_iconBox);
      paths = _iconPaths(icon);
      roundCaps = icon == DrinkIcon.cup || icon == DrinkIcon.hotCup;
    } else {
      box = DrinkGlyph.vesselSize(vessel!);
      paths = _vesselPaths(vessel);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.drinkGlyphStroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = roundCaps ? StrokeCap.round : StrokeCap.butt;
    canvas
      ..save()
      ..scale(size.width / box.width, size.height / box.height);
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DrinkGlyphPainter old) =>
      old.icon != icon || old.vessel != vessel || old.color != color;
}

const _r1 = Radius.circular(1);
const _r2 = Radius.circular(2);

/// SVG `a r r 0 0 1 dx dy`: a small clockwise arc.
extension on Path {
  void arcBy(double dx, double dy, Radius r) =>
      relativeArcToPoint(Offset(dx, dy), radius: r);
}

List<Path> _iconPaths(DrinkIcon icon) => switch (icon) {
  DrinkIcon.glass => _glassIcon,
  DrinkIcon.hotCup => [..._cupIcon, _steam],
  DrinkIcon.cup => _cupIcon,
  DrinkIcon.bottle => _bottleIcon,
  DrinkIcon.carton => _cartonIcon,
  DrinkIcon.can => _canIcon,
};

List<Path> _vesselPaths(DrinkVessel vessel) => switch (vessel) {
  DrinkVessel.glass => [glassOutline()],
  DrinkVessel.can => _canVessel,
  DrinkVessel.bottle => _bottleVessel,
  DrinkVessel.large => _largeVessel,
};

/// Mockup glass vessel and today-card glass, 22×28:
/// `M3 2h16l-1.6 23a1 1 0 0 1-1 1H5.6a1 1 0 0 1-1-1L3 2z`.
Path glassOutline() => Path()
  ..moveTo(3, 2)
  ..lineTo(19, 2)
  ..relativeLineTo(-1.6, 23)
  ..arcBy(-1, 1, _r1)
  ..lineTo(5.6, 26)
  ..arcBy(-1, -1, _r1)
  ..lineTo(3, 2)
  ..close();

// Wasser: `M7 3h10l-1.2 17a1 1 0 0 1-1 .9H9.2a1 1 0 0 1-1-.9L7 3z`,
// `M7.6 11h8.8`.
final _glassIcon = [
  Path()
    ..moveTo(7, 3)
    ..lineTo(17, 3)
    ..relativeLineTo(-1.2, 17)
    ..arcBy(-1, 0.9, _r1)
    ..lineTo(9.2, 20.9)
    ..arcBy(-1, -0.9, _r1)
    ..lineTo(7, 3)
    ..close(),
  Path()
    ..moveTo(7.6, 11)
    ..relativeLineTo(8.8, 0),
];

// Kaffee: `M5 8h11v6a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5V8z`,
// `M16 10h1.5a2.5 2.5 0 0 1 0 5H16`.
final _cupIcon = [
  Path()
    ..moveTo(5, 8)
    ..lineTo(16, 8)
    ..lineTo(16, 14)
    ..arcBy(-5, 5, const Radius.circular(5))
    ..lineTo(10, 19)
    ..arcBy(-5, -5, const Radius.circular(5))
    ..lineTo(5, 8)
    ..close(),
  Path()
    ..moveTo(16, 10)
    ..lineTo(17.5, 10)
    ..arcBy(0, 5, const Radius.circular(2.5))
    ..lineTo(16, 15),
];

// Pfefferminztee's steam: `M9 3v2M12 3v2`.
final _steam = Path()
  ..moveTo(9, 3)
  ..relativeLineTo(0, 2)
  ..moveTo(12, 3)
  ..relativeLineTo(0, 2);

// Apfelsaft: `M10 2h4v4l2 3v11a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V9l2-3V2z`,
// `M8 13h8`.
final _bottleIcon = [
  Path()
    ..moveTo(10, 2)
    ..lineTo(14, 2)
    ..lineTo(14, 6)
    ..relativeLineTo(2, 3)
    ..lineTo(16, 20)
    ..arcBy(-2, 2, _r2)
    ..lineTo(10, 22)
    ..arcBy(-2, -2, _r2)
    ..lineTo(8, 9)
    ..relativeLineTo(2, -3)
    ..lineTo(10, 2)
    ..close(),
  Path()
    ..moveTo(8, 13)
    ..relativeLineTo(8, 0),
];

// Hafermilch: `M8 7l2-4h4l2 4v13a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V7z`,
// `M8 7h8`.
final _cartonIcon = [
  Path()
    ..moveTo(8, 7)
    ..relativeLineTo(2, -4)
    ..lineTo(14, 3)
    ..relativeLineTo(2, 4)
    ..lineTo(16, 20)
    ..arcBy(-1, 1, _r1)
    ..lineTo(9, 21)
    ..arcBy(-1, -1, _r1)
    ..lineTo(8, 7)
    ..close(),
  Path()
    ..moveTo(8, 7)
    ..relativeLineTo(8, 0),
];

// Dose, 20×34: `M4 2h12l2 4v22l-2 4H4l-2-4V6l2-4z`, `M2 8h16`.
final _canVessel = [
  Path()
    ..moveTo(4, 2)
    ..lineTo(16, 2)
    ..relativeLineTo(2, 4)
    ..lineTo(18, 28)
    ..relativeLineTo(-2, 4)
    ..lineTo(4, 32)
    ..relativeLineTo(-2, -4)
    ..lineTo(2, 6)
    ..relativeLineTo(2, -4)
    ..close(),
  Path()
    ..moveTo(2, 8)
    ..relativeLineTo(16, 0),
];

/// The Dose vessel scaled into the 24 box, centred; its stroke stays
/// [AppConstants.drinkGlyphStroke] wide like the other icons'.
final _canIcon = () {
  const scale = DrinkGlyphPainter._iconBox / 34;
  const dx = (DrinkGlyphPainter._iconBox - 20 * scale) / 2;
  final m = Matrix4.translationValues(dx, 0, 0)
    ..scaleByDouble(scale, scale, 1, 1);
  return [for (final p in _canVessel) p.transform(m.storage)];
}();

// Flasche, 18×40: `M6 2h6v6l4 5v23a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V13l4-5V2z`.
final _bottleVessel = [
  Path()
    ..moveTo(6, 2)
    ..lineTo(12, 2)
    ..lineTo(12, 8)
    ..relativeLineTo(4, 5)
    ..lineTo(16, 36)
    ..arcBy(-2, 2, _r2)
    ..lineTo(4, 38)
    ..arcBy(-2, -2, _r2)
    ..lineTo(2, 13)
    ..relativeLineTo(4, -5)
    ..lineTo(6, 2)
    ..close(),
];

// Große, 24×46: `M9 2h6v7l6 6v27a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V15l6-6V2z`.
final _largeVessel = [
  Path()
    ..moveTo(9, 2)
    ..lineTo(15, 2)
    ..lineTo(15, 9)
    ..relativeLineTo(6, 6)
    ..lineTo(21, 42)
    ..arcBy(-2, 2, _r2)
    ..lineTo(5, 44)
    ..arcBy(-2, -2, _r2)
    ..lineTo(3, 15)
    ..relativeLineTo(6, -6)
    ..lineTo(9, 2)
    ..close(),
];
