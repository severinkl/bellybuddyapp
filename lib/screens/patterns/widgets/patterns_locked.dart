import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_progress.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/insight_progress_row.dart';
import '../../registration/widgets/step_field_label.dart';

/// The Muster page until the first patterns unlock: the Buddy's line, both
/// progress bars, a hint on what helps most, and a blurred sample of what
/// comes.
class PatternsLocked extends StatelessWidget {
  const PatternsLocked({super.key, required this.progress});

  final InsightProgress progress;

  static const title = 'Ich sammle noch!';
  static const sectionLabel = 'Bis zu den ersten Mustern';
  static const gutHint =
      'Trag abends kurz dein Bauchgefühl ein, das hilft mir am meisten.';
  static const keepGoingHint =
      'Trag weiter ein – jeder Tag mit Einträgen zählt.';
  static const previewLabel = 'Das siehst du dann · Beispiel';
  static const previewSemantics = 'Vorschau mit Beispielwerten';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BbCard(
          color: AppTheme.primarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                title,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
              AppConstants.gap6,
              Text(
                InsightCopy.lockedLine(progress),
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  height: AppTheme.lineHeightBody,
                  color: AppTheme.foreground,
                ),
              ),
            ],
          ),
        ),
        AppConstants.gap20,
        const StepFieldLabel(sectionLabel),
        AppConstants.gap12,
        InsightProgressRow(
          label: InsightCopy.activeDaysLabel,
          count: progress.activeDays,
          goal: InsightProgress.daysNeeded,
        ),
        AppConstants.gap10,
        InsightProgressRow(
          label: InsightCopy.gutFeelingEntriesLabel,
          count: progress.gutFeelingEntries,
          goal: InsightProgress.gutFeelingsNeeded,
        ),
        AppConstants.gap12,
        Text(
          progress.gutFeelingsLeft > 0 ? gutHint : keepGoingHint,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            height: AppTheme.lineHeightBody,
            color: AppTheme.mutedForeground,
          ),
        ),
        AppConstants.gap24,
        const StepFieldLabel(previewLabel),
        AppConstants.gap8,
        Semantics(
          label: previewSemantics,
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
        ),
      ],
    );
  }
}
