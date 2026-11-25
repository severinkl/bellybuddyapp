import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// How big the flame burns, by the streak ([StreakFlame.tierOf]): its
/// body's scale about its base. „lodert" ([blazing]) is taller than wide.
enum FlameTier {
  small(0.62, 0.62),
  medium(0.8, 0.8),
  large(1.0, 1.0),
  blazing(1.06, 1.18);

  const FlameTier(this.scaleX, this.scaleY);

  final double scaleX, scaleY;
}

/// How the flame shows: lit once today counts, else an ember (also at
/// streak 0).
enum FlameLook { ember, lit }

/// The streak flame: tongues of fire, red at their tips, yellow at the
/// base, around a bright core, in a warm glow. It grows with [streak]
/// ([tierOf]); unless [lit] it glows low as an ember, and [lit] turning
/// true ignites it with a small burst (also on the first build with
/// [igniteOnMount]). An ignite that comes while `TickerMode` is off plays
/// once the flame is visible.
///
/// The lit flame's tongues flicker and its sparks rise, and the ember
/// breathes. Under reduced motion all of it holds still and an ignite is
/// lit at once. It adds no semantics; the widget around it
/// speaks.
class StreakFlame extends StatelessWidget {
  const StreakFlame({
    super.key,
    required this.streak,
    required this.lit,
    required this.height,
    this.width,
    this.igniteOnMount = false,
    this.core = true,
    this.contained = false,
  }) : _mark = false;

  /// A still, lit, large flame: a kept day in the week row. Only painted,
  /// it never moves.
  const StreakFlame.mark({super.key, required this.height})
    : streak = _markStreak,
      lit = true,
      width = null,
      igniteOnMount = false,
      core = true,
      contained = false,
      _mark = true;

  /// A streak drawn as [FlameTier.large].
  static const _markStreak = 7;

  /// 0–2 small, 3–6 medium, 7–29 large, 30+ blazing.
  static FlameTier tierOf(int streak) => switch (streak) {
    < 3 => FlameTier.small,
    < 7 => FlameTier.medium,
    < 30 => FlameTier.large,
    _ => FlameTier.blazing,
  };

  /// Test seam: while false, flames hold their ambient motion (flicker,
  /// breathing, sparks) still, so `pumpAndSettle` can settle on screens
  /// that show one; the ignite still plays. The test root's
  /// `flutter_test_config.dart` sets it; never change it in app code.
  @visibleForTesting
  static bool ambientEnabled = true;

  final int streak;
  final bool lit;

  final double height;

  /// Its box's width; null follows the drawing's 100 × 120 box. In a
  /// narrower box the flame is narrowed to fit what it paints at rest
  /// (as tall); in a wider one it is centred.
  final double? width;
  final bool igniteOnMount;

  /// Whether it draws its bright core (and, blazing, the core's blue
  /// root). Home's backdrop leaves it out: behind the Buddy it would only
  /// show beside his stem.
  final bool core;

  /// Whether its ignite stays inside its box (Home's, behind the Buddy): its
  /// pop at most fills the box, its burst flies no further than its sides.
  final bool contained;

  final bool _mark;

  /// How it shows: lit, or an ember.
  FlameLook get look => lit ? FlameLook.lit : FlameLook.ember;

  @override
  Widget build(BuildContext context) {
    final size = Size(width ?? height * FlamePainter.aspectRatio, height);
    if (_mark) {
      return CustomPaint(
        size: size,
        painter: FlamePainter(look: look, tier: tierOf(streak)),
      );
    }
    return _LiveFlame(flame: this, size: size);
  }
}

/// A [StreakFlame] that can ignite and move.
class _LiveFlame extends StatefulWidget {
  const _LiveFlame({required this.flame, required this.size});

  final StreakFlame flame;
  final Size size;

  @override
  State<_LiveFlame> createState() => _LiveFlameState();
}

class _LiveFlameState extends State<_LiveFlame> with TickerProviderStateMixin {
  late final AnimationController _ignite = AnimationController(
    vsync: this,
    duration: AppConstants.streakFlameIgnite,
  );

  /// The lit flame's motion clock (flicker, sparks): time since it
  /// started.
  final ValueNotifier<Duration> _clock = ValueNotifier(Duration.zero);
  late final Ticker _ambient = createTicker((t) => _clock.value = t);

