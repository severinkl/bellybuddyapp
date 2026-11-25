import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy_geometry.dart';
import '../../../widgets/buddy/streak_flame.dart';

/// Home's streak flame, a glow behind the Buddy rather than a costume: the
/// [StreakFlame] for [streak] ([lit] once today counts), taller than his
/// square ([AppConstants.homeFlameScale]), centred on his stem with its
/// base just below his foot ([kBuddyFoot], [AppConstants.homeFlameBelowFeet]),
/// narrowed where the ring's middle ([middleWidth]) would cut it off, and
/// without its bright core. It is translucent, by how it shows (an ember,
/// lit or blazing), and slightly blurred, so it reads as a campfire behind
/// him and he stays the hero.
///
/// Laid out bottom-centred in his square ([buddySide] tall, see
/// `CareRing.behindBuddy`); it moves itself over to his foot.
class HomeFlame extends StatelessWidget {
  const HomeFlame({
    super.key,
    required this.streak,
    required this.lit,
    required this.buddySide,
    required this.middleWidth,
  });

  final int streak;
  final bool lit;

  /// The height of the Buddy's square.
  final double buddySide;

  /// The width of the ring's middle, between the bubbles.
  final double middleWidth;

  double get _opacity {
    if (!lit) return AppConstants.homeFlameEmberOpacity;
    return StreakFlame.tierOf(streak) == FlameTier.blazing
        ? AppConstants.homeFlameBlazingOpacity
        : AppConstants.homeFlameLitOpacity;
  }

  @override
  Widget build(BuildContext context) {
    final height = buddySide * AppConstants.homeFlameScale;
    // His foot, the middle of his stem's end (in his square): the flame
    // burns centred behind his stem, its base a little below his foot.
    final foot = BuddyLayout(Size.square(buddySide)).toLocal(kBuddyFoot);
    final footDx = foot.dx - buddySide / 2;
    final base = foot.dy + buddySide * AppConstants.homeFlameBelowFeet;
    final bottom = base + height * FlamePainter.baseInset;
    // Narrower where the ring's middle leaves less room around his foot
    // than it draws, so it shows whole: a teardrop, not a cut-off pillar.
    final drawn =
        height *
        FlamePainter.aspectRatio *
        FlamePainter.widthShare(
          look: lit ? FlameLook.lit : FlameLook.ember,
          tier: StreakFlame.tierOf(streak),
          height: height,
        );
    final fit = ((middleWidth - 2 * footDx.abs()) / drawn).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(footDx, bottom - buddySide),
      child: ImageFiltered(
        // Blurred, then faded: one layer. Clear beyond what it draws
        // (decal): clamped, its edges would smear out as streaks.
        imageFilter: ImageFilter.compose(
          outer: ColorFilter.mode(
            Colors.black.withValues(alpha: _opacity),
            BlendMode.dstIn,
          ),
          inner: ImageFilter.blur(
            sigmaX: AppConstants.homeFlameBlur,
            sigmaY: AppConstants.homeFlameBlur,
            tileMode: TileMode.decal,
          ),
        ),
        child: Transform.scale(
          scaleX: fit,
          alignment: Alignment.bottomCenter,
          // Its bright core would only show beside his stem, in the gaps
          // under his loops: the tongues' yellow base is its bright foot.
          child: StreakFlame(
            streak: streak,
            lit: lit,
            height: height,
            core: false,
          ),
        ),
      ),
    );
  }
}
