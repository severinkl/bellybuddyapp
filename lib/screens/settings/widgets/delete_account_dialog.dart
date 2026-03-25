import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../config/constants.dart';

/// Shows a confirmation dialog for account deletion.
///
/// Returns `true` if the account was successfully deleted.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final controller = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.destructive,
                size: 32,
              ),
            ),
            AppConstants.gap16,
            const Text(
              'Konto löschen',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppConstants.gap12,
            const Text(
              'Diese Aktion kann nicht rückgängig gemacht werden. Folgende Daten werden gelöscht:',
              style: TextStyle(fontSize: AppTheme.fontSizeBody),
            ),
            AppConstants.gap12,
            const _BulletItem('Alle Ernährungstagebuch-Einträge'),
            const _BulletItem('Dein Profil und Einstellungen'),
            const _BulletItem('Alle gespeicherten Rezepte'),
            const _BulletItem('Dein Benutzerkonto'),
            AppConstants.gap16,
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'LÖSCHEN eingeben',
                labelText: 'Bestätigung',
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: controller.text == 'LÖSCHEN'
                ? () async {
                    Navigator.pop(context);
                    try {
                      await ProviderScope.containerOf(
                        context,
                      ).read(authServiceProvider).deleteAccount();
                      if (!dialogContext.mounted) return;
                      dialogContext.go(RoutePaths.auth);
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Fehler beim Löschen.')),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.muted,
            ),
            child: const Text('Konto endgültig löschen'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result ?? false;
}

class _BulletItem extends StatelessWidget {
  final String text;

  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppTheme.mutedForeground),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: AppTheme.fontSizeBody),
            ),
          ),
        ],
      ),
    );
  }
}