  /// The ember's breath, one cycle per [AppConstants.streakFlameBreath].
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: AppConstants.streakFlameBreath,
  );
  late final Animation<double> _breathOpacity = _breath.drive(
    const _BreathOpacity(),
  );

  /// An ignite waits for the flame to be visible.
  late bool _ignitePending = _flame.igniteOnMount && _flame.lit;
  bool _reducedMotion = false;
  bool _visible = true;

  StreakFlame get _flame => widget.flame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveFlame old) {
    super.didUpdateWidget(old);
    if (_flame.lit && !old.flame.lit) _ignitePending = true;
    // Back to the ember at once (today's first entry deleted again).
    if (!_flame.lit) {
      _ignitePending = false;
      _ignite.stop();
    }
    _sync();
  }

  /// Whether the flame shows its ambient motion now.
  bool get _moving => StreakFlame.ambientEnabled && !_reducedMotion;

  /// Plays a pending ignite (once visible, never under reduced motion) and
  /// runs the motion the look has: the lit flame's clock or the ember's
  /// breath.
  void _sync() {
    // Read on every sync: a new widget can come in the frame that covers
    // the flame, before its didChangeDependencies.
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    if (_reducedMotion) {
      _ignitePending = false;
      _ignite.stop();
    } else if (_ignitePending && _visible) {
      _ignitePending = false;
      _ignite.forward(from: 0);
    }

    final look = _flame.look;
    final moving = _moving;
    if (moving && look == FlameLook.lit) {
      if (!_ambient.isActive) _ambient.start();
    } else if (_ambient.isActive) {
      _ambient.stop();
      _clock.value = Duration.zero;
    }
    if (moving && look == FlameLook.ember) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.reset();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _ignite.dispose();
    _breath.dispose();
    _clock.dispose();
    super.dispose();
  }

  // Its own layer: the motion repaints (or fades) every frame, the rest
  // not.
  @override
  Widget build(BuildContext context) {
    final look = _flame.look;
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _breath.isAnimating
            ? _breathOpacity
            : kAlwaysCompleteAnimation,
        child: CustomPaint(
          size: widget.size,
          painter: FlamePainter(
            look: look,
            tier: StreakFlame.tierOf(_flame.streak),
            core: _flame.core,
            contained: _flame.contained,
            ignite: _ignite,
            clock: _ambient.isActive ? _clock : null,
          ),
        ),
      ),
    );
  }
}

/// The ember's opacity along its breath (0..1): dimmest at the start and
/// end of a cycle, full in its middle.
class _BreathOpacity extends Animatable<double> {
  const _BreathOpacity();

  /// The opacity at the low of the breath.
  static const double _dim = 0.7;

  @override
  double transform(double t) =>
      _dim + (1 - _dim) * (1 - math.cos(2 * math.pi * t)) / 2;
}

/// Paints the flame, drawn in a 100 × 120 box, as tall as its size and as
/// wide (centred), narrowed where its size is narrower than what it paints
/// at rest. Back to front: the lit flame's glow (from
/// [AppConstants.streakFlameGlowMinHeight] up), its tongues, each
/// flickering on its own, the bright core and a blazing flame's blue root
/// (swaying with the centre tongue), the moving flame's sparks (from that
/// height up too) and an ignite's burst. The body is scaled by [bodyScale]
/// about its base. At rest all of it stays inside the box; only an
/// ignite's pop leaves it, unless [contained]. It repaints as [ignite]
/// runs and [clock] ticks, without a rebuild.
class FlamePainter extends CustomPainter {
  FlamePainter({
    required this.look,
    required this.tier,
    this.core = true,
    this.contained = false,
    this.ignite,
    this.clock,
  }) : super(repaint: Listenable.merge([ignite, clock]));

  /// Width per height of the drawing's box.
  static const double aspectRatio = _boxWidth / _boxHeight;

  /// How far the flame's base sits above the box's bottom, as a share of
  /// its height.
  static const double baseInset = (_boxHeight - _boxBaseY) / _boxHeight;

  /// An ember is its tier squashed this much: low embers at its base.
  static const Size _emberSquash = Size(0.8, 0.4);

  /// Half the body's width: its tongues share the base between x 14 and 86.
  static const double _bodyHalfWidth = 36;

  static const double _boxWidth = 100;
  static const double _boxHeight = 120;

