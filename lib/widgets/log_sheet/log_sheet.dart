import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../router/tracker_routes.dart';
import '../../services/buddy/daily_care.dart';
import '../../services/haptic_service.dart';
import '../../utils/date_format_utils.dart';
import '../buddy/need_icon.dart';
import '../common/bb_drag_handle.dart';

/// Opens the „Eintragen" sheet for [day]: pick what to log, then its tracker
/// opens. [now] is the current moment; [suggested] is highlighted.
Future<void> showLogSheet(
  BuildContext context, {
  required DateTime day,
  required DateTime now,
  CareNeed? suggested,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => LogSheet(day: day, now: now, suggested: suggested),
  );
}

class LogSheet extends StatelessWidget {
  const LogSheet({
    super.key,
    required this.day,
    required this.now,
    this.suggested,
  });

  /// An option's button: `log_sheet_<need>`.
  static Key optionKey(CareNeed need) => ValueKey('log_sheet_${need.name}');

  final DateTime day;
  final DateTime now;
  final CareNeed? suggested;

  @override
  Widget build(BuildContext context) {
    final today = isSameDay(day, now);
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BbDragHandle(),
            AppConstants.gap16,
            const Text(
              'Eintragen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitleLG,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap4,
            Text(
              today
                  ? 'Heute · ${formatTime(now)}'
                  : 'Für ${formatLogTargetDay(day)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
              ),
            ),
            AppConstants.gap20,
            Row(
              children: [
                _option(context, CareNeed.food, today),
                const SizedBox(width: AppConstants.spacing12),
                _option(context, CareNeed.drink, today),
              ],
            ),
            AppConstants.gap12,
            Row(
              children: [
                _option(context, CareNeed.gutFeeling, today),
                const SizedBox(width: AppConstants.spacing12),
                _option(context, CareNeed.toilet, today),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, CareNeed need, bool today) {
    return Expanded(
      child: _LogOption(
        key: optionKey(need),
        need: need,
        selected: need == suggested,
        onTap: () {
          HapticService.selection();
          final at = today ? null : buildTrackedAt(day, now: now);
          // Grab the root-level handles before the sheet's context is gone.
          final navigator = Navigator.of(context);
          navigator.pop();
          openTracker(navigator.context, need, at: at);
        },
      ),
    );
  }
}

class _LogOption extends StatelessWidget {
  const _LogOption({
    super.key,
    required this.need,
    required this.selected,
    required this.onTap,
  });

  final CareNeed need;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.radiusLg);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppTheme.primarySoft : AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected
                ? AppConstants.borderWidthLg
                : AppConstants.borderWidthMd,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppConstants.logSheetOptionHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeedIcon(need, size: AppConstants.logSheetIconSize),
                  AppConstants.gap4,
                  Text(
                    need.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
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
