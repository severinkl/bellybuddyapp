import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/weekly_tips_switch.dart';
import 'discover_tips_card.dart';

/// The Tipps section's content: the newest tip set and, while the weekly
/// tips are off, the opt-in. [weeklyTips] is null while the profile is
/// unknown. Entdecken shows it only once there are tips ([showsFor]).
class DiscoverTipsSection extends StatelessWidget {
  const DiscoverTipsSection({
    super.key,
    required this.sets,
    required this.weeklyTips,
    required this.onOpen,
  });

  /// Whether Entdecken shows the section: the loaded value (also one kept
  /// while refreshing) has a set with tips.
  static bool showsFor(AsyncValue<List<Recommendation>> tips) =>
      tips.value?.any((set) => set.recommendations.isNotEmpty) ?? false;

  /// The card with the opt-in switch.
  static const optInKey = Key('discover_weekly_tips');

  /// The tip sets, newest first.
  final List<Recommendation> sets;
  final bool? weeklyTips;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiscoverTipsCard(sets: sets, onTap: onOpen),
        if (weeklyTips == false) ...const [
          AppConstants.gap12,
          BbCard(key: optInKey, child: WeeklyTipsSwitch()),
        ],
      ],
    );
  }
}
