import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class DateTimeChips extends StatelessWidget {
  const DateTimeChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.chipColor = AppTheme.background,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  /// The chips' fill; the default suits the tinted tracker screens, a
  /// white sheet needs a tinted one.
  final Color chipColor;

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('de'),
    );
    if (date != null && context.mounted) {
      onChanged(
        DateTime(date.year, date.month, date.day, value.hour, value.minute),
      );
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time != null && context.mounted) {
      onChanged(
        DateTime(value.year, value.month, value.day, time.hour, time.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DateTimeChip(
            label: DateFormat('dd.MM.yyyy').format(value),
            icon: Icons.calendar_today_outlined,
            color: chipColor,
            onTap: () => _pickDate(context),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          _DateTimeChip(
            label: DateFormat('HH:mm').format(value),
            icon: Icons.access_time_outlined,
            color: chipColor,
            onTap: () => _pickTime(context),
          ),
        ],
      ),
    );
  }
}

class _DateTimeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DateTimeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacing10,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w500,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Icon(icon, size: 18, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
