import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';

import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common/bb_button.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _deleteConfirmController = TextEditingController();
  bool _isChangingPassword = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort muss mindestens 8 Zeichen lang sein.')),
      );
      return;
    }
    setState(() => _isChangingPassword = true);
    try {
      await AuthService.updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _currentPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort geändert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Ändern des Passworts.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) context.go(RoutePaths.auth);
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Diese Aktion kann nicht rückgängig gemacht werden. '
              'Gib "LÖSCHEN" ein, um dein Konto endgültig zu löschen.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deleteConfirmController,
              decoration: const InputDecoration(hintText: 'LÖSCHEN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              if (_deleteConfirmController.text != 'LÖSCHEN') return;
              Navigator.pop(context);
              setState(() => _isDeleting = true);
              try {
                await AuthService.deleteAccount();
                if (!context.mounted) return;
                context.go(RoutePaths.auth);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fehler beim Löschen.')),
                );
                setState(() => _isDeleting = false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final authMethod = AuthService.detectAuthMethod();
    final isEmailUser = authMethod == 'email';

    return Scaffold(
      appBar: AppBar(title: const Text('Konto & Sicherheit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account info
            const Text('Konto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('E-Mail: ${user?.email ?? '—'}'),
            Text('Anmeldung: ${authMethod ?? '—'}'),
            const SizedBox(height: 24),

            // Password change (email only)
            if (isEmailUser) ...[
              const Text('Passwort ändern', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Neues Passwort'),
              ),
              const SizedBox(height: 12),
              BbButton(
                label: 'Passwort ändern',
                isLoading: _isChangingPassword,
                onPressed: _changePassword,
              ),
              const SizedBox(height: 32),
            ],

            // Sign out
            BbButton(
              label: 'Abmelden',
              isOutlined: true,
              onPressed: _signOut,
            ),
            const SizedBox(height: 16),

            // Delete account
            BbButton(
              label: _isDeleting ? 'Wird gelöscht...' : 'Konto löschen',
              isDestructive: true,
              isOutlined: true,
              isLoading: _isDeleting,
              onPressed: _showDeleteDialog,
            ),
          ],
        ),
      ),
    );
  }
}