  /// The point the body scales and the tongues sway about: the flame's
  /// base.
  static const Offset _base = Offset(50, _boxBaseY);
  static const double _boxBaseY = 114;

  /// The ignite's pop: its peak scale, and when in the burst it peaks.
  static const double _popPeak = 1.24;
  static const double _popPeakAt = 0.45;

  /// A tongue's flicker at its peak: its skew and its stretch (of its
  /// height).
  static const double _maxSkew = 3 * math.pi / 180;
  static const double _maxStretch = 0.06;

  final FlameLook look;
  final FlameTier tier;

  /// Whether the lit flame draws its bright core and, blazing, its blue
  /// root ([StreakFlame.core]).
  final bool core;

  /// Whether the ignite stays inside the box ([StreakFlame.contained]).
  final bool contained;

  /// The ignite; its burst shows while it runs.
  final Animation<double>? ignite;

  /// The lit flame's motion clock; null while it holds still.
  final ValueListenable<Duration>? clock;

  bool get _lit => look == FlameLook.lit;

  /// 0..1 progress of the ignite burst; null when there is none.
  double? get burst {
    final ignite = this.ignite;
    return ignite != null && ignite.isAnimating ? ignite.value : null;
  }

  /// The body's scale about its base: its tier, squashed as an ember,
  /// popping while it ignites ([contained]: at most until its tallest
  /// tongue, flickering, reaches the box's top).
  Size get bodyScale {
    final squash = _lit ? const Size(1, 1) : _emberSquash;
    var pop = _pop(burst);
    if (contained) {
      final cap =
          _boxBaseY / ((_boxBaseY - _tipY) * tier.scaleY * (1 + _maxStretch));
      pop = Size(math.min(pop.width, cap), math.min(pop.height, cap));
    }
    return Size(
      tier.scaleX * squash.width * pop.width,
      tier.scaleY * squash.height * pop.height,
    );
  }

  /// Each tongue's sway, −1..1 (in [_tongues]' order); all 0 while the
  /// flame holds still and for an ember.
  @visibleForTesting
  List<double> get flicker => [for (final angle in _angles) math.sin(angle)];

  /// Each tongue's angle along its flicker (radians); all 0 while still.
  List<double> get _angles {
    final at = _lit ? clock?.value : null;
    return [
      for (final tongue in _tongues)
        at == null
            ? 0
            : 2 * math.pi * (_phaseOf(at, tongue.period) + tongue.phase),
    ];
  }

  /// 0..1 along the sparks' rise for a lit flame; null while still.
  double? get rise {
    final at = clock?.value;
    return _lit && at != null
        ? _phaseOf(at, AppConstants.streakFlameSparks)
        : null;
  }

  /// How many sparks rise: more from a blazing flame; none from an ember,
  /// while it ignites (none float over the still-small flame) or while it
  /// holds still (a frozen spark reads as a speck of dirt).
  int get sparkCount => !_lit || burst != null || rise == null
      ? 0
      : tier == FlameTier.blazing
      ? _sparks.length
      : 2;

  /// Whether it is painted tall enough at [size] for its glow and sparks
  /// ([AppConstants.streakFlameGlowMinHeight]); smaller, they would only
  /// smudge.
  static bool _glowsAt(Size size) =>
      size.height >= AppConstants.streakFlameGlowMinHeight;

  /// The sparks show when painted tall enough ([_glowsAt]).
  bool showsSparks(Size size) => sparkCount > 0 && _glowsAt(size);

  /// A blazing flame burns blue at its base (in its core).
  bool get hotCore => _lit && core && tier == FlameTier.blazing;

  /// The lit flame glows when painted tall enough ([_glowsAt]).
  bool showsGlow(Size size) => _lit && _glowsAt(size);

  /// [period]'s phase at [at], 0..1.
  static double _phaseOf(Duration at, Duration period) =>
      at.inMicroseconds % period.inMicroseconds / period.inMicroseconds;

  // Cached paints; each drawing call sets what varies.
  static final _fill = Paint();

