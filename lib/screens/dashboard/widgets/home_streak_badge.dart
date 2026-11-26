import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../widgets/buddy/streak_badge.dart';
import '../../../widgets/buddy/streak_flame.dart';
import 'home_flame.dart';

/// Home's [StreakBadge] at its flame's lower right, next to the Buddy's
/// feet: its right edge on the flame's ([HomeFlame.placeFor]), centred on
/// the flame's base, inside the ring's middle (never over a need bubble)
/// and the ring.
///
/// A `CareRing.onBuddy` layer: it fills the ring and places itself by his
/// square ([buddy]) and the ring's middle ([middle]); only the badge takes
/// taps.
class HomeStreakBadge extends StatelessWidget {
  const HomeStreakBadge({
    super.key,
    required this.streak,
    required this.lit,
    required this.buddy,
    required this.middle,
    required this.headroom,
    required this.onTap,
  });

  final int streak;
  final bool lit;

  /// The Buddy's square and the ring's middle, in the box it fills.
  final Rect buddy;
  final Rect middle;

  /// The flame's band above the ring ([HomeFlame.headroom]).
  final double headroom;

  /// Opens „Dein Streak".
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (:box, reach: _) = HomeFlame.placeFor(
      streak: streak,
      buddy: buddy,
      middle: middle,
      headroom: headroom,
    );
    return CustomSingleChildLayout(
      delegate: _AtFlameFoot(
        right: math.min(box.right, middle.right),
        left: middle.left,
        base: box.bottom - box.height * FlamePainter.baseInset,
      ),
      child: StreakBadge(streak: streak, lit: lit, onTap: onTap),
    );
  }
}

/// Puts the badge's right edge on [right] (no further left than [left]),
/// its centre on [base], inside the ring.
class _AtFlameFoot extends SingleChildLayoutDelegate {
  const _AtFlameFoot({
    required this.right,
    required this.left,
    required this.base,
  });

  final double right, left, base;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0, right - left));

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    right - childSize.width,
    (base - childSize.height / 2).clamp(
      0,
      math.max(0, size.height - childSize.height),
    ),
  );

  @override
  bool shouldRelayout(_AtFlameFoot old) =>
      old.right != right || old.left != left || old.base != base;
}
