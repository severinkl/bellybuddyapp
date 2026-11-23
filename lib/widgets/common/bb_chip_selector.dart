import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

class BbChipSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// How the chips line up in each row.
  final WrapAlignment alignment;

  /// The label shown for an option value (the value itself by default).
  final String Function(String value)? labelOf;

  const BbChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.alignment = WrapAlignment.center,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    // A selected value no longer on the list (an older answer) still shows,
    // so it can be seen and taken off.
    final shown = [...options, ...selected.where((s) => !options.contains(s))];
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      children: shown.map((option) {
        final isSelected = selected.contains(option);
        const chipColor = AppTheme.chipDefault;
        return FilterChip(
          label: Text(labelOf?.call(option) ?? option),
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
