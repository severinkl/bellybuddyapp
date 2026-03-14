import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/toilet_entry.dart';

class ToiletDetail extends StatelessWidget {
  final ToiletEntry toilet;
  final bool isEditing;
  final int editStoolType;
  final ValueChanged<int> onStoolTypeChanged;

  const ToiletDetail({
    super.key,
    required this.toilet,
    required this.isEditing,
    required this.editStoolType,
    required this.onStoolTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentType = isEditing ? editStoolType : toilet.stoolType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visual scale bar
        Row(
          children: List.generate(5, (i) {
            final type = i + 1;
            final isSelected = type == currentType;
            final color = AppTheme.stoolColor(type);
            return Expanded(
              child: GestureDetector(
                onTap: isEditing ? () => onStoolTypeChanged(type) : null,
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: color, width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$type',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConstants.stoolTypeDescriptions[type]!,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        if (!isEditing) ...[
          const SizedBox(height: 16),
          Text(
            'Konsistenz: ${AppConstants.stoolTypeDescriptions[toilet.stoolType] ?? 'Normal'}',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            'Stufe ${toilet.stoolType} von 5',
            style: const TextStyle(color: AppTheme.mutedForeground),
          ),
        ],
      ],
    );
  }
}
