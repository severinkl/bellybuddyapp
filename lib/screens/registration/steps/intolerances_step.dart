import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/intolerance_trigger_modal.dart';
import '../../../widgets/common/mascot_image.dart';

class IntolerancesStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Map<String, List<String>> triggers;
  final void Function(String intolerance, List<String> triggers)
  onTriggersChanged;

  const IntolerancesStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.triggers,
    required this.onTriggersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        children: [
          AppConstants.gap24,
          const MascotImage(
            assetPath: AppConstants.mascotNervous,
            width: 120,
            height: 120,
          ),
          AppConstants.gap16,
          const Text(
            'Wurden dir Unverträglichkeiten diagnostiziert?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap8,
          const Text(
            'Gib hier ärztlich diagnostizierte Unverträglichkeiten an. Diese Angaben helfen uns bei der personalisierten Analyse deiner Mahlzeiten.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap32,
          BbChipSelector(
            options: AppConstants.intoleranceOptions,
            selected: selected,
            onChanged: (newSelected) {
              final added = newSelected.where((s) => !selected.contains(s));
              onChanged(newSelected);
              for (final item in added) {
                if (triggerIntolerances.contains(item)) {
                  Future.microtask(() {
                    if (!context.mounted) return;
                    showIntoleranceTriggerModal(
                      context: context,
                      intolerance: item,
                      currentTriggers: triggers[item] ?? [],
                      onChanged: (t) => onTriggersChanged(item, t),
                    );
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
