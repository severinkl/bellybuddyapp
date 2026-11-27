import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../widgets/common/tap_target.dart';

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
    final hasRecentDrinks = ref.watch(
      drinkTrackerProvider.select((s) => s.hasRecentDrinks),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasRecentDrinks
              ? 'Wähle aus deinen letzten Getränken'
              : 'Häufige Getränke',
          style: const TextStyle(
            fontSize: AppTheme.fontSizeCaptionLG,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedForeground,
          ),
        ),
        AppConstants.gap8,
        // Each drink's hit area is padded to 48 high; the rows lose their
        // run spacing for it, so the pills keep their 8 px gaps.
        Wrap(
          spacing: AppConstants.spacingSm,
          children: quickDrinks.map((drink) {
            final isSelected = selectedDrink?.id == drink.id;
            return Semantics(
              container: true,
              button: true,
              selected: isSelected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticService.selection();
                  ref.read(drinkTrackerProvider.notifier).toggleDrink(drink);
                },
                child: TapTarget(
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacing14,
                      vertical: AppConstants.spacing10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.info
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
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
