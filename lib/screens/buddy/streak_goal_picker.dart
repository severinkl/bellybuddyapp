import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/bb_drag_handle.dart';

const List<int> kStreakGoalOptions = [7, 14, 30, 50, 100];

const Map<int, String> kStreakGoalLabels = {
  7: 'Guter Start',
  14: 'Stark',
  30: 'Legendär',
  50: 'Unaufhaltsam',
  100: 'Bauch-Legende',
};

/// The first three goal options above [currentStreak] (fewer if exhausted).
List<int> streakGoalChoices(int currentStreak) =>
    kStreakGoalOptions.where((g) => g > currentStreak).take(3).toList();

class StreakGoalPicker extends StatelessWidget {
  const StreakGoalPicker({
    super.key,
    required this.currentStreak,
    required this.onSelected,
  });

  final int currentStreak;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final choices = streakGoalChoices(currentStreak);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in choices) ...[
          Semantics(
            button: true,
            child: BbCard(
              onTap: () => onSelected(goal),
              child: Row(
                children: [
                  Text(
                    '$goal Tage',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeSubtitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const Spacer(),
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
          if (goal != choices.last) AppConstants.gap8,
        ],
      ],
    );
  }
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
