import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/buddy/daily_care.dart';

/// The Buddy inside a ring of his four daily needs. Each quarter of the ring
/// fills with today's progress of one need (Trinken top right, Bauchgefühl
/// bottom right, Klo bottom left, Essen top left), and a counter in
/// that corner shows it („🍽 2/3"). The ring only displays; tapping it calls
/// [onTap] (the Buddy's own taps win). The [highlight]ed
/// need (the one he suggests next) glows and, unless animations are off,
/// pulses gently on its own clock (paused while `TickerMode` is off).
class CareRing extends StatelessWidget {
  const CareRing({
    super.key,
    required this.care,
    required this.diameter,
    required this.buddy,
    required this.onTap,
    this.highlight,
  });

  /// The one tap target on the ring (opens the Tagebuch).
  static const tapKey = Key('care_ring_tap');

  /// A need's counter: `care_need_<name>`.
  static Key needKey(CareNeed need) => ValueKey('care_need_${need.name}');

  /// Test seam: while false, the highlighted need glows without pulsing,
  /// so `pumpAndSettle` can settle on screens that show the ring (e.g. the
  /// dashboard). The test root's `flutter_test_config.dart` sets it; never
  /// change it in app code.
  @visibleForTesting
  static bool pulseEnabled = true;

  /// The ring's diameter in a [width] wide slot on a [screenHeight] tall
  /// screen.
  static double diameterFor(double width, double screenHeight) => math
      .min(
        AppConstants.careRingMaxDiameter,
        math.min(
          width * AppConstants.careRingWidthFactor,
          screenHeight * AppConstants.careRingHeightFactor,
        ),
      )
      .clamp(
        AppConstants.careRingMinDiameter,
        AppConstants.careRingMaxDiameter,
      );

  final DailyCare care;
  final double diameter;

  /// Drawn centred inside the ring, [AppConstants.careRingBuddyFactor] of
  /// its diameter square.
  final Widget buddy;

  /// Tapping the ring (not the Buddy) calls this.
  final VoidCallback onTap;
  final CareNeed? highlight;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    Widget bubble(CareNeed need) => _NeedBubble(
      key: needKey(need),
      need: need,
      care: care,
      highlighted: need == highlight,
    );

    final ring = SizedBox(
      width: double.infinity,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: diameter,
            // The Buddy and the glow next to it repaint every frame; the
            // ring only while its progress animates.
            child: RepaintBoundary(
              child: TweenAnimationBuilder<_Progress>(
                tween: _ProgressTween(end: _progressOf(care)),
                duration: calm ? Duration.zero : AppConstants.animMedium,
                curve: Curves.easeOut,
                builder: (_, progress, _) =>
                    CustomPaint(painter: _RingPainter(progress)),
              ),
            ),
          ),
          SizedBox.square(
            dimension: diameter * AppConstants.careRingBuddyFactor,
            child: buddy,
          ),
          Positioned(top: 0, left: 0, child: bubble(CareNeed.food)),
          Positioned(top: 0, right: 0, child: bubble(CareNeed.drink)),
          Positioned(bottom: 0, left: 0, child: bubble(CareNeed.toilet)),
          Positioned(bottom: 0, right: 0, child: bubble(CareNeed.gutFeeling)),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: 'Heute im Tagebuch ansehen',
      child: GestureDetector(
        key: tapKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ring,
      ),
    );
  }
}

/// The ring quarters' progress (0..1), clockwise from the top: Trinken,
/// Bauchgefühl, Klo, Essen. A record compares by value, so a rebuild with
/// unchanged progress doesn't start the fill animation again.
typedef _Progress = (double, double, double, double);

_Progress _progressOf(DailyCare care) => (
  care.progress(CareNeed.drink),
  care.progress(CareNeed.gutFeeling),
  care.progress(CareNeed.toilet),
  care.progress(CareNeed.food),
);

/// Lerps the four quarters' progress.
class _ProgressTween extends Tween<_Progress> {
  _ProgressTween({required _Progress end}) : super(end: end);

