import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../services/buddy/daily_care.dart';
import '../../services/buddy/log_moment.dart';
import 'buddy_reaction_view.dart';
import 'need_icon.dart';
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
      child: NeedIcon(need, size: size * AppConstants.careMeterIconShare),
    );
  }
}

/// The tracker success page's hero: the logged need's circle charging
/// (none for Klo), the flame igniting next to „Tag n" when the entry is
/// today's first, and the Buddy reacting ([BuddyReactionView]), who gets
/// the height left over.
///
/// The calm page after a hard moment ([LogSentiment.bad]) cheers no
/// progress: it shows no ignite row. Nothing is scaled: the circle takes a
/// share of the slot, and in a slot shorter than
/// [AppConstants.logSuccessHeroStackedMinHeight] it stands beside „Tag n"
/// instead of above it, so the Buddy keeps a body.
class LogSuccessHero extends StatelessWidget {
  const LogSuccessHero({super.key, required this.moment, this.foodImageBytes});

  static const igniteKey = Key('log_success_ignite');

  /// What was logged and what it did.
  final LogMoment moment;

  /// The meal photo the Buddy eats ([BuddyReactionView.foodImageBytes]).
  final Uint8List? foodImageBytes;

  @override
  Widget build(BuildContext context) {
    final from = moment.from;
    final to = moment.to;
    final day = moment.sentiment == LogSentiment.bad ? null : moment.ignitesDay;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final meter = from == null || to == null
            ? null
            : ChargingMeter(
                need: moment.need,
                from: from,
                to: to,
                size: math.min(
                  AppConstants.careChargeSize,
                  height * AppConstants.careChargeHeightShare,
                ),
              );
        final ignite = day == null
            ? null
            : Row(
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
              );
        final sideBySide = height < AppConstants.logSuccessHeroStackedMinHeight;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sideBySide && meter != null && ignite != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  meter,
                  const SizedBox(width: AppConstants.spacingMd),
                  ignite,
                ],
              )
            else ...[
              ?meter,
              // Also the room the flame's ignite burst draws into above it.
              if (ignite != null) ...[AppConstants.gap8, ignite],
            ],
            AppConstants.gap8,
            Flexible(
              child: BuddyReactionView(
                kind: moment.kind,
                sentiment: moment.sentiment,
                foodImageBytes: foodImageBytes,
                line: moment.buddyLine,
              ),
            ),
          ],
        );
      },
    );
  }
}
