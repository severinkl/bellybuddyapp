import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_card.dart';

/// Opens the myfodmap blog in the browser.
class DiscoverKnowledgeCard extends StatelessWidget {
  const DiscoverKnowledgeCard({super.key, required this.onTap});

  /// The card.
  static const cardKey = Key('discover_knowledge');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: BbCard(
        key: cardKey,
        onTap: onTap,
        child: const Row(
          children: [
            Icon(Icons.menu_book_outlined, color: AppTheme.foreground),
            SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wissen rund um die Verdauung',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBodyLG,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  AppConstants.gap4,
                  Text(
                    'Artikel aus dem myfodmap-Blog',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppConstants.spacingSm),
            Icon(Icons.open_in_new, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
