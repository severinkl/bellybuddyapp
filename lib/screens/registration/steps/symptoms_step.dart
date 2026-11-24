import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/common/bb_selection_button.dart';
import '../../../config/constants.dart';
import '../../../config/symptom_options.dart';
import '../widgets/step_field_label.dart';

class SymptomsStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  static const symptomsTitleKey = Key('symptoms_title');

  const SymptomsStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.wizardStepPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepFieldLabel(
            key: symptomsTitleKey,
            'Beschwerden',
            helper: 'Mehrfachauswahl möglich.',
          ),
          AppConstants.gap16,
          ...kRegistrationSymptomOptions.map((option) {
            final isSelected = selected.contains(option.value);
            return BbSelectionButton(
              label: option.label,
              isSelected: isSelected,
              onPressed: () {
                final newSelected = List<String>.from(selected);
                if (isSelected) {
                  newSelected.remove(option.value);
                } else {
                  newSelected.add(option.value);
                }
                onChanged(newSelected);
              },
              // Checkboxes: several symptoms can be picked.
              leading: Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: isSelected ? AppTheme.primary : AppTheme.mutedForeground,
                size: 20,
              ),
            );
          }),
        ],
      ),
    );
  }
}
