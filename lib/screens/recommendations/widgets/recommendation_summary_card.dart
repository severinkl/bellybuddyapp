import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../utils/date_format_utils.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/mascot_image.dart';
import '../../registration/widgets/step_field_label.dart';

/// The set's summary: a weekly letter under „Dein Wochenbrief" (core #12),
/// an older set's summary in bold.
class RecommendationSummaryCard extends StatelessWidget {
  final Recommendation recommendation;

  const RecommendationSummaryCard({super.key, required this.recommendation});

  static const _letterLabel = 'Dein Wochenbrief';

  static const _letterStyle = TextStyle(
    fontSize: AppTheme.fontSizeBodyLG,
    fontWeight: FontWeight.w400,
    height: AppTheme.lineHeightBody,
    color: AppTheme.foreground,
  );

  static const _summaryStyle = TextStyle(
    fontSize: AppTheme.fontSizeBodyLG,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );

  @override
  Widget build(BuildContext context) {
    final letter = recommendation.isLetter;
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
                if (recommendation.summary case final summary?) ...[
                  if (letter) ...[
                    Text(
                      StepFieldLabel.capitals(_letterLabel),
                      semanticsLabel: _letterLabel,
                      style: StepFieldLabel.style,
                    ),
                    AppConstants.gap4,
                  ],
                  Text(summary, style: letter ? _letterStyle : _summaryStyle),
                ],
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
