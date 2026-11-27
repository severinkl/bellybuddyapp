import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
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
        // One value at a time: a radio-like group to assistive tech.
        return Semantics(
          container: true,
          button: true,
          selected: isSelected,
          inMutuallyExclusiveGroup: true,
          child: GestureDetector(
            onTap: () {
              HapticService.selection();
              onSelected(item);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacing10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected
                      ? AppConstants.borderWidthLg
                      : AppConstants.borderWidthDefault,
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
          ),
        );
      }).toList(),
    );
  }
}
