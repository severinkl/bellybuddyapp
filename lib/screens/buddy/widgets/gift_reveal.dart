import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';

/// A wrapped gift box. It wiggles now and then until tapped; the tap pops
/// the lid, bursts sparkles and reveals a „🛡 Streak-Saver" card.
/// [onOpened] fires once, on the first tap.
///
/// Reduced motion: no wiggle, no sparkles; the box opens instantly.
class GiftReveal extends StatefulWidget {
  const GiftReveal({super.key, required this.onOpened});

  final VoidCallback onOpened;

  static const boxKey = Key('gift_reveal_box');
  static const cardKey = Key('gift_reveal_card');

  @override
  State<GiftReveal> createState() => _GiftRevealState();
}

class _GiftRevealState extends State<GiftReveal> with TickerProviderStateMixin {
  /// One wiggle burst plus the pause before the next.
  static const _wigglePeriod = Duration(milliseconds: 1800);
  static const _openDuration = Duration(milliseconds: 1100);

  /// The card appears once the lid is off.
  static const _cardInterval = Interval(0.4, 1, curve: Curves.easeOutBack);

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: _wigglePeriod,
  );
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: _openDuration,
  );
  late final Animation<double> _card = CurvedAnimation(
    parent: _open,
    curve: _cardInterval,
  );

  bool _opened = false;
  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    if (_calm && _opened) _open.value = 1;
    _syncWiggle();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    _open.dispose();
    super.dispose();
  }

  /// Wiggles only while closed and motion is allowed.
  void _syncWiggle() {
    if (!_opened && !_calm) {
      if (!_wiggle.isAnimating) _wiggle.repeat();
    } else {
      _wiggle
        ..stop()
        ..value = 0;
    }
  }

  void _openGift() {
    if (_opened) return;
    HapticService.medium();
    setState(() => _opened = true);
    _syncWiggle();
    if (_calm) {
      _open.value = 1;
    } else {
      _open.forward();
    }
    widget.onOpened();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: !_opened,
          label: _opened ? 'Geschenk geöffnet' : 'Geschenk öffnen',
          onTap: _opened ? null : _openGift,
          child: GestureDetector(
            key: GiftReveal.boxKey,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _openGift,
            child: AnimatedBuilder(
              animation: Listenable.merge([_wiggle, _open]),
              builder: (context, _) => CustomPaint(
                size: const Size.square(AppConstants.giftRevealSize),
                painter: _GiftPainter(
                  wiggle: _wiggle.value,
                  open: _open.value,
                  sparkles: !_calm,
                ),
              ),
            ),
          ),
        ),
        if (_opened)
          FadeTransition(
            opacity: _card,
            child: ScaleTransition(
              scale: _card,
              child: const _SaverCard(key: GiftReveal.cardKey),
            ),
          ),
      ],
    );
  }
}

class _SaverCard extends StatelessWidget {
  const _SaverCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: AppTheme.buddyOutline,
          width: AppConstants.borderWidthLg,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        child: Text(
          '🛡 Streak-Saver',
          style: TextStyle(
            fontSize: AppTheme.fontSizeSubtitle,
            fontWeight: FontWeight.w700,
            color: AppTheme.foreground,
          ),
        ),
      ),
    );
  }
}

/// Draws the box in a square: body and lid in Buddy pinks with a yellow
/// ribbon and bow, outlined like the Buddy. Geometry is in fractions of the
/// side length.
class _GiftPainter extends CustomPainter {
  _GiftPainter({
    required this.wiggle,
    required this.open,
    required this.sparkles,
  });

  /// Wiggle loop phase 0..1 (a short shake at its start, then rest).
  final double wiggle;

  /// Opening progress 0..1 (lid lift, sparkle burst).
  final double open;

  /// Whether the sparkle burst is drawn (off under reduced motion).
  final bool sparkles;

  static const double _bodyLeft = 0.24, _bodyRight = 0.76;
  static const double _bodyTop = 0.56, _bodyBottom = 0.94;
  static const double _lidLeft = 0.2, _lidRight = 0.8, _lidHeight = 0.12;
  static const double _ribbonWidth = 0.08;
  static const double _outline = 0.018;

  /// How far (fraction of the side) and how much (radians) the lid flies.
  static const double _lidLift = 0.3, _lidTilt = -0.4;

  static const double _shakePart = 0.35, _shakeAngle = 0.09;
  static const int _shakeWaves = 3;

