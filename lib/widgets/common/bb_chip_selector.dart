import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

class BbChipSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const BbChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        const chipColor = AppTheme.chipDefault;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (value) {
            HapticService.selection();
            final newSelected = List<String>.from(selected);
            if (value) {
              newSelected.add(option);
            } else {
              newSelected.remove(option);
            }
            onChanged(newSelected);
          },
          selectedColor: chipColor,
          labelStyle: TextStyle(
            color: isSelected
                ? AppTheme.primaryForeground
                : AppTheme.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(color: isSelected ? chipColor : AppTheme.border),
        );
      }).toList(),
    );
  }
}
