import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';

class DietSelector extends StatelessWidget {
  final String? currentDiet;
  final ValueChanged<String> onChanged;

  const DietSelector({
    super.key,
    required this.currentDiet,
    required this.onChanged,
  });

  static const _options = ['alles', 'vegetarisch', 'vegan'];
  static const _labels = {
    'alles': 'Alles',
    'vegetarisch': 'Vegetarisch',
    'vegan': 'Vegan',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((diet) {
        final isSelected = (currentDiet ?? 'alles') == diet;
        return GestureDetector(
          onTap: () {
            HapticService.selection();
            onChanged(diet);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.secondary,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: Text(
              _labels[diet]!,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryForeground
                    : AppTheme.foreground,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
