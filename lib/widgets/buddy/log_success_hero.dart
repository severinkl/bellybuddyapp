import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../services/buddy/daily_care.dart';
import '../../services/buddy/log_moment.dart';
import 'buddy_reaction_view.dart';
import 'need_meter.dart';
import 'streak_flame.dart';

/// A need's circle charging from [from] to [to] in about
/// [AppConstants.careChargeDuration]; under reduced motion it shows [to]
/// at once. It adds no semantics.
class ChargingMeter extends StatelessWidget {
  const ChargingMeter({
    super.key,
    required this.need,
    required this.from,
    required this.to,
    required this.size,
  });

  final CareNeed need;
  final double from;
  final double to;
  final double size;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: calm ? to : from, end: to),
      duration: calm ? Duration.zero : AppConstants.careChargeDuration,
      curve: Curves.easeOutCubic,
      builder: (_, level, child) =>
          NeedMeter(need: need, level: level, size: size, child: child!),
      child: ExcludeSemantics(
        child: Text(
          need.emoji,
          style: const TextStyle(fontSize: AppTheme.fontSizeChargeIcon),
        ),
      ),
    );
  }
}

/// The tracker success page's hero: the logged need's circle charging
/// (none for Klo), the flame igniting next to „Tag n" when the entry is
/// today's first, and the Buddy reacting ([BuddyReactionView]), who gets
/// the height left over.
///
/// The calm page after a hard moment ([LogSentiment.bad]) cheers no
/// progress: it shows no ignite row. The hero is laid out at least
/// [AppConstants.logSuccessHeroMinHeight] tall and scaled down into a
/// shorter slot, so the Buddy keeps a body there.
class LogSuccessHero extends StatelessWidget {
  const LogSuccessHero({
    super.key,
    required this.moment,
    required this.kind,
    required this.sentiment,
    this.foodImageBytes,
  });

  static const igniteKey = Key('log_success_ignite');

  final LogMoment moment;
  final EntryKind kind;
  final LogSentiment sentiment;

  /// The meal photo the Buddy eats ([BuddyReactionView.foodImageBytes]).
  final Uint8List? foodImageBytes;

  @override
  Widget build(BuildContext context) {
    final from = moment.from;
    final to = moment.to;
    final day = sentiment == LogSentiment.bad ? null : moment.ignitesDay;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(
          constraints.maxHeight,
          AppConstants.logSuccessHeroMinHeight,
        );
        // The same tree at any height, so the reaction never restarts.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: height,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (from != null && to != null)
                  ChargingMeter(
                    need: moment.need,
                    from: from,
                    to: to,
                    size: math.min(
                      AppConstants.careChargeSize,
                      height * AppConstants.careChargeHeightShare,
                    ),
                  ),
                // Also the room the flame's ignite burst draws into above it.
                AppConstants.gap8,
                if (day != null) ...[
                  Row(
                    key: igniteKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreakFlame(
                        streak: day,
                        lit: true,
                        height: AppConstants.streakFlameIgniteHeight,
                        igniteOnMount: true,
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Text(
                        'Tag $day',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeTitleLG,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryForeground,
                        ),
                      ),
                    ],
                  ),
                  AppConstants.gap8,
                ],
                Flexible(
                  child: BuddyReactionView(
                    kind: kind,
                    sentiment: sentiment,
                    foodImageBytes: foodImageBytes,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
