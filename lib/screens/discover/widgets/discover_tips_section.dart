import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/weekly_tips_switch.dart';
import 'discover_section.dart';
import 'discover_tips_card.dart';

/// The Tipps section's content: the newest tip set and, while the weekly
/// tips are off, the opt-in. [weeklyTips] is null while the profile is
/// unknown.
class DiscoverTipsSection extends StatelessWidget {
  const DiscoverTipsSection({
    super.key,
    required this.tips,
    required this.unseen,
    required this.weeklyTips,
    required this.onOpen,
  });

  /// What an empty section says while the weekly tips are on.
  static const emptyWhileOn =
      'Deine ersten Tipps kommen am Montag, wenn du diese Woche mindestens 5 '
      'Mahlzeiten einträgst.';

  /// The card with the opt-in switch.
  static const optInKey = Key('discover_weekly_tips');

  final AsyncValue<List<Recommendation>> tips;
  final bool unseen;
  final bool? weeklyTips;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final list = tips.value;
    final optIn = weeklyTips == false;
    const optInCard = BbCard(key: optInKey, child: WeeklyTipsSwitch());
    if (list == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiscoverNote.pending(tips, 'Tipps', key: DiscoverTipsCard.cardKey),
          if (optIn) ...[AppConstants.gap12, optInCard],
        ],
      );
    }
    if (list.isEmpty) {
      return switch (weeklyTips) {
        false => optInCard,
        true => const DiscoverNote(key: DiscoverTipsCard.cardKey, emptyWhileOn),
        null => const DiscoverNote(
          key: DiscoverTipsCard.cardKey,
          'Noch keine Tipps.',
        ),
      };
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiscoverTipsCard(tips: tips, unseen: unseen, onTap: onOpen),
        if (optIn) ...[AppConstants.gap12, optInCard],
      ],
    );
  }
}
