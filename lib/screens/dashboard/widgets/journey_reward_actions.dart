import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/journey_rewards.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../router/navigation_extensions.dart';
import '../../../router/route_names.dart';
import '../../../services/journey/journey_copy.dart';
import '../../../services/journey/journey_rules.dart';
import '../../../utils/url_utils.dart';

/// Opens what [day]'s reward gives, from [context]:
/// - 1, 3 and 5: the picked recipe ([rewardPick]), else the recipes;
/// - 2: the article, in the in-app browser through [openUrl] (a SnackBar
///   says when that fails); completes once it opened or failed;
/// - 3 once the first tip was accepted: the Tipps;
/// - 4: nothing (the saying is the reward);
/// - 6 and 7: Muster.
///
/// Navigations are not awaited.
Future<void> openJourneyReward(
  BuildContext context,
  WidgetRef ref,
  int day, {
  UrlOpener openUrl = launchUrl,
}) async {
  final rewards = ref.read(journeyRewardsProvider) ?? const JourneyRewards();
  switch (day) {
    case 2:
      await openExternalUrl(
        context,
        JourneyCopy.articleUrl,
        mode: LaunchMode.inAppBrowserView,
        failureMessage: JourneyCopy.articleFailure,
        open: openUrl,
      );
    case 3 when rewards.tipOffer == TipOffer.accepted:
      unawaited(context.push(RoutePaths.recommendations));
    case 1 || 3 || 5:
      if (rewardPick(day, rewards) case final pick?) {
        unawaited(context.openRecipe(pick.id));
      } else {
        context.go(RoutePaths.discoverRecipes);
      }
    case 6 || 7:
      unawaited(context.push(RoutePaths.patterns));
  }
}
