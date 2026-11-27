import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/plus_provider.dart';
import '../../../services/plus/plus_copy.dart';
import '../../../services/purchases/purchases_gateway.dart';
import '../../../utils/logger.dart';

/// Whether [typed] confirms the deletion: „LÖSCHEN", trimmed and in any
/// case, with „Ö" also written „OE" (keyboards without umlauts) or as an O
/// with a combining diaeresis.
bool isDeleteConfirmation(String typed) =>
    typed
        .trim()
        .toUpperCase()
        .replaceAll('O\u0308', 'OE')
        .replaceAll('Ö', 'OE') ==
    'LOESCHEN';

/// Shows a confirmation dialog for account deletion.
///
/// Returns `true` if the user confirmed deletion. The actual delete call
/// runs inside the dialog — by the time this future resolves the account
/// is already being torn down and the auth state is flipping.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return result ?? false;
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  static const _log = AppLogger('DeleteAccountDialog');
  static const _confirmWord = 'LÖSCHEN';

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canDelete => isDeleteConfirmation(_controller.text);

  Future<void> _confirmDelete() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop(true);
    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
      // Signed out, the router has moved on to the welcome screen; the
      // snack bar shows there.
      messenger.showSnackBar(
        const SnackBar(content: Text('Dein Konto wurde gelöscht.')),
      );
    } catch (e, st) {
      _log.error('deleteAccount failed', e, st);
      messenger.showSnackBar(
        const SnackBar(content: Text('Fehler beim Löschen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The store keeps billing a subscription the deletion leaves behind. Said
    // also while the status is unknown (loading, failed): a subscriber must
    // not miss it. Not once it is cancelled (no renewal).
    final storeOn =
        ref.watch(paywallEnabledProvider) &&
        ref.watch(purchasesGatewayProvider.select((g) => g.available));
    final subscribed =
        storeOn &&
        ref.watch(
          plusProvider.select(
            (p) =>
                p.isLoading ||
                p.hasError ||
                (p.value?.granted == true && p.value!.willRenew),
          ),
        );
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppConstants.iconBadgeXl,
            height: AppConstants.iconBadgeXl,
            decoration: BoxDecoration(
              color: AppTheme.destructive.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.destructive,
              size: AppConstants.iconSizeLg,
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
          const _BulletItem('Alle Tagebuch-Einträge'),
          const _BulletItem('Dein Profil und Einstellungen'),
          const _BulletItem('Alle gespeicherten Rezepte'),
          const _BulletItem('Dein Benutzerkonto'),
          if (subscribed) ...[
            AppConstants.gap12,
            const Text(
              PlusCopy.deleteWarning,
              style: TextStyle(fontSize: AppTheme.fontSizeBody),
            ),
          ],
          AppConstants.gap16,
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: '$_confirmWord eingeben',
              labelText: 'Bestätigung',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _canDelete ? _confirmDelete : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.destructive,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.muted,
          ),
          child: const Text('Konto endgültig löschen'),
        ),
      ],
    );
  }
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
