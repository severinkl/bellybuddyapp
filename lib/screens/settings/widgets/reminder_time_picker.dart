import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/date_format_utils.dart';
import '../../../widgets/common/bb_icon_tap.dart';
import '../../../widgets/common/tap_target.dart';
import '../../../widgets/common/bb_tap_area.dart';

class ReminderTimePicker extends StatelessWidget {
  final List<String> selectedTimes;
  final ValueChanged<List<String>> onChanged;

  const ReminderTimePicker({
    super.key,
    required this.selectedTimes,
    required this.onChanged,
  });

  Future<void> _addTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Erinnerungszeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Hinzufügen',
    );
    if (picked == null) return;

    final formatted = _formatTimeOfDay(picked);
    if (selectedTimes.contains(formatted)) return;

    HapticService.selection();
    final newTimes = List<String>.from(selectedTimes)..add(formatted);
    newTimes.sort();
    onChanged(newTimes);
  }

  Future<void> _editTime(BuildContext context, int index) async {
    final current = _parseTimeOfDay(selectedTimes[index]);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Erinnerungszeit ändern',
      cancelText: 'Abbrechen',
      confirmText: 'Speichern',
    );
    if (picked == null) return;

    final formatted = _formatTimeOfDay(picked);
    if (formatted == selectedTimes[index]) return;
    if (selectedTimes.contains(formatted)) return;

    HapticService.selection();
    final newTimes = List<String>.from(selectedTimes);
    newTimes[index] = formatted;
    newTimes.sort();
    onChanged(newTimes);
  }

  void _removeTime(int index) {
    if (selectedTimes.length <= 1) return;
    HapticService.selection();
    final newTimes = List<String>.from(selectedTimes)..removeAt(index);
    onChanged(newTimes);
  }

  static String _formatTimeOfDay(TimeOfDay time) =>
      formatHourMinute(time.hour, time.minute);

  static TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingSm,
          children: [
            for (var i = 0; i < selectedTimes.length; i++)
              BbTapArea(
                tapTarget: false,
                onTap: () => _editTime(context, i),
                child: _Pill(
                  color: AppTheme.primary,
                  trailing: selectedTimes.length > 1
                      ? BbIconTap(
                          icon: Icons.close,
                          semanticLabel:
                              'Uhrzeit ${selectedTimes[i]} entfernen',
                          iconSize: AppConstants.iconSizeXs,
                          color: AppTheme.primaryForeground,
                          onTap: () => _removeTime(i),
                        )
                      : null,
                  child: Text(
                    selectedTimes[i],
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryForeground,
                    ),
                  ),
                ),
              ),
            BbTapArea(
              tapTarget: false,
              onTap: () => _addTime(context),
              child: const _Pill(
                color: AppTheme.secondary,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: AppConstants.spacingMd,
                      color: AppTheme.foreground,
                    ),
                    SizedBox(width: AppConstants.spacingXs),
                    Text(
                      'Hinzufügen',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A rounded chip drawn as before, with a hit area of at least
/// [AppConstants.minTapTarget] around it: the pill is inset from the hit
/// area, and a [trailing] ✕ takes its 48 × 48 across the pill's edge.
class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child, this.trailing});

  final Color color;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Without a ✕ the pill is the label plus its padding (36 px); with one,
    // the ✕ used to make it 40 px. The ✕'s 48 px sit 4 px past the pill.
    final inset = trailing == null
        ? AppConstants.spacing6
        : AppConstants.spacingXs;
    return TapTarget(
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: inset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: AppConstants.spacing14,
                  end: trailing == null ? AppConstants.spacing14 : 0,
                  top: AppConstants.spacingSm + inset,
                  bottom: AppConstants.spacingSm + inset,
                ),
                child: child,
              ),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }
}
