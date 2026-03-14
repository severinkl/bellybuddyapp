import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';

class DrinkSizeSelector extends ConsumerStatefulWidget {
  const DrinkSizeSelector({super.key});

  @override
  ConsumerState<DrinkSizeSelector> createState() => _DrinkSizeSelectorState();
}

class _DrinkSizeSelectorState extends ConsumerState<DrinkSizeSelector> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAmount =
        ref.watch(drinkTrackerProvider.select((s) => s.selectedAmount));
    final customAmount =
        ref.watch(drinkTrackerProvider.select((s) => s.customAmount));

    // Sync text controller when provider clears customAmount (e.g. preset tapped)
    ref.listen(drinkTrackerProvider.select((s) => s.customAmount), (_, next) {
      if (_customController.text != next) {
        _customController.text = next;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menge?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        // 4-column grid of preset sizes
        Row(
          children: [
            for (var i = 0; i < AppConstants.drinkSizes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SizeButton(
                  ml: AppConstants.drinkSizes[i],
                  isSelected: selectedAmount == AppConstants.drinkSizes[i] &&
                      customAmount.isEmpty,
                  onTap: () {
                    HapticService.selection();
                    ref
                        .read(drinkTrackerProvider.notifier)
                        .selectAmount(AppConstants.drinkSizes[i]);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Custom amount input with separate "ml" suffix
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Andere Menge',
                  filled: true,
                  fillColor: AppTheme.muted.withValues(alpha: 0.5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged:
                    ref.read(drinkTrackerProvider.notifier).setCustomAmount,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ml',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SizeButton extends StatelessWidget {
  final int ml;
  final bool isSelected;
  final VoidCallback onTap;

  const _SizeButton({
    required this.ml,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.info
              : AppTheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '$ml ml',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isSelected ? Colors.white : AppTheme.foreground,
          ),
        ),
      ),
    );
  }
}
