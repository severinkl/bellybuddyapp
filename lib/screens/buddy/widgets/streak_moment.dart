import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/buddy/streak_week_row.dart';
import '../../../widgets/common/bb_card.dart';

/// What counts as a streak day, in one sentence.
const String kStreakRuleText =
    'Jeder Tag mit mindestens einem Eintrag zählt: Mahlzeit, Getränk, '
    'Bauchgefühl oder Klo.';

/// The streak moment below the Buddy: the big count („🔥 1 Tag", left out
/// while [streak] is 0), this week's row and the rule of what counts.
class StreakMoment extends StatelessWidget {
  const StreakMoment({
    super.key,
    required this.streak,
    required this.weekDays,
    required this.today,
  });

  final int streak;
  final Set<DateTime> weekDays;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final unit = streak == 1 ? 'Tag' : 'Tage';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (streak > 0) ...[
          Semantics(
            label: 'Streak: $streak $unit',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: AppTheme.fontSizeStreakFlame),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeStreakCount,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeTitleLG,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppConstants.gap20,
        ],
        StreakWeekRow(activeDays: weekDays, today: today),
        AppConstants.gap20,
        const Text(
          kStreakRuleText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontSizeSubtitle,
            height: AppTheme.lineHeightBody,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Why a goal helps — above the goal list on the goal step.
class StreakGoalWhyCard extends StatelessWidget {
  const StreakGoalWhyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const BbCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacing14,
      ),
      color: AppTheme.beige,
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Warum ein Ziel?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap4,
          Text(
            'Je regelmäßiger du einträgst, desto besser erkennen wir '
            'Zusammenhänge zwischen Essen und Bauch. Ein Ziel hilft beim '
            'Dranbleiben.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              height: AppTheme.lineHeightBody,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
