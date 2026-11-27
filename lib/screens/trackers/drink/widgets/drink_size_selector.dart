import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../utils/drink_helpers.dart';

class DrinkSizeSelector extends ConsumerStatefulWidget {
  const DrinkSizeSelector({super.key});

  static const customAmountKey = Key('drink_custom_amount');

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
    final selectedAmount = ref.watch(
      drinkTrackerProvider.select((s) => s.selectedAmount),
    );
    final customAmount = ref.watch(
      drinkTrackerProvider.select((s) => s.customAmount),
    );

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
          style: TextStyle(
            fontSize: AppTheme.fontSizeSubtitle,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppConstants.gap12,
        // 4-column grid of preset sizes
        Row(
          children: [
            for (var i = 0; i < AppConstants.drinkSizes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SizeButton(
                  ml: AppConstants.drinkSizes[i],
                  isSelected:
                      selectedAmount == AppConstants.drinkSizes[i] &&
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
        AppConstants.gap12,
        // Custom amount input with separate "ml" suffix
        Row(
          children: [
            Expanded(
              // The hint goes once the user types; the name (with the
              // unit shown beside the field) stays.
              child: MergeSemantics(
                child: Semantics(
                  label: 'Andere Menge in ml',
                  textField: true,
                  child: TextField(
                    key: DrinkSizeSelector.customAmountKey,
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    // Scrolls the hint under the field into view with the
                    // field, not just the digits.
                    scrollPadding: AppConstants.fieldWithHintScrollPadding,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Andere Menge',
                      errorText: DrinkHelpers.amountError(customAmount),
                      filled: true,
                      fillColor: AppTheme.muted.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacing20,
                        vertical: AppConstants.spacing14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                        borderSide: const BorderSide(
                          color: AppTheme.destructive,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                        borderSide: const BorderSide(
                          color: AppTheme.destructive,
                        ),
                      ),
                    ),
                    onChanged: ref
                        .read(drinkTrackerProvider.notifier)
                        .setCustomAmount,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ml',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
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
    // One size at a time: a radio-like group to assistive tech.
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.info
                : AppTheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          alignment: Alignment.center,
          child: Text(
            '$ml ml',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
