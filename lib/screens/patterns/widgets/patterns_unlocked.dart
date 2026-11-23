import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insight_rules.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../registration/widgets/step_field_label.dart';
import 'day_columns.dart';
import 'insight_calendar.dart';
import 'noticed_list.dart';

/// The Muster page once the first patterns unlock: the last 30 days as a
/// calendar, the good and the hard days with what was often there, and
/// „Fällt mir auf" (from [InsightRules.minHardDays] hard days on).
class PatternsUnlocked extends StatelessWidget {
  const PatternsUnlocked({super.key, required this.insights});

  final Insights insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            InsightCopy.calendarHeader(insights.gutFeelingDays),
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              height: AppTheme.lineHeightSnug,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
        AppConstants.gap12,
        InsightCalendar(days: insights.calendar),
        AppConstants.gap24,
        const StepFieldLabel(InsightCopy.columnsTitle),
        AppConstants.gap8,
        DayColumns(good: insights.goodDays, hard: insights.hardDays),
        if (insights.hardDays.days >= InsightRules.minHardDays) ...[
          AppConstants.gap24,
          const StepFieldLabel(InsightCopy.noticedTitle),
          AppConstants.gap8,
          NoticedList(noticed: insights.noticed),
        ],
      ],
    );
  }
}
