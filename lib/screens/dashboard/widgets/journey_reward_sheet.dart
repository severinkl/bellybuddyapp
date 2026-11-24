import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_rules.dart';
import '../../../models/journey_rewards.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/insights_provider.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/recipe_collection_provider.dart';
import '../../../services/journey/journey_copy.dart';
import '../../../services/journey/journey_rules.dart';
import '../../../widgets/buddy/buddy_ask_sheet.dart';
import '../../../widgets/common/bb_card.dart';
import '../../patterns/widgets/patterns_preview.dart';
import '../../recipes/widgets/recipe_list_tile.dart';
import '../../registration/widgets/step_field_label.dart';

/// The Buddy gives [day]'s reward (1–6) in a [JourneyRewardSheet], over the
/// bottom bar. True for the primary button (or the reward's card): the
/// caller opens it (`openJourneyReward`); false for „Später", when
/// dismissed, and on days with nothing to open (4 and 6).
Future<bool> showJourneyRewardSheet(
  BuildContext context, {
  required int day,
  bool afterNo = false,
}) async =>
    await showBuddySheet<bool>(
      context,
      builder: (_) => JourneyRewardSheet(day: day, afterNo: afterNo),
    ) ??
    false;

/// [day]'s reward of the first days (1–6), as of the stored rewards: the
/// Buddy's line, what he gives, the primary button and, when there is
/// something to open, „Später". Day 3 after „Nein, danke" ([afterNo]) has
/// its own line.
class JourneyRewardSheet extends ConsumerWidget {
  const JourneyRewardSheet({super.key, required this.day, this.afterNo = false})
    : assert(day >= 1 && day < InsightRules.daysNeeded);

  final int day;
  final bool afterNo;

  static const primaryKey = Key('journey_reward_primary');
  static const laterKey = Key('journey_reward_later');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(journeyRewardsProvider) ?? const JourneyRewards();
    final weeklyTips = ref.watch(weeklyTipsEnabledProvider);
    void open() => Navigator.pop(context, true);
    final reward = switch (day) {
      2 => _Reward(
        line: JourneyCopy.day2Line,
        content: _Article(onTap: open),
        primary: JourneyCopy.readArticle,
      ),
      3 => switch (day3Of(rewards, weeklyTips: weeklyTips)) {
        Day3.waiting || Day3.offerOpen || Day3.tip => const _Reward(
          line: JourneyCopy.day3TipLine,
          primary: JourneyCopy.toTips,
        ),
        Day3.recipe => _recipeReward(
          rewardPick(day, rewards, weeklyTips: weeklyTips),
          onTap: open,
        ),
      },
      4 => _Reward(
        line: sayingFor(ref.watch(currentUserIdProvider) ?? ''),
        primary: JourneyCopy.thanks,
        opens: false,
      ),
      6 => _Reward(
        // The last known count, also while the insights reload.
        line: JourneyCopy.day6Line(
          ref.watch(insightsProvider).value?.progress.gutFeelingsLeft ?? 0,
        ),
        content: const _PatternsSample(),
        primary: JourneyCopy.okay,
        opens: false,
      ),
      _ => _recipeReward(
        rewardPick(day, rewards, weeklyTips: weeklyTips),
        onTap: open,
      ),
    };
    return BuddyAskSheet(
      line: reward.line,
      actions: BuddySheetActions(
        primaryKey: primaryKey,
        primary: reward.primary,
        onPrimary: () => Navigator.pop(context, reward.opens),
        secondaryKey: laterKey,
        secondary: reward.opens ? JourneyCopy.later : null,
        onSecondary: reward.opens ? () => Navigator.pop(context, false) : null,
      ),
      child: reward.content,
    );
  }

  /// The recipe of day 1, 3 or 5: [pick] with its line, or without one the
  /// way to the recipes.
  _Reward _recipeReward(RecipePick? pick, {required VoidCallback onTap}) {
    if (pick == null) {
      return const _Reward(
        line: JourneyCopy.noRecipe,
        primary: JourneyCopy.toRecipes,
      );
    }
    final matched = day == 5 ? pick.matched : const <String>[];
    return _Reward(
      line: switch (day) {
        1 => JourneyCopy.day1Line,
        3 => afterNo ? JourneyCopy.day3AfterNoLine : JourneyCopy.day3Line,
        _ =>
          matched.isEmpty ? JourneyCopy.day5GenericLine : JourneyCopy.day5Line,
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickCard(pick: pick, onTap: onTap),
          if (matched.isNotEmpty) ...[
            AppConstants.gap12,
            BuddySheetText(JourneyCopy.day5Because(matched)),
          ],
        ],
      ),
      primary: JourneyCopy.openRecipe,
    );
  }
}

/// What a day's sheet shows: the Buddy's [line], the [content] below him
/// and the [primary] button's label, which [opens] the reward (pops true)
/// or only closes the sheet.
class _Reward {
  const _Reward({
    required this.line,
    this.content,
    required this.primary,
    this.opens = true,
  });

  final String line;
  final Widget? content;
  final String primary;
  final bool opens;
}

/// The picked recipe as a list row, while the collection holds it; else
/// (loading, failed or hidden since) a card naming the stored title.
class _PickCard extends ConsumerWidget {
  const _PickCard({required this.pick, required this.onTap});

  final RecipePick pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(recipeFitProvider(pick.id)).value case final fit?) {
      return RecipeListTile(recipe: fit.recipe, badge: fit.badge, onTap: onTap);
    }
    return _LinkCard(
      icon: Icons.restaurant_menu,
      onTap: onTap,
      child: Text(
        pick.title,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeBody,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
  }
}

/// Day 2: what the article is about, and the article.
class _Article extends StatelessWidget {
  const _Article({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BuddySheetText(JourneyCopy.day2Body),
        AppConstants.gap12,
        _LinkCard(
          icon: Icons.menu_book_outlined,
          onTap: onTap,
          child: const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: JourneyCopy.articleTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                TextSpan(text: ' · ${JourneyCopy.articleSource}'),
              ],
            ),
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// A card that opens the reward: [icon], [child], a chevron.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppConstants.iconSizeMd,
            color: AppTheme.mutedForeground,
          ),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(child: child),
          const SizedBox(width: AppConstants.spacingXs),
          const Icon(
            Icons.chevron_right,
            size: AppConstants.iconSizeClose,
            color: AppTheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}

/// Day 6: what the preview is, its „Beispiel" label and the Muster page's
/// fictional sample.
class _PatternsSample extends StatelessWidget {
  const _PatternsSample();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuddySheetText(JourneyCopy.day6Body),
        AppConstants.gap12,
        StepFieldLabel(JourneyCopy.example),
        AppConstants.gap8,
        PatternsPreview(),
      ],
    );
  }
}