  /// The tongues, back to front: the sides, then the centre. Each shares
  /// the rounded base between x 14 and 86 and flickers on its own period
  /// (pairwise different).
  static final _tongues = [
    // Left, tip at (30, 48).
    _Tongue(
      Path()
        ..moveTo(50, 114)
        ..cubicTo(34, 114, 14, 105, 14, 88)
        ..cubicTo(14, 72, 22, 61, 30, 48)
        ..cubicTo(32, 60, 42, 68, 50, 79)
        ..cubicTo(58, 90, 60, 114, 50, 114)
        ..close(),
      tipY: 48,
      phase: 0,
      period: const Duration(milliseconds: 1300),
    ),
    // Right, tip at (71, 40).
    _Tongue(
      Path()
        ..moveTo(50, 114)
        ..cubicTo(66, 114, 86, 105, 86, 88)
        ..cubicTo(86, 70, 79, 56, 71, 40)
        ..cubicTo(68, 54, 58, 64, 50, 78)
        ..cubicTo(42, 90, 40, 114, 50, 114)
        ..close(),
      tipY: 40,
      phase: 0.37,
      period: const Duration(milliseconds: 1700),
    ),
    // Centre, tip at (50, 24).
    _Tongue(
      Path()
        ..moveTo(50, 114)
        ..cubicTo(36, 114, 27, 103, 27, 88)
        ..cubicTo(27, 68, 42, 54, 50, 24)
        ..cubicTo(56, 52, 73, 66, 73, 88)
        ..cubicTo(73, 103, 64, 114, 50, 114)
        ..close(),
      tipY: 24,
      phase: 0.71,
      period: const Duration(milliseconds: 1100),
    ),
  ];

  /// The centre tongue's index in [_tongues]: the core sways with it.
  static const int _centre = 2;

  /// The highest tongue tip's y.
  static final double _tipY = _tongues.map((t) => t.tipY).reduce(math.min);

  /// Half the width the flame paints at rest at [size] (in the drawing's
  /// units): its glow where it shows one, else its body (squashed as an
  /// ember).
  double _restingHalfWidth(Size size) =>
      tier.scaleX *
      (showsGlow(size)
          ? _glowRadius
          : _lit
          ? _bodyHalfWidth
          : _bodyHalfWidth * _emberSquash.width);

  /// Each tongue filled from its base to its tip: lit, yellow → orange →
  /// red, fading at the tip; as an ember in the ember's colours.
  static final List<Paint> _litTongues = [
    for (final tongue in _tongues)
      _gradient(tongue.tipY, const [
        AppTheme.streakFlameCore,
        AppTheme.streakFlame,
        AppTheme.streakFlameRed,
      ], tipAlpha: 0.25),
  ];
  static final List<Paint> _emberTongues = [
    for (final tongue in _tongues)
      _gradient(tongue.tipY, const [
        AppTheme.streakEmberCore,
        AppTheme.streakEmber,
        AppTheme.streakEmber,
      ], tipAlpha: 0.5),
  ];

  /// A vertical gradient from the base up to [tipY]: [colors] at its
  /// bottom, middle and top, the top's colour full just below the tip and
  /// fading to [tipAlpha] at it.
  static Paint _gradient(
    double tipY,
    List<Color> colors, {
    required double tipAlpha,
  }) => Paint()
    ..shader = ui.Gradient.linear(
      _base,
      Offset(_base.dx, tipY),
      [colors[0], colors[1], colors[2], colors[2].withValues(alpha: tipAlpha)],
      const [0, 0.4, 0.78, 1],
    );

