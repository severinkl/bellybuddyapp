import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../models/progress.dart';
import '../../../services/progress/progress_copy.dart';
import '../../patterns/widgets/day_class_look.dart';

/// The top of „Dein Verlauf": the header, a tile per day class with its
/// total, the positive line when it holds, the current and longest streak
/// and how many days were logged.
class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    super.key,
    required this.progress,
    required this.currentStreak,
  });

  final Progress progress;

  /// The Buddy's streak, the same number as Home's.
  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: const Text(
            ProgressCopy.header,
            style: AppTheme.bodyMutedStyle,
          ),
        ),
        AppConstants.gap12,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppConstants.spacingSm,
            children: [
              for (final (c, n) in [
                (DayClass.good, p.good),
                (DayClass.medium, p.medium),
                (DayClass.hard, p.hard),
              ])
                Expanded(
                  child: _ClassTile(dayClass: c, count: n),
                ),
            ],
          ),
        ),
        if (p.moreGoodDaysLastWeek) ...[
          AppConstants.gap12,
          const Text(
            ProgressCopy.moreGoodDays,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              height: AppTheme.lineHeightSnug,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ],
        AppConstants.gap12,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppConstants.spacingSm,
            children: [
              Expanded(
                child: _StreakTile(
                  label: ProgressCopy.currentStreak,
                  days: currentStreak,
                ),
              ),
              Expanded(
                child: _StreakTile(
                  label: ProgressCopy.longestStreak,
                  // A run longer than the window shows as the current one.
                  days: math.max(p.longestStreak, currentStreak),
                  sub: ProgressCopy.longestSub,
                ),
              ),
            ],
          ),
        ),
        AppConstants.gap12,
        Text(
          ProgressCopy.loggedTotal(p.activeDays, p.elapsedDays),
          style: AppTheme.bodyMutedStyle,
        ),
      ],
    );
  }
}

/// A day class's icon on its fill, and „34 gute Tage".
class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.dayClass, required this.count});

  final DayClass dayClass;
  final int count;

  @override
  Widget build(BuildContext context) {
    final look = dayClassLook(dayClass)!;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        spacing: AppConstants.spacingXs,
        children: [
          ExcludeSemantics(
            child: Icon(
              look.icon,
              size: AppConstants.iconSizeMd,
              color: look.color,
            ),
          ),
          Text(
            ProgressCopy.classTotal(dayClass, count),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// „Aktueller Streak" / „Längster Streak" with its days.
class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.label, required this.days, this.sub});

  final String label;
  final int days;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final sub = this.sub;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppConstants.spacing2,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.mutedForeground,
            ),
          ),
          Text(
            ProgressCopy.streakDays(days),
            style: TextStyle(
              fontSize: days == 0
                  ? AppTheme.fontSizeBody
                  : AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: AppTheme.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
