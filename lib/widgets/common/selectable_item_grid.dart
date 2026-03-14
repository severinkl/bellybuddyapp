import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

class SelectableItemGrid<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;

  const SelectableItemGrid({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = item == selectedValue;
        return GestureDetector(
          onTap: () {
            HapticService.selection();
            onSelected(item);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              labelBuilder(item),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: AppTheme.foreground,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
