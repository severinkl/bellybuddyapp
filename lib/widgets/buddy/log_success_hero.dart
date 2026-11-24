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
    final day = moment.ignitesDay;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (from != null && to != null)
            ChargingMeter(
              need: moment.need,
              from: from,
              to: to,
              size: math.min(
                AppConstants.careChargeSize,
                constraints.maxHeight * AppConstants.careChargeHeightShare,
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
            child: _ScaledBelowBubble(
              child: BuddyReactionView(
                kind: kind,
                sentiment: sentiment,
                foodImageBytes: foodImageBytes,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Buddy's stage in the height left to it, at most
/// [AppConstants.buddyReactionSize]. Below its bubble's height
/// ([AppConstants.buddyBubbleHeight]) the stage would overflow, so there
/// it is laid out at that height and scaled down to fit. The tree stays
/// the same either way, so the reaction never restarts.
class _ScaledBelowBubble extends StatelessWidget {
  const _ScaledBelowBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight.clamp(
          AppConstants.buddyBubbleHeight,
          AppConstants.buddyReactionSize,
        ),
        child: child,
      ),
    ),
  );
}
