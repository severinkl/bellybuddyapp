import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_settings_item.dart';
import '../../config/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = ref.watch(currentUserProvider)?.email;

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Einstellungen'),
      ),
      body: Padding(
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
              icon: Icons.feedback_outlined,
              title: 'Feedback geben',
              subtitle: 'Teile uns deine Ideen und Wünsche mit',
              onTap: () => launchUrl(
                Uri.parse(AppConstants.feedbackFormUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            if (AppConstants.adminEmails.contains(userEmail)) ...[
              AppConstants.gap12,
              BbSettingsItem(
                icon: Icons.bug_report_outlined,
                title: 'Sentry Test-Error',
                subtitle: 'Test-Exception an Sentry senden',
                onTap: () {
                  Sentry.captureException(
                    StateError('Test error from settings'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test-Error gesendet!')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
