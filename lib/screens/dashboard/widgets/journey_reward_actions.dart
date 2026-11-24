import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/journey_rewards.dart';
import '../../../providers/first_tip_provider.dart';
import '../../../providers/home_cover_provider.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../router/navigation_extensions.dart';
import '../../../router/route_names.dart';
import '../../../services/journey/journey_copy.dart';
import '../../../services/journey/journey_rules.dart';
import '../../../utils/url_utils.dart';
import 'first_tip_offer_sheet.dart';
import 'journey_reward_sheet.dart';

/// Opens what [day]'s reward gives, from [context]:
/// - 1, 3 and 5: the picked recipe ([rewardPick]), else the recipes;
/// - 2: the article, in the in-app browser through [openUrl] (a SnackBar
///   says when that fails); completes once it opened or failed;
/// - 3 while it is the tip ([day3IsTip]): the Tipps (an open offer is
///   answered through [offerFirstTip], never here);
/// - 4: nothing (the saying is the reward);
/// - 6 and 7: Muster.
///
/// Navigations are not awaited; each tells [homeCoveredProvider] that Home
/// is left as it starts. The article (over the app) and day 4 never leave
/// Home.
Future<void> openJourneyReward(
  BuildContext context,
  WidgetRef ref,
  int day, {
  UrlOpener openUrl = launchUrl,
}) async {
  final rewards = ref.read(journeyRewardsProvider) ?? const JourneyRewards();
  final weeklyTips = ref.read(weeklyTipsEnabledProvider);
  final cover = ref.read(homeCoveredProvider.notifier);
  void push(Future<void> page) {
    cover.leftHome(page);
    unawaited(page);
  }

  switch (day) {
    case 2:
      await openExternalUrl(
        context,
        JourneyCopy.articleUrl,
        mode: LaunchMode.inAppBrowserView,
        failureMessage: JourneyCopy.articleFailure,
        open: openUrl,
      );
    case 3 when day3IsTip(rewards, weeklyTips: weeklyTips):
      push(context.push(RoutePaths.recommendations));
    case 1 || 3 || 5:
      if (rewardPick(day, rewards, weeklyTips: weeklyTips) case final pick?) {
        push(context.openRecipe(pick.id));
      } else {
        cover.leftHome(null);
        context.go(RoutePaths.discoverRecipes);
      }
    case 6 || 7:
      push(context.push(RoutePaths.patterns));
  }
}

/// How the day-3 offer of a first tip ended ([offerFirstTip]).
enum FirstTipOutcome {
  /// „Ja, gern": the weekly tips are on and the first tip is on its way.
  started,

  /// „Ja, gern", but switching the weekly tips on failed: nothing sent.
  optInFailed,

  /// „Nein, danke": answered so, and day 3's recipe given.
  declined,

  /// Dismissed, or [offerFirstTip]'s context gone meanwhile: nothing
  /// stored. What that means is the caller's.
  dismissed,
}

/// The day-3 offer of a first tip ([showFirstTipOfferSheet]), from
/// [context], and what follows the answer:
/// - „Ja, gern" requests it (`FirstTipNotifier.accept`, which switches the
///   weekly tips on first): [FirstTipOutcome.started], or
///   [FirstTipOutcome.optInFailed] when that failed;
/// - „Nein, danke" answers the offer so, then gives day 3's recipe
///   ([showJourneyRewardSheet] after „Nein"; its primary button opens it):
///   [FirstTipOutcome.declined]; opening it leaves Home as
///   [openJourneyReward] does;
/// - a dismissal stores nothing: [FirstTipOutcome.dismissed].
///
/// The caller presents the outcome. Nothing is requested before „Ja".
Future<FirstTipOutcome> offerFirstTip(
  BuildContext context,
  WidgetRef ref,
) async {
  final answer = await showFirstTipOfferSheet(context);
  if (answer == null || !context.mounted) return FirstTipOutcome.dismissed;
  switch (answer) {
    case FirstTipAnswer.yes:
      return await ref.read(firstTipProvider.notifier).accept()
          ? FirstTipOutcome.started
          : FirstTipOutcome.optInFailed;
    case FirstTipAnswer.no:
      await ref
          .read(journeyRewardsProvider.notifier)
          .answerTipOffer(accepted: false);
      if (context.mounted &&
          await showJourneyRewardSheet(context, day: 3, afterNo: true) &&
          context.mounted) {
        await openJourneyReward(context, ref, 3);
      }
      return FirstTipOutcome.declined;
  }
}
