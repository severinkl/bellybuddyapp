import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../utils/drink_helpers.dart';
import '../../../../widgets/common/bb_button.dart';
import 'drink_glyph.dart';

/// „Wie zuletzt": the most recent drink and amount, saved again with one
/// tap ([onSave]) at the screen's chosen time. Nothing without a last
/// drink.
class LastDrinkRow extends ConsumerWidget {
  const LastDrinkRow({super.key, required this.onSave});

  final VoidCallback onSave;

  static const saveKey = Key('last_drink_save');

  static const _caption = 'Wie zuletzt';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(drinkTrackerProvider.select((s) => s.lastDrink));
    final isSaving = ref.watch(drinkTrackerProvider.select((s) => s.isSaving));
    if (last == null) return const SizedBox.shrink();

    final what =
        '${last.drink.name}, ${DrinkHelpers.formatAmount(last.amountMl)}';
    final stacked = AppConstants.isLargeText(context);

    final text = Semantics(
      container: true,
      label: '$_caption, $what',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            _caption,
            style: TextStyle(
              fontSize: AppTheme.fontSizeCaptionLG,
              color: AppTheme.mutedForeground,
            ),
          ),
          Text(
            what,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
    final glyph = DrinkGlyph.icon(
      DrinkHelpers.iconFor(last.drink),
      size: AppConstants.drinkRowIconSize,
      color: AppTheme.infoText,
    );
    final button = BbButton(
      tapKey: saveKey,
      label: 'Eintragen',
      semanticLabel: '$what eintragen',
      isLoading: isSaving,
      compact: true,
      onPressed: onSave,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingSm,
        AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: stacked
          // Large text: the button under the text, across the row.
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    glyph,
                    const SizedBox(width: AppConstants.spacing12),
                    Expanded(child: text),
                  ],
                ),
                AppConstants.gap8,
                button,
              ],
            )
          : Row(
              children: [
                glyph,
                const SizedBox(width: AppConstants.spacing12),
                Expanded(child: text),
                const SizedBox(width: AppConstants.spacingSm),
                button,
              ],
            ),
    );
  }
}