  static const int _sparkleCount = 10;
  static const double _sparkleReach = 0.46, _sparkleSize = 0.05;
  static const List<Color> _sparkleColors = [
    AppTheme.buddySparkle,
    AppTheme.buddyHeart,
    AppTheme.primary,
    AppTheme.buddyWater,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final outline = Paint()
      ..color = AppTheme.buddyOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * _outline
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    // Wiggle about the bottom centre.
    final pivot = Offset(s / 2, s * _bodyBottom);
    canvas
      ..translate(pivot.dx, pivot.dy)
      ..rotate(_shake())
      ..translate(-pivot.dx, -pivot.dy);

    _paintBody(canvas, s, outline);
    if (sparkles && open > 0 && open < 1) _paintSparkles(canvas, s);
    _paintLid(canvas, s, outline);
    canvas.restore();
  }

  double _shake() {
    if (wiggle >= _shakePart) return 0;
    final p = wiggle / _shakePart;
    return _shakeAngle * math.sin(p * _shakeWaves * 2 * math.pi) * (1 - p);
  }

  void _paintBody(Canvas canvas, double s, Paint outline) {
    final body = RRect.fromLTRBR(
      s * _bodyLeft,
      s * _bodyTop,
      s * _bodyRight,
      s * _bodyBottom,
      Radius.circular(s * 0.03),
    );
    canvas
      ..drawRRect(body, Paint()..color = AppTheme.buddyBody)
      ..drawRect(
        Rect.fromCenter(
          center: body.center,
          width: s * _ribbonWidth,
          height: body.height,
        ),
        Paint()..color = AppTheme.buddySparkle,
      )
      ..drawRRect(body, outline);
    if (open > 0) {
      // The open top: a dark slit the light comes out of.
      final rim = Rect.fromLTRB(
        s * (_bodyLeft + 0.02),
        s * (_bodyTop - 0.015),
        s * (_bodyRight - 0.02),
        s * (_bodyTop + 0.03),
      );
      canvas.drawOval(rim, Paint()..color = AppTheme.buddyOutline);
    }
  }

  void _paintLid(Canvas canvas, double s, Paint outline) {
    final p = Curves.easeOutBack.transform(open);
    final lid = Rect.fromLTRB(
      s * _lidLeft,
      s * (_bodyTop - _lidHeight),
      s * _lidRight,
      s * _bodyTop,
    );
    canvas.save();
    canvas
      ..translate(lid.center.dx, lid.center.dy - s * _lidLift * p)
      ..rotate(_lidTilt * open)
      ..translate(-lid.center.dx, -lid.center.dy);

    // Bow: two loops on top of the lid.
    final bowY = lid.top - s * 0.04;
    for (final dx in [-0.07, 0.07]) {
      final loop = Rect.fromCenter(
        center: Offset(lid.center.dx + s * dx, bowY),
        width: s * 0.13,
        height: s * 0.09,
      );
      canvas
        ..drawOval(loop, Paint()..color = AppTheme.buddySparkle)
        ..drawOval(loop, outline);
    }

    final rrect = RRect.fromRectAndRadius(lid, Radius.circular(s * 0.03));
    canvas
      ..drawRRect(rrect, Paint()..color = AppTheme.buddyBlush)
      ..drawRect(
        Rect.fromCenter(
          center: lid.center,
          width: s * _ribbonWidth,
          height: lid.height,
        ),
        Paint()..color = AppTheme.buddySparkle,
      )
      ..drawRRect(rrect, outline)
      ..drawCircle(
        Offset(lid.center.dx, bowY),
        s * 0.025,
        Paint()..color = AppTheme.buddyOutline,
      );
    canvas.restore();
  }

  /// Four-point stars flying out of the box and fading.
  void _paintSparkles(Canvas canvas, double s) {
    final p = Curves.easeOut.transform(open);
    final origin = Offset(s / 2, s * _bodyTop);
    final fade = (1 - open).clamp(0.0, 1.0);
    for (var i = 0; i < _sparkleCount; i++) {
      // Upper half-circle, spread evenly, alternating reach.
      final angle = math.pi + math.pi * (i + 0.5) / _sparkleCount;
      final reach = s * _sparkleReach * p * (i.isEven ? 1 : 0.7);
      final c = origin + Offset(math.cos(angle), math.sin(angle)) * reach;
      final r = s * _sparkleSize * (0.6 + 0.4 * fade);
      final color = _sparkleColors[i % _sparkleColors.length];
      canvas.drawPath(
        _star(c, r),
        Paint()..color = color.withValues(alpha: fade),
      );
    }
  }

  static Path _star(Offset c, double r) {
    final w = r * 0.3;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.3, c.dy - w * 0.3, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.3, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.3, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.3, c.dy - w * 0.3, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_GiftPainter old) =>
      old.wiggle != wiggle || old.open != open || old.sparkles != sparkles;
}
