import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/common/bb_selection_button.dart';
import '../../../config/constants.dart';

/// Symptom labels offered during registration.
const List<String> kRegistrationSymptoms = [
  'Belastender Durchfall',
  'Nervige Verstopfung',
  'Unangenehme Blähungen',
  'Übermäßiges Völlegefühl',
  'Hartnäckiger Blähbauch ohne Pupsen',
];

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
      padding: AppConstants.paddingLg,
      child: Column(
        children: [
          const Text(
            key: symptomsTitleKey,
            'Welche Beschwerden nerven dich?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap32,
          ...kRegistrationSymptoms.map((option) {
            final isSelected = selected.contains(option);
            return BbSelectionButton(
              label: option,
              isSelected: isSelected,
              onPressed: () {
                final newSelected = List<String>.from(selected);
                if (isSelected) {
                  newSelected.remove(option);
                } else {
                  newSelected.add(option);
                }
                onChanged(newSelected);
              },
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
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
