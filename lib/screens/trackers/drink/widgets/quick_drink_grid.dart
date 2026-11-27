import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../utils/reduced_motion.dart';
import '../../../../widgets/common/bb_tap_area.dart';

class QuickDrinkGrid extends ConsumerWidget {
  const QuickDrinkGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickDrinks = ref.watch(
      drinkTrackerProvider.select((s) => s.quickDrinks),
    );
    final selectedDrink = ref.watch(
      drinkTrackerProvider.select((s) => s.selectedDrink),
    );
    final hasLastDrink = ref.watch(
      drinkTrackerProvider.select((s) => s.lastDrink != null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasLastDrink
              ? 'Wähle aus deinen letzten Getränken'
              : 'Häufige Getränke',
          style: const TextStyle(
            fontSize: AppTheme.fontSizeCaptionLG,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedForeground,
          ),
        ),
        AppConstants.gap8,
        // Each drink's hit area is at least 48 high. The rows' 8 px gap is
        // the pill's own 4 px above and below (inside the hit area), so it
        // stays at any text size.
        Wrap(
          spacing: AppConstants.spacingSm,
          children: quickDrinks.map((drink) {
            final isSelected = selectedDrink?.id == drink.id;
            return BbTapArea(
              selected: isSelected,
              // One drink at a time (tapping it again clears it).
              exclusive: true,
              onTap: () {
                HapticService.selection();
                ref.read(drinkTrackerProvider.notifier).toggleDrink(drink);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingXs,
                ),
                child: AnimatedContainer(
                  duration: ReducedMotion.duration(
                    context,
                    AppConstants.animFast,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacing14,
                    vertical: AppConstants.spacing10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.infoText
                        : AppTheme.muted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusFull,
                    ),
                  ),
                  child: Text(
                    drink.name,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.foreground,
                    ),
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
