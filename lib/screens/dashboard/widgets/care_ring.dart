import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/buddy/care_meters.dart';
import '../../../services/buddy/care_now.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/gut_feeling_rating.dart';
import '../../../widgets/buddy/buddy_geometry.dart';
import '../../../widgets/buddy/need_icon.dart';
import '../../../widgets/buddy/need_meter.dart';

/// Builds a layer of [CareRing] around the Buddy, in the ring's box: his
/// square ([buddy]) and the ring's middle between the bubbles' columns
/// ([middle]), both in that box.
typedef CareRingLayer = Widget Function(Rect buddy, Rect middle);

/// The Buddy among his four needs, a bubble in each corner (Essen top
/// left, Trinken top right, Klo bottom left, Bauchgefühl bottom right):
/// a column of two bubbles on each side of him, at least [diameter] tall
/// and taller where large text needs it, so no bubble ever covers another.
/// The four labels share one size, shrunk together where the longest
/// would not fit its bubble.
/// A bubble's meter shows how full its need is ([care]'s [CareMeters]);
/// Klo has no meter and says when it was last instead
/// ([CareCopy.looLine]). Tapping a bubble calls [onNeed] with its need;
/// the space between them is no tap target (the Buddy has his own). The
/// [highlight]ed need (the one he suggests next) glows and, unless
/// animations are off, pulses gently on its own clock (paused while
/// `TickerMode` is off). [behindBuddy] (Home's streak flame) is drawn
/// under him and the bubbles, [overBuddy] (his speech bubble) on his head,
/// over it all.
class CareRing extends StatelessWidget {
  const CareRing({
    super.key,
    required this.care,
    required this.diameter,
    required this.buddy,
    required this.onNeed,
    this.highlight,
    this.behindBuddy,
    this.overBuddy,
    this.overBuddyRoom = 0,
  });

  /// A need's bubble (its whole tap area): `care_need_<name>`.
  static Key needKey(CareNeed need) => ValueKey('care_need_${need.name}');

  /// The Buddy's square.
  static const buddyKey = Key('care_ring_buddy');

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

  /// The side of the Buddy's square on a ring of [diameter]: he is drawn
  /// as tall, and as wide where the ring's middle leaves the room.
  static double buddySideFor(double diameter) =>
      diameter * AppConstants.careRingBuddyFactor;

  /// A bubble's meter on a ring of [diameter].
  static double meterSizeFor(double diameter) =>
      (diameter * AppConstants.careMeterFactor).clamp(
        AppConstants.careMeterMinSize,
        AppConstants.careMeterMaxSize,
      );

  /// His needs at the moment shown.
  final CareNow care;
  final double diameter;

  /// Drawn centred in his square ([buddySideFor]).
  final Widget buddy;

  /// Tapping a need's bubble calls this with the need.
  final ValueChanged<CareNeed> onNeed;
  final CareNeed? highlight;

  /// Drawn under the Buddy and the bubbles, filling the ring: it places
  /// itself by his square and the ring's middle it is handed, and keeps
  /// to the middle (never over or under a bubble). It is never a tap
  /// target: a tap on it lands on what is over it.
  final CareRingLayer? behindBuddy;

  /// Drawn over everything in the ring, the bubbles included (Home's
  /// speech bubble): centred on the ring, its bottom on the Buddy's head
  /// ([BuddyLayout.headTop]). It gets at most the ring's width and the
  /// height from the ring's top down to his head plus [overBuddyRoom], and
  /// is never a tap target: a tap on it lands on what it covers.
  final CareRingLayer? overBuddy;

  /// How far [overBuddy] may rise above the ring.
  final double overBuddyRoom;

