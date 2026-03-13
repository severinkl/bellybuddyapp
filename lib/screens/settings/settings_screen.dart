import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_settings_item.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            BbSettingsItem(
              icon: Icons.person_outline,
              title: 'Mein Profil',
              subtitle: 'Persönliche Daten, Ernährung & Symptome',
              onTap: () => context.push(RoutePaths.settingsProfile),
            ),
            const SizedBox(height: 12),
            BbSettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Benachrichtigungen',
              subtitle: 'Push-Nachrichten & Erinnerungen',
              onTap: () => context.push(RoutePaths.settingsNotifications),
            ),
            const SizedBox(height: 12),
            BbSettingsItem(
              icon: Icons.lock_outline,
              title: 'Konto & Sicherheit',
              subtitle: 'Abmelden, Passwort ändern, Konto verwalten',
              onTap: () => context.push(RoutePaths.settingsAccount),
            ),
          ],
        ),
      ),
    );
  }
}
