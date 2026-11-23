import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../widgets/buddy/buddy_controller.dart';
import 'tutorial/tutorial_keys.dart';

/// The Buddy inside a ring of his four daily needs. Each quarter of the ring
/// fills with today's progress of one need (Trinken top right, Bauchgefühl
/// bottom right, Klo bottom left, Essen top left), and a tappable bubble in
/// that corner shows it („🍽 2/3") and opens its tracker. The [highlight]ed
/// need (the one he suggests next) glows and, unless animations are off,
/// pulses gently with [pulse] (the Buddy's controller, his frame clock).
class CareRing extends StatelessWidget {
  const CareRing({
    super.key,
    required this.care,
    required this.diameter,
    required this.buddy,
    required this.onNeed,
    this.highlight,
    this.pulse,
  });

  /// A need's bubble: `care_need_<name>`.
  static Key needKey(CareNeed need) => ValueKey('care_need_${need.name}');

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
  final ValueChanged<CareNeed> onNeed;
  final CareNeed? highlight;
  final BuddyController? pulse;

  /// Ring quarters clockwise from the top.
  static const _ringOrder = [
    CareNeed.drink,
    CareNeed.gutFeeling,
    CareNeed.toilet,
    CareNeed.food,
  ];

  /// The tour's targets among the bubbles.
  static final _tutorialKeys = <CareNeed, GlobalKey>{
    CareNeed.gutFeeling: TutorialKeys.bauchgefuehl,
    CareNeed.toilet: TutorialKeys.klo,
  };

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    Widget bubble(CareNeed need) {
      final b = _NeedBubble(
        key: needKey(need),
        need: need,
        care: care,
        highlighted: need == highlight,
        pulse: pulse,
        onTap: () => onNeed(need),
      );
      final tutorialKey = _tutorialKeys[need];
      return tutorialKey == null ? b : KeyedSubtree(key: tutorialKey, child: b);
    }

    return SizedBox(
      width: double.infinity,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: diameter,
            child: TweenAnimationBuilder<List<double>>(
              tween: _ProgressTween(
                end: [for (final n in _ringOrder) care.progress(n)],
              ),
              duration: calm ? Duration.zero : AppConstants.animMedium,
              curve: Curves.easeOut,
              builder: (_, progress, _) =>
                  CustomPaint(painter: _RingPainter(progress)),
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
  }
}

/// Lerps the four quarters' progress.
class _ProgressTween extends Tween<List<double>> {
  _ProgressTween({required List<double> end}) : super(end: end);

  @override
  List<double> lerp(double t) {
    final from = begin ?? end!;
    return [
      for (var i = 0; i < end!.length; i++) from[i] + (end![i] - from[i]) * t,
    ];
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  /// Per quarter, clockwise from the top: 0..1.
  final List<double> progress;

  static const _colors = [
    AppTheme.careWater,
    AppTheme.careGut,
    AppTheme.careLoo,
    AppTheme.careFood,
  ];

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
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (var i = 0; i < 4; i++) {
      final start = -math.pi / 2 + i * math.pi / 2 + gap / 2;
      canvas.drawArc(rect, start, sweep, false, paint..color = AppTheme.muted);
      final p = progress[i].clamp(0.0, 1.0);
      if (p > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep * p,
          false,
          paint..color = _colors[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => !_listEquals(old.progress, progress);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A need's corner bubble: its count over its label; filled once met,
/// ringed and glowing while it is the next need. The glow breathes with
/// [pulse]'s clock (the Buddy's controller) unless animations are off.
class _NeedBubble extends StatelessWidget {
  const _NeedBubble({
    super.key,
    required this.need,
    required this.care,
    required this.highlighted,
    required this.onTap,
    this.pulse,
  });

  final CareNeed need;
  final DailyCare care;
  final bool highlighted;
  final VoidCallback onTap;
  final BuddyController? pulse;

  /// The glow's spread at the pulse's low point, as a share of its peak.
  static const _glowMin = 0.6;

  static const _hints = {
    CareNeed.food: 'Mahlzeit eintragen',
    CareNeed.drink: 'Getränk eintragen',
    CareNeed.gutFeeling: 'Bauchgefühl eintragen',
    CareNeed.toilet: 'Klo-Eintrag hinzufügen',
  };

  (String, String) get _value => switch (need) {
    CareNeed.food => ('🍽 ${care.meals}/${DailyCare.mealGoal}', 'Essen'),
    CareNeed.drink => ('💧 ${care.glasses}/${DailyCare.glassGoal}', 'Trinken'),
    CareNeed.gutFeeling => (
      care.isMet(CareNeed.gutFeeling) ? '🙂 ✓' : '🙂 –',
      'Bauchgefühl',
    ),
    CareNeed.toilet => (
      care.toilets > 0 ? '🧻 ${care.toilets}×' : '🧻 –',
      'Klo',
    ),
  };

  String get _semantics => switch (need) {
    CareNeed.food =>
      'Essen: ${care.meals} von ${DailyCare.mealGoal} Mahlzeiten',
    CareNeed.drink =>
      'Trinken: ${care.glasses} von ${DailyCare.glassGoal} Gläsern',
    CareNeed.gutFeeling =>
      care.isMet(CareNeed.gutFeeling)
          ? 'Bauchgefühl: heute eingetragen'
          : 'Bauchgefühl: heute noch offen',
    CareNeed.toilet =>
      'Klo: ${care.toilets} ${care.toilets == 1 ? 'Eintrag' : 'Einträge'} '
          'heute',
  };

  /// 0..1 along the pulse; 1 (full glow) without one.
  static double _pulseAt(BuddyController? clock) {
    if (clock == null) return 1;
    final period = AppConstants.careNeedPulse.inMicroseconds / 1e6;
    return 0.5 + 0.5 * math.sin(clock.elapsed / period * 2 * math.pi);
  }

  BoxDecoration _decoration(double pulse) => BoxDecoration(
    color: care.isMet(need) ? AppTheme.primarySoft : AppTheme.background,
    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
    border: Border.all(
      color: highlighted ? AppTheme.primary : AppTheme.border,
      width: AppConstants.borderWidthLg,
    ),
    boxShadow: [
      if (highlighted)
        BoxShadow(
          color: AppTheme.careGlow,
          spreadRadius:
              AppConstants.careNeedGlow * (_glowMin + (1 - _glowMin) * pulse),
        ),
      BoxShadow(
        color: highlighted ? AppTheme.primary : AppTheme.border,
        offset: AppConstants.careNeedShadowOffset,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final (value, label) = _value;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
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
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
    Widget box(double pulse) => Container(
      width: AppConstants.careNeedWidth,
      constraints: const BoxConstraints(
        minHeight: AppConstants.careNeedMinHeight,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXs,
        vertical: AppConstants.spacing6,
      ),
      decoration: _decoration(pulse),
      child: content,
    );
    final clock = highlighted && !MediaQuery.disableAnimationsOf(context)
        ? pulse
        : null;
    return Semantics(
      button: true,
      label: _semantics,
      hint: _hints[need],
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: clock == null
            ? box(1)
            : AnimatedBuilder(
                animation: clock,
                builder: (_, _) => box(_pulseAt(clock)),
              ),
      ),
    );
  }
}
