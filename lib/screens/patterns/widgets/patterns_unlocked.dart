import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../registration/widgets/step_field_label.dart';
import 'day_columns.dart';
import 'insight_calendar.dart';
import 'noticed_list.dart';
import 'stats_section.dart';

/// The Muster page once the first patterns unlock: the last 30 days as a
/// calendar, the good and the hard days with what was often there, and
/// „Fällt mir auf" ([Insights.showNoticed]), then the 90-day comparison
/// „Genauer hingeschaut" ([StatsSection]).
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
            style: AppTheme.bodyMutedStyle,
          ),
        ),
        AppConstants.gap12,
        InsightCalendar(days: insights.calendar),
        AppConstants.gap24,
        const StepFieldLabel(InsightCopy.columnsTitle),
        AppConstants.gap8,
        DayColumns(good: insights.goodDays, hard: insights.hardDays),
        if (insights.showNoticed) ...[
          AppConstants.gap24,
          const StepFieldLabel(InsightCopy.noticedTitle),
          AppConstants.gap8,
          NoticedList(noticed: insights.noticed),
        ],
        AppConstants.gap24,
        const StatsSection(),
      ],
    );
  }
}
