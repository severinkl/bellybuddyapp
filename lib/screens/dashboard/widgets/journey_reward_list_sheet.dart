import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_rules.dart';
import '../../../models/journey_rewards.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/home_cover_provider.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../services/journey/journey_copy.dart';
import '../../../services/journey/journey_rules.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/buddy/buddy_ask_sheet.dart';
import '../../../widgets/common/bb_drag_handle.dart';
import '../../../widgets/common/weekly_tips_switch.dart';
import 'journey_reward_actions.dart';

/// Opens „Deine Belohnungen" ([JourneyRewardListSheet]) over the bottom bar,
/// then what the tapped row gives, from [context] with [ref] (both must
/// outlive the sheet, e.g. Home's):
/// - day 3 while its offer is open ([tipOfferDue]): the offer
///   ([offerFirstTip]); a SnackBar says when the first tip started or the
///   opt-in failed, and a dismissal here is no „Nein": the Buddy still asks;
/// - any other: [openJourneyReward], articles through [openUrl].
///
/// Home counts as covered ([homeCoveredProvider]) until that is done, and
/// while a page it opened is on its way over Home, so the Buddy's cues
/// wait. Completes once that is done.
Future<void> showJourneyRewardListSheet(
  BuildContext context,
  WidgetRef ref, {
  UrlOpener openUrl = launchUrl,
}) => ref
    .read(homeCoveredProvider.notifier)
    .whileOpen(() => _showRewards(context, ref, openUrl: openUrl));

/// [showJourneyRewardListSheet]'s list and what follows it.
Future<void> _showRewards(
  BuildContext context,
  WidgetRef ref, {
  required UrlOpener openUrl,
}) async {
  final day = await showBuddySheet<int>(
    context,
    builder: (_) => const JourneyRewardListSheet(),
  );
  if (day == null || !context.mounted) return;
  final rewards = ref.read(journeyRewardsProvider);
  final offersTip =
      day == 3 &&
      rewards != null &&
      tipOfferDue(rewards, weeklyTips: ref.read(weeklyTipsEnabledProvider));
  if (!offersTip) {
    return openJourneyReward(context, ref, day, openUrl: openUrl);
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = switch (await offerFirstTip(context, ref)) {
    FirstTipOutcome.started => JourneyCopy.firstTipStarted,
    FirstTipOutcome.optInFailed => WeeklyTipsSwitch.failure,
    FirstTipOutcome.declined || FirstTipOutcome.dismissed => null,
  };
  if (message != null) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// „Deine Belohnungen": a row per day of the first 7. An earned one names
/// its reward and what it gives, and a tap closes the sheet with its day
/// ([showJourneyRewardListSheet] then opens it); day 4's saying has nothing to
/// open, nor has day 3 while its offer waits and the weekly tips are
/// unknown. A day not earned yet is locked.
class JourneyRewardListSheet extends ConsumerWidget {
  const JourneyRewardListSheet({super.key});

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

  /// [day]'s row; a tap on one that opens something closes the sheet with
  /// [day].
  Widget _row(
    BuildContext context,
    WidgetRef ref,
    int day,
    JourneyRewards rewards, {
    required bool? weeklyTips,
  }) {
    final earned = rewardEarned(day, rewards);
    final opens =
        earned &&
        switch (day) {
          4 => false,
          3 => switch (day3Of(rewards, weeklyTips: weeklyTips)) {
            Day3.waiting => false,
            Day3.offerOpen => tipOfferDue(rewards, weeklyTips: weeklyTips),
            Day3.tip || Day3.recipe => true,
          },
          _ => true,
        };
    return _RewardRow(
      key: rowKey(day),
      day: day,
      title: rewardTitle(day, rewards, weeklyTips: weeklyTips),
      detail: earned
          ? _detail(day, rewards, ref, weeklyTips: weeklyTips)
          : null,
      onTap: opens ? () => Navigator.pop(context, day) : null,
    );
  }

  /// What [day]'s earned reward gives, under its title.
  String _detail(
    int day,
    JourneyRewards rewards,
    WidgetRef ref, {
    required bool? weeklyTips,
  }) => switch (day) {
    2 => '${JourneyCopy.articleTitle} · ${JourneyCopy.articleSource}',
    3 => switch (day3Of(rewards, weeklyTips: weeklyTips)) {
      Day3.waiting || Day3.offerOpen => JourneyCopy.day3Pending,
      Day3.tip => JourneyCopy.toTips,
      Day3.recipe => _pickTitle(day, rewards, weeklyTips: weeklyTips),
    },
    4 => sayingFor(ref.watch(currentUserIdProvider) ?? ''),
    6 => JourneyCopy.example,
    7 => InsightCopy.openPatterns,
    _ => _pickTitle(day, rewards, weeklyTips: weeklyTips),
  };

  /// The title of [day]'s picked recipe, else the way to the recipes.
  String _pickTitle(
    int day,
    JourneyRewards rewards, {
    required bool? weeklyTips,
  }) =>
      rewardPick(day, rewards, weeklyTips: weeklyTips)?.title ??
      JourneyCopy.noRecipe;
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
