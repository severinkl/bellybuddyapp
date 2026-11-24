import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../common/bb_button.dart';
import '../common/bb_drag_handle.dart';
import 'buddy_pose.dart';
import 'buddy_says.dart';

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
/// saying [line] (the sheet has no title of its own), [child] below him,
/// and the [actions]. On a screen shorter than
/// [AppConstants.buddyAskSheetCompactBelow] the Buddy is compact, so more
/// fits on screen.
class BuddyAskSheet extends StatelessWidget {
  const BuddyAskSheet({
    super.key,
    required this.line,
    this.mood = BuddyMood.happy,
    this.child,
    this.actions,
  });

  final String line;
  final BuddyMood mood;

  /// Below the Buddy: what he offers, or the answers themselves; scrolls
  /// with him when the sheet is too short.
  final Widget? child;

  /// The sheet's buttons, below [child] but pinned to the sheet's bottom:
  /// on screen without scrolling, however long [child] is.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).height <
        AppConstants.buddyAskSheetCompactBelow;
    final child = this.child, actions = this.actions;
    final content = SingleChildScrollView(
      padding: actions == null
          ? AppConstants.paddingLg
          : const EdgeInsets.only(
              left: AppConstants.spacingLg,
              top: AppConstants.spacingLg,
              right: AppConstants.spacingLg,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BbDragHandle(color: AppTheme.border),
          AppConstants.gap16,
          BuddySays(
            mood: mood,
            line: line,
            height: compact
                ? AppConstants.buddyAskSheetCompactHeight
                : AppConstants.streakSheetBuddyHeight,
          ),
          if (child != null) ...[AppConstants.gap16, child],
        ],
      ),
    );
    if (actions == null) return SafeArea(child: content);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: content),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingMd,
              AppConstants.spacingLg,
              AppConstants.spacingLg,
            ),
            child: actions,
          ),
        ],
      ),
    );
  }
}

/// A Buddy sheet's [BuddyAskSheet.actions]: the [primary] button, then, if
/// given, the muted text button [secondary] („Später", „Nein, danke").
class BuddySheetActions extends StatelessWidget {
  const BuddySheetActions({
    super.key,
    required this.primary,
    required this.onPrimary,
    this.primaryKey,
    this.secondary,
    this.onSecondary,
    this.secondaryKey,
  }) : assert((secondary == null) == (onSecondary == null));

  final String primary;
  final VoidCallback onPrimary;
  final Key? primaryKey;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    final secondary = this.secondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BbButton(tapKey: primaryKey, label: primary, onPressed: onPrimary),
        if (secondary != null) ...[
          AppConstants.gap8,
          TextButton(
            key: secondaryKey,
            onPressed: onSecondary,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mutedForeground,
            ),
            child: Text(secondary),
          ),
        ],
      ],
    );
  }
}

/// Running text in a Buddy sheet, below him: centred and muted.
class BuddySheetText extends StatelessWidget {
  const BuddySheetText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: AppTheme.fontSizeBody,
        height: AppTheme.lineHeightBody,
        color: AppTheme.mutedForeground,
      ),
    );
  }
}
