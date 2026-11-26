import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'streak_pop.dart';

/// Compact streak indicator on Ich: the count, "5 Tage" (the streak only;
/// savers are not shown here). Home shows a [StreakBadge] at its flame.
///
/// Muted while today is not yet counted; pops when [streak] increases.
/// With [onTap] it is a button that sets the streak goal. Its tap area is
/// at least [AppConstants.homeTapTarget] tall, the pill centred in it.
class StreakChip extends StatelessWidget {
  const StreakChip({
    super.key,
    required this.streak,
    required this.todayCounted,
    this.onTap,
  });

  final int streak;
  final bool todayCounted;

  /// Opens the streak goal picker.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = !todayCounted && streak > 0;
    final days = '$streak ${streak == 1 ? 'Tag' : 'Tage'}';
    final semantics = [
      'Streak: $days',
      if (muted) 'Heute noch offen',
    ].join(', ');
    final color = muted ? AppTheme.mutedForeground : AppTheme.foreground;

    final onTap = this.onTap;
    Widget chip = Semantics(
      label: semantics,
      button: onTap != null,
      hint: onTap == null ? null : 'Streak-Ziel festlegen',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppConstants.homeTapTarget,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: StreakPop(
              streak: streak,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacing12,
                  vertical: AppConstants.spacing6,
                ),
                decoration: BoxDecoration(
                  color: muted ? AppTheme.muted : AppTheme.secondary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  days,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (muted) {
      chip = Tooltip(message: 'Heute noch offen', child: chip);
    }
    return chip;
  }
}
