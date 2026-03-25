import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';

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

  static String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatSummary() {
    final sorted = List<String>.from(selectedTimes)..sort();
    if (sorted.length == 1) {
      return 'Erinnerung um ${sorted.first} Uhr';
    }
    return '${sorted.length} Erinnerungen: ${sorted.join(', ')}';
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
              Dismissible(
                key: ValueKey(selectedTimes[i]),
                direction: selectedTimes.length > 1
                    ? DismissDirection.horizontal
                    : DismissDirection.none,
                onDismissed: (_) => _removeTime(i),
                background: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.destructive,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusFull,
                    ),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: GestureDetector(
                  onTap: () => _editTime(context, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacing14,
                      vertical: AppConstants.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                    ),
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
              ),
            GestureDetector(
              onTap: () => _addTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacing14,
                  vertical: AppConstants.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: const Row(
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
        AppConstants.gap16,
        Text(
          _formatSummary(),
          style: const TextStyle(
            fontSize: AppTheme.fontSizeCaptionLG,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
