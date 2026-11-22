import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/mascot_image.dart';
import '../settings/widgets/delete_account_dialog.dart';

/// Asks a signed-in user for explicit consent (GDPR Art. 9) to the
/// processing of their health data. The router keeps the user here while
/// `healthConsentRequiredProvider` is set; the only ways out are consenting,
/// signing out, or deleting the account.
class HealthConsentScreen extends ConsumerStatefulWidget {
  const HealthConsentScreen({super.key});

  static const consentCheckboxKey = Key('health_consent_checkbox');
  static const acceptButtonKey = Key('health_consent_accept_button');

  @override
  ConsumerState<HealthConsentScreen> createState() =>
      _HealthConsentScreenState();
}

class _HealthConsentScreenState extends ConsumerState<HealthConsentScreen> {
  static const _log = AppLogger('HealthConsent');

  bool _consentChecked = false;
  bool _isSaving = false;

  Future<void> _accept() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).acceptHealthConsent();
      if (mounted) context.go(RoutePaths.dashboard);
    } catch (e, st) {
      _log.error('acceptHealthConsent failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Deine Einwilligung konnte nicht gespeichert werden. '
              'Bitte versuche es erneut.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go(RoutePaths.auth);
    } catch (e, st) {
      _log.error('signOut failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abmelden fehlgeschlagen.')),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(AppConstants.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      _log.error('opening privacy policy failed', e, st);
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.screenBackground,
        body: SafeArea(
          child: SingleChildScrollView(
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
                  'Deine Gesundheitsdaten',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeHeadingLG,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap16,
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
                    onPressed: _openPrivacyPolicy,
                    icon: const Icon(
                      Icons.open_in_new,
                      size: AppConstants.iconSizeXs,
                    ),
                    label: const Text('Datenschutzerklärung lesen'),
                  ),
                ),
                AppConstants.gap8,
                InkWell(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  onTap: _isSaving
                      ? null
                      : () =>
                            setState(() => _consentChecked = !_consentChecked),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        key: HealthConsentScreen.consentCheckboxKey,
                        value: _consentChecked,
                        activeColor: AppTheme.primary,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => _consentChecked = v!),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: AppConstants.spacing12),
                          child: Text(
                            'Ich willige ausdrücklich ein, dass meine '
                            'Gesundheitsdaten wie beschrieben verarbeitet '
                            'werden.',
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
                AppConstants.gap24,
                BbButton(
                  tapKey: HealthConsentScreen.acceptButtonKey,
                  label: 'Zustimmen und fortfahren',
                  isLoading: _isSaving,
                  onPressed: _consentChecked ? _accept : null,
                ),
                AppConstants.gap12,
                BbButton(
                  label: 'Abmelden',
                  isSecondary: true,
                  icon: Icons.logout,
                  onPressed: _isSaving ? null : _signOut,
                ),
                AppConstants.gap8,
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.destructive,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => showDeleteAccountDialog(context),
                  child: const Text('Konto löschen'),
                ),
              ],
            ),
          ),
        ),
      ),
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
