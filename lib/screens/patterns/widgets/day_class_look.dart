import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../models/insights.dart';

/// How a day class looks on the Muster page: its icon, the icon's colour
/// and a cell's fill.
typedef DayClassLook = ({IconData icon, Color color, Color fill});

/// The look of [c] in the calendar, its legend and the good and hard days'
/// columns; `null` for a day without a gut-feeling entry.
DayClassLook? dayClassLook(DayClass c) => switch (c) {
  DayClass.good => (
    icon: Icons.sentiment_satisfied_alt,
    color: AppTheme.gutFeelingGoodIcon,
    fill: AppTheme.gutFeelingGoodSoft,
  ),
  DayClass.medium => (
    icon: Icons.sentiment_neutral,
    color: AppTheme.gutFeelingNeutralIcon,
    fill: AppTheme.gutFeelingNeutralSoft,
  ),
  DayClass.hard => (
    icon: Icons.sentiment_dissatisfied,
    color: AppTheme.gutFeelingBadIcon,
    fill: AppTheme.gutFeelingBadSoft,
  ),
  DayClass.none => null,
};
