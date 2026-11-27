import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
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

/// The outline of a day without a gut-feeling entry.
final dayNoneBorder = Border.all(
  color: AppTheme.border,
  width: AppConstants.borderWidthMd,
);

/// The mark of a day with entries but without a gut feeling („Dein
/// Verlauf"): a small muted dot.
class NoGutFeelingDot extends StatelessWidget {
  const NoGutFeelingDot({super.key});

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.circle,
    size: AppConstants.progressDayDotSize,
    color: AppTheme.mutedForeground,
  );
}
