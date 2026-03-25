import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/settings_section_card.dart';
import 'delete_account_dialog.dart';
import 'password_change_section.dart';
import '../../../config/constants.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  bool _isDeleting = false;

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go(RoutePaths.auth);
  }

  void _showDeleteDialog() async {
    final deleted = await showDeleteAccountDialog(context);
    if (deleted && mounted) {
      setState(() => _isDeleting = true);
    }
  }

  String _formatAuthMethod(String? method) {
    return switch (method) {
      'google' => 'Google',
      'apple' => 'Apple',
      'email' => 'E-Mail',
      _ => 'E-Mail',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final authMethod = ref.watch(authServiceProvider).detectAuthMethod();
    final showPasswordSection = authMethod == 'email' || authMethod == null;

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Konto & Sicherheit'),
      ),
      body: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account info card
            SettingsSectionCard(
              icon: Icons.person_outline,
              title: 'Kontoinformationen',
              child: Column(
                children: [
                  _InfoRow(label: 'E-Mail', value: user?.email ?? '—'),
                  AppConstants.gap8,
                  _InfoRow(
                    label: 'Anmeldemethode',
                    value: _formatAuthMethod(authMethod),
                  ),
                  if (showPasswordSection) ...[
                    AppConstants.gap12,
                    const PasswordChangeSection(),
                  ],
                ],
              ),
            ),
            AppConstants.gap16,

            // Sign out
            BbButton(
              label: 'Abmelden',
              isSecondary: true,
              icon: Icons.logout,
              onPressed: _signOut,
            ),
            AppConstants.gap24,

            // Danger zone
            SettingsSectionCard(
              icon: Icons.warning_amber_rounded,
              title: 'Gefahrenzone',
              iconColor: AppTheme.destructive,
              titleColor: AppTheme.destructive,
              cardColor: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Das Löschen deines Kontos entfernt alle deine Daten dauerhaft. Diese Aktion kann nicht rückgängig gemacht werden.',
                    style: TextStyle(fontSize: AppTheme.fontSizeBody),
                  ),
                  AppConstants.gap16,
                  BbButton(
                    label: _isDeleting ? 'Wird gelöscht...' : 'Konto löschen',
                    isDestructive: true,
                    icon: Icons.delete_outline,
                    isLoading: _isDeleting,
                    onPressed: _showDeleteDialog,
                  ),
                ],
              ),
            ),
            AppConstants.gap32,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
