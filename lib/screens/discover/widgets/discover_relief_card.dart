import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/relief/relief_content.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/mascot_image.dart';

/// „Ruhe für den Bauch" on top of Entdecken: the zen Buddy, the title, the
/// subtitle and a chevron; the whole card opens the exercises.
class DiscoverReliefCard extends StatelessWidget {
  const DiscoverReliefCard({super.key, required this.onOpen});

  static const cardKey = ValueKey('discover-relief');

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      key: cardKey,
      onTap: onOpen,
      constraints: const BoxConstraints(minHeight: AppConstants.minTapTarget),
      child: const Row(
        children: [
          MascotImage(
            assetPath: AppConstants.mascotZen,
            width: AppConstants.discoverReliefBuddySize,
            height: AppConstants.discoverReliefBuddySize,
          ),
          SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ReliefCopy.title,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap4,
                Text(
                  ReliefCopy.cardSubtitle,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                    height: AppTheme.lineHeightBody,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
        ],
      ),
    );
  }
}
