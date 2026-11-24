import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// How big the flame burns, by the streak ([StreakFlame.tierOf]).
enum FlameTier {
  small(0.62),
  medium(0.8),
  large(1.0),
  blazing(1.06);

  const FlameTier(this.scale);

  /// The body's scale about its base.
  final double scale;
}

/// How the flame shows: lit once today counts, an ember while a streak
/// waits for today's first entry, off without a streak.
enum FlameLook { off, ember, lit }

/// The streak flame, drawn in the Buddy's style (black outline, flat
/// colours). It grows with [streak] ([tierOf]); unless [lit] it glows dimly
/// as an ember, and [lit] turning true ignites it with a small burst (also
/// on the first build with [igniteOnMount]). An ignite that comes while
/// `TickerMode` is off plays once the flame is visible.
///
/// Unless [still], the lit flame wobbles, the ember breathes and a blazing
/// flame's sparks rise. Under reduced motion all of it holds still and an
/// ignite is lit at once. It adds no semantics; the widget around it
/// speaks.
class StreakFlame extends StatefulWidget {
  const StreakFlame({
    super.key,
    required this.streak,
    required this.lit,
    required this.height,
    this.igniteOnMount = false,
    this.still = false,
  });

  /// A still, lit, large flame: a kept day in the week row.
  const StreakFlame.mark({super.key, required this.height})
    : streak = _markStreak,
      lit = true,
      igniteOnMount = false,
      still = true;

  /// A streak drawn as [FlameTier.large].
  static const _markStreak = 7;

  /// 0–2 small, 3–6 medium, 7–29 large, 30+ blazing.
  static FlameTier tierOf(int streak) => switch (streak) {
    < 3 => FlameTier.small,
    < 7 => FlameTier.medium,
    < 30 => FlameTier.large,
    _ => FlameTier.blazing,
  };

  /// Test seam: while false, flames hold their ambient motion (wobble,
  /// breathing, sparks) still, so `pumpAndSettle` can settle on screens
  /// that show one; the ignite still plays. The test root's
  /// `flutter_test_config.dart` sets it; never change it in app code.
  @visibleForTesting
  static bool ambientEnabled = true;

  final int streak;
  final bool lit;

  /// The width follows the drawing's 100 × 120 box.
  final double height;
  final bool igniteOnMount;

  /// No ambient motion, even with animations on.
  final bool still;

  FlameLook get _look => lit
      ? FlameLook.lit
      : streak > 0
      ? FlameLook.ember
      : FlameLook.off;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with TickerProviderStateMixin {
  late final AnimationController _ignite = AnimationController(
    vsync: this,
    duration: AppConstants.streakFlameIgnite,
  );

  /// The ambient motion's clock: time since it started.
  final ValueNotifier<Duration> _clock = ValueNotifier(Duration.zero);
  late final Ticker _ambient;
  late final Listenable _frames = Listenable.merge([_ignite, _clock]);

  /// An ignite waits for the flame to be visible.
  bool _ignitePending = false;
  bool _reducedMotion = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _ambient = createTicker((elapsed) => _clock.value = elapsed);
    _ignitePending = widget.igniteOnMount && widget.lit;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(StreakFlame old) {
    super.didUpdateWidget(old);
    if (widget.lit && !old.lit) _ignitePending = true;
    // Back to the ember at once (today's first entry deleted again).
    if (!widget.lit) {
      _ignitePending = false;
      _ignite.stop();
    }
    _sync();
  }

  /// Plays a pending ignite (once visible, never under reduced motion) and
  /// runs the ambient clock while there is motion to show. A stopped ignite
  /// shows no burst ([FlamePainter.burst] 0); the build that follows paints
  /// it.
  void _sync() {
    if (_reducedMotion) {
      _ignitePending = false;
      _ignite.stop();
    } else if (_ignitePending && _visible) {
      _ignitePending = false;
      _ignite.forward(from: 0);
    }

    final ambient =
        StreakFlame.ambientEnabled &&
        !widget.still &&
        !_reducedMotion &&
        widget._look != FlameLook.off;
    if (ambient && !_ambient.isActive) {
      _ambient.start();
    } else if (!ambient && _ambient.isActive) {
      _ambient.stop();
      _clock.value = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _ignite.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// [period]'s phase at the ambient clock, 0..1.
  double _phase(Duration period) =>
      _clock.value.inMicroseconds %
      period.inMicroseconds /
      period.inMicroseconds;

  FlamePainter _painter() {
    final look = widget._look;
    final tier = StreakFlame.tierOf(widget.streak);
    final moving = _ambient.isActive;
    final lit = look == FlameLook.lit;
    return FlamePainter(
      look: look,
      tier: tier,
      burst: _ignite.isAnimating ? _ignite.value : 0,
      wobble: moving && lit
          ? math.sin(2 * math.pi * _phase(AppConstants.streakFlameWobble))
          : 0,
      breath: moving && look == FlameLook.ember
          ? (1 -
                    math.cos(
                      2 * math.pi * _phase(AppConstants.streakFlameBreath),
                    )) /
                2
          : 1,
      rise: moving && lit && tier == FlameTier.blazing
          ? _phase(AppConstants.streakFlameSparks)
          : null,
    );
  }

  // Its own layer: the motion repaints every frame, the rest not.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: widget.height * FlamePainter.aspectRatio,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _frames,
        builder: (_, _) => CustomPaint(painter: _painter()),
      ),
    ),
  );
}

