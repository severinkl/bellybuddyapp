import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../providers/auth_provider.dart';

import '../../../utils/password_validator.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_password_hint.dart';
import '../../../config/constants.dart';

class PasswordChangeSection extends ConsumerStatefulWidget {
  const PasswordChangeSection({super.key});

  @override
  ConsumerState<PasswordChangeSection> createState() =>
      _PasswordChangeSectionState();
}

class _PasswordChangeSectionState extends ConsumerState<PasswordChangeSection> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _expanded = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  PasswordValidation get _validation =>
      PasswordValidator.validate(_newPasswordController.text);
  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;
  bool get _canSubmitPassword => PasswordValidator.canSubmit(
    currentPassword: _currentPasswordController.text,
    newPassword: _newPasswordController.text,
    confirmPassword: _confirmPasswordController.text,
  );

  Future<void> _changePassword() async {
    if (!_canSubmitPassword) return;
    setState(() => _isChangingPassword = true);
    try {
      final email = ref.read(currentUserProvider)?.email;
      if (email == null) throw Exception('No email found');
      final notifier = ref.read(authNotifierProvider.notifier);
      await notifier.signInWithEmail(email, _currentPasswordController.text);
      await notifier.updatePassword(_newPasswordController.text);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        setState(() => _expanded = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Passwort geändert!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aktuelles Passwort ist falsch oder ein Fehler ist aufgetreten.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = ref.read(currentUserProvider)?.email;
    if (email == null) return;
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link zum Zurücksetzen wurde gesendet.'),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppTheme.border),
        AppConstants.gap12,
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 20,
                color: AppTheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              const Text(
                'Passwort ändern',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.mutedForeground,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildPasswordFields(),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildPasswordFields() {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Aktuelles Passwort',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AppConstants.gap12,
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: 'Neues Passwort',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AppConstants.gap12,
            BbPasswordHint(
              text: 'Mindestens 8 Zeichen',
              isValid: _validation.hasMinLength,
            ),
            BbPasswordHint(
              text: 'Mindestens 1 Großbuchstabe',
              isValid: _validation.hasUppercase,
            ),
            BbPasswordHint(
              text: 'Mindestens 1 Kleinbuchstabe',
              isValid: _validation.hasLowercase,
            ),
            BbPasswordHint(
              text: 'Mindestens 1 Zahl',
              isValid: _validation.hasNumber,
            ),
            AppConstants.gap12,
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Passwort bestätigen',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_confirmPasswordController.text.isNotEmpty) ...[
              AppConstants.gap4,
              Row(
                children: [
                  Icon(
                    _passwordsMatch ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: _passwordsMatch
                        ? AppTheme.success
                        : AppTheme.destructive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _passwordsMatch
                        ? 'Passwörter stimmen überein'
                        : 'Passwörter stimmen nicht überein',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: _passwordsMatch
                          ? AppTheme.success
                          : AppTheme.destructive,
                    ),
                  ),
                ],
              ),
            ],
            AppConstants.gap8,
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
                  style: TextStyle(fontSize: AppTheme.fontSizeCaptionLG),
                ),
              ),
            ),
            AppConstants.gap16,
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
