import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/meal_entry.dart';
import '../meal_image.dart';

class MealDetail extends StatelessWidget {
  final MealEntry meal;

  const MealDetail({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meal.imageUrl != null) MealImage(imageUrl: meal.imageUrl!),
        if (meal.ingredients.isNotEmpty) ...[
          const Text(
            'Zutaten',
            style: TextStyle(fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.w600),
          ),
          AppConstants.gap8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                meal.ingredients.map((i) => Chip(label: Text(i))).toList(),
          ),
        ],
        if (meal.notes != null) ...[
          AppConstants.gap16,
          Text(meal.notes!,
              style: const TextStyle(color: AppTheme.mutedForeground)),
        ],
      ],
    );
  }
}
