import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/mascot_image.dart';
import '../../health_consent/widgets/health_consent_content.dart';

/// First registration step: the GDPR Art. 9 consent to health-data
/// processing, asked before any health data (body data, diet, symptoms,
/// intolerances) is collected. The wizard keeps "Weiter" disabled until the
/// checkbox is ticked.
class HealthConsentStep extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;
  static const titleKey = Key('health_consent_step_title');

  const HealthConsentStep({
    super.key,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotProfessor,
            width: AppConstants.mascotSizeMd,
            height: AppConstants.mascotSizeMd,
          ),
          AppConstants.gap16,
          const Text(
            key: titleKey,
            'Deine Gesundheitsdaten',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap16,
          HealthConsentContent(checked: checked, onChanged: onChanged),
        ],
      ),
    );
  }
}
