import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/relief/relief_content.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/mascot_image.dart';
import 'discover_section.dart';

/// „Ruhe für den Bauch" on top of Entdecken: the zen Buddy, the title, the
/// subtitle and a chevron; the whole card opens the exercises.
///
/// [DiscoverReliefCard.teaser], while the feature is off: the same card with
/// a short line and „Kommt bald" instead of the chevron. It opens nothing
/// and reads as one item, not a button.
class DiscoverReliefCard extends StatelessWidget {
  const DiscoverReliefCard({super.key, required VoidCallback this.onOpen});

  const DiscoverReliefCard.teaser({super.key}) : onOpen = null;

  static const cardKey = ValueKey('discover-relief');
  static const teaserKey = ValueKey('discover-relief-teaser');

  /// Null for the teaser.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final teaser = onOpen == null;
    final card = BbCard(
      key: teaser ? teaserKey : cardKey,
      onTap: onOpen,
      constraints: const BoxConstraints(minHeight: AppConstants.minTapTarget),
      child: Row(
        children: [
          // Decorative; in the teaser it would make the one item an image.
          ExcludeSemantics(
            excluding: teaser,
            child: const MascotImage(
              assetPath: AppConstants.mascotZen,
              width: AppConstants.discoverReliefBuddySize,
              height: AppConstants.discoverReliefBuddySize,
            ),
          ),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  ReliefCopy.title,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap4,
                Text(
                  teaser ? ReliefCopy.teaserLine : ReliefCopy.cardSubtitle,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                    height: AppTheme.lineHeightBody,
                  ),
                ),
              ],
            ),
          ),
          if (teaser) ...[
            const SizedBox(width: AppConstants.spacingSm),
            const DiscoverPill(ReliefCopy.comingSoon),
          ] else
            const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
        ],
      ),
    );
    return teaser ? MergeSemantics(child: card) : card;
  }
}
