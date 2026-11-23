import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_scroll_picker.dart';
import '../widgets/step_field_label.dart';

class BirthYearStep extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;
  static const birthYearTitleKey = Key('birth_year_title');

  const BirthYearStep({super.key, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (i) => currentYear - 10 - i);

    return Padding(
      padding: AppConstants.wizardStepPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepFieldLabel(
            key: birthYearTitleKey,
            'Geburtsjahr',
            helper: 'Hilft mir, deine Verdauung besser zu analysieren.',
          ),
          AppConstants.gap16,
          Expanded(
            child: Container(
              padding: AppConstants.paddingMd,
              decoration: BoxDecoration(
                color: AppTheme.beige,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              child: BbScrollPicker(
                items: years,
                selectedValue: value,
                onChanged: onChanged,
                expand: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
