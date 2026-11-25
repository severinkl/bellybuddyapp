import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy_geometry.dart';
import '../../../widgets/buddy/streak_flame.dart';

/// Home's streak flame, a glow behind the Buddy rather than a costume: the
/// [StreakFlame] for [streak] ([lit] once today counts), taller than his
/// square ([AppConstants.homeFlameScale]), centred on his stem with its
/// base just below his foot ([kBuddyFoot], [AppConstants.homeFlameBelowFeet]),
/// and without its bright core. It is translucent, by how it shows
/// ([opacityFor]), and slightly blurred, so it reads as a campfire behind
/// him and he stays the hero.
///
/// A `CareRing.behindBuddy` layer: it fills the ring and places itself by
/// his square ([buddy]), as wide as the ring's middle ([middle]) leaves
/// around his foot, its blur included. Narrower there than it draws, it is
/// narrowed to fit whole (a teardrop, not a cut-off pillar); its ignite
/// stays inside its box too ([StreakFlame.contained]).
class HomeFlame extends StatelessWidget {
  const HomeFlame({
    super.key,
    required this.streak,
    required this.lit,
    required this.buddy,
    required this.middle,
  });

  final int streak;
  final bool lit;

  /// The Buddy's square and the ring's middle, in the box it fills.
  final Rect buddy;
  final Rect middle;

  /// How far its blur reaches past what it paints (3 σ).
  static const double _blurReach = 3 * AppConstants.homeFlameBlur;

  /// How opaque it shows: as an ember, lit („brennt") or blazing
  /// („lodert").
  static double opacityFor({required int streak, required bool lit}) {
    if (!lit) return AppConstants.homeFlameEmberOpacity;
    return StreakFlame.tierOf(streak) == FlameTier.blazing
        ? AppConstants.homeFlameBlazingOpacity
        : AppConstants.homeFlameLitOpacity;
  }

  @override
  Widget build(BuildContext context) {
    final side = buddy.height;
    final height = side * AppConstants.homeFlameScale;
    // His foot, the middle of his stem's end: the flame burns centred
    // behind his stem, its base a little below his foot.
    final foot = buddy.topLeft + BuddyLayout(buddy.size).toLocal(kBuddyFoot);
    final bottom =
        foot.dy +
        side * AppConstants.homeFlameBelowFeet +
        height * FlamePainter.baseInset;
    final room = 2 * math.min(foot.dx - middle.left, middle.right - foot.dx);
    final width = math.max(0.0, room - 2 * _blurReach);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: foot.dx - width / 2,
          top: bottom - height,
          child: ImageFiltered(
            // Blurred, then faded: one layer. Clear beyond what it draws
            // (decal): clamped, its edges would smear out as streaks.
            imageFilter: ImageFilter.compose(
              outer: ColorFilter.mode(
                Colors.black.withValues(
                  alpha: opacityFor(streak: streak, lit: lit),
                ),
                BlendMode.dstIn,
              ),
              inner: ImageFilter.blur(
                sigmaX: AppConstants.homeFlameBlur,
                sigmaY: AppConstants.homeFlameBlur,
                tileMode: TileMode.decal,
              ),
            ),
            // Its bright core would only show beside his stem, in the gaps
            // under his loops: the tongues' yellow base is its bright foot.
            child: StreakFlame(
              streak: streak,
              lit: lit,
              height: height,
              width: width,
              core: false,
              contained: true,
            ),
          ),
        ),
      ],
    );
  }
}
