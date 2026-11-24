import 'package:material_ui/material_ui.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_selection_button.dart';
import '../widgets/step_field_label.dart';

class DietStep extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  static const dietTitleKey = Key('diet_title');
  static const dietAllesKey = Key('diet_alles');

  const DietStep({super.key, this.value, required this.onChanged});

  static const _options = [
    ('alles', 'Alles', 'diet_alles'),
    ('vegetarisch', 'Vegetarisch', 'diet_vegetarisch'),
    ('vegan', 'Vegan', 'diet_vegan'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.wizardStepPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepFieldLabel(
            key: dietTitleKey,
            'Ernährung',
            helper:
                'Damit ich dir passende Zutaten und Rezepte vorschlagen kann.',
          ),
          AppConstants.gap16,
          ..._options.map((option) {
            return BbSelectionButton(
              selectionKey: Key(option.$3),
              label: option.$2,
              isSelected: value == option.$1,
              onPressed: () => onChanged(option.$1),
              height: 56,
            );
          }),
        ],
      ),
    );
  }
}
