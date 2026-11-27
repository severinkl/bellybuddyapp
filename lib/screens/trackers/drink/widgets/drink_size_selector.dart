import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../widgets/common/bb_labeled_field.dart';
import '../../../../utils/drink_helpers.dart';
import '../../../../utils/reduced_motion.dart';
import '../../../../widgets/common/bb_tap_area.dart';
import 'drink_glyph.dart';
import 'drink_tile_grid.dart';

/// The „Wie viel?" section: four vessel tiles and „Andere Menge". The
/// tiles are disabled (and say why) until a drink is chosen.
class DrinkSizeSelector extends ConsumerStatefulWidget {
  const DrinkSizeSelector({super.key});

  static const customAmountKey = Key('drink_custom_amount');
  static Key vesselKey(int ml) => Key('drink_vessel_$ml');

  static const _needDrinkHint = 'Wähle zuerst ein Getränk.';

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
    final hasDrink = ref.watch(
      drinkTrackerProvider.select((s) => s.selectedDrink != null),
    );
    final selectedAmount = ref.watch(
      drinkTrackerProvider.select((s) => s.selectedAmount),
    );
    final customAmount = ref.watch(
      drinkTrackerProvider.select((s) => s.customAmount),
    );
    // A pending save keeps its amount: the tiles do nothing meanwhile (and
    // keep their look).
    final isSaving = ref.watch(drinkTrackerProvider.select((s) => s.isSaving));
    final notifier = ref.read(drinkTrackerProvider.notifier);

    // Sync text controller when provider clears customAmount (e.g. a vessel
    // tapped)
    ref.listen(drinkTrackerProvider.select((s) => s.customAmount), (_, next) {
      if (_customController.text != next) {
        _customController.text = next;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Wie viel?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: hasDrink ? AppTheme.foreground : AppTheme.mutedForeground,
            ),
          ),
        ),
        AppConstants.gap8,
        DrinkTileGrid(
          normalColumns: DrinkVessel.values.length,
          children: [
            for (final vessel in DrinkVessel.values)
              _VesselTile(
                vessel: vessel,
                enabled: hasDrink,
                isSelected:
                    hasDrink &&
                    selectedAmount == vessel.ml &&
                    customAmount.isEmpty,
                onTap: isSaving
                    ? null
                    : () {
                        HapticService.selection();
                        notifier.selectAmount(vessel.ml);
                      },
              ),
          ],
        ),
        AppConstants.gap8,
        if (!hasDrink)
          const ExcludeSemantics(
            child: Text(
              DrinkSizeSelector._needDrinkHint,
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.mutedForeground,
              ),
            ),
          )
        else
          _CustomAmountRow(
            controller: _customController,
            customAmount: customAmount,
            onChanged: notifier.setCustomAmount,
          ),
      ],
    );
  }
}

class _VesselTile extends StatelessWidget {
  const _VesselTile({
    required this.vessel,
    required this.enabled,
    required this.isSelected,
    required this.onTap,
  });

  final DrinkVessel vessel;
  final bool enabled;
  final bool isSelected;

  /// Null while a save is pending.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glyphColor = !enabled
        ? AppTheme.mutedForeground
        : isSelected
        ? AppTheme.infoText
        : AppTheme.foreground;
    final amount = DrinkHelpers.formatAmount(vessel.ml);
    return BbTapArea(
      tapKey: DrinkSizeSelector.vesselKey(vessel.ml),
      label: '${vessel.label}, $amount',
      hint: enabled ? null : DrinkSizeSelector._needDrinkHint,
      selected: isSelected,
      // One size at a time.
      exclusive: true,
      // The tile is vesselTileMinHeight (96) tall already.
      tapTarget: false,
      excludeChild: true,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: ReducedMotion.duration(context, AppConstants.animFast),
        constraints: const BoxConstraints(
          minHeight: AppConstants.vesselTileMinHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing2,
          vertical: AppConstants.spacingSm,
        ),
        decoration: drinkTileDecoration(selected: isSelected),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DrinkGlyph.vessel(vessel, color: glyphColor),
            AppConstants.gap4,
            Text(
              vessel.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: AppTheme.mutedForeground,
              ),
            ),
            Text(
              amount,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
                color: enabled ? AppTheme.foreground : AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomAmountRow extends StatelessWidget {
  const _CustomAmountRow({
    required this.controller,
    required this.customAmount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String customAmount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder pill(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      borderSide: BorderSide(color: color, width: AppConstants.borderWidthLg),
    );
    final edge = pill(
      customAmount.isEmpty ? AppTheme.border : AppTheme.infoText,
    );
    final error = DrinkHelpers.amountError(customAmount);
    final textScaler = MediaQuery.textScalerOf(context);
    final stacked = AppConstants.isLargeText(context);

    const labelText = Text(
      'Andere Menge',
      style: TextStyle(
        fontSize: AppTheme.fontSizeBody,
        fontWeight: FontWeight.w500,
        color: AppTheme.foreground,
      ),
    );
    final field = BbLabeledField(
      label: 'Andere Menge in ml',
      child: TextField(
        key: DrinkSizeSelector.customAmountKey,
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeSubtitle,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
        // Scrolls the hint under the field into view with the
        // field, not just the digits, also when it wraps.
        scrollPadding: AppConstants.customAmountScrollPadding.copyWith(
          bottom: textScaler.scale(
            AppConstants.customAmountScrollPadding.bottom,
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        decoration: InputDecoration(
          suffixText: 'ml',
          suffixStyle: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
          errorText: error,
          // Room to wrap in the narrow field instead of an ellipsis.
          errorMaxLines: AppConstants.customAmountHintMaxLines,
          filled: true,
          fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacing14,
          ),
          border: edge,
          enabledBorder: edge,
          focusedBorder: edge,
          errorBorder: pill(AppTheme.destructive),
          focusedErrorBorder: pill(AppTheme.destructive),
        ),
        onChanged: onChanged,
      ),
    );
    if (stacked) {
      // Large text: the label over a full-width field, so neither is cut.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(child: labelText),
          AppConstants.gap8,
          field,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: ConstrainedBox(
              // At least as tall as the field, so the label centres on it;
              // taller when it wraps.
              constraints: const BoxConstraints(
                minHeight: AppConstants.minTapTarget,
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: labelText,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacing10),
        SizedBox(width: AppConstants.customAmountFieldWidth, child: field),
      ],
    );
  }
}
