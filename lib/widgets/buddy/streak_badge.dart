import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'streak_flame.dart';
import 'streak_pop.dart';

/// Home's streak count at its flame: a small pill with the drawn flame and
/// the count („🔥 12"), a button that opens „Dein Streak" ([onTap]). It
/// shows at 0 too, the way into „Dein Streak".
///
/// While today is not yet counted its flame is an ember and the count
/// muted (and it says so); pops when [streak] increases. Its
/// tap area is at least [AppConstants.homeTapTarget] square, the pill
/// centred in it; the count grows with the user's text size.
class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.streak,
    required this.lit,
    required this.onTap,
  });

  final int streak;

  /// Whether today counts already.
  final bool lit;

  /// Opens „Dein Streak".
  final VoidCallback onTap;

  /// To a screen reader: „Streak: 12 Tage, Dein Streak öffnen", with
  /// „heute noch offen" while [muted].
  String _semantics({required bool muted}) => [
    'Streak: $streak ${streak == 1 ? 'Tag' : 'Tage'}',
    if (muted) 'heute noch offen',
    'Dein Streak öffnen',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    // Nothing to keep at 0: never muted.
    final muted = !lit && streak > 0;
    return Semantics(
      label: _semantics(muted: muted),
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppConstants.homeTapTarget,
            minHeight: AppConstants.homeTapTarget,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: StreakPop(
              streak: streak,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingSm,
                    vertical: AppConstants.spacingXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreakFlame.mark(
                        height: AppConstants.iconSizeXs,
                        lit: lit,
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      Text(
                        '$streak',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeCaptionLG,
                          fontWeight: FontWeight.w700,
                          color: muted
                              ? AppTheme.mutedForeground
                              : AppTheme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
