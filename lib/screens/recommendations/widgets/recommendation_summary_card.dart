import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../utils/date_format_utils.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/mascot_image.dart';

class RecommendationSummaryCard extends StatelessWidget {
  final Recommendation recommendation;

  const RecommendationSummaryCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return BbCard(
      color: AppTheme.primary.withValues(alpha: 0.1),
      showBorder: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotProfessor,
            width: 80,
            height: 80,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommendation.summary != null)
                  Text(
                    recommendation.summary!,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBodyLG,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                if (recommendation.createdAt != null) ...[
                  AppConstants.gap8,
                  Text(
                    'Erstellt ${formatTimeAgo(recommendation.createdAt!)}',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatAnalysisDateRange(recommendation.createdAt!),
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
