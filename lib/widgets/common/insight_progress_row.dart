import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'bb_progress_bar.dart';

/// „[label] … n von [goal]" over its bar; read as one label.
class InsightProgressRow extends StatelessWidget {
  const InsightProgressRow({
    super.key,
    required this.label,
    required this.count,
    required this.goal,
  });

  final String label;
  final int count;
  final int goal;

  @override
  Widget build(BuildContext context) {
    // A full bar says „7 von 7", not „9 von 7".
    final shown = count.clamp(0, goal);
    final value = '$shown von $goal';
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacing10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeCaptionLG,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          AppConstants.gap4,
          BbProgressBar(
            value: shown / goal,
            height: AppConstants.insightProgressHeight,
          ),
        ],
      ),
    );
  }
}
