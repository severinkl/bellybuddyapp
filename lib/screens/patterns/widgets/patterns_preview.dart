import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../widgets/common/bb_card.dart';

/// A blurred sample of what the Muster page shows once unlocked: clearly
/// fictional values, read to a screen reader only as a preview with
/// sample values. Whoever shows it labels it as an example.
class PatternsPreview extends StatelessWidget {
  const PatternsPreview({super.key});

  /// Clearly fictional: placeholders, not the user's data.
  static const _sample = Noticed(
    name: 'Beispiel-Zutat',
    hard: 3,
    hardDays: 4,
    good: 1,
    goodDays: 5,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: InsightCopy.previewSemantics,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: AppConstants.patternsPreviewBlur,
              sigmaY: AppConstants.patternsPreviewBlur,
            ),
            child: BbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    InsightCopy.noticedTitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeSubtitle,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  AppConstants.gap8,
                  Text(
                    InsightCopy.noticedRow(_sample),
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
