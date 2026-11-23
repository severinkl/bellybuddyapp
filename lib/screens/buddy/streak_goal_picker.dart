import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/common/bb_drag_handle.dart';

const List<int> kStreakGoalOptions = [7, 14, 30, 50, 100];

const Map<int, String> kStreakGoalLabels = {
  7: 'Guter Start',
  14: 'Stark',
  30: 'Legendär',
  50: 'Unaufhaltsam',
  100: 'Bauch-Legende',
};

/// One line per goal under its day count.
const Map<int, String> kStreakGoalHints = {
  7: 'Eine Woche zum Reinkommen',
  14: 'Zwei Wochen am Stück',
  30: 'Ein ganzer Monat',
  50: 'Für echte Durchhalter',
  100: 'Das ganz große Ziel',
};

/// The goal the Buddy recommends among [choices].
const int kStreakGoalTip = 14;

/// Every goal option above [currentStreak] (none once all are passed).
List<int> streakGoalChoices(int currentStreak) =>
    kStreakGoalOptions.where((g) => g > currentStreak).toList();

/// The Buddy's tip among [choices]: [kStreakGoalTip] while it is open,
/// else the nearest goal; null without choices.
int? recommendedStreakGoal(List<int> choices) {
  if (choices.isEmpty) return null;
  return choices.firstWhere(
    (g) => g >= kStreakGoalTip,
    orElse: () => choices.last,
  );
}

/// The goals above [currentStreak], each with its one-liner and label; the
/// Buddy's tip ([recommendedStreakGoal]) is ringed and badged.
class StreakGoalPicker extends StatelessWidget {
  const StreakGoalPicker({
    super.key,
    required this.currentStreak,
    required this.onSelected,
  });

  /// A goal's row: `streak_goal_<days>`.
  static Key goalKey(int goal) => ValueKey('streak_goal_$goal');

  final int currentStreak;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final choices = streakGoalChoices(currentStreak);
    final tip = recommendedStreakGoal(choices);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in choices) ...[
          _GoalRow(
            key: goalKey(goal),
            goal: goal,
            tip: goal == tip,
            onTap: () => onSelected(goal),
          ),
          if (goal != choices.last) AppConstants.gap8,
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    super.key,
    required this.goal,
    required this.tip,
    required this.onTap,
  });

  final int goal;
  final bool tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.radiusPill);
    return Semantics(
      button: true,
      child: Material(
        color: tip ? AppTheme.background : AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: tip ? AppTheme.primary : AppTheme.border,
            width: tip
                ? AppConstants.borderWidthLg
                : AppConstants.borderWidthMd,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppConstants.streakGoalRowHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$goal Tage',
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeSubtitle,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                          ),
                        ),
                        Text(
                          kStreakGoalHints[goal] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeCaption,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  if (tip) ...[
                    const _TipBadge(),
                    const SizedBox(width: AppConstants.spacing6),
                  ],
                  Text(
                    kStreakGoalLabels[goal] ?? '',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipBadge extends StatelessWidget {
  const _TipBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingSm,
      vertical: AppConstants.spacing2,
    ),
    decoration: BoxDecoration(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(AppConstants.radiusFull),
    ),
    child: const Text(
      'Mein Tipp',
      style: TextStyle(
        fontSize: AppTheme.fontSizeSM,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryForeground,
      ),
    ),
  );
}

/// Modal sheet with the Buddy (his bubble asks [title]) and the goal picker.
/// Returns the chosen goal, or null when dismissed.
Future<int?> showStreakGoalSheet(
  BuildContext context, {
  required int currentStreak,
  required String title,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) =>
        _StreakGoalSheet(currentStreak: currentStreak, title: title),
  );
}

class _StreakGoalSheet extends StatefulWidget {
  const _StreakGoalSheet({required this.currentStreak, required this.title});

  final int currentStreak;
  final String title;

  @override
  State<_StreakGoalSheet> createState() => _StreakGoalSheetState();
}

class _StreakGoalSheetState extends State<_StreakGoalSheet> {
  final BuddyController _buddy = BuddyController(mood: BuddyMood.inLove);

  @override
  void initState() {
    super.initState();
    // The Buddy asks; the sheet has no title of its own.
    _buddy.say(widget.title, duration: null);
  }

  @override
  void dispose() {
    _buddy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BbDragHandle(color: AppTheme.border),
            AppConstants.gap16,
            SizedBox(
              height: AppConstants.streakSheetBuddyHeight,
              child: BuddyStage(controller: _buddy),
            ),
            AppConstants.gap16,
            StreakGoalPicker(
              currentStreak: widget.currentStreak,
              onSelected: (g) => Navigator.pop(context, g),
            ),
          ],
        ),
      ),
    );
  }
}