  @override
  _Progress lerp(double t) {
    final (a1, a2, a3, a4) = begin ?? end!;
    final (b1, b2, b3, b4) = end!;
    double at(double a, double b) => a + (b - a) * t;
    return (at(a1, b1), at(a2, b2), at(a3, b3), at(a4, b4));
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final _Progress progress;

  static const _colors = [
    AppTheme.careWater,
    AppTheme.careGut,
    AppTheme.careLoo,
    AppTheme.careFood,
  ];

  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = AppConstants.careRingStroke;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppConstants.careRingStroke;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    const gap = AppConstants.careRingGapDegrees * math.pi / 180;
    const sweep = math.pi / 2 - gap;
    final (p1, p2, p3, p4) = progress;
    final quarters = [p1, p2, p3, p4];
    for (var i = 0; i < 4; i++) {
      final start = -math.pi / 2 + i * math.pi / 2 + gap / 2;
      canvas.drawArc(rect, start, sweep, false, _paint..color = AppTheme.muted);
      final p = quarters[i].clamp(0.0, 1.0);
      if (p > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep * p,
          false,
          _paint..color = _colors[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// A need's corner bubble: its count over its label; filled once met,
/// ringed and glowing ([_Glow]) while it is the next need.
class _NeedBubble extends StatelessWidget {
  const _NeedBubble({
    super.key,
    required this.need,
    required this.care,
    required this.highlighted,
  });

  final CareNeed need;
  final DailyCare care;
  final bool highlighted;

  /// Today's count as shown after the need's emoji („2/3") and as spoken
  /// after its label („2 von 3 Mahlzeiten").
  (String, String) get _count => switch (need) {
    CareNeed.food => (
      '${care.meals}/${DailyCare.mealGoal}',
      '${care.meals} von ${DailyCare.mealGoal} Mahlzeiten',
    ),
    CareNeed.drink => (
      '${care.glasses}/${DailyCare.glassGoal}',
      '${care.glasses} von ${DailyCare.glassGoal} Gläsern',
    ),
    CareNeed.gutFeeling =>
      care.isMet(CareNeed.gutFeeling)
          ? ('✓', 'heute eingetragen')
          : ('–', 'heute noch offen'),
    CareNeed.toilet => (
      care.toilets > 0 ? '${care.toilets}×' : '–',
      '${care.toilets} ${care.toilets == 1 ? 'Eintrag' : 'Einträge'} heute',
    ),
  };

  BoxDecoration get _decoration => BoxDecoration(
    color: care.isMet(need) ? AppTheme.primarySoft : AppTheme.background,
    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
    border: Border.all(
      color: highlighted ? AppTheme.primary : AppTheme.border,
      width: AppConstants.borderWidthLg,
    ),
    boxShadow: [
      BoxShadow(
        color: highlighted ? AppTheme.primary : AppTheme.border,
        offset: AppConstants.careNeedShadowOffset,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final (count, spoken) = _count;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${need.emoji} $count',
            maxLines: 1,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            need.label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
    final box = Container(
      width: AppConstants.careNeedWidth,
      constraints: const BoxConstraints(
        minHeight: AppConstants.careNeedMinHeight,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXs,
        vertical: AppConstants.spacing6,
      ),
      decoration: _decoration,
      child: content,
    );
    return Semantics(
      container: true,
      label: '${need.label}: $spoken',
      excludeSemantics: true,
      child: highlighted ? _Glow(child: box) : box,
    );
  }
}

/// The next need's glow around its bubble ([child]), painted under it. It
/// breathes once per [AppConstants.careNeedPulse] on its own clock (paused
/// while `TickerMode` is off) and stays full while animations are off.
class _Glow extends StatefulWidget {
  const _Glow({required this.child});

  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  /// The glow's spread at the pulse's low point, as a share of its peak.
  static const _glowMin = 0.6;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: AppConstants.careNeedPulse,
  );

  /// Animations are off: a full glow that doesn't pulse.
  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = !CareRing.pulseEnabled || MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// 0..1 along the pulse (a sine wave); 1 while [_still].
  double get _pulse =>
      _still ? 1 : 0.5 + 0.5 * math.sin(_clock.value * 2 * math.pi);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (_, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.careGlow,
            spreadRadius:
                AppConstants.careNeedGlow *
                (_glowMin + (1 - _glowMin) * _pulse),
          ),
        ],
      ),
      child: child,
    ),
    child: widget.child,
  );
}
