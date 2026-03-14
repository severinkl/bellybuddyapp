import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_password_hint.dart';
import '../../../widgets/common/settings_section_card.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deleteConfirmController = TextEditingController();
  bool _isChangingPassword = false;
  bool _isDeleting = false;
  bool _passwordSectionExpanded = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  // Password validation
  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUppercase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;
  bool get _allRequirementsMet =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;
  bool get _canSubmitPassword =>
      _allRequirementsMet &&
      _passwordsMatch &&
      _currentPasswordController.text.isNotEmpty;

  Future<void> _changePassword() async {
    if (!_canSubmitPassword) return;
    setState(() => _isChangingPassword = true);
    try {
      // Verify current password first
      final email = SupabaseService.currentUser?.email;
      if (email == null) throw Exception('No email found');
      await AuthService.signInWithEmail(email, _currentPasswordController.text);

      // Update to new password
      await AuthService.updatePassword(_newPasswordController.text);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        setState(() => _passwordSectionExpanded = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort geändert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktuelles Passwort ist falsch oder ein Fehler ist aufgetreten.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = SupabaseService.currentUser?.email;
    if (email == null) return;
    try {
      await AuthService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link zum Zurücksetzen wurde gesendet.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Senden des Links.')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) context.go(RoutePaths.auth);
  }

  void _showDeleteDialog() {
    _deleteConfirmController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.destructive.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.destructive, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Konto löschen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Diese Aktion kann nicht rückgängig gemacht werden. Folgende Daten werden gelöscht:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              // Bullet list
              const _BulletItem('Alle Ernährungstagebuch-Einträge'),
              const _BulletItem('Dein Profil und Einstellungen'),
              const _BulletItem('Alle gespeicherten Rezepte'),
              const _BulletItem('Dein Benutzerkonto'),
              const SizedBox(height: 16),
              TextField(
                controller: _deleteConfirmController,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: _deleteConfirmController.text == 'LÖSCHEN'
                  ? () async {
                      Navigator.pop(context);
                      setState(() => _isDeleting = true);
                      try {
                        await AuthService.deleteAccount();
                        if (!dialogContext.mounted) return;
                        context.go(RoutePaths.auth);
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fehler beim Löschen.')),
                        );
                        setState(() => _isDeleting = false);
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
    final authMethod = AuthService.detectAuthMethod();
    final showPasswordSection = authMethod == 'email' || authMethod == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto & Sicherheit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Anmeldemethode', value: _formatAuthMethod(authMethod)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Password section
            if (showPasswordSection) ...[
              _buildPasswordSection(),
              const SizedBox(height: 16),
            ],

            // Sign out
            BbButton(
              label: 'Abmelden',
              isOutlined: true,
              onPressed: _signOut,
            ),
            const SizedBox(height: 24),

            // Danger zone
            SettingsSectionCard(
              icon: Icons.warning_amber_rounded,
              title: 'Gefahrenzone',
              iconColor: AppTheme.destructive,
              titleColor: AppTheme.destructive,
              cardColor: AppTheme.destructive.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Das Löschen deines Kontos entfernt alle deine Daten dauerhaft. Diese Aktion kann nicht rückgängig gemacht werden.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return GestureDetector(
      onTap: () => setState(() => _passwordSectionExpanded = !_passwordSectionExpanded),
      child: SettingsSectionCard(
        icon: Icons.lock_outline,
        title: 'Passwort ändern',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Passwort aktualisieren',
                  style: TextStyle(fontSize: 14, color: AppTheme.mutedForeground),
                ),
                const Spacer(),
                Icon(
                  _passwordSectionExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.mutedForeground,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildPasswordFields(),
              crossFadeState: _passwordSectionExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordFields() {
    return GestureDetector(
      // Prevent card tap from toggling when interacting with fields
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current password
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Aktuelles Passwort',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // New password
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: 'Neues Passwort',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Strength checklist
            BbPasswordHint(text: 'Mindestens 8 Zeichen', isValid: _hasMinLength),
            BbPasswordHint(text: 'Mindestens 1 Großbuchstabe', isValid: _hasUppercase),
            BbPasswordHint(text: 'Mindestens 1 Kleinbuchstabe', isValid: _hasLowercase),
            BbPasswordHint(text: 'Mindestens 1 Zahl', isValid: _hasNumber),
            const SizedBox(height: 12),

            // Confirm password
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Passwort bestätigen',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_confirmPasswordController.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _passwordsMatch ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: _passwordsMatch ? AppTheme.success : AppTheme.destructive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _passwordsMatch ? 'Passwörter stimmen überein' : 'Passwörter stimmen nicht überein',
                    style: TextStyle(
                      fontSize: 13,
                      color: _passwordsMatch ? AppTheme.success : AppTheme.destructive,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Passwort vergessen?',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Submit button
            BbButton(
              label: 'Passwort ändern',
              isLoading: _isChangingPassword,
              onPressed: _canSubmitPassword ? _changePassword : null,
            ),
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
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.mutedForeground)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