  /// The bright core: a teardrop low in the centre tongue, melting into
  /// it at its tip.
  static final Path _core = Path()
    ..moveTo(50, 54)
    ..cubicTo(54, 68, 63, 80, 63, 94)
    ..cubicTo(63, 105, 57, 111, 50, 111)
    ..cubicTo(43, 111, 37, 105, 37, 94)
    ..cubicTo(37, 80, 46, 68, 50, 54)
    ..close();
  static final Paint _corePaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(50, 111),
      const Offset(50, 54),
      [
        AppTheme.streakFlameBright,
        AppTheme.streakFlameCore,
        AppTheme.streakFlameCore.withValues(alpha: 0),
      ],
      const [0.2, 0.6, 1],
    );

  /// A blazing flame's hot core: a soft blue root about the bright core's
  /// bottom, this wide and tall (half-axes), fading out upward into it.
  /// Painted inside the bright core (over the yellow base, blue would turn
  /// muddy): the core's outline filled with the root's elliptic gradient.
  static const Offset _hotRoot = Offset(50, 111);
  static const double _hotWidth = 14;
  static const double _hotHeight = 26;
  static final Paint _hotPaint = Paint()
    ..shader = ui.Gradient.radial(
      _hotRoot,
      _hotWidth,
      [
        AppTheme.streakFlameHot.withValues(alpha: 0.95),
        AppTheme.streakFlameHot.withValues(alpha: 0.55),
        AppTheme.streakFlameHot.withValues(alpha: 0),
      ],
      const [0, 0.45, 1],
      TileMode.clamp,
      // Stretched to its height about the root.
      (Matrix4.diagonal3Values(1, _hotHeight / _hotWidth, 1)..setTranslationRaw(
            0,
            _hotRoot.dy * (1 - _hotHeight / _hotWidth),
            0,
          ))
          .storage,
    );

  /// The glow: a soft ellipse about [_glowCenter], full in its inner half.
  static const Offset _glowCenter = Offset(50, 74);
  static const double _glowRadius = 46;
  static const double _glowHeightRatio = 44 / 46;
  static final Paint _glowPaint = Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      _glowRadius,
      [
        AppTheme.streakFlameGlow,
        AppTheme.streakFlameGlow,
        AppTheme.streakFlameGlow.withValues(alpha: 0),
      ],
      const [0, 0.5, 1],
    );

  /// The sparks: a lit flame shows the first two; a blazing one all.
  static const _sparks = [
    _Spark(from: Offset(32, 56), drift: -4, radius: 2.6, offset: 0),
    _Spark(from: Offset(69, 50), drift: 3, radius: 2.3, offset: 0.5),
    _Spark(from: Offset(42, 40), drift: -2, radius: 2, offset: 0.22),
    _Spark(from: Offset(60, 36), drift: 2.5, radius: 2.2, offset: 0.72),
    _Spark(from: Offset(24, 70), drift: -3, radius: 1.8, offset: 0.4),
  ];

  /// How far a spark rises, and how much of the rise it shows for.
  static const double _sparkRise = 26;
  static const double _sparkLife = 0.6;

  /// The burst's circles fly from [_burstFrom] (at scale 1) by these
  /// offsets.
  static const Offset _burstFrom = Offset(50, 66);
  static const double _burstRadius = 4;

  /// How far a burst circle flies sideways, at most ([_burstTo]).
  static const double _burstReach = 40;
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
    final scaleY = size.height / _boxHeight;
    final scaleX = math.min(scaleY, size.width / (2 * _restingHalfWidth(size)));
    canvas.save();
    canvas.translate(size.width / 2, 0);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-_base.dx, 0);
    if (showsGlow(size)) _paintGlow(canvas);
    final scale = bodyScale;

    canvas.save();
    _aboutBase(canvas, () => canvas.scale(scale.width, scale.height));
    final angles = _angles;
    final tongues = _lit ? _litTongues : _emberTongues;
    for (var i = 0; i < _tongues.length; i++) {
      _swaying(canvas, angles[i], () {
        canvas.drawPath(_tongues[i].path, tongues[i]);
      });
    }
    if (_lit && core) {
      _swaying(canvas, angles[_centre], () {
        canvas.drawPath(_core, _corePaint);
        if (hotCore) canvas.drawPath(_core, _hotPaint);
      });
    }
    canvas.restore();

    if (showsSparks(size)) _paintSparks(canvas);
    final burst = this.burst;
    if (burst != null) {
      // Contained, it flies no further than the box's sides.
      final spread = contained
          ? ((size.width / 2 / scaleX - _burstRadius) / _burstReach).clamp(
              0.0,
              1.0,
            )
          : 1.0;
      _paintBurst(canvas, burst, scale, spread);
    }
    canvas.restore();
  }

  /// The glow behind the body, scaled with its tier. It grows with an
  /// ignite's pop, but never past the tier, so it stays inside the box.
  void _paintGlow(Canvas canvas) {
    final pop = _pop(burst);
    canvas.save();
    _aboutBase(
      canvas,
      () => canvas.scale(
        tier.scaleX * math.min(pop.width, 1),
        tier.scaleY * math.min(pop.height, 1),
      ),
    );
    canvas.translate(_glowCenter.dx, _glowCenter.dy);
    canvas.scale(1, _glowHeightRatio);
    canvas.drawCircle(Offset.zero, _glowRadius, _glowPaint);
    canvas.restore();
  }

  /// Draws with a tongue's flicker at [angle]: it sways about the base
  /// and stretches twice per sway, so its tip traces a figure eight (at
  /// rest, angle 0, it holds its own shape).
  static void _swaying(Canvas canvas, double angle, VoidCallback draw) {
    canvas.save();
    _aboutBase(canvas, () {
      canvas.skew(math.tan(_maxSkew * math.sin(angle)), 0);
      canvas.scale(1, 1 + _maxStretch * math.sin(2 * angle));
    });
    draw();
    canvas.restore();
  }

  /// The body's pop while it ignites ([burst] not null): from the ember's
  /// size up to [_popPeak] (at [_popPeakAt] of the burst), then down to its
  /// own.
  static Size _pop(double? burst) {
    if (burst == null || burst >= 1) return const Size(1, 1);
    if (burst < _popPeakAt) {
      final t = Curves.easeOut.transform(burst / _popPeakAt);
      return Size(
        _lerp(_emberSquash.width, _popPeak, t),
        _lerp(_emberSquash.height, _popPeak, t),
      );
    }
    final pop = _lerp(
      _popPeak,
      1,
      Curves.easeInOut.transform((burst - _popPeakAt) / (1 - _popPeakAt)),
    );
    return Size(pop, pop);
  }

  /// The first [sparkCount] sparks (yellow with a bright heart), each
  /// rising from near a tongue's tip (placed by the tier, not by an
  /// ignite's pop) for part of the rise: fading in, drifting, shrinking and
  /// fading out, never above the box.
  void _paintSparks(Canvas canvas) {
    final rise = this.rise!;
    for (final spark in _sparks.take(sparkCount)) {
      final t = (rise + spark.offset) % 1;
      if (t >= _sparkLife) continue;
      final u = t / _sparkLife;
      final start = _scaledAboutBase(
        spark.from,
        Size(tier.scaleX, tier.scaleY),
      );
      final r = spark.radius * _lerp(1, 0.4, u);
      final travel = math.min(_sparkRise, start.dy - spark.radius - 1);
      final opacity = u < 0.2 ? u / 0.2 : 1 - (u - 0.2) / 0.8;
      final at =
          start +
          Offset(spark.drift * u, -travel * Curves.easeOut.transform(u));
      _dot(canvas, at, r, AppTheme.streakFlameCore, opacity);
      _dot(canvas, at, r / 2, AppTheme.streakFlameBright, opacity);
    }
  }

  /// The burst's circles fly out from the middle of the flame as it pops
  /// (its body at [scale]), [spread] of their way, shrinking and fading.
  static void _paintBurst(
    Canvas canvas,
    double burst,
    Size scale,
    double spread,
  ) {
    final t = Curves.easeOut.transform(burst);
    final from = _scaledAboutBase(_burstFrom, scale);
    for (final to in _burstTo) {
      _dot(
        canvas,
        from + to * (t * spread),
        _burstRadius * _lerp(1, 0.4, t),
        AppTheme.streakFlameCore,
        1 - t,
      );
    }
  }

  static void _dot(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    canvas.drawCircle(
      center,
      radius,
      _fill..color = color.withValues(alpha: alpha),
    );
  }

  /// [point] (of the drawing at scale 1) scaled by [scale] about [_base].
  static Offset _scaledAboutBase(Offset point, Size scale) =>
      _base +
      Offset(
        (point.dx - _base.dx) * scale.width,
        (point.dy - _base.dy) * scale.height,
      );

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
      old.core != core ||
      old.contained != contained ||
      old.ignite != ignite ||
      old.clock != clock;
}

/// One tongue of the flame: its outline, its tip's height (its gradient's
/// top), its flicker's offset (of a cycle) and period.
class _Tongue {
  const _Tongue(
    this.path, {
    required this.tipY,
    required this.phase,
    required this.period,
  });

  final Path path;
  final double tipY;
  final double phase;
  final Duration period;
}

/// A spark: where it starts (at scale 1), how far it drifts sideways as it
/// rises, its radius and its offset along the rise.
class _Spark {
  const _Spark({
    required this.from,
    required this.drift,
    required this.radius,
    required this.offset,
  });

  final Offset from;
  final double drift;
  final double radius;
  final double offset;
}
