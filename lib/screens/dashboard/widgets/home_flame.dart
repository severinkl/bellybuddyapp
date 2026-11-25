import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy_geometry.dart';
import '../../../widgets/buddy/streak_flame.dart';

/// Home's streak flame, a glow behind the Buddy rather than a costume: the
/// [StreakFlame] for [streak] ([lit] once today counts), larger than his
/// square ([AppConstants.homeFlameScale]), its base just below his foot
/// ([AppConstants.homeFlameBelowFeet]) and its bright core behind his
/// stem. It is translucent, by how it shows (an ember, lit or blazing),
/// and slightly blurred, so it reads as a campfire behind him and he stays
/// the hero.
///
/// Laid out bottom-centred in his square ([buddySide] tall, see
/// `CareRing.behindBuddy`); it moves itself over to his foot.
class HomeFlame extends StatelessWidget {
  const HomeFlame({
    super.key,
    required this.streak,
    required this.lit,
    required this.buddySide,
  });

  final int streak;
  final bool lit;

  /// The height of the Buddy's square.
  final double buddySide;

  double get _opacity {
    if (!lit) return AppConstants.homeFlameEmberOpacity;
    return StreakFlame.tierOf(streak) == FlameTier.blazing
        ? AppConstants.homeFlameBlazingOpacity
        : AppConstants.homeFlameLitOpacity;
  }

  @override
  Widget build(BuildContext context) {
    final height = buddySide * AppConstants.homeFlameScale;
    // His foot, the end of his stem (in his square): the flame's base goes
    // a little below it, so its core burns behind his stem and his lowest
    // loop, not in the gaps beside them.
    final foot = BuddyLayout(
      Size.square(buddySide),
    ).toLocal(kBuddyCenterline.last);
    final base = foot.dy + buddySide * AppConstants.homeFlameBelowFeet;
    final bottom = base + height * FlamePainter.baseInset;
    return Transform.translate(
      offset: Offset(foot.dx - buddySide / 2, bottom - buddySide),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: AppConstants.homeFlameBlur,
          sigmaY: AppConstants.homeFlameBlur,
        ),
        child: Opacity(
          opacity: _opacity,
          child: StreakFlame(streak: streak, lit: lit, height: height),
        ),
      ),
    );
  }
}
