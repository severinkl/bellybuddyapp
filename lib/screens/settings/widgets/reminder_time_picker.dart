import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';

class ReminderTimePicker extends StatefulWidget {
  final List<int> selectedTimes;
  final ValueChanged<List<int>> onChanged;

  const ReminderTimePicker({
    super.key,
    required this.selectedTimes,
    required this.onChanged,
  });

  @override
  State<ReminderTimePicker> createState() => _ReminderTimePickerState();
}

class _ReminderTimePickerState extends State<ReminderTimePicker> {
  static const _presetHours = [7, 9, 12, 15, 18, 20, 21];
  bool _showCustomPicker = false;
  int? _customHour;

  List<int> get _customTimes =>
      widget.selectedTimes.where((h) => !_presetHours.contains(h)).toList()..sort();

  void _toggleHour(int hour) {
    HapticService.selection();
    final newTimes = List<int>.from(widget.selectedTimes);
    if (newTimes.contains(hour)) {
      if (newTimes.length <= 1) return; // enforce min 1
      newTimes.remove(hour);
    } else {
      newTimes.add(hour);
    }
    newTimes.sort();
    widget.onChanged(newTimes);
  }

  void _addCustomHour() {
    if (_customHour == null) return;
    if (widget.selectedTimes.contains(_customHour)) return;
    HapticService.selection();
    final newTimes = List<int>.from(widget.selectedTimes)..add(_customHour!);
    newTimes.sort();
    widget.onChanged(newTimes);
    setState(() {
      _customHour = null;
      _showCustomPicker = false;
    });
  }

  void _removeCustomHour(int hour) {
    if (widget.selectedTimes.length <= 1) return;
    HapticService.selection();
    final newTimes = List<int>.from(widget.selectedTimes)..remove(hour);
    newTimes.sort();
    widget.onChanged(newTimes);
  }

  String _formatSummary() {
    final sorted = List<int>.from(widget.selectedTimes)..sort();
    if (sorted.length == 1) {
      return 'Erinnerung um ${sorted.first.toString().padLeft(2, '0')}:00 Uhr';
    }
    final times = sorted.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', ');
    return '${sorted.length} Erinnerungen: $times';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presetHours.map((hour) {
              final isSelected = widget.selectedTimes.contains(hour);
              return _TimePill(
                label: '${hour.toString().padLeft(2, '0')}:00',
                isSelected: isSelected,
                onTap: () => _toggleHour(hour),
              );
            }),
            // "+ Andere" button
            _TimePill(
              label: 'Andere',
              isSelected: _showCustomPicker,
              icon: Icons.add,
              onTap: () => setState(() => _showCustomPicker = !_showCustomPicker),
            ),
          ],
        ),

        // Custom picker
        if (_showCustomPicker) ...[
          AppConstants.gap12,
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _customHour,
                  decoration: const InputDecoration(
                    hintText: 'Uhrzeit wählen',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: List.generate(24, (i) => i)
                      .where((h) => !widget.selectedTimes.contains(h))
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text('${h.toString().padLeft(2, '0')}:00'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _customHour = v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _customHour != null ? _addCustomHour : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Hinzufügen'),
                ),
              ),
            ],
          ),
        ],

        // Custom time chips (removable)
        if (_customTimes.isNotEmpty) ...[
          AppConstants.gap12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customTimes.map((hour) {
              return Chip(
                label: Text('${hour.toString().padLeft(2, '0')}:00'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeCustomHour(hour),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
              );
            }).toList(),
          ),
        ],

        // Summary
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

class _TimePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _TimePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.secondary,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? AppTheme.primaryForeground : AppTheme.foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primaryForeground : AppTheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