  /// The labels' style; [_labelScaler] fits the longest into a bubble.
  static const _labelStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );

  /// The text scale all four labels share: the user's, or less where the
  /// longest label would not fit [AppConstants.careNeedWidth]. Measured as
  /// [Text] draws them: bold where the platform asks for bold text.
  static TextScaler _labelScaler(BuildContext context) {
    var style = DefaultTextStyle.of(context).style.merge(_labelStyle);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    double widest(TextScaler scaler) {
      var widest = 0.0;
      for (final need in CareNeed.values) {
        final painter = TextPainter(
          text: TextSpan(text: need.label, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    final scaler = MediaQuery.textScalerOf(context);
    const fit = AppConstants.careNeedWidth;
    final natural = widest(scaler);
    if (natural <= fit) return scaler;
    // Text doesn't narrow quite in step with its size: shrink on until the
    // longest label fits.
    var factor =
        scaler.scale(AppTheme.fontSizeCaptionLG) /
        AppTheme.fontSizeCaptionLG *
        fit /
        natural;
    var fitted = TextScaler.linear(factor);
    while (widest(fitted) > fit) {
      factor *= _labelShrinkStep;
      fitted = TextScaler.linear(factor);
    }
    return fitted;
  }

  /// How much each further step shrinks the labels by ([_labelScaler]).
  static const _labelShrinkStep = 0.98;

  /// The Buddy's square and the ring's middle (between the bubbles'
  /// columns) in a ring of [size], as its row lays them out: he is centred
  /// in the middle, narrower where it leaves less room than [buddySide].
  static ({Rect buddy, Rect middle}) _placesIn(Size size, double buddySide) {
    const column = AppConstants.careNeedWidth + 2 * AppConstants.careNeedGlow;
    final middle = Rect.fromLTRB(
      column,
      0,
      math.max(column, size.width - column),
      size.height,
    );
    final buddy = Rect.fromCenter(
      center: middle.center,
      width: math.min(buddySide, middle.width),
      height: math.min(buddySide, middle.height),
    );
    return (buddy: buddy, middle: middle);
  }

  /// [layer] in a ring-filling box that takes no tap, handed his square
  /// and the middle; [place] puts what it builds into that box.
  Widget _layer(
    CareRingLayer layer,
    double buddySide, {
    Widget Function(Rect buddy, Widget child)? place,
  }) => Positioned.fill(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (_, constraints) {
          final (:buddy, :middle) = _placesIn(constraints.biggest, buddySide);
          final child = layer(buddy, middle);
          return place == null ? child : place(buddy, child);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final meterSize = meterSizeFor(diameter);
    final labelScaler = _labelScaler(context);
    final buddySide = buddySideFor(diameter);
    Widget bubble(CareNeed need) => _NeedBubble(
      key: needKey(need),
      need: need,
      level: care.meters.level(need),
      // Bauchgefühl shows how today's latest entry was.
      gutFeeling: need == CareNeed.gutFeeling ? care.gutFeelingLevel : null,
      line: need == CareNeed.toilet ? care.looLine : null,
      spoken: care.spoken(need),
      meterSize: meterSize,
      labelScaler: labelScaler,
      highlighted: need == highlight,
      onTap: () => onNeed(need),
    );
    Widget side(CareNeed top, CareNeed bottom) => Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [bubble(top), bubble(bottom)],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: diameter),
      child: IntrinsicHeight(
        // As tall as the row: a positioned child adds no height.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (behindBuddy case final behind?) _layer(behind, buddySide),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                side(CareNeed.food, CareNeed.toilet),
                // His square, narrower where the bubbles leave less room (he
                // is drawn narrower than tall, so his height stays):
                // [_placesIn].
                Expanded(
                  child: Center(
                    child: SizedBox.square(
                      key: buddyKey,
                      dimension: buddySide,
                      child: buddy,
                    ),
                  ),
                ),
                side(CareNeed.drink, CareNeed.gutFeeling),
              ],
            ),
            if (overBuddy case final over?)
              _layer(
                over,
                buddySide,
                place: (buddy, child) => CustomSingleChildLayout(
                  delegate: _OverBuddyLayout(
                    head: buddy.top + BuddyLayout(buddy.size).headTop,
                    room: overBuddyRoom,
                  ),
                  child: child,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lays out [CareRing.overBuddy] in the ring: at most the ring's width and
/// the height down to the Buddy's [head] plus [room], centred on the ring,
/// its bottom on his head.
class _OverBuddyLayout extends SingleChildLayoutDelegate {
  const _OverBuddyLayout({required this.head, required this.room});

  /// The top of his head in the ring.
  final double head;

  /// How far it may rise above the ring ([CareRing.overBuddyRoom]).
  final double room;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: math.max(0, head + room),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset((size.width - childSize.width) / 2, head - childSize.height);

  @override
  bool shouldRelayout(_OverBuddyLayout old) =>
      old.head != head || old.room != room;
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
    required this.gutFeeling,
    required this.line,
    required this.spoken,
    required this.meterSize,
    required this.labelScaler,
    required this.highlighted,
    required this.onTap,
  });

  final CareNeed need;

  /// Its meter's level; null for Klo, which has none.
  final double? level;

  /// Bauchgefühl's latest level, the mouth on its icon ([NeedIcon]).
  final GutFeelingRatingLevel? gutFeeling;

  /// A second line under the label (Klo's „vor 3 Std").
  final String? line;

  /// The button's semantics value: when it was last.
  final String spoken;
  final double meterSize;

  /// The text scale all four labels share ([CareRing._labelScaler]).
  final TextScaler labelScaler;
  final bool highlighted;
  final VoidCallback onTap;

  void _tap() {
    HapticService.selection();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final icon = NeedIcon(need, gutFeeling: gutFeeling);
    // The glow goes inside the tween: when it moves on (the need just
    // logged), the tween keeps its place and the meter still fills.
    Widget meterAt(double? shown, Widget child) {
      final meter = NeedMeter(
        need: need,
        level: shown,
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
                Text(
                  need.label,
                  maxLines: 1,
                  textScaler: labelScaler,
                  style: CareRing._labelStyle,
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

  // Its own layer: the pulse repaints every frame, the rest of Home not;
  // nor the meter, in a layer of its own above it.
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
      child: RepaintBoundary(child: widget.child),
    ),
  );
}
