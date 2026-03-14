import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

class BbChipSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Color Function(String)? chipColorBuilder;

  const BbChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.chipColorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        final chipColor = chipColorBuilder?.call(option) ?? AppTheme.primary;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
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
          selectedColor: chipColor.withValues(alpha: 0.2),
          checkmarkColor: chipColor,
          labelStyle: TextStyle(
            color: AppTheme.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected ? chipColor : AppTheme.border,
          ),
        );
      }).toList(),
    );
  }
}
