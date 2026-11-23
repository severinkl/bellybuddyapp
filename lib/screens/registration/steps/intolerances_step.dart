import 'package:material_ui/material_ui.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/intolerance_trigger_modal.dart';
import '../widgets/step_field_label.dart';

class IntolerancesStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Map<String, List<String>> triggers;
  final void Function(String intolerance, List<String> triggers)
  onTriggersChanged;
  static const intolerancesTitleKey = Key('intolerances_title');

  const IntolerancesStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.triggers,
    required this.onTriggersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: AppConstants.wizardStepPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepFieldLabel(
              key: intolerancesTitleKey,
              'Ärztlich diagnostiziert',
              helper: 'Hilft mir bei der Analyse deiner Mahlzeiten.',
            ),
            AppConstants.gap16,
            BbChipSelector(
              alignment: WrapAlignment.start,
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
      ),
    );
  }
}
