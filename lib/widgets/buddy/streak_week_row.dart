import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../utils/date_format_utils.dart';
import 'streak_flame.dart';

/// The current local week, Monday to Sunday: one circle per day with a
/// flame ([StreakFlame.mark]) on each day in [activeDays] (any time of day
/// counts), today's label in bold and ringed. Future days stay empty.
class StreakWeekRow extends StatelessWidget {
  const StreakWeekRow({
    super.key,
    required this.activeDays,
    required this.today,
  });

  /// Today's circle.
  static const todayKey = Key('streak_week_row_today');

  /// Days with at least one entry (or a saved day).
  final Set<DateTime> activeDays;

  /// Now; picks the week.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final day0 = startOfDay(today);
    final monday = mondayOf(today);
    final active = activeDays.map(startOfDay).toSet();
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    final activeNames = [
      for (var i = 0; i < 7; i++)
        if (active.contains(days[i])) kWeekdayNames[i],
    ];
    return Semantics(
      label: activeNames.isEmpty
          ? 'Diese Woche noch kein Eintrag'
          : 'Diese Woche eingetragen: ${activeNames.join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _Day(
                  key: days[i] == day0 ? todayKey : null,
                  label: kWeekdayShortNames[i],
                  active: active.contains(days[i]),
                  isToday: days[i] == day0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    super.key,
    required this.label,
    required this.active,
    required this.isToday,
  });

  final String label;
  final bool active;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const circle = AppConstants.streakWeekDaySize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circle,
          height: circle,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppTheme.primarySoft : AppTheme.background,
            border: Border.all(
              color: active || isToday ? AppTheme.primary : AppTheme.border,
              width: AppConstants.borderWidthLg,
            ),
          ),
          child: active
              ? const StreakFlame.mark(
                  height: AppConstants.streakFlameMarkHeight,
                )
              : null,
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSizeCaptionLG,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? AppTheme.foreground : AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
