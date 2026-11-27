import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/progress.dart';
import '../../../services/progress/progress_copy.dart';
import '../../../utils/date_format_utils.dart';
import '../../patterns/widgets/day_class_look.dart';
import '../../patterns/widgets/insight_calendar.dart';

/// „Dein Verlauf"'s weeks, newest first: per week its label, its seven
/// days (a class's fill and icon; an active day without gut feeling an
/// outline with a dot; a day without entries an empty outline; a future
/// day nothing) and its counts with how many days were logged. Then the
/// legend.
class ProgressWeeks extends StatelessWidget {
  const ProgressWeeks({super.key, required this.weeks, required this.today});

  /// Oldest first ([Progress.weeks]).
  final List<ProgressWeek> weeks;

  /// For the current week's label.
  final DateTime today;

  /// A week's row, by its Monday.
  static Key weekKey(DateTime monday) =>
      ValueKey('progress_week_${monday.year}-${monday.month}-${monday.day}');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppConstants.spacingMd,
      children: [
        // Every day's label names its date; the weekdays would only repeat.
        ExcludeSemantics(
          child: _days([
            for (final name in kWeekdayShortNames)
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeSM,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedForeground,
                ),
              ),
          ]),
        ),
        for (final week in weeks.reversed) _WeekRow(week: week, today: today),
        const DayClassLegend(withNoGutFeeling: true),
      ],
    );
  }
}

Widget _days(List<Widget> days) => Row(
  spacing: AppConstants.spacingXs,
  children: [for (final day in days) Expanded(child: day)],
);

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week, required this.today});

  final ProgressWeek week;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ProgressWeeks.weekKey(week.monday),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppConstants.spacingXs,
      children: [
        Text(
          ProgressCopy.weekLabel(week.monday, today),
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        _days([for (final day in week.days) _DayCell(day)]),
        Text(
          '${ProgressCopy.weekCounts(week)}${ProgressCopy.weekLogged(week)}',
          style: const TextStyle(
            fontSize: AppTheme.fontSizeCaption,
            height: AppTheme.lineHeightSnug,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// A day, read as „18. Nov: gut"; a future day is blank and silent.
class _DayCell extends StatelessWidget {
  const _DayCell(this.day);

  final ProgressDay day;

  @override
  Widget build(BuildContext context) {
    if (day.future) {
      return const SizedBox(height: AppConstants.progressDayCellHeight);
    }
    final look = dayClassLook(day.dayClass);
    return Semantics(
      container: true,
      label: ProgressCopy.daySemantics(day),
      excludeSemantics: true,
      child: Container(
        height: AppConstants.progressDayCellHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: look?.fill,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: look == null ? dayNoneBorder : null,
        ),
        child: switch (look) {
          final look? => Icon(
            look.icon,
            size: AppConstants.iconSizeXs,
            color: look.color,
          ),
          null when day.active => const NoGutFeelingDot(),
          null => null,
        },
      ),
    );
  }
}
