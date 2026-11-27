import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../services/progress/progress_copy.dart';
import '../../../utils/date_format_utils.dart';
import 'day_class_look.dart';

/// The insights window as a calendar, Monday first: each day with its
/// number and its class's icon (gut, mittel, schwer; an empty outlined
/// cell without a gut-feeling entry), never by colour alone. Then the
/// legend.
class InsightCalendar extends StatelessWidget {
  const InsightCalendar({super.key, required this.days});

  /// The window's days, oldest first ([Insights.calendar]).
  final List<InsightDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    // Blanks before the first day and after the last fill whole weeks.
    final cells = <InsightDay?>[
      for (var i = 1; i < days.first.day.weekday; i++) null,
      ...days,
    ];
    while (cells.length % DateTime.daysPerWeek != 0) {
      cells.add(null);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppConstants.spacingXs,
      children: [
        // Every day's label names its date; the weekdays would only repeat.
        ExcludeSemantics(
          child: _week([
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
        for (var i = 0; i < cells.length; i += DateTime.daysPerWeek)
          _week([
            for (final day in cells.sublist(i, i + DateTime.daysPerWeek))
              day == null ? const SizedBox.shrink() : _DayCell(day),
          ]),
        AppConstants.gap8,
        const DayClassLegend(),
      ],
    );
  }

  static Widget _week(List<Widget> days) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppConstants.spacingXs,
    children: [for (final day in days) Expanded(child: day)],
  );
}

/// A day: its number over its class's icon, read as „18. Nov: schwer".
class _DayCell extends StatelessWidget {
  const _DayCell(this.day);

  final InsightDay day;

  @override
  Widget build(BuildContext context) {
    final look = dayClassLook(day.dayClass);
    return Semantics(
      container: true,
      label: InsightCopy.daySemantics(day),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
        decoration: BoxDecoration(
          color: look?.fill,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: look == null ? dayNoneBorder : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${day.day.day}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppConstants.spacing2),
            // A day without an entry keeps the icon's room, so every week
            // row is as tall.
            if (look == null)
              const SizedBox.square(dimension: AppConstants.iconSizeXs)
            else
              Icon(look.icon, size: AppConstants.iconSizeXs, color: look.color),
          ],
        ),
      ),
    );
  }
}

/// One extra [DayClassLegend] entry: its mark and label.
typedef DayClassLegendItem = ({Widget mark, String label});

/// „gut · mittel · schwer · kein Eintrag", each with its cell's mark;
/// [withNoGutFeeling] adds „ohne Bauchgefühl" with its dot before „kein
/// Eintrag" („Dein Verlauf"). [noneMark] replaces the „kein Eintrag" mark
/// and [extra] follows it (the test page's own marks).
class DayClassLegend extends StatelessWidget {
  const DayClassLegend({
    super.key,
    this.withNoGutFeeling = false,
    this.noneMark,
    this.extra = const [],
  });

  final bool withNoGutFeeling;
  final Widget? noneMark;
  final List<DayClassLegendItem> extra;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppConstants.spacing14,
      runSpacing: AppConstants.spacing6,
      children: [
        for (final c in DayClass.values) ...[
          if (c == DayClass.none && withNoGutFeeling)
            _item(
              const SizedBox.square(
                dimension: AppConstants.iconSizeXs,
                child: Center(child: NoGutFeelingDot()),
              ),
              ProgressCopy.noGutFeelingLegend,
            ),
          _item(switch (dayClassLook(c)) {
            final look? => Icon(
              look.icon,
              size: AppConstants.iconSizeXs,
              color: look.color,
            ),
            null =>
              noneMark ??
                  Container(
                    width: AppConstants.iconSizeXs,
                    height: AppConstants.iconSizeXs,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusXs,
                      ),
                      border: dayNoneBorder,
                    ),
                  ),
          }, InsightCopy.dayClassLabel(c)),
        ],
        for (final e in extra) _item(e.mark, e.label),
      ],
    );
  }

  static Widget _item(Widget mark, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AppConstants.spacing6,
    children: [
      mark,
      Flexible(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeCaptionLG,
            color: AppTheme.mutedForeground,
          ),
        ),
      ),
    ],
  );
}
