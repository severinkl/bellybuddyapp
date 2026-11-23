import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../common/bb_drag_handle.dart';
import 'buddy_controller.dart';
import 'buddy_pose.dart';
import 'buddy_stage.dart';

/// Opens a sheet [builder] builds (usually a [BuddyAskSheet]) over the
/// bottom bar too, since these open from Home's tab. Returns what it pops
/// with, or null when dismissed.
Future<T?> showBuddySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: false,
  builder: builder,
);

/// A sheet in which the Buddy asks: the drag handle, the Buddy in [mood]
/// saying [line] (the sheet has no title of its own), and [child] below him
/// (the answers).
class BuddyAskSheet extends StatefulWidget {
  const BuddyAskSheet({
    super.key,
    required this.line,
    this.mood = BuddyMood.happy,
    required this.child,
  });

  final String line;
  final BuddyMood mood;
  final Widget child;

  @override
  State<BuddyAskSheet> createState() => _BuddyAskSheetState();
}

class _BuddyAskSheetState extends State<BuddyAskSheet> {
  late final BuddyController _buddy = BuddyController(mood: widget.mood);

  @override
  void initState() {
    super.initState();
    _buddy.say(widget.line, duration: null);
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
            widget.child,
          ],
        ),
      ),
    );
  }
}
