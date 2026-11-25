import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/weekly_tips_switch.dart';
import 'discover_tips_card.dart';

/// The Tipps section's content: the newest tip set with tips ([set]) and,
/// while the weekly tips are off, the opt-in. [weeklyTips] is null while
/// the profile is unknown. Entdecken shows it only once there are tips
/// (`newestTipSetProvider`).
class DiscoverTipsSection extends StatelessWidget {
  const DiscoverTipsSection({
    super.key,
    required this.set,
    required this.weeklyTips,
    required this.onOpen,
  });

  /// The card with the opt-in switch.
  static const optInKey = Key('discover_weekly_tips');

  final Recommendation set;
  final bool? weeklyTips;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiscoverTipsCard(set: set, onTap: onOpen),
        if (weeklyTips == false) ...const [
          AppConstants.gap12,
          BbCard(key: optInKey, child: WeeklyTipsSwitch()),
        ],
      ],
    );
  }
}
