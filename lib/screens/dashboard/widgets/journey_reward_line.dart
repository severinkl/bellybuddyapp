import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/home_cover_provider.dart';
import '../../../providers/journey_rewards_provider.dart';
import '../../../services/journey/journey_copy.dart';
import 'journey_rewards_sheet.dart';

/// The journey card's reward line ([journeyRewardLineProvider]): today's
/// reward („Heute: …") or the next („Heute wartet: …", „Bald: …"). Its own
/// button: a tap opens „Deine Belohnungen" ([showJourneyRewardsSheet]),
/// once (a tap while Home is covered, e.g. by the list itself, does
/// nothing). Nothing while the line is null.
class JourneyRewardLineView extends ConsumerWidget {
  const JourneyRewardLineView({super.key});

  static const lineKey = Key('journey_reward_line');

  static const _style = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    fontWeight: FontWeight.w600,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.foreground,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = ref.watch(journeyRewardLineProvider);
    if (line == null) return const SizedBox.shrink();
    void open() {
      if (ref.read(homeCoveredProvider)) return;
      unawaited(showJourneyRewardsSheet(context, ref));
    }

    return Semantics(
      key: lineKey,
      container: true,
      button: true,
      label: line,
      hint: JourneyCopy.openRewards,
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
          child: Row(
            children: [
              const Icon(
                Icons.card_giftcard_outlined,
                size: AppConstants.iconSizeXs,
                color: AppTheme.primary,
              ),
              const SizedBox(width: AppConstants.spacing6),
              Expanded(child: Text(line, style: _style)),
              const SizedBox(width: AppConstants.spacingXs),
              const Icon(
                Icons.chevron_right,
                size: AppConstants.iconSizeXs,
                color: AppTheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