/// Paints the flame in a 100 × 120 box scaled to its size: the body (outer
/// flame with its shine, inner flame, a blazing flame's hot core) scaled by
/// [tier] about its base, a blazing flame's sparks behind it and an
/// ignite's burst in front.
class FlamePainter extends CustomPainter {
  const FlamePainter({
    required this.look,
    required this.tier,
    this.burst = 0,
    this.wobble = 0,
    this.breath = 1,
    this.rise,
  });

  /// Width per height of the drawing's box.
  static const double aspectRatio = _boxWidth / _boxHeight;

  static const double _boxWidth = 100;
  static const double _boxHeight = 120;

  /// The point the body scales and wobbles about: the flame's base.
  static const Offset _base = Offset(50, 114);

  /// An ember is this much smaller than its lit tier.
  static const double _emberScale = 0.8;

  /// The ignite's pop: its peak scale, and when in the burst it peaks.
  static const double _popPeak = 1.24;
  static const double _popPeakAt = 0.45;

  /// The ember's opacity at the low of its breath.
  static const double _emberDim = 0.7;

  /// The lit flame's skew at the peak of its wobble (outer, inner).
  static const double _outerSkew = 3 * math.pi / 180;
  static const double _innerSkew = 2 * math.pi / 180;

  final FlameLook look;
  final FlameTier tier;

  /// 0..1 progress of the ignite burst, 0 when none.
  final double burst;

  /// −1..1 along the lit flame's wobble, 0 when still.
  final double wobble;

  /// 0..1 along the ember's breathing, 1 when still.
  final double breath;

  /// 0..1 along the sparks' rise; null when still (sparks at rest).
  final double? rise;

  static final Path _outer = Path()
    ..moveTo(50, 6)
    ..cubicTo(58, 26, 82, 40, 82, 72)
    ..cubicTo(82, 98, 66, 114, 50, 114)
    ..cubicTo(34, 114, 18, 100, 18, 76)
    ..cubicTo(18, 60, 26, 50, 32, 42)
    ..cubicTo(33, 54, 38, 60, 44, 62)
    ..cubicTo(40, 44, 44, 24, 50, 6)
    ..close();

  static final Path _shine = Path()
    ..moveTo(25.5, 88)
    ..cubicTo(23, 78, 24, 67, 29, 59);

  static final Path _inner = Path()
    ..moveTo(50, 50)
    ..cubicTo(56, 62, 68, 72, 68, 88)
    ..cubicTo(68, 102, 60, 108, 50, 108)
    ..cubicTo(40, 108, 32, 101, 32, 89)
    ..cubicTo(32, 79, 38, 73, 42, 65)
    ..cubicTo(43, 70, 45, 72, 47, 72)
    ..cubicTo(46, 64, 47, 57, 50, 50)
    ..close();

  static final Path _core = Path()
    ..moveTo(50, 84)
    ..cubicTo(54, 90, 57, 94, 57, 99)
    ..cubicTo(57, 104, 54, 106.5, 50, 106.5)
    ..cubicTo(46, 106.5, 43, 104, 43, 99)
    ..cubicTo(43, 94, 46, 90, 50, 84)
    ..close();

  /// Sparks: centre and radius at rest.
  static const _sparks = [
    (28.0, 36.0, 3.4),
    (72.0, 30.0, 3.0),
    (56.0, 14.0, 2.6),
  ];

