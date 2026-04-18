import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/tutorial_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_settings_item.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _restartTutorial(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tour neu starten?'),
        content: const Text(
          'Möchtest du die Einführung erneut starten? Die Tour wird beim nächsten Öffnen des Dashboards angezeigt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Neu starten'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(tutorialProvider.notifier).reset();
      if (!context.mounted) return;
      router.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Konnte die Tour nicht zurücksetzen. Bitte versuche es später erneut.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            AppConstants.gap12,
            BbSettingsItem(
              icon: Icons.replay_outlined,
              title: 'Tour neu starten',
              subtitle: 'Zeige die Einführung zum Dashboard erneut',
              onTap: () => _restartTutorial(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
