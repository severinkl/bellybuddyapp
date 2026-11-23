import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/buddy_provider.dart';
import '../../../utils/logger.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/bb_drag_handle.dart';
import '../../../widgets/common/bb_progress_bar.dart';
import '../../buddy/streak_goal_picker.dart';
import '../../buddy/widgets/streak_moment.dart';

const _log = AppLogger('StreakSheet');

/// „Dein Streak" for [status]: the count and this week's row, the goal's
/// progress, the streak savers, and „Ziel ändern" (the goal list to choose
/// from in the same sheet, the current goal selected). Returns the chosen
/// goal, or null when dismissed.
Future<int?> showStreakSheet(
  BuildContext context, {
  required BuddyStatus status,
  required DateTime today,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => StreakSheet(status: status, today: today),
  );
}

/// Opens „Dein Streak" ([showStreakSheet]) and saves the goal chosen there
/// ([saveStreakGoal]), unless the sheet was dismissed or [context] is gone
/// by then.
Future<void> openStreakSheetAndSaveGoal(
  BuildContext context,
  WidgetRef ref, {
  required BuddyStatus status,
  required DateTime today,
}) async {
  final goal = await showStreakSheet(context, status: status, today: today);
  if (goal == null || !context.mounted) return;
  await saveStreakGoal(ref, goal);
}

/// Sets the Buddy's streak goal to [goal]. Never throws: a failing save is
/// logged.
Future<void> saveStreakGoal(WidgetRef ref, int goal) async {
  try {
    await ref.read(buddyProvider.notifier).setStreakGoal(goal);
  } catch (e, st) {
    _log.error('Saving the new streak goal failed', e, st);
  }
}

class StreakSheet extends StatefulWidget {
  const StreakSheet({super.key, required this.status, required this.today});

  static const changeGoalKey = Key('streak_sheet_change_goal');

  static const saverText =
      'Alle 7 Tage am Stück bekommst du einen, höchstens 2. Er rettet '
      'automatisch einen vergessenen Tag.';

  final BuddyStatus status;
  final DateTime today;

  @override
  State<StreakSheet> createState() => _StreakSheetState();
}

class _StreakSheetState extends State<StreakSheet> {
  /// Showing the goal list instead of the overview.
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final streak = status.streak;
    final goal = status.state.streakGoal;
    final canPick = streakGoalChoices(streak).isNotEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BbDragHandle(color: AppTheme.border),
            AppConstants.gap16,
            Text(
              _picking ? 'Neues Streak-Ziel' : 'Dein Streak',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeTitleLG,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap16,
            if (_picking)
              StreakGoalChooser(
                currentStreak: streak,
                initialGoal: goal,
                onConfirmed: (g) => Navigator.pop(context, g),
              )
            else ...[
              StreakMoment(
                streak: streak,
                weekDays: status.weekDays,
                today: widget.today,
              ),
              AppConstants.gap20,
              _GoalProgress(streak: streak, goal: goal),
              AppConstants.gap12,
              _SaverCard(savers: status.state.savers),
              if (canPick) ...[
                AppConstants.gap20,
                BbButton(
                  tapKey: StreakSheet.changeGoalKey,
                  label: goal == null ? 'Ziel festlegen' : 'Ziel ändern',
                  isOutlined: true,
                  onPressed: () => setState(() => _picking = true),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A card of the sheet (goal, savers).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BbCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingMd,
      vertical: AppConstants.spacing14,
    ),
    borderWidth: AppConstants.borderWidthMd,
    child: child,
  );
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.streak, required this.goal});

  final int streak;
  final int? goal;

  static const _titleStyle = TextStyle(
    fontSize: AppTheme.fontSizeBodyLG,
    fontWeight: FontWeight.w700,
    color: AppTheme.foreground,
  );
  static const _noteStyle = TextStyle(
    fontSize: AppTheme.fontSizeBody,
    color: AppTheme.mutedForeground,
  );

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    if (goal == null) {
      return const _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Noch kein Ziel', style: _titleStyle),
            AppConstants.gap4,
            Text('Ein Ziel hilft beim Dranbleiben.', style: _noteStyle),
          ],
        ),
      );
    }
    final reached = streak >= goal;
    final note = reached
        ? 'Geschafft! 🎉'
        : '${kStreakGoalLabels[goal] ?? ''} · $streak von $goal';
    return Semantics(
      label: 'Ziel: $goal Tage, $streak von $goal geschafft',
      excludeSemantics: true,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Ziel: $goal Tage', style: _titleStyle),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    note,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _noteStyle,
                  ),
                ),
              ],
            ),
            AppConstants.gap8,
            BbProgressBar(
              value: streak / goal,
              height: AppConstants.streakProgressHeight,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaverCard extends StatelessWidget {
  const _SaverCard({required this.savers});

  final int savers;

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🛡', style: TextStyle(fontSize: AppTheme.fontSizeTitleLG)),
        const SizedBox(width: AppConstants.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streak-Saver: $savers',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
              AppConstants.gap4,
              const Text(
                StreakSheet.saverText,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  height: 1.4,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
