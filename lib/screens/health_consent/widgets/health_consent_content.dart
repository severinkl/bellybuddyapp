import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../utils/logger.dart';

/// The GDPR Art. 9 health-data consent text, the privacy policy link and the
/// explicit-consent checkbox. Shared by the post-login [HealthConsentScreen]
/// and the registration wizard's consent step so both ask for the same
/// consent with the same wording.
class HealthConsentContent extends StatelessWidget {
  /// Whether the consent checkbox is ticked.
  final bool checked;

  /// Called with the new checkbox value; null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  static const checkboxKey = Key('health_consent_checkbox');
  static const consentText =
      'Ich willige ausdrücklich ein, dass meine Gesundheitsdaten wie '
      'beschrieben verarbeitet werden.';

  static const _log = AppLogger('HealthConsentContent');

  const HealthConsentContent({
    super.key,
    required this.checked,
    required this.onChanged,
  });

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(AppConstants.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      _log.error('opening privacy policy failed', e, st);
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Die Datenschutzerklärung konnte nicht geöffnet werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Belly Buddy verarbeitet Gesundheitsdaten von dir, um dir '
          'Muster und FODMAP-Hinweise zu zeigen. Dazu gehören:',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.foreground,
          ),
        ),
        AppConstants.gap8,
        const _Bullet('Mahlzeiten mit Fotos'),
        const _Bullet('Getränke'),
        const _Bullet('Bauchgefühl und Symptome'),
        const _Bullet('Toiletten-Einträge'),
        AppConstants.gap12,
        const Text(
          'Fotos und Beschreibungen deiner Mahlzeiten werden von einem '
          'KI-Dienst (Anthropic, USA) analysiert.',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.foreground,
          ),
        ),
        AppConstants.gap12,
        const Text(
          'Du kannst deine Einwilligung jederzeit widerrufen, indem du '
          'dein Konto in den Einstellungen löschst.',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
        AppConstants.gap8,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openPrivacyPolicy(context),
            icon: const Icon(Icons.open_in_new, size: AppConstants.iconSizeXs),
            label: const Text('Datenschutzerklärung lesen'),
          ),
        ),
        AppConstants.gap8,
        InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          onTap: onChanged == null ? null : () => onChanged(!checked),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: checkboxKey,
                value: checked,
                activeColor: AppTheme.primary,
                onChanged: onChanged == null
                    ? null
                    : (v) => onChanged(v ?? false),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: AppConstants.spacing12),
                  child: Text(
                    consentText,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.spacingXs,
        bottom: AppConstants.spacingXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: AppConstants.iconSizeXs,
            color: AppTheme.primary,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
