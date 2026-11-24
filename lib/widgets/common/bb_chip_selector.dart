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
      children: [
        for (final option in shown)
          BbFilterChip(
            label: labelOf?.call(option) ?? option,
            selected: selected.contains(option),
            onSelected: (value) => onChanged(
              value
                  ? [...selected, option]
                  : (List.of(selected)..remove(option)),
            ),
          ),
      ],
    );
  }
}

/// The app's filter chip: filled while [selected]. A tap gives the
/// selection haptic, then [onSelected] with the new state.
class BbFilterChip extends StatelessWidget {
  const BbFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    const chipColor = AppTheme.chipDefault;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (value) {
        HapticService.selection();
        onSelected(value);
      },
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryForeground : AppTheme.foreground,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(color: selected ? chipColor : AppTheme.border),
    );
  }
}
