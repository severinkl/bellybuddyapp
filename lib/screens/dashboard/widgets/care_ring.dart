import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/buddy/care_meters.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../services/haptic_service.dart';
import '../../../widgets/buddy/need_meter.dart';

/// The Buddy among his four needs, a bubble in each corner (Essen top
/// left, Trinken top right, Klo bottom left, Bauchgefühl bottom right).
/// A bubble's meter shows how full its need is at [now] ([CareMeters]
/// from [log]); Klo has no meter and says when it was last instead
/// ([CareCopy.looLine]). Tapping a bubble calls [onNeed] with its need;
/// the space between them is no tap target (the Buddy has his own). The
/// [highlight]ed need (the one he suggests next) glows and, unless
/// animations are off, pulses gently on its own clock (paused while
/// `TickerMode` is off).
class CareRing extends StatelessWidget {
  const CareRing({
    super.key,
    required this.log,
    required this.now,
    required this.diameter,
    required this.buddy,
    required this.onNeed,
    this.highlight,
  });

  /// A need's bubble (its whole tap area): `care_need_<name>`.
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

  /// A bubble's meter on a ring of [diameter].
  static double meterSizeFor(double diameter) =>
      (diameter * AppConstants.careMeterFactor).clamp(
        AppConstants.careMeterMinSize,
        AppConstants.careMeterMaxSize,
      );

  /// When each need was last logged.
  final CareLog log;

  /// The moment the meters show.
  final DateTime now;
  final double diameter;

  /// Drawn centred, [AppConstants.careRingBuddyFactor] of [diameter]
  /// square.
  final Widget buddy;

  /// Tapping a need's bubble calls this with the need.
  final ValueChanged<CareNeed> onNeed;
  final CareNeed? highlight;

  @override
  Widget build(BuildContext context) {
    final meters = CareMeters.at(log, now);
    final meterSize = meterSizeFor(diameter);
    Widget bubble(CareNeed need) => _NeedBubble(
      key: needKey(need),
      need: need,
      level: meters.level(need),
      // Bauchgefühl shows how today's latest entry was.
      emoji: need == CareNeed.gutFeeling
          ? log.lastGutFeelingLevel?.face ?? need.emoji
          : need.emoji,
      line: need == CareNeed.toilet ? CareCopy.looLine(log, now) : null,
      spoken: CareCopy.spoken(need, log, now),
      meterSize: meterSize,
      highlighted: need == highlight,
      onTap: () => onNeed(need),
    );

    return SizedBox(
      width: double.infinity,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
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

/// A need's corner bubble, a button that logs it ([onTap]): its meter
/// (glowing ([_Glow]) while it is the next need) over its label and, for
/// Klo, when it was last ([line]). A new [level] fills or drains the meter
/// over [AppConstants.animMedium] (at once with animations off); the same
/// level again doesn't move it. Its tap area is everything it paints: the
/// bubble inset by the glow's reach ([AppConstants.careNeedGlow]), so the
/// ring's box holds all of it and no tap on the bubble lands on what sits
/// around the ring.
class _NeedBubble extends StatelessWidget {
  const _NeedBubble({
    super.key,
    required this.need,
    required this.level,
    required this.emoji,
    required this.line,
    required this.spoken,
    required this.meterSize,
    required this.highlighted,
    required this.onTap,
  });

  final CareNeed need;

  /// Its meter's level; null for Klo, which has none.
  final double? level;
  final String emoji;

  /// A second line under the label (Klo's „vor 3 Std").
  final String? line;

  /// The button's semantics value: when it was last.
  final String spoken;
  final double meterSize;
  final bool highlighted;
  final VoidCallback onTap;

  void _tap() {
    HapticService.selection();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Text(
      emoji,
      style: const TextStyle(fontSize: AppTheme.fontSizeHeading),
    );
    // The glow goes inside the tween: when it moves on (the need just
    // logged), the tween keeps its place and the meter still fills.
    Widget meterAt(double? l, Widget child) {
      final meter = NeedMeter(
        need: need,
        level: l,
        size: meterSize,
        child: child,
      );
      return highlighted ? _Glow(child: meter) : meter;
    }

    final l = level;
    final meter = l == null
        ? meterAt(null, icon)
        : TweenAnimationBuilder<double>(
            tween: Tween(end: l),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppConstants.animMedium,
            curve: Curves.easeOut,
            builder: (_, value, child) => meterAt(value, child!),
            child: icon,
          );
    final line = this.line;

    return Semantics(
      button: true,
      label: need.logLabel,
      value: spoken,
      excludeSemantics: true,
      onTap: _tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.careNeedGlow),
          child: SizedBox(
            width: AppConstants.careNeedWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                meter,
                AppConstants.gap4,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    need.label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
                if (line != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      line,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The next need's glow, a circle around its meter ([child]), painted
/// under it. It breathes once per [AppConstants.careNeedPulse] on its own
/// clock (paused while `TickerMode` is off) and stays full while
/// animations are off.
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

  // Its own layer: the pulse repaints every frame, the rest of Home not.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _clock,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
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
    ),
  );
}
