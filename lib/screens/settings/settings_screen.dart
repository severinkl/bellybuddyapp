import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../router/route_names.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_settings_item.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.openUrl = launchUrl});

  static const productDataKey = Key('settings_product_data');

  /// Opens the links of the product-data dialog.
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Einstellungen'),
      ),
      body: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          children: [
            BbSettingsItem(
              icon: Icons.person_outline,
              title: 'Mein Profil',
              subtitle: 'Persönliche Daten, Ernährung & Symptome',
              onTap: () => context.push(RoutePaths.settingsProfile),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Benachrichtigungen',
              subtitle: 'Push-Benachrichtigungen & Erinnerungen',
              onTap: () => context.push(RoutePaths.settingsNotifications),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.shield_outlined,
              title: 'Konto & Sicherheit',
              subtitle: 'Abmelden, Passwort ändern, Konto verwalten',
              onTap: () => context.push(RoutePaths.settingsAccount),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Datenschutzerklärung',
              subtitle: 'Wie wir deine Daten verarbeiten',
              onTap: () => launchUrl(
                Uri.parse(AppConstants.privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            AppConstants.gap12,
            BbSettingsItem(
              key: productDataKey,
              icon: Icons.inventory_2_outlined,
              title: 'Produktdaten',
              subtitle: 'Open Food Facts, Lizenz ODbL',
              onTap: () => _showProductDataDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) => openExternalUrl(
    context,
    url,
    failureMessage: 'Link konnte nicht geöffnet werden.',
    open: openUrl,
  );

  Future<void> _showProductDataDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produktdaten von Open Food Facts'),
        content: const Text(
          'Name, Marke und Zutaten von Produkten, die du scannst oder '
          'suchst, stammen aus Open Food Facts, einer freien '
          'Lebensmitteldatenbank. Die Daten stehen unter der Open '
          'Database License (ODbL).',
        ),
        actions: [
          TextButton(
            onPressed: () => _openLink(context, AppConstants.offHomeUrl),
            child: const Text('Open Food Facts öffnen'),
          ),
          TextButton(
            onPressed: () => _openLink(context, AppConstants.odblLicenseUrl),
            child: const Text('Lizenz ansehen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}
