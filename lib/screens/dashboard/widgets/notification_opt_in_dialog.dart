import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/profile_provider.dart';
import '../../../repositories/notification_repository.dart';
import '../../../widgets/common/mascot_image.dart';

/// Shows the one-time notification opt-in dialog.
/// Returns `true` if the user granted permission, `false` otherwise.
Future<bool> showNotificationOptInDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _NotificationOptInDialog(),
  );
  return result ?? false;
}

class _NotificationOptInDialog extends ConsumerStatefulWidget {
  const _NotificationOptInDialog();

  @override
  ConsumerState<_NotificationOptInDialog> createState() =>
      _NotificationOptInDialogState();
}

class _NotificationOptInDialogState
    extends ConsumerState<_NotificationOptInDialog> {
  bool _loading = false;

  Future<void> _activate() async {
    final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
    if (profile == null) {
      if (mounted) Navigator.pop(context, false);
      return;
    }

    setState(() => _loading = true);

    try {
      final granted = await ref
          .read(notificationRepositoryProvider)
          .requestAllPermissions();

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyNotificationModalShown, true);
      await ref
          .read(profileProvider.notifier)
          .updateProfile(profile.copyWith(pushEnabled: granted));

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, granted);

      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Du kannst Benachrichtigungen jederzeit in den Einstellungen aktivieren.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyNotificationModalShown, true);
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      contentPadding: AppConstants.paddingLg,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: _dismiss,
              child: const Icon(Icons.close, color: AppTheme.mutedForeground),
            ),
          ),
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: 96,
            height: 96,
          ),
          AppConstants.gap16,
          const Text(
            'Bleib auf dem Laufenden!',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap12,
          const Text(
            'Erhalte Erinnerungen zum Tracken, eine tägliche '
            'Zusammenfassung und persönliche Tipps für '
            'dein Wohlbefinden.',
            style: TextStyle(fontSize: AppTheme.fontSizeBody),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap24,
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: _loading ? null : _activate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: AppConstants.spinnerSize,
                      height: AppConstants.spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Aktivieren'),
            ),
          ),
        ],
      ),
    );
  }
}
