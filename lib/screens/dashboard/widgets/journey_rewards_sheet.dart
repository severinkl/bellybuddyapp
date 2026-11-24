import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_rules.dart';
import '../../../models/journey_rewards.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/journey/journey_copy.dart';
import '../../../services/journey/journey_rules.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/buddy/buddy_ask_sheet.dart';
import '../../../widgets/common/bb_drag_handle.dart';
import 'journey_reward_actions.dart';

/// Opens „Deine Belohnungen" ([JourneyRewardsSheet]) over the bottom bar;
/// completes when it closed. Articles open through [openUrl].
Future<void> showJourneyRewardsSheet(
  BuildContext context, {
  UrlOpener openUrl = launchUrl,
}) => showBuddySheet<void>(
  context,
  builder: (_) => JourneyRewardsSheet(openUrl: openUrl),
);

/// „Deine Belohnungen": a row per day of the first 7. An earned one names
/// its reward and what it gives, and a tap closes the sheet and opens it
/// ([openJourneyReward]); day 4's saying has nothing to open. A day not
/// earned yet is locked.
class JourneyRewardsSheet extends ConsumerWidget {
  const JourneyRewardsSheet({super.key, this.openUrl = launchUrl});

  /// Opens the day-2 article.
  final UrlOpener openUrl;

  static Key rowKey(int day) => ValueKey('journey_reward_row_$day');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(journeyRewardsProvider) ?? const JourneyRewards();
    final weeklyTips = ref.watch(weeklyTipsEnabledProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BbDragHandle(color: AppTheme.border),
            AppConstants.gap16,
            Semantics(
              header: true,
              child: const Text(
                JourneyCopy.rewardsTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitleLG,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            AppConstants.gap16,
            for (var day = 1; day <= InsightRules.daysNeeded; day++)
              _row(context, ref, day, rewards, weeklyTips: weeklyTips),
          ],
        ),
      ),
    );
  }

  /// [day]'s row; a tap on an earned one closes the sheet and opens its
  /// reward (day 4's saying has nothing to open).
  Widget _row(
    BuildContext context,
    WidgetRef ref,
    int day,
    JourneyRewards rewards, {
    required bool? weeklyTips,
  }) {
    final earned = rewardEarned(day, rewards);
    return _RewardRow(
      key: rowKey(day),
      day: day,
      title: rewardTitle(day, rewards, weeklyTips: weeklyTips),
      detail: earned ? _detail(day, rewards, ref) : null,
      onTap: !earned || day == 4
          ? null
          : () {
              Navigator.pop(context);
              // The sheet's context stays mounted while it slides out.
              unawaited(openJourneyReward(context, ref, day, openUrl: openUrl));
            },
    );
  }

  /// What [day]'s earned reward gives, under its title.
  String _detail(int day, JourneyRewards rewards, WidgetRef ref) =>
      switch (day) {
        2 => '${JourneyCopy.articleTitle} · ${JourneyCopy.articleSource}',
        3 when rewards.tipOffer == TipOffer.accepted => JourneyCopy.toTips,
        4 => sayingFor(ref.watch(currentUserIdProvider) ?? ''),
        6 => JourneyCopy.example,
        7 => JourneyCopy.toPatterns,
        _ => rewardPick(day, rewards)?.title ?? JourneyCopy.noRecipe,
      };
}

/// A day's row: its day circle, [title] and [detail], and a chevron when
/// it opens something ([onTap]). Without a [detail] the day isn't earned
/// yet: muted and locked.
class _RewardRow extends StatelessWidget {
  const _RewardRow({
    super.key,
    required this.day,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final int day;
  final String title;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final earned = detail != null;
    final dayLabel = JourneyCopy.dayLabel(day);
    return Semantics(
      container: true,
      button: onTap != null,
      label: earned
          ? '$dayLabel: $title, $detail'
          : JourneyCopy.notYet(day, title),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
          child: Row(
            children: [
              _DayCircle(label: dayLabel, earned: earned),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        fontWeight: FontWeight.w600,
                        color: earned
                            ? AppTheme.foreground
                            : AppTheme.mutedForeground,
                      ),
                    ),
                    if (earned) ...[
                      const SizedBox(height: AppConstants.spacing2),
                      Text(detail, style: AppTheme.captionMutedStyle),
                    ],
                  ],
                ),
              ),
              if (!earned || onTap != null) ...[
                const SizedBox(width: AppConstants.spacingSm),
                Icon(
                  earned ? Icons.chevron_right : Icons.lock_outline,
                  size: AppConstants.iconSizeClose,
                  color: AppTheme.mutedForeground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// „Tag n" in a circle: green-tinted once earned, muted before. A larger
/// text scale shrinks the label to fit instead of growing the circle.
class _DayCircle extends StatelessWidget {
  const _DayCircle({required this.label, required this.earned});

  final String label;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.journeyRewardDaySize,
      height: AppConstants.journeyRewardDaySize,
      padding: const EdgeInsets.all(AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: earned ? AppTheme.primarySoft : AppTheme.muted,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSizeCaption,
            fontWeight: FontWeight.w700,
            color: earned
                ? AppTheme.primaryForegroundMuted
                : AppTheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
