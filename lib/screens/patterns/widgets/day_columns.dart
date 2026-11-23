import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../widgets/common/bb_card.dart';

/// „Deine guten und schweren Tage": a card for each, stacked, with what was
/// often there before them.
class DayColumns extends StatelessWidget {
  const DayColumns({super.key, required this.good, required this.hard});

  final DayColumn good;
  final DayColumn hard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppConstants.spacing10,
      children: [_ColumnCard(good, hard: false), _ColumnCard(hard, hard: true)],
    );
  }
}

/// „6 gute Tage", then „oft dabei:" and its items, or why there are none.
class _ColumnCard extends StatelessWidget {
  const _ColumnCard(this.column, {required this.hard});

  final DayColumn column;
  final bool hard;

  static const _textStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.foreground,
  );

  static const _mutedStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    height: AppTheme.lineHeightSnug,
    color: AppTheme.mutedForeground,
  );

  @override
  Widget build(BuildContext context) {
    return BbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppConstants.spacingSm,
            children: [
              // The title says which column it is.
              ExcludeSemantics(
                child: Icon(
                  hard
                      ? Icons.sentiment_dissatisfied
                      : Icons.sentiment_satisfied_alt,
                  size: AppConstants.iconSizeSm,
                  color: hard
                      ? AppTheme.gutFeelingBadIcon
                      : AppTheme.gutFeelingGoodIcon,
                ),
              ),
              Expanded(
                child: Text(
                  InsightCopy.columnTitle(column, hard: hard),
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
            ],
          ),
          AppConstants.gap8,
          if (!column.shown)
            Text(InsightCopy.tooFewDays(hard: hard), style: _mutedStyle)
          else if (column.often.isEmpty)
            const Text(InsightCopy.nothingOften, style: _mutedStyle)
          else ...[
            const Text(InsightCopy.oftenLabel, style: _mutedStyle),
            for (final item in column.often)
              Padding(
                padding: const EdgeInsets.only(top: AppConstants.spacingXs),
                child: Text(
                  InsightCopy.oftenRow(item, hard: hard),
                  style: _textStyle,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
