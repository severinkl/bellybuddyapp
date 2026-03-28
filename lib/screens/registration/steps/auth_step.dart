import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../router/route_names.dart';
import '../../../widgets/common/bb_auth_banner.dart';
import '../../../utils/password_validator.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_password_field.dart';
import '../../../widgets/common/bb_password_hint.dart';
import '../../../widgets/common/bb_social_button.dart';

class AuthStep extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final Future<void> Function(String email, String password) onEmailSignUp;
  final Future<void> Function() onGoogleSignUp;
  final Future<void> Function() onAppleSignUp;
  static const emailFieldKey = Key('auth_email_field');

  const AuthStep({
    super.key,
    required this.isLoading,
    required this.error,
    required this.onEmailSignUp,
    required this.onGoogleSignUp,
    required this.onAppleSignUp,
  });

  @override
  State<AuthStep> createState() => _AuthStepState();
}

class _AuthStepState extends State<AuthStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  PasswordValidation get _validation =>
      PasswordValidator.validate(_passwordController.text);

  bool get _isPasswordValid => _validation.allMet;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPasswordValid) return;
    widget.onEmailSignUp(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppConstants.paddingLg,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppConstants.gap16,
            const Text(
              'Konto erstellen',
              style: TextStyle(
                fontSize: AppTheme.fontSizeDisplay,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            AppConstants.gap8,
            const Text(
              'Erstelle dein Konto, um dein Profil zu speichern.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLG,
                color: AppTheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            AppConstants.gap32,

            if (widget.error != null)
              BbAuthBanner(text: widget.error!, isError: true),

            TextFormField(
              key: AuthStep.emailFieldKey,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                hintText: 'deine@email.de',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'E-Mail ist erforderlich';
                }
                if (!v.contains('@')) return 'Ungültige E-Mail';
                return null;
              },
            ),
            AppConstants.gap16,

            BbPasswordField(
              controller: _passwordController,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Passwort ist erforderlich';
                return null;
              },
            ),
            if (_passwordController.text.isNotEmpty) ...[
              AppConstants.gap8,
              BbPasswordHint(
                text: 'Mindestens 8 Zeichen',
                isValid: _validation.hasMinLength,
              ),
              BbPasswordHint(
                text: 'Mindestens ein Großbuchstabe',
                isValid: _validation.hasUppercase,
              ),
              BbPasswordHint(
                text: 'Mindestens ein Kleinbuchstabe',
                isValid: _validation.hasLowercase,
              ),
              BbPasswordHint(
                text: 'Mindestens eine Zahl',
                isValid: _validation.hasNumber,
              ),
            ],
            AppConstants.gap24,

            BbButton(
              label: 'Registrieren',
              isLoading: widget.isLoading,
              onPressed: _isPasswordValid ? _submit : null,
            ),

            AppConstants.gap24,
            const Row(
              children: [
                Expanded(child: Divider(color: AppTheme.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'oder',
                    style: TextStyle(color: AppTheme.mutedForeground),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.border)),
              ],
            ),
            AppConstants.gap24,

            BbSocialButton.google(
              onPressed: widget.isLoading ? null : widget.onGoogleSignUp,
            ),

            if (Platform.isIOS) ...[
              AppConstants.gap12,
              BbSocialButton.apple(
                onPressed: widget.isLoading ? null : widget.onAppleSignUp,
              ),
            ],

            AppConstants.gap24,
            TextButton(
              onPressed: () => context.go(RoutePaths.auth),
              child: const Text('Bereits registriert? Anmelden'),
            ),
          ],
        ),
      ),
    );
  }
}
