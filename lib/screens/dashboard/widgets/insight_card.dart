import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_progress.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/bb_progress_bar.dart';
import '../../registration/widgets/step_field_label.dart';

/// Home's card on what the Buddy learns about the user's gut. Locked, it
/// says how much is left until the first patterns and shows both progress
/// bars (days with entries, gut-feeling entries); unlocked, for now, that
/// they come soon. Hidden while the first [progress] loads or failed.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.progress});

  static const cardKey = Key('insight_card');

  static const _title = 'Was ich über deinen Bauch lerne';
  static const _soon = 'dann zeig ich dir erste Muster.';

  final AsyncValue<InsightProgress> progress;

  /// The Buddy's line: what is still missing, days first.
  static String _line(InsightProgress p) {
    if (p.daysLeft > 0) {
      final days = p.daysLeft == 1 ? 'Tag' : 'Tage';
      return 'Noch ${p.daysLeft} $days, $_soon';
    }
    if (p.gutFeelingsLeft > 0) {
      final entries = p.gutFeelingsLeft == 1
          ? 'Bauchgefühl-Eintrag'
          : 'Bauchgefühl-Einträge';
      return 'Noch ${p.gutFeelingsLeft} $entries, $_soon';
    }
    return 'Genug Einträge! Deine ersten Muster kommen bald.';
  }

  @override
  Widget build(BuildContext context) {
    final p = progress.value;
    if (p == null) return const SizedBox.shrink();
    final locked = !p.unlocked;
    return BbCard(
      key: cardKey,
      color: AppTheme.beige,
      showBorder: false,
      radius: AppConstants.radiusRound,
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacing14,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (locked) ...[
                const Icon(
                  Icons.lock_outline,
                  size: AppConstants.iconSizeXs,
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(width: AppConstants.spacing6),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    _title.toUpperCase(),
                    semanticsLabel: _title,
                    style: StepFieldLabel.style,
                  ),
                ),
              ),
            ],
          ),
          AppConstants.gap8,
          Text(
            _line(p),
            style: const TextStyle(
              fontSize: AppTheme.fontSizeSubtitleLG,
              fontWeight: FontWeight.w700,
              height: AppTheme.lineHeightSnug,
              color: AppTheme.foreground,
            ),
          ),
          if (locked) ...[
            AppConstants.gap12,
            _ProgressRow(
              label: 'Tage mit Einträgen',
              count: p.activeDays,
              goal: InsightProgress.daysNeeded,
            ),
            AppConstants.gap10,
            _ProgressRow(
              label: 'Bauchgefühl-Einträge',
              count: p.gutFeelingEntries,
              goal: InsightProgress.gutFeelingsNeeded,
            ),
          ],
        ],
      ),
    );
  }
}

/// „[label] … n von [goal]" over its bar; read as one label.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
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
