import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/app_version_service.dart';

/// Dismissible modal shown on cold start when the installed version is
/// below `latest_version` but at or above `minimum_supported_version`.
Future<void> showUpgradeAvailableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Update verfügbar'),
      content: const Text(
        'Eine neue Version von Belly Buddy ist im Store verfügbar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Später'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          onPressed: () {
            Navigator.of(ctx).pop();
            AppVersionService().openStore();
          },
          child: const Text('Jetzt aktualisieren'),
        ),
      ],
    ),
  );
}