  /// The burst's circles fly from [_burstFrom] by these offsets.
  static const Offset _burstFrom = Offset(50, 66);
  static const double _burstRadius = 4;
  static const _burstTo = [
    Offset(0, -40),
    Offset(28, -30),
    Offset(40, -4),
    Offset(30, 24),
    Offset(-30, 24),
    Offset(-40, -4),
    Offset(-28, -30),
    Offset(12, -46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _boxWidth, size.height / _boxHeight);
    if (look == FlameLook.lit && tier == FlameTier.blazing) {
      _paintSparks(canvas);
    }
    _paintBody(canvas);
    if (burst > 0) _paintBurst(canvas);
    canvas.restore();
  }

  void _paintBody(Canvas canvas) {
    final (outer, inner) = switch (look) {
      FlameLook.lit => (AppTheme.streakFlame, AppTheme.streakFlameCore),
      FlameLook.ember => (AppTheme.streakEmber, AppTheme.streakEmberCore),
      FlameLook.off => (AppTheme.streakEmberOff, null),
    };
    final lit = look == FlameLook.lit;
    final ember = look == FlameLook.ember;
    final opacity = ember ? _emberDim + (1 - _emberDim) * breath : 1.0;

    canvas.save();
    _aboutBase(
      canvas,
      () => canvas.scale(tier.scale * (ember ? _emberScale : 1) * _pop),
    );
    if (opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }

    canvas.save();
    _aboutBase(canvas, () {
      canvas.skew(math.tan(_outerSkew * wobble), 0);
      canvas.scale(1 - 0.02 * wobble, 1 + 0.03 * wobble);
    });
    _shape(canvas, _outer, outer, 4.5);
    if (lit) {
      canvas.drawPath(
        _shine,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    canvas.restore();

    if (inner != null) {
      // The inner flame sways against the outer one, stretching up at
      // both ends of the wobble.
      final stretch = wobble * wobble;
      canvas.save();
      _aboutBase(canvas, () {
        canvas.skew(math.tan(-_innerSkew * wobble), 0);
        canvas.scale(1 - 0.04 * stretch, 1 + 0.05 * stretch);
      });
      _shape(canvas, _inner, inner, 3);
      if (lit && tier == FlameTier.blazing) {
        _shape(canvas, _core, AppTheme.streakFlameHot, 2.6);
      }
      canvas.restore();
    }

    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  /// The body's pop while it ignites: from the ember's size up to
  /// [_popPeak] (at [_popPeakAt] of the burst), then down to its own.
  double get _pop {
    if (burst <= 0 || burst >= 1) return 1;
    if (burst < _popPeakAt) {
      return _lerp(
        _emberScale,
        _popPeak,
        Curves.easeOut.transform(burst / _popPeakAt),
      );
    }
    return _lerp(
      _popPeak,
      1,
      Curves.easeInOut.transform((burst - _popPeakAt) / (1 - _popPeakAt)),
    );
  }

  /// Three sparks, a third of the rise apart: each rises from below its
  /// rest, shrinking, and fades in, then out.
  void _paintSparks(Canvas canvas) {
    for (var i = 0; i < _sparks.length; i++) {
      final (x, y, r) = _sparks[i];
      final rise = this.rise;
      if (rise == null) {
        _dot(canvas, Offset(x, y), r, 1);
        continue;
      }
      final t = (rise - i / _sparks.length) % 1;
      final dy = _lerp(8, -24, Curves.easeOut.transform(t));
      final opacity = t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8;
      _dot(canvas, Offset(x, y + dy), r * _lerp(0.6, 0.3, t), opacity);
    }
  }

  /// The burst's circles fly out from the flame's middle, shrinking and
  /// fading.
  void _paintBurst(Canvas canvas) {
    final t = Curves.easeOut.transform(burst);
    for (final to in _burstTo) {
      _dot(canvas, _burstFrom + to * t, _burstRadius * _lerp(1, 0.4, t), 1 - t);
    }
  }

  /// A flame-core dot with its outline.
  static void _dot(Canvas canvas, Offset center, double radius, double alpha) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppTheme.streakFlameCore.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppTheme.buddyOutline.withValues(alpha: alpha),
    );
  }

  /// [path] filled with [fill] and outlined [strokeWidth] wide.
  static void _shape(Canvas canvas, Path path, Color fill, double strokeWidth) {
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = AppTheme.buddyOutline,
    );
  }

  /// Applies [transform] about [_base].
  static void _aboutBase(Canvas canvas, VoidCallback transform) {
    canvas.translate(_base.dx, _base.dy);
    transform();
    canvas.translate(-_base.dx, -_base.dy);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(FlamePainter old) =>
      old.look != look ||
      old.tier != tier ||
      old.burst != burst ||
      old.wobble != wobble ||
      old.breath != breath ||
      old.rise != rise;
}
