import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../widgets/common/bb_card.dart';
import 'discover_section.dart';

/// The newest tip set: „Neu" while it is unseen, its ISO week, how many
/// tips, two lines of its summary. No tips: a line, not tappable.
class DiscoverTipsCard extends StatelessWidget {
  const DiscoverTipsCard({super.key, required this.tips, required this.onTap});

  /// The card (or the line in its place).
  static const cardKey = Key('discover_tips');

  final AsyncValue<List<Recommendation>> tips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final list = tips.value;
    if (list == null) return DiscoverNote.pending(tips, 'Tipps', key: cardKey);
    if (list.isEmpty) {
      return const DiscoverNote(key: cardKey, 'Noch keine Tipps.');
    }
    // The list is newest first.
    final newest = list.first;
    final summary = newest.summary?.trim() ?? '';
    return BbCard(
      key: cardKey,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (newest.seenAt == null) ...[
                const DiscoverPill('Neu'),
                const SizedBox(width: AppConstants.spacingSm),
              ],
              Expanded(
                child: Text(
                  newest.weekLabel ?? 'Deine Tipps',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              Text(
                newest.tipCountLabel,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeCaptionLG,
                  color: AppTheme.mutedForeground,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
            ],
          ),
          if (summary.isNotEmpty) ...[
            AppConstants.gap6,
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
                height: AppTheme.lineHeightBody,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
