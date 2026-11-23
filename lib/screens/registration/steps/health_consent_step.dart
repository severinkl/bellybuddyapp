import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../health_consent/widgets/health_consent_content.dart';

/// Registration step right after the Buddy's name: the GDPR Art. 9 consent
/// to health-data processing, asked before any health data (body data, diet,
/// symptoms, intolerances) is collected. The text scrolls; the privacy
/// policy link and the checkbox stay pinned below it, right above the
/// wizard's „Weiter" (disabled until it is ticked), so neither is hidden
/// below the fold. The Buddy's bubble above
/// says one quiet line; the title stays because this is a legal text.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppConstants.wizardStepPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  key: titleKey,
                  'Deine Gesundheitsdaten',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeHeading,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap12,
                HealthConsentContent(
                  checked: checked,
                  onChanged: onChanged,
                  showCheckbox: false,
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingXs,
              AppConstants.spacingLg,
              AppConstants.spacingSm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HealthConsentPrivacyLink(),
                HealthConsentCheckbox(checked: checked, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
