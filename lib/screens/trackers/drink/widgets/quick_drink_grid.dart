import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';

class QuickDrinkGrid extends ConsumerWidget {
  const QuickDrinkGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickDrinks =
        ref.watch(drinkTrackerProvider.select((s) => s.quickDrinks));
    final selectedDrink =
        ref.watch(drinkTrackerProvider.select((s) => s.selectedDrink));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wähle aus deinen letzten Getränken',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickDrinks.map((drink) {
            final isSelected = selectedDrink?.id == drink.id;
            return GestureDetector(
              onTap: () {
                HapticService.selection();
                ref.read(drinkTrackerProvider.notifier).toggleDrink(drink);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.info
                      : AppTheme.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  drink.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.foreground,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
