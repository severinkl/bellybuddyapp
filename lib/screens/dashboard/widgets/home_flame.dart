import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy_geometry.dart';
import '../../../widgets/buddy/buddy_shape_data.dart' show kBuddyHeight;
import '../../../widgets/buddy/streak_flame.dart';

/// Home's streak flame, a fire behind the Buddy rather than a costume: the
/// [StreakFlame] for [streak] ([lit] once today counts), its base just
/// below his foot ([kBuddyFoot], [AppConstants.homeFlameBelowFeet]), a
/// little right of it ([AppConstants.homeFlameOffset]), its tips clearly
/// above his head, higher the longer the streak ([riseFor]), and without
/// its bright core. It is only a little translucent ([opacityFor]) and
/// lightly blurred: it reads as fire behind him, and he stays the hero.
/// While he says one line, his bubble covers its tips, their flicker
/// included.
///
/// A `CareRing.behindBuddy` layer: it fills the ring and places itself by
/// his square ([buddy]) and the ring's middle ([middle]) ([placeFor]). Its
/// tips may rise into the band of [headroom] above the ring, never past
/// it; it is as wide as the middle leaves around it, its blur included.
/// Narrower there than it draws, it is narrowed to fit whole (a teardrop,
/// not a cut-off pillar); its flicker and ignite stay inside its box too
/// ([StreakFlame.contained]).
class HomeFlame extends StatelessWidget {
  const HomeFlame({
    super.key,
    required this.streak,
    required this.lit,
    required this.buddy,
    required this.middle,
    required this.headroom,
  });

  final int streak;
  final bool lit;

  /// The Buddy's square and the ring's middle, in the box it fills.
  final Rect buddy;
  final Rect middle;

  /// How far above the ring it may reach.
  final double headroom;

  /// How far its blur reaches past what it paints (3 σ).
  static const double _blurReach = 3 * AppConstants.homeFlameBlur;

  /// How far its tips rise above his head by [tier], per his height.
  static double riseFor(FlameTier tier) => switch (tier) {
    FlameTier.small => AppConstants.homeFlameRiseSmall,
    FlameTier.medium => AppConstants.homeFlameRiseMedium,
    FlameTier.large => AppConstants.homeFlameRiseLarge,
    FlameTier.blazing => AppConstants.homeFlameRiseBlazing,
  };

  /// How opaque it shows: as an ember, lit („brennt") or blazing
  /// („lodert").
  static double opacityFor({required int streak, required bool lit}) {
    if (!lit) return AppConstants.homeFlameEmberOpacity;
    return StreakFlame.tierOf(streak) == FlameTier.blazing
        ? AppConstants.homeFlameBlazingOpacity
        : AppConstants.homeFlameLitOpacity;
  }

  /// Where the flame for [streak] burns in the ring's box: its box, from
  /// the band's top (less its blur) down past its base, and how high its
  /// tips reach in it ([StreakFlame.reach]), lit; an ember is low in the
  /// same box.
  static ({Rect box, double reach}) placeFor({
    required int streak,
    required Rect buddy,
    required Rect middle,
    required double headroom,
  }) {
    final layout = BuddyLayout(buddy.size);
    final height = kBuddyHeight * layout.scale;
    final head = buddy.top + layout.headTop;
    final foot = buddy.topLeft + layout.toLocal(kBuddyFoot);
    final centre = foot.dx + AppConstants.homeFlameOffset * height;
    final base = foot.dy + buddy.height * AppConstants.homeFlameBelowFeet;
    final top = _blurReach - headroom;
    final boxHeight = (base - top) / (1 - FlamePainter.baseInset);
    final tip = math.max(
      top,
      head - riseFor(StreakFlame.tierOf(streak)) * height,
    );
    final room = 2 * math.min(centre - middle.left, middle.right - centre);
    final width = math.max(0.0, room - 2 * _blurReach);
    return (
      box: Rect.fromLTWH(centre - width / 2, top, width, boxHeight),
      reach: (base - tip) / boxHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (:box, :reach) = placeFor(
      streak: streak,
      buddy: buddy,
      middle: middle,
      headroom: headroom,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: box,
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
              height: box.height,
              width: box.width,
              core: false,
              contained: true,
              reach: reach,
            ),
          ),
        ),
      ],
    );
  }
}
