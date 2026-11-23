import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../utils/date_format_utils.dart';
import '../../../widgets/common/bb_card.dart';

/// Home's row while a tip set is new: „✨ Neue Tipps · Woche 47 · 3 Tipps".
/// A tap opens the Tipps.
class TipsRow extends StatelessWidget {
  const TipsRow({super.key, required this.set, required this.onTap});

  static const rowKey = Key('home_tips_row');

  final Recommendation set;
  final VoidCallback onTap;

  /// The row's text; the week and the count are left out when unknown.
  static String label(Recommendation set) {
    final createdAt = set.createdAt;
    final count = set.recommendations.length;
    return [
      '✨ Neue Tipps',
      if (createdAt != null) 'Woche ${isoWeekOf(createdAt.toLocal())}',
      if (count > 0) count == 1 ? '1 Tipp' : '$count Tipps',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: BbCard(
      key: rowKey,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label(set),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBodyLG,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
        ],
      ),
    ),
  );
}
