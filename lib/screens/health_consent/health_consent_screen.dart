import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_consent_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/mascot_image.dart';
import '../settings/widgets/delete_account_dialog.dart';
import 'widgets/health_consent_content.dart';

/// Asks a signed-in user for explicit consent (GDPR Art. 9) to the
/// processing of their health data. The router keeps the user here while
/// `healthConsentRequiredProvider` is set; the only ways out are consenting,
/// signing out, or deleting the account. A user who consented to an older
/// policy version first reads that the policy changed.
class HealthConsentScreen extends ConsumerStatefulWidget {
  const HealthConsentScreen({super.key});

  static const consentCheckboxKey = HealthConsentContent.checkboxKey;
  static const acceptButtonKey = Key('health_consent_accept_button');

  /// Above the copy when the user consented to an older policy version.
  static String get policyUpdated =>
      'Wir haben unsere Datenschutzerklärung aktualisiert (Stand '
      '${formatDateShort(DateTime.parse(AppConstants.privacyPolicyVersion))}).';

  @override
  ConsumerState<HealthConsentScreen> createState() =>
      _HealthConsentScreenState();
}

class _HealthConsentScreenState extends ConsumerState<HealthConsentScreen> {
  static const _log = AppLogger('HealthConsent');

  bool _consentChecked = false;
  bool _isSaving = false;

  /// Whether [HealthConsentScreen.policyUpdated] shows, as the profile was
  /// when the screen came (the gate shows it only for a loaded profile).
  /// Read once: the accepted consent makes the profile current while the
  /// screen is still leaving, and the text must not jump then.
  late final bool _policyUpdated = consentedToOlderPolicy(
    ref.read(profileProvider).value,
  );

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
                if (_policyUpdated) ...[
                  Text(
                    HealthConsentScreen.policyUpdated,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  AppConstants.gap12,
                ],
                HealthConsentContent(
                  checked: _consentChecked,
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() => _consentChecked = v),
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
